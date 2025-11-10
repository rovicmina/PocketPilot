import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import 'package:flutter/foundation.dart';
import '../models/user.dart' as app_user;
import '../models/transaction.dart' as app_transaction;
import '../models/reminder.dart';
import '../models/budget.dart';
import '../models/goal.dart';
import '../models/debt.dart';
import 'enhanced_network_service.dart';

/// Enhanced Firebase service with better network resilience
class EnhancedFirebaseService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Get current user ID
  static String? get currentUserId => _auth.currentUser?.uid;

  // Check current authentication status with enhanced resilience
  static Future<Map<String, dynamic>> getAuthStatus() async {
    return await EnhancedNetworkService.executeWithResilience(
      () async {
        try {
          final user = _auth.currentUser;
          if (user == null) {
            return {
              'authenticated': false,
              'userId': null,
              'email': null,
              'message': 'No user is currently signed in'
            };
          }

          // Wait for the user to be fully loaded with timeout
          await user.reload().timeout(const Duration(seconds: 5));
          final refreshedUser = _auth.currentUser;

          return {
            'authenticated': true,
            'userId': refreshedUser?.uid,
            'email': refreshedUser?.email,
            'emailVerified': refreshedUser?.emailVerified,
            'isAnonymous': refreshedUser?.isAnonymous,
            'creationTime': refreshedUser?.metadata.creationTime?.toIso8601String(),
            'lastSignInTime': refreshedUser?.metadata.lastSignInTime?.toIso8601String(),
            'message': 'User is authenticated'
          };
        } on TimeoutException catch (e) {
          debugPrint('Auth status check timed out: $e');
          return {
            'authenticated': false,
            'userId': null,
            'email': null,
            'message': 'Authentication check timed out'
          };
        } catch (e) {
          debugPrint('Auth status check error: $e');
          return {
            'authenticated': false,
            'userId': null,
            'email': null,
            'message': 'Error checking authentication status'
          };
        }
      },
      timeout: const Duration(seconds: 10),
      retryOnTimeout: true,
      retryOnNetworkError: true,
    );
  }

  // Force refresh authentication token with enhanced resilience
  static Future<bool> refreshAuthToken() async {
    return await EnhancedNetworkService.executeWithResilience(
      () async {
        final user = _auth.currentUser;
        if (user == null) return false;

        try {
          await user.getIdToken(true); // Force refresh
          return true;
        } on FirebaseAuthException catch (e) {
          debugPrint('Failed to refresh auth token (FirebaseAuthException): ${e.code} - ${e.message}');
          return false;
        } on TimeoutException catch (e) {
          debugPrint('Failed to refresh auth token (TimeoutException): $e');
          return false;
        } catch (e) {
          debugPrint('Failed to refresh auth token: $e');
          return false;
        }
      },
      timeout: const Duration(seconds: 15),
      retryOnTimeout: true,
      retryOnNetworkError: true,
    );
  }

  // User Authentication with enhanced resilience
  static Future<Map<String, dynamic>> registerUser(String email, String password, String name) async {
    return await EnhancedNetworkService.executeWithResilience(
      () async {
        UserCredential? userCredential;
        User? firebaseUser;
        
        try {
          // First, check if user is already authenticated and sign out if needed
          if (_auth.currentUser != null) {
            await _auth.signOut();
            await Future.delayed(const Duration(milliseconds: 500)); // Brief delay to ensure signout completes
          }

          // Pre-check: Try to verify if email is already in use by attempting sign-in
          // This helps catch existing users before attempting registration
          try {
            final testResult = await _auth.signInWithEmailAndPassword(
              email: email,
              password: 'dummy_password_for_test',
            );
            // If sign-in succeeds with any password, email exists
            if (testResult.user != null) {
              await _auth.signOut();
              return {'success': false, 'message': 'This email is already registered. Please try signing in instead.'};
            }
          } on FirebaseAuthException catch (testE) {
            // Expected behavior for new emails: wrong-password, user-not-found, invalid-credential
            if (testE.code == 'wrong-password' || testE.code == 'user-not-found' || testE.code == 'invalid-credential') {
              // Email exists but wrong password - this means email is already registered
              if (testE.code == 'wrong-password') {
                return {'success': false, 'message': 'This email is already registered. Please try signing in instead.'};
              }
              // For user-not-found or invalid-credential, proceed with registration
            } else {
              // Other errors during pre-check, log but continue with registration
              debugPrint('Pre-check error (continuing): ${testE.code} - ${testE.message}');
            }
          }

          // Proceed with user creation
          userCredential = await _auth.createUserWithEmailAndPassword(
            email: email,
            password: password,
          );

          firebaseUser = userCredential.user;
          if (firebaseUser == null) {
            return {'success': false, 'message': 'Registration failed - no user created'};
          }

          final userId = firebaseUser.uid;
          
          // Verify the user was created successfully by reloading
          await firebaseUser.reload();
          final refreshedUser = _auth.currentUser;
          
          if (refreshedUser?.uid != userId) {
            // User creation verification failed - attempt cleanup
            await _cleanupFailedRegistration(firebaseUser);
            return {'success': false, 'message': 'Registration verification failed'};
          }

          // Create user object for database
          final user = app_user.User(
            id: userId,
            email: email,
            name: name,
            password: '',
            monthlyIncome: 0.0,
            createdAt: DateTime.now(),
          );

          // Save user data to Firestore with retry mechanism
          bool dbSaveSuccess = false;
          int retryCount = 0;
          const maxRetries = 3;

          while (!dbSaveSuccess && retryCount < maxRetries) {
            try {
              await _db.collection('users').doc(userId).set(user.toJson());
              dbSaveSuccess = true;
            } catch (dbError) {
              retryCount++;
              debugPrint('Database save attempt $retryCount failed: $dbError');
              if (retryCount < maxRetries) {
                await Future.delayed(Duration(milliseconds: 500 * retryCount)); // Exponential backoff
              }
            }
          }

          if (!dbSaveSuccess) {
            // Database save failed - cleanup the Firebase Auth user
            await _cleanupFailedRegistration(firebaseUser);
            return {'success': false, 'message': 'Registration failed - could not save user data. Please try again.'};
          }

          debugPrint('Registration successful for user: $email');
          return {'success': true, 'message': 'Registration successful'};
          
        } on FirebaseAuthException catch (e) {
          debugPrint('Registration error: ${e.code} - ${e.message}');
          
          // If we have a partially created user, attempt cleanup
          if (firebaseUser != null) {
            await _cleanupFailedRegistration(firebaseUser);
          }
          
          switch (e.code) {
            case 'email-already-in-use':
              return {'success': false, 'message': 'This email is already registered. Please try signing in instead.'};
            case 'weak-password':
              return {'success': false, 'message': 'Password is too weak. Please choose a stronger password.'};
            case 'invalid-email':
              return {'success': false, 'message': 'Invalid email address format.'};
            case 'operation-not-allowed':
              return {'success': false, 'message': 'Email registration is not enabled. Please contact support.'};
            case 'network-request-failed':
              return {'success': false, 'message': 'Network error. Please check your internet connection.'};
            case 'too-many-requests':
              return {'success': false, 'message': 'Too many registration attempts. Please wait a few minutes and try again.'};
            default:
              return {'success': false, 'message': 'Registration failed: ${e.message}'};
          }
        } catch (e) {
          debugPrint('Registration error: $e');
          
          // If we have a partially created user, attempt cleanup
          if (firebaseUser != null) {
            await _cleanupFailedRegistration(firebaseUser);
          }
          
          return {'success': false, 'message': 'Registration failed. Please try again.'};
        }
      },
      timeout: const Duration(seconds: 30),
      retryOnTimeout: true,
      retryOnNetworkError: true,
      onError: (attempt, error) {
        debugPrint('Registration attempt $attempt failed: $error');
      },
    );
  }

  // Helper method to cleanup failed registration attempts
  static Future<void> _cleanupFailedRegistration(User? firebaseUser) async {
    if (firebaseUser == null) return;
    
    try {
      debugPrint('Cleaning up failed registration for user: ${firebaseUser.uid}');
      
      // Remove user document from Firestore if it exists
      try {
        await _db.collection('users').doc(firebaseUser.uid).delete();
        debugPrint('Removed user document from Firestore');
      } catch (dbError) {
        debugPrint('Failed to remove user document: $dbError');
      }
      
      // Delete the Firebase Auth user
      try {
        await firebaseUser.delete();
        debugPrint('Deleted Firebase Auth user');
      } catch (authError) {
        debugPrint('Failed to delete Firebase Auth user: $authError');
        // If we can't delete the user, at least sign them out
        try {
          await _auth.signOut();
        } catch (signOutError) {
          debugPrint('Failed to sign out user: $signOutError');
        }
      }
    } catch (e) {
      debugPrint('Error during registration cleanup: $e');
    }
  }

  // Enhanced method to check if email exists using sign-in attempt
  static Future<bool> checkEmailExists(String email) async {
    return await EnhancedNetworkService.executeWithResilience(
      () async {
        try {
          // Try to sign in with a dummy password to check if email exists
          await _auth.signInWithEmailAndPassword(
            email: email,
            password: 'dummy_password_12345',
          );
          // If this succeeds, email exists (though this is unlikely with dummy password)
          await _auth.signOut();
          return true;
        } on FirebaseAuthException catch (e) {
          switch (e.code) {
            case 'wrong-password':
            case 'invalid-credential':
              // Email exists but wrong password
              return true;
            case 'user-not-found':
              // Email doesn't exist
              return false;
            case 'too-many-requests':
              // Rate limited - assume email exists to be safe
              return true;
            default:
              debugPrint('Error checking email existence: ${e.code} - ${e.message}');
              return false; // Assume email doesn't exist if we can't check
          }
        } catch (e) {
          debugPrint('Error checking email existence: $e');
          return false; // Assume email doesn't exist if we can't check
        }
      },
      timeout: const Duration(seconds: 10),
      retryOnTimeout: true,
      retryOnNetworkError: true,
    );
  }

  static Future<Map<String, dynamic>> loginUser(String email, String password) async {
    return await EnhancedNetworkService.executeWithResilience(
      () async {
        debugPrint('LoginUser: Starting login attempt for email: $email');

        try {
          final userCredential = await _auth.signInWithEmailAndPassword(
            email: email,
            password: password,
          );

          final user = userCredential.user;
          debugPrint('LoginUser: Firebase Auth successful for user: ${user?.uid}');

          if (user == null) {
            debugPrint('LoginUser: UserCredential.user is null');
            return {'success': false, 'message': 'Authentication failed - no user data received.'};
          }

          debugPrint('LoginUser: Checking profile completion');

          // Check if user profile is complete
          final isProfileComplete = await isUserProfileComplete();
          debugPrint('LoginUser: Profile complete: $isProfileComplete');

          return {
            'success': true,
            'profileComplete': isProfileComplete,
            'message': 'Login successful'
          };
        } on FirebaseAuthException catch (e) {
          debugPrint('LoginUser: FirebaseAuthException - Code: ${e.code}, Message: ${e.message}');
          switch (e.code) {
            case 'user-not-found':
              return {'success': false, 'message': 'No user found with this email address.'};
            case 'wrong-password':
              return {'success': false, 'message': 'Incorrect password.'};
            case 'invalid-email':
              return {'success': false, 'message': 'Invalid email address format.'};
            case 'user-disabled':
              return {'success': false, 'message': 'This account has been disabled.'};
            case 'too-many-requests':
              return {'success': false, 'message': 'Too many login attempts. Please wait a few minutes and try again.'};
            case 'network-request-failed':
              return {'success': false, 'message': 'Network error. Please check your internet connection.'};
            default:
              return {'success': false, 'message': 'Login failed: ${e.message}'};
          }
        } catch (e) {
          debugPrint('LoginUser: Unexpected error: $e');

          // Provide more specific error messages for common issues
          if (e.toString().contains('unknown') || e.toString().contains('internal')) {
            return {'success': false, 'message': 'Unable to connect to authentication service. Please check your internet connection and try again.'};
          } else if (e.toString().contains('network')) {
            return {'success': false, 'message': 'Network connection error. Please check your internet connection and try again.'};
          } else {
            return {'success': false, 'message': 'Login failed. Please try again.'};
          }
        }
      },
      timeout: const Duration(seconds: 20),
      retryOnTimeout: true,
      retryOnNetworkError: true,
      onError: (attempt, error) {
        debugPrint('Login attempt $attempt failed: $error');
      },
    );
  }

  static Future<void> logout() async {
    return await EnhancedNetworkService.executeWithResilience(
      () async {
        try {
          await _auth.signOut();
          debugPrint('User successfully logged out');
        } catch (e) {
          debugPrint('Error during logout: $e');
          // Even if logout fails, we'll consider it successful for UI purposes
        }
      },
      timeout: const Duration(seconds: 10),
      retryOnTimeout: false, // Don't retry logout
      retryOnNetworkError: false, // Don't retry logout
    );
  }

  static Future<bool> isLoggedIn() async {
    return await EnhancedNetworkService.executeWithResilience(
      () async {
        return _auth.currentUser != null;
      },
      timeout: const Duration(seconds: 5),
      retryOnTimeout: true,
      retryOnNetworkError: true,
    );
  }

  // Change user password with proper Firebase Auth reauthentication and timeout
  static Future<Map<String, dynamic>> changePassword(String currentPassword, String newPassword) async {
    return await EnhancedNetworkService.executeWithResilience(
      () async {
        debugPrint('ChangePassword: Starting password change process');
        
        final user = _auth.currentUser;
        if (user == null) {
          debugPrint('ChangePassword: No current user found');
          return {
            'success': false,
            'message': 'No user is currently signed in'
          };
        }

        if (user.email == null) {
          debugPrint('ChangePassword: Current user has no email');
          return {
            'success': false,
            'message': 'User account has no email address'
          };
        }

        debugPrint('ChangePassword: User found - ${user.email}');
        debugPrint('ChangePassword: User emailVerified - ${user.emailVerified}');

        try {
          // First, try to sign in again with current credentials to verify
          debugPrint('ChangePassword: Verifying current password by re-signing in');
          
          // Create a new credential with current password for verification
          final testCredential = await _auth.signInWithEmailAndPassword(
            email: user.email!,
            password: currentPassword,
          );
          
          if (testCredential.user == null) {
            debugPrint('ChangePassword: Current password verification failed');
            return {
              'success': false,
              'message': 'Current password is incorrect'
            };
          }
          
          debugPrint('ChangePassword: Current password verified, updating to new password');
          
          // Now update the password
          await testCredential.user!.updatePassword(newPassword)
              .timeout(const Duration(seconds: 15));
          
          debugPrint('ChangePassword: Password update successful');
          return {
            'success': true,
            'message': 'Password changed successfully'
          };
          
        } on FirebaseAuthException catch (e) {
          debugPrint('ChangePassword: FirebaseAuthException - Code: ${e.code}, Message: ${e.message}');
          switch (e.code) {
            case 'wrong-password':
            case 'invalid-credential':
            case 'user-not-found':
              return {
                'success': false,
                'message': 'Current password is incorrect'
              };
            case 'weak-password':
              return {
                'success': false,
                'message': 'New password is too weak. Please choose a stronger password (at least 6 characters).'
              };
            case 'requires-recent-login':
              return {
                'success': false,
                'message': 'For security reasons, please log out and log back in, then try again.'
              };
            case 'user-disabled':
              return {
                'success': false,
                'message': 'Your account has been disabled. Please contact support.'
              };
            case 'network-request-failed':
              return {
                'success': false,
                'message': 'Network error. Please check your internet connection.'
              };
            case 'too-many-requests':
              return {
                'success': false,
                'message': 'Too many failed attempts. Please wait a few minutes and try again.'
              };
            case 'operation-not-allowed':
              return {
                'success': false,
                'message': 'Password sign-in is not enabled. Please contact support.'
              };
            case 'unknown-error':
              // This is common on desktop platforms
              return {
                'success': false,
                'message': 'Unable to change password on this platform. This feature may not be fully supported on Windows desktop. Please try using the web version or mobile app.'
              };
            default:
              return {
                'success': false,
                'message': 'Failed to change password: ${e.code}. Please try again or contact support if the issue persists.'
              };
          }
        } on TimeoutException {
          debugPrint('ChangePassword: Operation timed out');
          return {
            'success': false,
            'message': 'Operation timed out. Please check your internet connection and try again.'
          };
        } catch (e) {
          debugPrint('ChangePassword: Unexpected error - $e');
          return {
            'success': false,
            'message': 'An unexpected error occurred. Please try again later.'
          };
        }
      },
      timeout: const Duration(seconds: 25),
      retryOnTimeout: true,
      retryOnNetworkError: true,
      onError: (attempt, error) {
        debugPrint('Change password attempt $attempt failed: $error');
      },
    );
  }

  // Check if user profile is complete with enhanced resilience
  static Future<bool> isUserProfileComplete() async {
    return await EnhancedNetworkService.executeWithResilience(
      () async {
        try {
          // Add timeout to prevent hanging
          final user = await getUser().timeout(const Duration(seconds: 10));
          if (user == null) return false;
          
          // Check if essential profile fields are completed
          bool hasBasicInfo = user.birthMonth != null && 
                             user.birthDay != null && 
                             user.birthYear != null &&
                             user.gender != null &&
                             user.profession != null &&
                             user.city != null && user.city!.isNotEmpty &&
                             user.province != null && user.province!.isNotEmpty;
          
          return hasBasicInfo;
        } on TimeoutException catch (e) {
          debugPrint('Profile completion check timed out: $e');
          return false; // Treat timeout as incomplete profile
        } catch (e) {
          debugPrint('Profile completion check error: $e');
          return false; // Treat any other error as incomplete profile
        }
      },
      timeout: const Duration(seconds: 15),
      retryOnTimeout: true,
      retryOnNetworkError: true,
    );
  }

  // User Data Management with enhanced resilience
  static Future<app_user.User?> getUser() async {
    return await EnhancedNetworkService.executeWithResilience(
      () async {
        final userId = currentUserId;
        if (userId == null) {
          debugPrint('Get user error: No authenticated user');
          return null;
        }

        try {
          // Add timeout to prevent hanging
          final doc = await _db.collection('users').doc(userId).get()
              .timeout(const Duration(seconds: 10));
          
          if (doc.exists) {
            return app_user.User.fromJson(doc.data()!);
          }
          return null;
        } on FirebaseException catch (e) {
          debugPrint('Get user Firebase error: ${e.code} - ${e.message}');
          switch (e.code) {
            case 'permission-denied':
              debugPrint('Permission denied: User may not be properly authenticated or Firestore rules are restrictive');
              break;
            case 'unavailable':
              debugPrint('Firestore service unavailable');
              break;
            case 'unauthenticated':
              debugPrint('User not authenticated');
              break;
          }
          return null;
        } on TimeoutException catch (e) {
          debugPrint('Get user timeout error: $e');
          return null;
        } catch (e) {
          debugPrint('Get user error: $e');
          return null;
        }
      },
      timeout: const Duration(seconds: 15),
      retryOnTimeout: true,
      retryOnNetworkError: true,
    );
  }

  static Future<bool> saveUser(app_user.User user) async {
    return await EnhancedNetworkService.executeWithResilience(
      () async {
        final userId = currentUserId;
        if (userId == null) return false;

        try {
          await _db.collection('users').doc(userId).set(user.toJson());
          return true;
        } catch (e) {
          debugPrint('Save user error: $e');
          return false;
        }
      },
      timeout: const Duration(seconds: 15),
      retryOnTimeout: true,
      retryOnNetworkError: true,
    );
  }

  static Future<bool> updateUserInfo({
    required int birthMonth,
    required int birthDay,
    required int birthYear,
    String? gender,
    required String profession,
    double incomeAmount = 0.0,
    String incomeType = 'Not specified',
    String incomeFrequency = 'irregular',
    String themePreference = 'light',
    bool? isWorkingStudent,
    bool? isBusinessOwner,
    String? civilStatus,
    bool? hasKids,
    int? numberOfChildren,
    String? householdSituation,
    List<String>? debtStatuses,
    List<String>? savingsInvestments,
    List<String>? incomeSources,
    String? otherIncomeSource,
    String? city,
    String? province,
    double? initialBudget,
    double? monthlyNet,
    double? emergencyFundAmount,
    List<String>? selectedCategories,
  }) async {
    return await EnhancedNetworkService.executeWithResilience(
      () async {
        final userId = currentUserId;
        if (userId == null) {
          debugPrint('Update user info error: No authenticated user');
          return false;
        }

        try {
          final updateData = {
            'birthMonth': birthMonth,
            'birthDay': birthDay,
            'birthYear': birthYear,
            'profession': profession,
            'incomeAmount': incomeAmount,
            'incomeType': incomeType,
            'incomeFrequency': incomeFrequency,
            'themePreference': themePreference,
            'monthlyIncome': incomeAmount,
            'updatedAt': DateTime.now().toIso8601String(),
          };

          if (gender != null) updateData['gender'] = gender;
          if (isWorkingStudent != null) updateData['isWorkingStudent'] = isWorkingStudent;
          if (isBusinessOwner != null) updateData['isBusinessOwner'] = isBusinessOwner;
          if (civilStatus != null) updateData['civilStatus'] = civilStatus;
          if (hasKids != null) updateData['hasKids'] = hasKids;
          if (numberOfChildren != null) updateData['numberOfChildren'] = numberOfChildren;
          if (householdSituation != null) updateData['householdSituation'] = householdSituation;
          if (debtStatuses != null) updateData['debtStatuses'] = debtStatuses;
          if (savingsInvestments != null) updateData['savingsInvestments'] = savingsInvestments;
          if (incomeSources != null) updateData['incomeSources'] = incomeSources;
          if (otherIncomeSource != null) updateData['otherIncomeSource'] = otherIncomeSource;

          if (city != null) updateData['city'] = city;
          if (province != null) updateData['province'] = province;
          if (initialBudget != null) updateData['initialBudget'] = initialBudget;
          if (monthlyNet != null) updateData['monthlyNet'] = monthlyNet;
          if (emergencyFundAmount != null) updateData['emergencyFundAmount'] = emergencyFundAmount;
          if (selectedCategories != null) updateData['selectedCategories'] = selectedCategories;

          await _db.collection('users').doc(userId).update(updateData);
          return true;
        } on FirebaseException catch (e) {
          debugPrint('Update user info Firebase error: ${e.code} - ${e.message}');
          switch (e.code) {
            case 'permission-denied':
              debugPrint('Permission denied: Check Firestore security rules and user authentication');
              break;
            case 'not-found':
              debugPrint('User document not found, creating new document');
              // Try to create the document instead
              try {
                final createData = {
                  'birthMonth': birthMonth,
                  'birthDay': birthDay,
                  'birthYear': birthYear,
                  'profession': profession,
                  'incomeAmount': incomeAmount,
                  'incomeType': incomeType,
                  'incomeFrequency': incomeFrequency,
                  'themePreference': themePreference,
                  'monthlyIncome': incomeAmount,
                  'updatedAt': DateTime.now().toIso8601String(),
                };

                if (gender != null) createData['gender'] = gender;
                if (isWorkingStudent != null) createData['isWorkingStudent'] = isWorkingStudent;
                if (isBusinessOwner != null) createData['isBusinessOwner'] = isBusinessOwner;
                if (civilStatus != null) createData['civilStatus'] = civilStatus;
                if (hasKids != null) createData['hasKids'] = hasKids;
                if (numberOfChildren != null) createData['numberOfChildren'] = numberOfChildren;
                if (householdSituation != null) createData['householdSituation'] = householdSituation;
                if (debtStatuses != null) createData['debtStatuses'] = debtStatuses;
                if (savingsInvestments != null) createData['savingsInvestments'] = savingsInvestments;
                if (incomeSources != null) createData['incomeSources'] = incomeSources;
                if (otherIncomeSource != null) createData['otherIncomeSource'] = otherIncomeSource;
                if (city != null) createData['city'] = city;
                if (province != null) createData['province'] = province;
                if (initialBudget != null) createData['initialBudget'] = initialBudget;
                if (monthlyNet != null) createData['monthlyNet'] = monthlyNet;
                if (emergencyFundAmount != null) createData['emergencyFundAmount'] = emergencyFundAmount;
                if (selectedCategories != null) createData['selectedCategories'] = selectedCategories;
                
                await _db.collection('users').doc(userId).set(createData);
                return true;
              } catch (createError) {
                debugPrint('Failed to create user document: $createError');
                return false;
              }
            case 'unavailable':
              debugPrint('Firestore service unavailable');
              break;
            case 'unauthenticated':
              debugPrint('User not authenticated');
              break;
          }
          return false;
        } catch (e) {
          debugPrint('Update user info error: $e');
          return false;
        }
      },
      timeout: const Duration(seconds: 20),
      retryOnTimeout: true,
      retryOnNetworkError: true,
    );
  }

  // Transaction Management - Organized by Date with enhanced resilience
  static Future<void> saveTransactions(List<app_transaction.Transaction> transactions) async {
    await EnhancedNetworkService.executeWithResilience(
      () async {
        final userId = currentUserId;
        if (userId == null) return;

        try {
          final batch = _db.batch();
          for (final transaction in transactions) {
            // Create date-based path: users/{userId}/transactions/{YYYY-MM-DD}/transactions/{transactionId}
            final dateKey = _formatDateKey(transaction.date);
            final docRef = _db
                .collection('users')
                .doc(userId)
                .collection('transactions')
                .doc(dateKey)
                .collection('daily_transactions')
                .doc(transaction.id);
            batch.set(docRef, transaction.toJson());
          }
          await batch.commit();
        } catch (e) {
          debugPrint('Save transactions error: $e');
        }
      },
      timeout: const Duration(seconds: 30),
      retryOnTimeout: true,
      retryOnNetworkError: true,
    );
  }

  static Future<List<app_transaction.Transaction>> getTransactions() async {
    return await EnhancedNetworkService.executeWithResilience(
      () async {
        final userId = currentUserId;
        if (userId == null) return [];

        try {
          final List<app_transaction.Transaction> allTransactions = [];

          // Get all date documents
          final dateSnapshot = await _db.collection('users').doc(userId).collection('transactions').get();

          // For each date, get all transactions
          for (final dateDoc in dateSnapshot.docs) {
            final dailySnapshot = await dateDoc.reference.collection('daily_transactions').get();
            final dailyTransactions = dailySnapshot.docs
                .map((doc) => app_transaction.Transaction.fromJson(doc.data()))
                .toList();
            allTransactions.addAll(dailyTransactions);
          }

          // Sort by date (newest first)
          allTransactions.sort((a, b) => b.date.compareTo(a.date));
          return allTransactions;
        } catch (e) {
          debugPrint('Get transactions error: $e');
          return [];
        }
      },
      timeout: const Duration(seconds: 30),
      retryOnTimeout: true,
      retryOnNetworkError: true,
    );
  }

  static Future<void> addTransaction(app_transaction.Transaction transaction) async {
    await EnhancedNetworkService.executeWithResilience(
      () async {
        final userId = currentUserId;
        if (userId == null) return;

        try {
          // Save transaction organized by date
          final dateKey = _formatDateKey(transaction.date);
          await _db
              .collection('users')
              .doc(userId)
              .collection('transactions')
              .doc(dateKey)
              .collection('daily_transactions')
              .doc(transaction.id)
              .set(transaction.toJson());
        } catch (e) {
          debugPrint('Add transaction error: $e');
        }
      },
      timeout: const Duration(seconds: 15),
      retryOnTimeout: true,
      retryOnNetworkError: true,
    );
  }

  static Future<void> updateTransaction(app_transaction.Transaction transaction) async {
    await EnhancedNetworkService.executeWithResilience(
      () async {
        final userId = currentUserId;
        if (userId == null) return;

        try {
          // Update transaction organized by date
          final dateKey = _formatDateKey(transaction.date);
          await _db
              .collection('users')
              .doc(userId)
              .collection('transactions')
              .doc(dateKey)
              .collection('daily_transactions')
              .doc(transaction.id)
              .update(transaction.toJson());
        } catch (e) {
          debugPrint('Update transaction error: $e');
        }
      },
      timeout: const Duration(seconds: 15),
      retryOnTimeout: true,
      retryOnNetworkError: true,
    );
  }

  static Future<void> deleteTransaction(String transactionId) async {
    await EnhancedNetworkService.executeWithResilience(
      () async {
        final userId = currentUserId;
        if (userId == null) {
          throw Exception('User not authenticated');
        }

        try {
          // We need to find the transaction across all dates
          // Get all date documents
          final dateSnapshot = await _db.collection('users').doc(userId).collection('transactions').get();
          
          bool transactionFound = false;
          // Search through each date for the transaction
          for (final dateDoc in dateSnapshot.docs) {
            final transactionDoc = await dateDoc.reference
                .collection('daily_transactions')
                .doc(transactionId)
                .get();
                
            if (transactionDoc.exists) {
              await transactionDoc.reference.delete();
              transactionFound = true;
              debugPrint('Transaction $transactionId deleted successfully');
              break;
            }
          }
          
          if (!transactionFound) {
            throw Exception('Transaction not found');
          }
        } catch (e) {
          debugPrint('Delete transaction error: $e');
          rethrow; // Re-throw the error so the UI can handle it
        }
      },
      timeout: const Duration(seconds: 20),
      retryOnTimeout: true,
      retryOnNetworkError: true,
    );
  }

  // More efficient delete method if we know the transaction date
  static Future<void> deleteTransactionByDate(String transactionId, DateTime transactionDate) async {
    await EnhancedNetworkService.executeWithResilience(
      () async {
        final userId = currentUserId;
        if (userId == null) {
          throw Exception('User not authenticated');
        }

        try {
          final dateKey = _formatDateKey(transactionDate);
          
          // Use a timeout to prevent hanging
          final transactionDoc = await _db
              .collection('users')
              .doc(userId)
              .collection('transactions')
              .doc(dateKey)
              .collection('daily_transactions')
              .doc(transactionId)
              .get()
              .timeout(
                const Duration(seconds: 10),
                onTimeout: () => throw Exception('Connection timeout. Please check your internet connection.'),
              );
              
          if (transactionDoc.exists) {
            await transactionDoc.reference.delete().timeout(
              const Duration(seconds: 10),
              onTimeout: () => throw Exception('Delete operation timeout. Please try again.'),
            );
            debugPrint('Transaction $transactionId deleted successfully');
          } else {
            throw Exception('Transaction not found');
          }
        } on Exception {
          rethrow;
        } catch (e) {
          debugPrint('Delete transaction by date error: $e');
          if (e.toString().contains('network') || e.toString().contains('connection')) {
            throw Exception('Network error. Please check your connection and try again.');
          }
          throw Exception('Failed to delete transaction. Please try again.');
        }
      },
      timeout: const Duration(seconds: 25),
      retryOnTimeout: true,
      retryOnNetworkError: true,
    );
  }

  // Budget Management with enhanced resilience
  static Future<void> saveBudget(Budget budget) async {
    await EnhancedNetworkService.executeWithResilience(
      () async {
        final userId = currentUserId;
        if (userId == null) return;

        try {
          await _db.collection('users').doc(userId).collection('budgets').doc(budget.id).set(budget.toJson());
        } catch (e) {
          debugPrint('Save budget error: $e');
        }
      },
      timeout: const Duration(seconds: 15),
      retryOnTimeout: true,
      retryOnNetworkError: true,
    );
  }

  static Future<Budget?> getBudget() async {
    return await EnhancedNetworkService.executeWithResilience(
      () async {
        final userId = currentUserId;
        if (userId == null) return null;

        try {
          final snapshot = await _db.collection('users').doc(userId).collection('budgets').limit(1).get();
          if (snapshot.docs.isNotEmpty) {
            return Budget.fromJson(snapshot.docs.first.data());
          }
          return null;
        } catch (e) {
          debugPrint('Get budget error: $e');
          return null;
        }
      },
      timeout: const Duration(seconds: 15),
      retryOnTimeout: true,
      retryOnNetworkError: true,
    );
  }

  // Goal Management with enhanced resilience
  static Future<void> saveGoal(Goal goal) async {
    await EnhancedNetworkService.executeWithResilience(
      () async {
        final userId = currentUserId;
        if (userId == null) return;

        try {
          await _db.collection('users').doc(userId).collection('goals').doc(goal.id).set(goal.toJson());
        } catch (e) {
          debugPrint('Save goal error: $e');
        }
      },
      timeout: const Duration(seconds: 15),
      retryOnTimeout: true,
      retryOnNetworkError: true,
    );
  }

  static Future<List<Goal>> getGoals() async {
    return await EnhancedNetworkService.executeWithResilience(
      () async {
        final userId = currentUserId;
        if (userId == null) return [];

        try {
          final snapshot = await _db.collection('users').doc(userId).collection('goals').get();
          return snapshot.docs.map((doc) => Goal.fromJson(doc.data())).toList();
        } catch (e) {
          debugPrint('Get goals error: $e');
          return [];
        }
      },
      timeout: const Duration(seconds: 15),
      retryOnTimeout: true,
      retryOnNetworkError: true,
    );
  }

  // Debt Management with enhanced resilience
  static Future<void> saveDebt(Debt debt) async {
    await EnhancedNetworkService.executeWithResilience(
      () async {
        final userId = currentUserId;
        if (userId == null) return;

        try {
          await _db.collection('users').doc(userId).collection('debts').doc(debt.id).set(debt.toJson());
        } catch (e) {
          debugPrint('Save debt error: $e');
        }
      },
      timeout: const Duration(seconds: 15),
      retryOnTimeout: true,
      retryOnNetworkError: true,
    );
  }

  static Future<List<Debt>> getDebts() async {
    return await EnhancedNetworkService.executeWithResilience(
      () async {
        final userId = currentUserId;
        if (userId == null) return [];

        try {
          final snapshot = await _db.collection('users').doc(userId).collection('debts').get();
          return snapshot.docs.map((doc) => Debt.fromJson(doc.data())).toList();
        } catch (e) {
          debugPrint('Get debts error: $e');
          return [];
        }
      },
      timeout: const Duration(seconds: 15),
      retryOnTimeout: true,
      retryOnNetworkError: true,
    );
  }

  // Reminder Management with enhanced resilience
  static Future<void> saveReminder(Reminder reminder) async {
    await EnhancedNetworkService.executeWithResilience(
      () async {
        final userId = currentUserId;
        if (userId == null) return;

        try {
          final userRef = _db.collection('users').doc(userId);
          final remindersRef = userRef.collection('reminders');

          if (reminder.recurrence != RecurrenceType.single) {
            // Delete existing reminders with the same base ID
            final existingQuery = await remindersRef.where('baseId', isEqualTo: reminder.baseId).get();
            final batch = _db.batch();
            
            for (final doc in existingQuery.docs) {
              batch.delete(doc.reference);
            }

            // Generate all occurrences for recurring reminders
            final allOccurrences = reminder.generateAllOccurrences();
            for (final occurrence in allOccurrences) {
              final docRef = remindersRef.doc(occurrence.id);
              batch.set(docRef, occurrence.toJson());
            }

            await batch.commit();
          } else {
            await remindersRef.doc(reminder.id).set(reminder.toJson());
          }
        } catch (e) {
          debugPrint('Save reminder error: $e');
        }
      },
      timeout: const Duration(seconds: 20),
      retryOnTimeout: true,
      retryOnNetworkError: true,
    );
  }

  static Future<List<Reminder>> getReminders() async {
    return await EnhancedNetworkService.executeWithResilience(
      () async {
        final userId = currentUserId;
        if (userId == null) return [];

        try {
          final snapshot = await _db.collection('users').doc(userId).collection('reminders').get();
          return snapshot.docs.map((doc) => Reminder.fromJson(doc.data())).toList();
        } catch (e) {
          debugPrint('Get reminders error: $e');
          return [];
        }
      },
      timeout: const Duration(seconds: 15),
      retryOnTimeout: true,
      retryOnNetworkError: true,
    );
  }

  static Future<void> updateReminder(Reminder reminder) async {
    await EnhancedNetworkService.executeWithResilience(
      () async {
        final userId = currentUserId;
        if (userId == null) return;

        try {
          final userRef = _db.collection('users').doc(userId);
          final remindersRef = userRef.collection('reminders');

          if (reminder.recurrence != RecurrenceType.single) {
            // Delete existing reminders with the same base ID
            final existingQuery = await remindersRef.where('baseId', isEqualTo: reminder.baseId).get();
            final batch = _db.batch();
            
            for (final doc in existingQuery.docs) {
              batch.delete(doc.reference);
            }

            // Generate all occurrences for recurring reminders
            final allOccurrences = reminder.generateAllOccurrences();
            for (final occurrence in allOccurrences) {
              final docRef = remindersRef.doc(occurrence.id);
              batch.set(docRef, occurrence.toJson());
            }

            await batch.commit();
          } else {
            await remindersRef.doc(reminder.id).set(reminder.toJson());
          }
        } catch (e) {
          debugPrint('Update reminder error: $e');
        }
      },
      timeout: const Duration(seconds: 20),
      retryOnTimeout: true,
      retryOnNetworkError: true,
    );
  }

  static Future<void> deleteReminder(String reminderId) async {
    await EnhancedNetworkService.executeWithResilience(
      () async {
        final userId = currentUserId;
        if (userId == null) return;

        try {
          final userRef = _db.collection('users').doc(userId);
          final remindersRef = userRef.collection('reminders');

          // Find the reminder to delete
          final reminderDoc = await remindersRef.doc(reminderId).get();
          
          if (reminderDoc.exists) {
            final reminderData = reminderDoc.data()!;
            final reminder = Reminder.fromJson(reminderData);

            if (reminder.recurrence != RecurrenceType.single) {
              // Delete all occurrences with the same base ID
              final existingQuery = await remindersRef.where('baseId', isEqualTo: reminder.baseId).get();
              final batch = _db.batch();
              
              for (final doc in existingQuery.docs) {
                batch.delete(doc.reference);
              }
              await batch.commit();
            } else {
              await remindersRef.doc(reminderId).delete();
            }
          }
        } catch (e) {
          debugPrint('Delete reminder error: $e');
        }
      },
      timeout: const Duration(seconds: 15),
      retryOnTimeout: true,
      retryOnNetworkError: true,
    );
  }

  static Future<List<Reminder>> getRemindersForDate(DateTime date) async {
    return await EnhancedNetworkService.executeWithResilience(
      () async {
        final allReminders = await getReminders();
        final targetDate = DateTime(date.year, date.month, date.day);

        return allReminders.where((reminder) {
          final reminderDate = DateTime(
            reminder.date.year,
            reminder.date.month,
            reminder.date.day,
          );
          return reminderDate.isAtSameMomentAs(targetDate);
        }).toList();
      },
      timeout: const Duration(seconds: 15),
      retryOnTimeout: true,
      retryOnNetworkError: true,
    );
  }

  static Future<List<Reminder>> getRemindersForDateRange(
    DateTime startDate,
    DateTime endDate
  ) async {
    return await EnhancedNetworkService.executeWithResilience(
      () async {
        final allReminders = await getReminders();
        final start = DateTime(startDate.year, startDate.month, startDate.day);
        final end = DateTime(endDate.year, endDate.month, endDate.day);

        return allReminders.where((reminder) {
          final reminderDate = DateTime(
            reminder.date.year,
            reminder.date.month,
            reminder.date.day,
          );
          return (reminderDate.isAfter(start) || reminderDate.isAtSameMomentAs(start)) &&
                 (reminderDate.isBefore(end) || reminderDate.isAtSameMomentAs(end));
        }).toList();
      },
      timeout: const Duration(seconds: 15),
      retryOnTimeout: true,
      retryOnNetworkError: true,
    );
  }

  static Future<void> markReminderAsCompleted(String reminderId) async {
    await EnhancedNetworkService.executeWithResilience(
      () async {
        final userId = currentUserId;
        if (userId == null) return;

        try {
          final reminderRef = _db.collection('users').doc(userId).collection('reminders').doc(reminderId);
          await reminderRef.update({
            'isCompleted': true,
            'completedAt': DateTime.now().toIso8601String(),
          });
        } catch (e) {
          debugPrint('Mark reminder completed error: $e');
        }
      },
      timeout: const Duration(seconds: 15),
      retryOnTimeout: true,
      retryOnNetworkError: true,
    );
  }

  // Savings Goal Data with enhanced resilience
  static Future<Map<String, double>> getSavingsGoalData() async {
    return await EnhancedNetworkService.executeWithResilience(
      () async {
        final goals = await getGoals();
        final activeSavingsGoal = goals.firstWhere(
          (goal) => !goal.isCompleted && goal.name.toLowerCase().contains('savings'),
          orElse: () => Goal(
            id: '',
            name: '',
            targetAmount: 10000,
            startDate: DateTime.now(),
            endDate: DateTime.now(),
            frequency: 'monthly',
            amountPerFrequency: 0,
            totalDepositsNeeded: 0,
            createdAt: DateTime.now(),
          ),
        );

        final currentSavings = goals.fold<double>(
          0.0,
          (total, goal) => total + (goal.name.toLowerCase().contains('savings') ? goal.currentAmount : 0.0),
        );

        return {
          'target': activeSavingsGoal.targetAmount,
          'current': currentSavings,
        };
      },
      timeout: const Duration(seconds: 15),
      retryOnTimeout: true,
      retryOnNetworkError: true,
    );
  }

  // Utility Methods with enhanced resilience
  static Future<void> clearAllData() async {
    await EnhancedNetworkService.executeWithResilience(
      () async {
        final userId = currentUserId;
        if (userId == null) return;

        try {
          final batch = _db.batch();
          
          // Clear all subcollections
          final collections = ['transactions', 'budgets', 'goals', 'debts', 'recurring_expenses', 'reminders', 'previous_month_data'];
          
          for (final collection in collections) {
            final snapshot = await _db.collection('users').doc(userId).collection(collection).get();
            for (final doc in snapshot.docs) {
              batch.delete(doc.reference);
            }
          }
          
          await batch.commit();
        } catch (e) {
          debugPrint('Clear all data error: $e');
        }
      },
      timeout: const Duration(seconds: 30),
      retryOnTimeout: true,
      retryOnNetworkError: true,
    );
  }

  // Date-based transaction query methods
  static String _formatDateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  static Future<List<app_transaction.Transaction>> getTransactionsByDate(DateTime date) async {
    return await EnhancedNetworkService.executeWithResilience(
      () async {
        final userId = currentUserId;
        if (userId == null) return [];

        try {
          final dateKey = _formatDateKey(date);
          final snapshot = await _db
              .collection('users')
              .doc(userId)
              .collection('transactions')
              .doc(dateKey)
              .collection('daily_transactions')
              .get();

          return snapshot.docs
              .map((doc) => app_transaction.Transaction.fromJson(doc.data()))
              .toList();
        } catch (e) {
          debugPrint('Get transactions by date error: $e');
          return [];
        }
      },
      timeout: const Duration(seconds: 15),
      retryOnTimeout: true,
      retryOnNetworkError: true,
    );
  }

  static Future<List<app_transaction.Transaction>> getTransactionsByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    return await EnhancedNetworkService.executeWithResilience(
      () async {
        final userId = currentUserId;
        if (userId == null) return [];

        try {
          final List<app_transaction.Transaction> allTransactions = [];
          
          // Get all dates in the range
          DateTime currentDate = DateTime(startDate.year, startDate.month, startDate.day);
          final endDateNormalized = DateTime(endDate.year, endDate.month, endDate.day);
          
          while (currentDate.isBefore(endDateNormalized) || currentDate.isAtSameMomentAs(endDateNormalized)) {
            final dateKey = _formatDateKey(currentDate);
            final snapshot = await _db
                .collection('users')
                .doc(userId)
                .collection('transactions')
                .doc(dateKey)
                .collection('daily_transactions')
                .get();

            final dailyTransactions = snapshot.docs
                .map((doc) => app_transaction.Transaction.fromJson(doc.data()))
                .toList();
            
            allTransactions.addAll(dailyTransactions);
            currentDate = currentDate.add(const Duration(days: 1));
          }

          // Sort by date (newest first)
          allTransactions.sort((a, b) => b.date.compareTo(a.date));
          return allTransactions;
        } catch (e) {
          debugPrint('Get transactions by date range error: $e');
          return [];
        }
      },
      timeout: const Duration(seconds: 30),
      retryOnTimeout: true,
      retryOnNetworkError: true,
    );
  }

  static Future<List<app_transaction.Transaction>> getTodayTransactions() async {
    return await EnhancedNetworkService.executeWithResilience(
      () async {
        final userId = currentUserId;
        if (userId == null) return [];

        try {
          final today = DateTime.now();
          final dateKey = _formatDateKey(today);
          final snapshot = await _db
              .collection('users')
              .doc(userId)
              .collection('transactions')
              .doc(dateKey)
              .collection('daily_transactions')
              .get();

          return snapshot.docs
              .map((doc) => app_transaction.Transaction.fromJson(doc.data()))
              .toList();
        } catch (e) {
          debugPrint('Get today transactions error: $e');
          return [];
        }
      },
      timeout: const Duration(seconds: 15),
      retryOnTimeout: true,
      retryOnNetworkError: true,
    );
  }

  static Future<double> getTotalSpentThisMonth() async {
    return await EnhancedNetworkService.executeWithResilience(
      () async {
        final userId = currentUserId;
        if (userId == null) return 0.0;

        try {
          final now = DateTime.now();
          final startOfMonth = DateTime(now.year, now.month, 1);
          final endOfMonth = DateTime(now.year, now.month + 1, 0);

          final transactions = await EnhancedFirebaseService.getTransactionsByDateRange(startOfMonth, endOfMonth);
          
          double total = 0.0;
          for (final transaction in transactions) {
            if (transaction.type == app_transaction.TransactionType.expense || 
                transaction.type == app_transaction.TransactionType.recurringExpense) {
              total += transaction.amount;
            }
          }
          return total;
        } catch (e) {
          debugPrint('Get total spent this month error: $e');
          return 0.0;
        }
      },
      timeout: const Duration(seconds: 15),
      retryOnTimeout: true,
      retryOnNetworkError: true,
    );
  }

  static Future<Map<String, double>> getCategorySpending(DateTime startDate, DateTime endDate) async {
    return await EnhancedNetworkService.executeWithResilience(
      () async {
        final userId = currentUserId;
        if (userId == null) return {};

        try {
          final transactions = await EnhancedFirebaseService.getTransactionsByDateRange(startDate, endDate);
          
          final Map<String, double> categorySpending = {};
          
          for (final transaction in transactions) {
            if (transaction.type == app_transaction.TransactionType.expense || 
                transaction.type == app_transaction.TransactionType.recurringExpense) {
              final currentAmount = categorySpending[transaction.category] ?? 0.0;
              categorySpending[transaction.category] = currentAmount + transaction.amount;
            }
          }
          
          return categorySpending;
        } catch (e) {
          debugPrint('Get category spending error: $e');
          return {};
        }
      },
      timeout: const Duration(seconds: 20),
      retryOnTimeout: true,
      retryOnNetworkError: true,
    );
  }
}