import 'package:flutter/material.dart';
import '../models/user.dart' as user_models;
import '../services/firebase_service.dart';
import '../services/theme_service.dart';

class SecurityPage extends StatefulWidget {
  final user_models.User user;

  const SecurityPage({super.key, required this.user});

  @override
  State<SecurityPage> createState() => _SecurityPageState();
}

class _SecurityPageState extends State<SecurityPage> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _deletePasswordController = TextEditingController();
  
  bool _isLoading = false;
  bool _obscureCurrentPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  bool _obscureDeletePassword = true;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _deletePasswordController.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Early validation for better UX
    if (_currentPasswordController.text == _newPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('New password must be different from current password'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Starting password change
    setState(() {
      _isLoading = true;
    });

    try {
      // Check authentication status first
      final authStatus = await FirebaseService.getAuthStatus();
      // Auth status checked
      
      if (!authStatus['authenticated']) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('Authentication error: ${authStatus['message']}'),
                  ),
                ],
              ),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
        }
        return;
      }

      // Calling changePassword service
      // Add timeout to prevent indefinite loading
      final result = await Future.any([
        FirebaseService.changePassword(
          _currentPasswordController.text,
          _newPasswordController.text,
        ),
        Future.delayed(const Duration(seconds: 15), () => {
          'success': false,
          'message': 'Request timed out. Please check your internet connection and try again.'
        }),
      ]);

      // Password change completed

      if (mounted) {
        if (result['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text('Password changed successfully!'),
                ],
              ),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
          
          // Clear form on success
          _currentPasswordController.clear();
          _newPasswordController.clear();
          _confirmPasswordController.clear();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(result['message'] ?? 'Failed to change password'),
                  ),
                ],
              ),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      // Exception caught during password change
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.warning, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Error: ${e.toString()}'),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      // Ensure loading state is cleared even if widget is disposed
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _deleteAccount() async {
    // Show confirmation dialog first
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text(
          'Are you sure you want to delete your account? This action cannot be undone. All your data will be permanently deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Show password dialog
    String? password;
    if (mounted) {
      password = await showDialog<String>(
        context: context,
        builder: (context) => _buildDeletePasswordDialog(),
      );
    } else {
      return;
    }

    if (password == null || password.isEmpty) return;

    // Start deletion process
    setState(() {
      _isLoading = true;
    });

    try {
      final result = await FirebaseService.deleteUserAccount(password);

      if (mounted) {
        if (result['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Account deleted successfully. You have been logged out.'),
              backgroundColor: Colors.green,
            ),
          );
          
          // Navigate to login screen or home screen
          Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Failed to delete account'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting account: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildDeletePasswordDialog() {
    final theme = Theme.of(context);
    
    return AlertDialog(
      title: const Text('Confirm Password'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Please enter your password to confirm account deletion:'),
          const SizedBox(height: 16),
          TextFormField(
            controller: _deletePasswordController,
            obscureText: _obscureDeletePassword,
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: Icon(Icons.lock_outline, color: theme.colorScheme.primary),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureDeletePassword ? Icons.visibility : Icons.visibility_off,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
                onPressed: () {
                  setState(() {
                    _obscureDeletePassword = !_obscureDeletePassword;
                  });
                },
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: theme.dividerColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: theme.dividerColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
              ),
              filled: true,
              fillColor: theme.cardTheme.color,
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Password is required';
              }
              return null;
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            _deletePasswordController.clear();
            Navigator.of(context).pop();
          },
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            if (_deletePasswordController.text.isNotEmpty) {
              final password = _deletePasswordController.text;
              _deletePasswordController.clear();
              Navigator.of(context).pop(password);
            }
          },
          child: const Text('Confirm', style: TextStyle(color: Colors.red)),
        ),
      ],
    );
  }

  String? _validateCurrentPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your current password';
    }
    return null;
  }

  String? _validateNewPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter a new password';
    }
    if (value.length < 6) {
      return 'Password must be at least 6 characters long';
    }
    if (value == _currentPasswordController.text) {
      return 'New password must be different from current password';
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your new password';
    }
    if (value != _newPasswordController.text) {
      return 'Passwords do not match';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final themeService = ThemeService();
    
    return AnimatedBuilder(
      animation: themeService,
      builder: (context, child) {
        final theme = Theme.of(context);
        
        return Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          appBar: AppBar(
            title: LayoutBuilder(
              builder: (context, constraints) {
                final isNarrowScreen = MediaQuery.of(context).size.width < 600;
                final titleFontSize = isNarrowScreen ? 20.0 : 22.0; // Section Heading range (20–24sp)
                
                return Text(
                  'Security',
                  style: TextStyle(
                    color: theme.appBarTheme.foregroundColor,
                    fontWeight: FontWeight.bold,
                    fontSize: titleFontSize,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                );
              },
            ),
            backgroundColor: theme.appBarTheme.backgroundColor,
            elevation: 0,
            iconTheme: IconThemeData(color: theme.appBarTheme.foregroundColor),
          ),
          body: LayoutBuilder(
            builder: (context, constraints) {
              // Determine responsive layout parameters
              final isNarrowScreen = constraints.maxWidth < 600;
              final isVeryNarrowScreen = constraints.maxWidth < 400;
              
              // Responsive sizing following typography standards  
              final sectionHeaderFontSize = isNarrowScreen ? 18.0 : 20.0; // Reduced from 20/22 to 18/20
              final bodyTextFontSize = isNarrowScreen ? 13.0 : 15.0; // Reduced from 14/16 to 13/15
              final secondaryTextFontSize = isNarrowScreen ? 12.0 : 14.0; // Secondary Text range (12–14sp)
              final buttonTextFontSize = isNarrowScreen ? 16.0 : 18.0; // Button Text range (16–18sp)
              final iconSize = isNarrowScreen ? 32.0 : 36.0; // Reduced from 40/48 to 32/36
              final containerPadding = isNarrowScreen ? 14.0 : 18.0; // Reduced from 16/24 to 14/18
              final mainPadding = isNarrowScreen ? 12.0 : 16.0;
              final spacingAfterHeader = isNarrowScreen ? 12.0 : 16.0; // Reduced from 20/24 to 12/16 for closer cards
              
              return SingleChildScrollView(
                padding: EdgeInsets.all(mainPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Security Header
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(containerPadding),
                      decoration: BoxDecoration(
                        color: theme.cardTheme.color,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: theme.shadowColor.withValues(alpha: 0.1),
                            spreadRadius: 1,
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Container(
                            padding: EdgeInsets.all(isNarrowScreen ? 8.0 : 12.0), // Reduced from 12/16 to 8/12
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(50),
                            ),
                            child: Icon(
                              Icons.security,
                              size: iconSize,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          SizedBox(height: isNarrowScreen ? 8.0 : 12.0), // Reduced from 12/16 to 8/12
                          Text(
                            'Account Security',
                            style: TextStyle(
                              fontSize: sectionHeaderFontSize,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurface,
                            ),
                            maxLines: isVeryNarrowScreen ? 2 : 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: isNarrowScreen ? 4.0 : 6.0), // Reduced from 6/8 to 4/6
                          Text(
                            'Keep your account secure by updating your password regularly',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: bodyTextFontSize,
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                            maxLines: isVeryNarrowScreen ? 3 : 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: spacingAfterHeader),

                    // Change Password Section
                    Container(
                      padding: EdgeInsets.all(containerPadding),
                      decoration: BoxDecoration(
                        color: theme.cardTheme.color,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: theme.shadowColor.withValues(alpha: 0.1),
                            spreadRadius: 1,
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Change Password',
                              style: TextStyle(
                                fontSize: sectionHeaderFontSize,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onSurface,
                              ),
                              maxLines: isVeryNarrowScreen ? 2 : 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(height: isNarrowScreen ? 4.0 : 6.0), // Reduced spacing
                            Text(
                              'Enter your current password and choose a new one',
                              style: TextStyle(
                                fontSize: secondaryTextFontSize,
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                              ),
                              maxLines: isVeryNarrowScreen ? 2 : 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(height: isNarrowScreen ? 14.0 : 20.0), // Reduced from 16/24 to 14/20

                            // Current Password Field
                            _buildPasswordField(
                              controller: _currentPasswordController,
                              label: 'Current Password',
                              obscureText: _obscureCurrentPassword,
                              onToggleVisibility: () {
                                setState(() {
                                  _obscureCurrentPassword = !_obscureCurrentPassword;
                                });
                              },
                              validator: _validateCurrentPassword,
                              isNarrowScreen: isNarrowScreen,
                            ),
                            SizedBox(height: isNarrowScreen ? 12.0 : 16.0),

                            // New Password Field
                            _buildPasswordField(
                              controller: _newPasswordController,
                              label: 'New Password',
                              obscureText: _obscureNewPassword,
                              onToggleVisibility: () {
                                setState(() {
                                  _obscureNewPassword = !_obscureNewPassword;
                                });
                              },
                              validator: _validateNewPassword,
                              isNarrowScreen: isNarrowScreen,
                            ),
                            SizedBox(height: isNarrowScreen ? 12.0 : 16.0),

                            // Confirm Password Field
                            _buildPasswordField(
                              controller: _confirmPasswordController,
                              label: 'Confirm New Password',
                              obscureText: _obscureConfirmPassword,
                              onToggleVisibility: () {
                                setState(() {
                                  _obscureConfirmPassword = !_obscureConfirmPassword;
                                });
                              },
                              validator: _validateConfirmPassword,
                              isNarrowScreen: isNarrowScreen,
                            ),
                            SizedBox(height: isNarrowScreen ? 16.0 : 24.0),

                            // Password Requirements
                            Container(
                              padding: EdgeInsets.all(isNarrowScreen ? 12.0 : 16.0),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: theme.colorScheme.primary.withValues(alpha: 0.2),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.info_outline,
                                        size: isNarrowScreen ? 18.0 : 20.0,
                                        color: theme.colorScheme.primary,
                                      ),
                                      SizedBox(width: isNarrowScreen ? 6.0 : 8.0),
                                      Expanded(
                                        child: Text(
                                          'Password Requirements',
                                          style: TextStyle(
                                            fontSize: secondaryTextFontSize,
                                            fontWeight: FontWeight.w600,
                                            color: theme.colorScheme.primary,
                                          ),
                                          maxLines: isVeryNarrowScreen ? 2 : 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: isNarrowScreen ? 6.0 : 8.0),
                                  _buildRequirement('At least 6 characters long', isNarrowScreen),
                                  _buildRequirement('Different from current password', isNarrowScreen),
                                ],
                              ),
                            ),
                            SizedBox(height: isNarrowScreen ? 24.0 : 32.0),

                            // Change Password Button
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _changePassword,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _isLoading ? theme.disabledColor : theme.colorScheme.primary,
                                  foregroundColor: theme.colorScheme.onPrimary,
                                  padding: EdgeInsets.symmetric(vertical: isNarrowScreen ? 14.0 : 16.0),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: _isLoading ? 0 : 2,
                                ),
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 200),
                                  child: _isLoading
                                      ? Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            SizedBox(
                                              height: isNarrowScreen ? 16.0 : 18.0,
                                              width: isNarrowScreen ? 16.0 : 18.0,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.onPrimary),
                                              ),
                                            ),
                                            SizedBox(width: isNarrowScreen ? 10.0 : 12.0),
                                            Text(
                                              isVeryNarrowScreen ? 'Changing...' : 'Changing Password...',
                                              style: TextStyle(
                                                fontSize: buttonTextFontSize,
                                                fontWeight: FontWeight.bold,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        )
                                      : Text(
                                          'Change Password',
                                          style: TextStyle(
                                            fontSize: buttonTextFontSize,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: spacingAfterHeader),

                    // Delete Account Section
                    Container(
                      padding: EdgeInsets.all(containerPadding),
                      decoration: BoxDecoration(
                        color: theme.cardTheme.color,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: theme.shadowColor.withValues(alpha: 0.1),
                            spreadRadius: 1,
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Delete Account',
                            style: TextStyle(
                              fontSize: sectionHeaderFontSize,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurface,
                            ),
                            maxLines: isVeryNarrowScreen ? 2 : 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: isNarrowScreen ? 4.0 : 6.0),
                          Text(
                            'Permanently delete your account and all associated data',
                            style: TextStyle(
                              fontSize: secondaryTextFontSize,
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                            maxLines: isVeryNarrowScreen ? 2 : 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: isNarrowScreen ? 16.0 : 24.0),

                          // Warning Message
                          Container(
                            padding: EdgeInsets.all(isNarrowScreen ? 12.0 : 16.0),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.red.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.warning_amber,
                                      size: isNarrowScreen ? 18.0 : 20.0,
                                      color: Colors.red,
                                    ),
                                    SizedBox(width: isNarrowScreen ? 6.0 : 8.0),
                                    Expanded(
                                      child: Text(
                                        'Important Notice',
                                        style: TextStyle(
                                          fontSize: secondaryTextFontSize,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.red,
                                        ),
                                        maxLines: isVeryNarrowScreen ? 2 : 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: isNarrowScreen ? 6.0 : 8.0),
                                Text(
                                  'Deleting your account will permanently remove all your data including transactions, budgets, goals, and profile information. This action cannot be undone.',
                                  style: TextStyle(
                                    fontSize: bodyTextFontSize,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: isNarrowScreen ? 24.0 : 32.0),

                          // Delete Account Button
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: _isLoading ? null : _deleteAccount,
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.red),
                                padding: EdgeInsets.symmetric(vertical: isNarrowScreen ? 14.0 : 16.0),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 200),
                                child: _isLoading
                                    ? Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          SizedBox(
                                            height: isNarrowScreen ? 16.0 : 18.0,
                                            width: isNarrowScreen ? 16.0 : 18.0,
                                            child: const CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
                                            ),
                                          ),
                                          SizedBox(width: isNarrowScreen ? 10.0 : 12.0),
                                          Text(
                                            'Deleting...',
                                            style: TextStyle(
                                              fontSize: buttonTextFontSize,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.red,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      )
                                    : Text(
                                        'Delete Account',
                                        style: TextStyle(
                                          fontSize: buttonTextFontSize,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.red,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: spacingAfterHeader),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required bool obscureText,
    required VoidCallback onToggleVisibility,
    required String? Function(String?) validator,
    required bool isNarrowScreen,
  }) {
    final theme = Theme.of(context);
    
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(Icons.lock_outline, color: theme.colorScheme.primary),
        suffixIcon: IconButton(
          icon: Icon(
            obscureText ? Icons.visibility : Icons.visibility_off,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
          onPressed: onToggleVisibility,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: theme.dividerColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: theme.dividerColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
        ),
        filled: true,
        fillColor: theme.cardTheme.color,
      ),
    );
  }

  Widget _buildRequirement(String text, bool isNarrowScreen) {
    final theme = Theme.of(context);
    final captionFontSize = isNarrowScreen ? 10.0 : 12.0; // Caption range (10–12sp)
    
    return Padding(
      padding: EdgeInsets.only(top: isNarrowScreen ? 3.0 : 4.0),
      child: Row(
        children: [
          Icon(
            Icons.check_circle_outline,
            size: isNarrowScreen ? 14.0 : 16.0,
            color: theme.colorScheme.primary,
          ),
          SizedBox(width: isNarrowScreen ? 6.0 : 8.0),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: captionFontSize,
                color: theme.colorScheme.primary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}