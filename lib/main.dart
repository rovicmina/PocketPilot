import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'firebase_options.dart';
import 'services/firebase_service.dart';
import 'services/theme_service.dart';
import 'services/transaction_monitor_service.dart';
import 'services/budget_preloader_service.dart';
import 'services/smart_notification_service.dart';
import 'services/widget_data_service.dart';
import 'services/native_widget_bridge.dart';
import 'services/notification_sync_service.dart';
import 'pages/main_navigation.dart';
import 'pages/user_info_form_page.dart';
import 'pages/profile_page.dart';
import 'pages/forgot_password_page.dart';
import 'utils/form_state_tracker.dart';
import 'widgets/unsaved_changes_dialog.dart';
import 'widgets/app_logo.dart';
import 'utils/responsive_utils.dart';
import 'widgets/tutorial_cleanup.dart';
import 'widgets/tutorial_error_handler.dart';
import 'widgets/edge_to_edge_widget.dart'; // Import edge-to-edge widget

import 'widgets/tutorial_hotfix.dart';
import 'widgets/error_boundary.dart';
import 'utils/logger.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set up global error handler
  FlutterError.onError = (FlutterErrorDetails details) {
    // Log the error using our logger
    Logger.exception(details.exception, details.stack);
    
    // Handle tutorial system errors specifically
    try {
      if (details.exception.toString().contains('_dependents.isEmpty')) {
        // This is the specific error we're trying to fix
        TutorialErrorHandler.handleWidgetDependencyError(details.exception, details.stack ?? StackTrace.current);
      } else {
        TutorialErrorHandler.handleTutorialError(details.exception, details.stack ?? StackTrace.current);
      }
    } catch (e) {
      Logger.error('Error in tutorial error handler: $e');
    }
    
    // In production, you might want to send this to a logging service
  };
  
  // Add zone error handler for async errors
  runZonedGuarded(() async {
    // Clean up tutorial resources to prevent dependency issues
    TutorialCleanup.cleanupTutorialResources();

    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Initialize essential services immediately
    TransactionMonitorService.startMonitoring();

    // Initialize non-critical services in background (non-blocking)
    Future.microtask(() async {
      try {
        // Initialize services that don't need to block app startup
        await Future.wait([
          SmartNotificationService.initialize(),
          NotificationSyncService.initialize(),
          WidgetDataService.initializeWidgetData(),
        ]);

        // Update widget data immediately after initialization
        await WidgetDataService.updateWidgetData();
      } catch (e) {
        Logger.error('Background service initialization error: $e');
        // Handle tutorial system errors specifically
        TutorialErrorHandler.handleTutorialError(e, StackTrace.current);
      }
    });

    // Set up widget click handler (non-blocking)
    Future.microtask(() {
      NativeWidgetBridge.setWidgetClickHandler((action) {
        // Handle widget clicks here - could navigate to specific pages
      });
    });

    runApp(const MyApp());
  }, (error, stackTrace) {
    // Handle async errors
    Logger.exception(error, stackTrace);
    
    // Handle tutorial system errors specifically
    try {
      if (error.toString().contains('_dependents.isEmpty')) {
        // This is the specific error we're trying to fix
        TutorialErrorHandler.handleWidgetDependencyError(error, stackTrace);
      } else {
        TutorialErrorHandler.handleTutorialError(error, stackTrace);
      }
    } catch (e) {
      Logger.error('Error in tutorial error handler: $e');
    }
  });
}

// Error boundary widget to catch unhandled exceptions
class ErrorBoundary extends StatefulWidget {
  final Widget child;

  const ErrorBoundary({super.key, required this.child});

  @override
  State<ErrorBoundary> createState() => _ErrorBoundaryState();
}

class _ErrorBoundaryState extends State<ErrorBoundary> {
  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final ThemeService _themeService = ThemeService();

  @override
  void initState() {
    super.initState();
    // Initialize theme in background without blocking UI
    _initializeThemeAsync();
    
    // Set up global error handler
    FlutterError.onError = (FlutterErrorDetails details) {
      // Log the error
      debugPrint('Flutter Error: ${details.exception}');
      debugPrint('Stack Trace: ${details.stack}');
      
      // Handle tutorial system errors specifically
      try {
        if (details.exception.toString().contains('_dependents.isEmpty')) {
          // This is the specific error we're trying to fix
          TutorialErrorHandler.handleWidgetDependencyError(details.exception, details.stack ?? StackTrace.current);
        } else {
          TutorialErrorHandler.handleTutorialError(details.exception, details.stack ?? StackTrace.current);
        }
      } catch (e) {
        debugPrint('Error in tutorial error handler: $e');
      }
      
      // You could send this to a logging service in production
    };
  }

  void _initializeThemeAsync() {
    // Initialize theme asynchronously without blocking the UI
    _themeService.initializeTheme().catchError((e) {
      Logger.error('Theme initialization error: $e');
    });
  }

  @override
  Widget build(BuildContext context) {
    return EdgeToEdgeWidget( // Wrap the entire app with EdgeToEdgeWidget
      child: ErrorBoundary(
        child: AnimatedBuilder(
          animation: _themeService,
          builder: (context, child) {
            return MaterialApp(
              title: 'PocketPilot',
              theme: _themeService.lightTheme,
              darkTheme: _themeService.darkTheme,
              themeMode: _themeService.isDarkMode ? ThemeMode.dark : ThemeMode.light,
              home: const AppInitializer(),
              routes: {
                '/profile': (context) => const ProfilePage(),
              },
              // Disable hero animations globally to avoid duplicate hero tag errors
              navigatorObservers: [
                HeroController(createRectTween: (begin, end) => RectTween(begin: begin, end: end)),
              ],
              // Add error handler for the entire app
              builder: (context, widget) {
                return ErrorBoundary(
                  child: widget ?? Container(),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class AppInitializer extends StatefulWidget {
  const AppInitializer({super.key});

  @override
  State<AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends State<AppInitializer> {
  bool _budgetPreloadStarted = false;
  bool _profileCheckCompleted = false;
  bool? _isProfileComplete;
  bool _hasError = false; // Track if we've encountered an error

  @override
  void initState() {
    super.initState();
    try {
      // Clean up tutorial resources when app initializes
      TutorialCleanup.cleanupTutorialResources();
    } catch (e) {
      Logger.error('Error cleaning up tutorial resources: $e');
      // Continue initialization even if cleanup fails
    }
    // Pre-check profile status when auth state becomes available
    _initializeProfileCheck();
  }

  void _initializeProfileCheck() {
    FirebaseAuth.instance.authStateChanges().listen((user) async {
      if (user != null && !_profileCheckCompleted && !_hasError) {
        _profileCheckCompleted = true;
        try {
          // Add a small delay to ensure auth state is fully settled
          await Future.delayed(const Duration(milliseconds: 500));
          
          // Check profile in background with timeout
          final profileCheckResult = await FirebaseService.isUserProfileComplete()
              .timeout(const Duration(seconds: 10)); // Add timeout to prevent hanging
          
          if (mounted) {
            setState(() {
              _isProfileComplete = profileCheckResult;
              _hasError = false;
            });
          }
        } catch (e) {
          Logger.error('Profile check error: $e');
          if (mounted) {
            setState(() {
              _isProfileComplete = false; // Default to incomplete on error
              _hasError = true; // Mark that we had an error
            });
          }
          
          // Show error message to user
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Error loading profile. Please try again.'),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 4),
              ),
            );
          }
        }
      }
    }, onError: (error) {
      Logger.error('Auth state change error: $error');
      if (mounted) {
        setState(() {
          _hasError = true;
        });
        
        // Show error message to user
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Authentication error. Please try logging in again.'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    });
  }

  /// Start budget preloading when user is authenticated
  void _startBudgetPreloadingIfNeeded(User? user) {
    if (user != null && !_budgetPreloadStarted) {
      _budgetPreloadStarted = true;
      // Start budget preloading in background (non-blocking)
      Future.microtask(() {
        BudgetPreloaderService.preloadBudgetData().catchError((e) {
          Logger.error('Budget preloading error: $e');
          // Don't propagate this error to UI as it's non-critical
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Show loading while waiting for auth state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // Handle auth errors
        if (snapshot.hasError) {
          Logger.error('Auth stream error: ${snapshot.error}');
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, color: Colors.red, size: 48),
                  const SizedBox(height: 16),
                  const Text(
                    'Authentication Error',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Please try logging in again.',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      // Reset error state and try again
                      setState(() {
                        _hasError = false;
                        _profileCheckCompleted = false;
                        _isProfileComplete = null;
                      });
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }

        final user = snapshot.data;

        // Navigate based on auth state
        if (user != null) {
          // Start budget preloading as soon as user is authenticated
          _startBudgetPreloadingIfNeeded(user);

          // Check if profile check is completed or if we had an error
          if (_hasError) {
            return Scaffold(
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error, color: Colors.red, size: 48),
                    const SizedBox(height: 16),
                    const Text(
                      'Profile Loading Error',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Unable to load your profile information.',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () async {
                        // Reset error state and try again
                        setState(() {
                          _hasError = false;
                          _profileCheckCompleted = false;
                          _isProfileComplete = null;
                        });
                        
                        // Force refresh the user token
                        await FirebaseService.refreshAuthToken();
                      },
                      child: const Text('Retry'),
                    ),
                    TextButton(
                      onPressed: () async {
                        // Logout and go back to login screen
                        await FirebaseService.logout();
                        if (mounted) {
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(builder: (context) => const LandingPage()),
                            (route) => false,
                          );
                        }
                      },
                      child: const Text('Logout'),
                    ),
                  ],
                ),
              ),
            );
          }
          
          if (_isProfileComplete == null) {
            // Still checking profile
            return const Scaffold(
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Loading your profile...'),
                  ],
                ),
              ),
            );
          }

          // Redirect based on profile completion
          return _isProfileComplete! ? const MainNavigation() : const UserInfoFormPage();
        } else {
          return const LandingPage();
        }
      },
    );
  }
}

class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Determine responsive layout parameters
          final isNarrowScreen = constraints.maxWidth < 600;
          final isVeryNarrowScreen = constraints.maxWidth < 400;
          final isExtremelyNarrowScreen = constraints.maxWidth < 320;
          final isWideScreen = constraints.maxWidth > 1200;

          // Responsive sizing
          final padding = isExtremelyNarrowScreen ? 12.0 : isVeryNarrowScreen ? 16.0 : isNarrowScreen ? 20.0 : isWideScreen ? 40.0 : 24.0;
          final logoSize = isExtremelyNarrowScreen ? 100.0 : isVeryNarrowScreen ? 120.0 : isNarrowScreen ? 140.0 : isWideScreen ? 180.0 : 160.0;
          final logoFontSize = isExtremelyNarrowScreen ? 28.0 : isVeryNarrowScreen ? 32.0 : isNarrowScreen ? 36.0 : isWideScreen ? 44.0 : 40.0;
          final featureTextFontSize = isExtremelyNarrowScreen ? 12.0 : isVeryNarrowScreen ? 14.0 : isNarrowScreen ? 16.0 : isWideScreen ? 20.0 : 18.0;
          final spacingAfterLogo = isExtremelyNarrowScreen ? 12.0 : isVeryNarrowScreen ? 16.0 : isNarrowScreen ? 20.0 : isWideScreen ? 28.0 : 24.0;
          final spacingAfterFeatures = isExtremelyNarrowScreen ? 20.0 : isVeryNarrowScreen ? 24.0 : isNarrowScreen ? 28.0 : isWideScreen ? 40.0 : 36.0;
          final buttonSpacing = isExtremelyNarrowScreen ? 10.0 : isVeryNarrowScreen ? 12.0 : isNarrowScreen ? 14.0 : isWideScreen ? 18.0 : 16.0; // Reduced from 12-22 to 10-18
          final buttonHeight = isExtremelyNarrowScreen ? 40.0 : isVeryNarrowScreen ? 44.0 : isNarrowScreen ? 48.0 : isWideScreen ? 52.0 : 50.0; // Reduced from 44-60 to 40-52
          final buttonFontSize = isExtremelyNarrowScreen ? 14.0 : isVeryNarrowScreen ? 15.0 : isNarrowScreen ? 16.0 : isWideScreen ? 18.0 : 17.0; // Reduced from 16-20 to 14-18

          return SingleChildScrollView(
            child: SafeArea(
              child: SizedBox(
                height: constraints.maxHeight, // Take full height
                child: Padding(
                  padding: EdgeInsets.all(padding),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center, // Center vertically
                    children: [
                      // App Logo with branding
                      AppLogoWithText(
                        logoSize: logoSize,
                        fontSize: logoFontSize,
                        showSubtitle: !isExtremelyNarrowScreen, // Hide subtitle on extremely narrow screens
                      ),
                      SizedBox(height: spacingAfterLogo),
                      Text(
                        '• Track your expenses\n• Set financial goals\n• Get personalized advice\n• Build wealth smartly',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: featureTextFontSize,
                          height: 1.5,
                        ),
                      ),
                      SizedBox(height: spacingAfterFeatures),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const LoginPage()),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            minimumSize: Size(double.infinity, buttonHeight),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(isExtremelyNarrowScreen ? 8.0 : 12.0),
                            ),
                          ),
                          child: Text(
                            'Sign In',
                            style: TextStyle(fontSize: buttonFontSize),
                          ),
                        ),
                      ),
                      SizedBox(height: buttonSpacing),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const SignUpPage()),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            minimumSize: Size(double.infinity, buttonHeight),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(isExtremelyNarrowScreen ? 8.0 : 12.0),
                            ),
                          ),
                          child: Text(
                            'Sign Up',
                            style: TextStyle(fontSize: buttonFontSize),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with FormStateTracker {
  final _formKey = GlobalKey<FormState>();
  late final TrackedTextEditingController _emailController;
  late final TrackedTextEditingController _passwordController;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _emailController = createTrackedController('email', this);
    _passwordController = createTrackedController('password', this);

    // Initialize form tracking with empty values
    initializeFormTracking({
      'email': '',
      'password': '',
    });
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email is required';
    }
    if (!value.contains('@') || !value.contains('.')) {
      return 'Please enter a valid email';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (value.length < 6) {
      return 'Password must be at least 6 characters';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return TutorialHotfixWrapper( // Wrap with TutorialHotfixWrapper
      child: FormPageWrapper(
        hasUnsavedChanges: hasUnsavedChanges,
        warningTitle: 'Discard Login?',
        warningMessage: 'You have entered some information. Are you sure you want to go back?',
        child: Scaffold(
          appBar: AppBar(
            title: LayoutBuilder(
              builder: (context, constraints) {
                final isNarrowScreen = constraints.maxWidth < 600;
                final isVeryNarrowScreen = constraints.maxWidth < 400;
                final isExtremelyNarrowScreen = constraints.maxWidth < 320;
                final titleFontSize = isExtremelyNarrowScreen ? 16.0 : isVeryNarrowScreen ? 17.0 : isNarrowScreen ? 18.0 : 20.0; // Section Heading range (16–20sp)
                return Text(
                  'Sign In',
                  style: TextStyle(fontSize: titleFontSize),
                );
              },
            ),
            backgroundColor: Colors.teal,
          ),
          body: LayoutBuilder(
            builder: (context, constraints) {
              // Determine responsive layout parameters
              final isNarrowScreen = constraints.maxWidth < 600;
              final isVeryNarrowScreen = constraints.maxWidth < 400;
              final isExtremelyNarrowScreen = constraints.maxWidth < 320;
              final isUltraNarrowScreen = constraints.maxWidth < 280; // Added for ultra narrow screens
              final isWideScreen = constraints.maxWidth > 1200;

              // Responsive sizing
              final padding = isUltraNarrowScreen ? 8.0 : isExtremelyNarrowScreen ? 10.0 : isVeryNarrowScreen ? 12.0 : isNarrowScreen ? 14.0 : isWideScreen ? 20.0 : 16.0;
              final iconSize = isUltraNarrowScreen ? 40.0 : isExtremelyNarrowScreen ? 45.0 : isVeryNarrowScreen ? 50.0 : isNarrowScreen ? 55.0 : isWideScreen ? 80.0 : 60.0;
              final spacingAfterIcon = isUltraNarrowScreen ? 16.0 : isExtremelyNarrowScreen ? 18.0 : isVeryNarrowScreen ? 20.0 : isNarrowScreen ? 22.0 : isWideScreen ? 32.0 : 24.0;
              final fieldSpacing = isUltraNarrowScreen ? 8.0 : isExtremelyNarrowScreen ? 9.0 : isVeryNarrowScreen ? 10.0 : isNarrowScreen ? 11.0 : isWideScreen ? 16.0 : 12.0;
              final forgotPasswordFontSize = isUltraNarrowScreen ? 10.0 : isExtremelyNarrowScreen ? 11.0 : isVeryNarrowScreen ? 12.0 : isNarrowScreen ? 12.5 : isWideScreen ? 15.0 : 13.0;
              final buttonPadding = isUltraNarrowScreen ? 4.0 : isExtremelyNarrowScreen ? 5.0 : isVeryNarrowScreen ? 6.0 : isNarrowScreen ? 7.0 : isWideScreen ? 12.0 : 8.0;
              final buttonFontSize = isUltraNarrowScreen ? 13.0 : isExtremelyNarrowScreen ? 14.0 : isVeryNarrowScreen ? 15.0 : isNarrowScreen ? 15.5 : isWideScreen ? 18.0 : 16.0;
              final buttonHeight = isUltraNarrowScreen ? 36.0 : isExtremelyNarrowScreen ? 38.0 : isVeryNarrowScreen ? 40.0 : isNarrowScreen ? 42.0 : isWideScreen ? 54.0 : 46.0;
              final bottomTextFontSize = isUltraNarrowScreen ? 11.0 : isExtremelyNarrowScreen ? 12.0 : isVeryNarrowScreen ? 13.0 : isNarrowScreen ? 13.5 : isWideScreen ? 16.0 : 14.0;
              final formFieldHeight = isUltraNarrowScreen ? 38.0 : isExtremelyNarrowScreen ? 40.0 : isVeryNarrowScreen ? 42.0 : isNarrowScreen ? 44.0 : isWideScreen ? 60.0 : 48.0;
              final borderRadius = isUltraNarrowScreen ? 4.0 : isExtremelyNarrowScreen ? 5.0 : isVeryNarrowScreen ? 6.0 : 8.0;

              return SingleChildScrollView(
                padding: EdgeInsets.all(padding),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(height: spacingAfterIcon), // Add top margin
                      Icon(
                        Icons.account_circle,
                        size: iconSize,
                        color: Colors.teal,
                      ),
                      SizedBox(height: spacingAfterIcon),
                      SizedBox(
                        height: formFieldHeight,
                        child: TextFormField(
                          controller: _emailController,
                          decoration: InputDecoration(
                            labelText: 'Email',
                            prefixIcon: const Icon(Icons.email, size: 18),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(borderRadius),
                            ),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: isUltraNarrowScreen ? 8.0 : 12.0,
                              vertical: isUltraNarrowScreen ? 6.0 : 10.0,
                            ),
                          ),
                          keyboardType: TextInputType.emailAddress,
                          validator: _validateEmail,
                          style: TextStyle(
                            fontSize: isUltraNarrowScreen ? 12.0 : isExtremelyNarrowScreen ? 13.0 : 14.0,
                          ),
                        ),
                      ),
                      SizedBox(height: fieldSpacing),
                      SizedBox(
                        height: formFieldHeight,
                        child: TextFormField(
                          controller: _passwordController,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: const Icon(Icons.lock, size: 18),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(borderRadius),
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword ? Icons.visibility_off : Icons.visibility,
                                size: isUltraNarrowScreen ? 16.0 : 18.0,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                              padding: EdgeInsets.zero,
                              constraints: BoxConstraints(
                                minWidth: isUltraNarrowScreen ? 30.0 : 36.0,
                                minHeight: isUltraNarrowScreen ? 30.0 : 36.0,
                              ),
                            ),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: isUltraNarrowScreen ? 8.0 : 12.0,
                              vertical: isUltraNarrowScreen ? 6.0 : 10.0,
                            ),
                          ),
                          obscureText: _obscurePassword,
                          validator: _validatePassword,
                          style: TextStyle(
                            fontSize: isUltraNarrowScreen ? 12.0 : isExtremelyNarrowScreen ? 13.0 : 14.0,
                          ),
                        ),
                      ),
                      SizedBox(height: fieldSpacing),
                      // Forgot Password Button
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const ForgotPasswordPage(),
                              ),
                            );
                          },
                          child: Text(
                            'Forgot Password?',
                            style: TextStyle(
                              color: Colors.teal,
                              fontSize: forgotPasswordFontSize,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      ElevatedButton(
                        onPressed: () async {
                          if (_formKey.currentState!.validate()) {
                            setSubmitting(true);
                            final navigator = Navigator.of(context);
                            final scaffoldMessenger = ScaffoldMessenger.of(context);

                            try {
                              // Show loading indicator
                              if (mounted) {
                                scaffoldMessenger.showSnackBar(
                                  SnackBar(
                                    content: Row(
                                      children: [
                                        SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: isUltraNarrowScreen ? 1.5 : 2,
                                            valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                                          ),
                                        ),
                                        SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'Signing in...',
                                            style: TextStyle(
                                              fontSize: isUltraNarrowScreen ? 12.0 : 14.0,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                    backgroundColor: Colors.teal,
                                    duration: const Duration(seconds: 10),
                                    behavior: SnackBarBehavior.floating,
                                    margin: EdgeInsets.all(isUltraNarrowScreen ? 8.0 : 16.0),
                                  ),
                                );
                              }

                              // Initialize result with a default error value
                              Map<String, dynamic> result = {
                                'success': false,
                                'message': 'Login failed. Please try again.'
                              };

                              // Try login with retry mechanism for unknown errors
                              int retryCount = 0;
                              const maxRetries = 2;

                              do {
                                try {
                                  result = await FirebaseService.loginUser(
                                    _emailController.text.trim(),
                                    _passwordController.text.trim(),
                                  );

                                  // If we get an unknown error, retry
                                  if (result['success'] == false &&
                                      result['message'] != null &&
                                      (result['message'].toString().contains('unknown') ||
                                       result['message'].toString().contains('Unable to connect')) &&
                                      retryCount < maxRetries) {
                                    retryCount++;
                                    Logger.debug('Retrying login due to connection error (attempt $retryCount)');
                                    await Future.delayed(Duration(milliseconds: 1500 * retryCount)); // Exponential backoff
                                  } else {
                                    break; // Success or a different error, don't retry
                                  }
                                } catch (loginError) {
                                  Logger.error('Login attempt error: $loginError');
                                  
                                  // If it's a network error and we have retries left, retry
                                  if (retryCount < maxRetries && 
                                      (loginError.toString().contains('network') || 
                                       loginError.toString().contains('unknown'))) {
                                    retryCount++;
                                    Logger.debug('Retrying login due to network error (attempt $retryCount)');
                                    await Future.delayed(Duration(milliseconds: 1500 * retryCount));
                                  } else {
                                    // For other errors or max retries reached, return error result
                                    result = {
                                      'success': false,
                                      'message': 'Login failed. Please try again.'
                                    };
                                    break;
                                  }
                                }
                              } while (retryCount <= maxRetries);

                              // Clear the loading message
                              if (mounted) {
                                scaffoldMessenger.hideCurrentSnackBar();
                              }

                              if (mounted) {
                                if (result['success'] == true) {
                                  // Get user information for personalized welcome
                                  final user = await FirebaseService.getUser();
                                  final userName = user?.name ?? 'User';

                                  // Navigate directly to dashboard without any dialog
                                  if (mounted) {
                                    Navigator.pushAndRemoveUntil(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => const _AppRestartWrapper(
                                          child: MainNavigation(),
                                        ),
                                      ),
                                      (route) => false,
                                    );
                                  }
                                } else {
                                  scaffoldMessenger.showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        result['message'] ?? 'Login failed',
                                        style: TextStyle(
                                          fontSize: isUltraNarrowScreen ? 12.0 : 14.0,
                                        ),
                                      ),
                                      backgroundColor: Colors.red,
                                      duration: const Duration(seconds: 4),
                                      behavior: SnackBarBehavior.floating,
                                      margin: EdgeInsets.all(isUltraNarrowScreen ? 8.0 : 16.0),
                                    ),
                                  );
                                }
                              }
                            } catch (error) {
                              Logger.error('Login error: $error');
                              String errorMessage = 'Login failed. Please try again.';

                              // Provide more specific error messages for common issues
                              if (error.toString().contains('unknown-error')) {
                                errorMessage = 'Unable to connect to authentication service. Please check your internet connection and try again.';
                              } else if (error.toString().contains('network-request-failed')) {
                                errorMessage = 'Network connection error. Please check your internet connection and try again.';
                              } else if (error.toString().contains('too-many-requests')) {
                                errorMessage = 'Too many login attempts. Please wait a few minutes and try again.';
                              } else if (error.toString().contains('invalid-credential')) {
                                errorMessage = 'Invalid email or password. Please check your credentials and try again.';
                              } else {
                                errorMessage = 'Login failed: ${error.toString()}';
                              }

                              if (mounted) {
                                scaffoldMessenger.showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      isUltraNarrowScreen 
                                          ? 'Login failed. Try again.' 
                                          : errorMessage,
                                      style: TextStyle(
                                        fontSize: isUltraNarrowScreen ? 12.0 : 14.0,
                                      ),
                                    ),
                                    backgroundColor: Colors.red,
                                    duration: const Duration(seconds: 6),
                                    behavior: SnackBarBehavior.floating,
                                    margin: EdgeInsets.all(isUltraNarrowScreen ? 8.0 : 16.0),
                                  ),
                                );
                              }
                            } finally {
                              if (mounted) {
                                setSubmitting(false);
                              }
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          minimumSize: Size(double.infinity, buttonHeight),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(borderRadius),
                          ),
                          padding: EdgeInsets.zero,
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(buttonPadding),
                          child: Text(
                            'Sign In',
                            style: TextStyle(fontSize: buttonFontSize),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            isUltraNarrowScreen ? 'New?' : 'New User?',
                            style: TextStyle(fontSize: bottomTextFontSize),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(width: 4),
                          GestureDetector(
                            onTap: () {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(builder: (context) => const SignUpPage()),
                              );
                            },
                            child: Text(
                              'Sign up',
                              style: TextStyle(
                                fontSize: bottomTextFontSize,
                                color: Colors.teal,
                                fontWeight: FontWeight.bold,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}

/// A custom AlertDialog that automatically closes after a timeout period
class _TimedAlertDialog extends StatefulWidget {
  final String title;
  final String message;
  final String buttonText;

  const _TimedAlertDialog({
    required this.title,
    required this.message,
    required this.buttonText,
  });

  @override
  State<_TimedAlertDialog> createState() => _TimedDialogState();
}

class _TimedDialogState extends State<_TimedAlertDialog> {
  late Timer _timer;
  int _countdown = 5; // 5 seconds countdown

  @override
  void initState() {
    super.initState();
    // Start countdown timer
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _countdown--;
        });
        
        // Close dialog when countdown reaches 0
        if (_countdown <= 0) {
          _closeDialog();
        }
      }
    });
  }

  void _closeDialog() {
    _timer.cancel();
    if (mounted) {
      Navigator.of(context).pop(true); // true indicates timeout closure
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.celebration, color: Colors.green, size: 28),
          const SizedBox(width: 8),
          Text(widget.title),
        ],
      ),
      content: Text(widget.message),
      actions: [
        TextButton(
          onPressed: _closeDialog,
          child: Text(
            '${widget.buttonText} ($_countdown)',
            style: const TextStyle(color: Colors.teal, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> with FormStateTracker {
  final _formKey = GlobalKey<FormState>();
  late final TrackedTextEditingController _nameController;
  late final TrackedTextEditingController _emailController;
  late final TrackedTextEditingController _passwordController;
  late final TrackedTextEditingController _confirmPasswordController;

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _nameController = createTrackedController('name', this);
    _emailController = createTrackedController('email', this);
    _passwordController = createTrackedController('password', this);
    _confirmPasswordController = createTrackedController('confirmPassword', this);

    // Initialize form tracking with empty values
    initializeFormTracking({
      'name': '',
      'email': '',
      'password': '',
      'confirmPassword': '',
    });
  }

  String? _validateName(String? value) {
    if (value == null || value.isEmpty) {
      return 'Name is required';
    }
    return null;
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email is required';
    }
    if (!value.contains('@') || !value.contains('.')) {
      return 'Please enter a valid email';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (value.length < 6) {
      return 'Password must be at least 6 characters';
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your password';
    }
    if (value != _passwordController.text) {
      return 'Passwords do not match';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return TutorialHotfixWrapper( // Wrap with TutorialHotfixWrapper
      child: FormPageWrapper(
        hasUnsavedChanges: hasUnsavedChanges,
        warningTitle: 'Discard Sign Up?',
        warningMessage: 'You have entered some information. Are you sure you want to go back?',
        child: Scaffold(
          appBar: AppBar(
            title: LayoutBuilder(
              builder: (context, constraints) {
                final isNarrowScreen = constraints.maxWidth < 600;
                final isVeryNarrowScreen = constraints.maxWidth < 400;
                final isExtremelyNarrowScreen = constraints.maxWidth < 320;
                final isUltraNarrowScreen = constraints.maxWidth < 280; // Added for ultra narrow screens
                final titleFontSize = isUltraNarrowScreen ? 16.0 : isExtremelyNarrowScreen ? 17.0 : isVeryNarrowScreen ? 18.0 : isNarrowScreen ? 19.0 : 20.0; // Section Heading range (16–20sp)
                return Text(
                  'Sign Up',
                  style: TextStyle(fontSize: titleFontSize),
                );
              },
            ),
            backgroundColor: Colors.teal,
          ),
          body: LayoutBuilder(
            builder: (context, constraints) {
              // Determine responsive layout parameters
              final isNarrowScreen = constraints.maxWidth < 600;
              final isVeryNarrowScreen = constraints.maxWidth < 400;
              final isExtremelyNarrowScreen = constraints.maxWidth < 320;
              final isUltraNarrowScreen = constraints.maxWidth < 280; // Added for ultra narrow screens
              final isWideScreen = constraints.maxWidth > 1200;

              // Responsive sizing
              final padding = isUltraNarrowScreen ? 8.0 : isExtremelyNarrowScreen ? 10.0 : isVeryNarrowScreen ? 12.0 : isNarrowScreen ? 14.0 : isWideScreen ? 20.0 : 16.0;
              final iconSize = isUltraNarrowScreen ? 40.0 : isExtremelyNarrowScreen ? 45.0 : isVeryNarrowScreen ? 50.0 : isNarrowScreen ? 55.0 : isWideScreen ? 80.0 : 60.0;
              final spacingAfterIcon = isUltraNarrowScreen ? 16.0 : isExtremelyNarrowScreen ? 18.0 : isVeryNarrowScreen ? 20.0 : isNarrowScreen ? 22.0 : isWideScreen ? 32.0 : 24.0;
              final fieldSpacing = isUltraNarrowScreen ? 8.0 : isExtremelyNarrowScreen ? 9.0 : isVeryNarrowScreen ? 10.0 : isNarrowScreen ? 11.0 : isWideScreen ? 16.0 : 12.0;
              final buttonSpacing = isUltraNarrowScreen ? 14.0 : isExtremelyNarrowScreen ? 16.0 : isVeryNarrowScreen ? 18.0 : isNarrowScreen ? 19.0 : isWideScreen ? 26.0 : 20.0;
              final buttonPadding = isUltraNarrowScreen ? 4.0 : isExtremelyNarrowScreen ? 5.0 : isVeryNarrowScreen ? 6.0 : isNarrowScreen ? 7.0 : isWideScreen ? 12.0 : 8.0;
              final buttonFontSize = isUltraNarrowScreen ? 13.0 : isExtremelyNarrowScreen ? 14.0 : isVeryNarrowScreen ? 15.0 : isNarrowScreen ? 15.5 : isWideScreen ? 18.0 : 16.0;
              final buttonHeight = isUltraNarrowScreen ? 36.0 : isExtremelyNarrowScreen ? 38.0 : isVeryNarrowScreen ? 40.0 : isNarrowScreen ? 42.0 : isWideScreen ? 54.0 : 46.0;
              final bottomTextFontSize = isUltraNarrowScreen ? 11.0 : isExtremelyNarrowScreen ? 12.0 : isVeryNarrowScreen ? 13.0 : isNarrowScreen ? 13.5 : isWideScreen ? 16.0 : 14.0;
              final formFieldHeight = isUltraNarrowScreen ? 38.0 : isExtremelyNarrowScreen ? 40.0 : isVeryNarrowScreen ? 42.0 : isNarrowScreen ? 44.0 : isWideScreen ? 60.0 : 48.0;
              final borderRadius = isUltraNarrowScreen ? 4.0 : isExtremelyNarrowScreen ? 5.0 : isVeryNarrowScreen ? 6.0 : 8.0;

              return SingleChildScrollView(
                padding: EdgeInsets.all(padding),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(height: spacingAfterIcon), // Add top margin
                      Icon(
                        Icons.person_add,
                        size: iconSize,
                        color: Colors.teal,
                      ),
                      SizedBox(height: spacingAfterIcon),
                      SizedBox(
                        height: formFieldHeight,
                        child: TextFormField(
                          controller: _nameController,
                          decoration: InputDecoration(
                            labelText: 'Full Name',
                            prefixIcon: const Icon(Icons.person, size: 18),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(borderRadius),
                            ),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: isUltraNarrowScreen ? 8.0 : 12.0,
                              vertical: isUltraNarrowScreen ? 6.0 : 10.0,
                            ),
                          ),
                          validator: _validateName,
                          style: TextStyle(
                            fontSize: isUltraNarrowScreen ? 12.0 : isExtremelyNarrowScreen ? 13.0 : 14.0,
                          ),
                        ),
                      ),
                      SizedBox(height: fieldSpacing),
                      SizedBox(
                        height: formFieldHeight,
                        child: TextFormField(
                          controller: _emailController,
                          decoration: InputDecoration(
                            labelText: 'Email',
                            prefixIcon: const Icon(Icons.email, size: 18),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(borderRadius),
                            ),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: isUltraNarrowScreen ? 8.0 : 12.0,
                              vertical: isUltraNarrowScreen ? 6.0 : 10.0,
                            ),
                          ),
                          keyboardType: TextInputType.emailAddress,
                          validator: _validateEmail,
                          style: TextStyle(
                            fontSize: isUltraNarrowScreen ? 12.0 : isExtremelyNarrowScreen ? 13.0 : 14.0,
                          ),
                        ),
                      ),
                      SizedBox(height: fieldSpacing),
                      SizedBox(
                        height: formFieldHeight,
                        child: TextFormField(
                          controller: _passwordController,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: const Icon(Icons.lock, size: 18),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(borderRadius),
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword ? Icons.visibility_off : Icons.visibility,
                                size: isUltraNarrowScreen ? 16.0 : 18.0,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                              padding: EdgeInsets.zero,
                              constraints: BoxConstraints(
                                minWidth: isUltraNarrowScreen ? 30.0 : 36.0,
                                minHeight: isUltraNarrowScreen ? 30.0 : 36.0,
                              ),
                            ),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: isUltraNarrowScreen ? 8.0 : 12.0,
                              vertical: isUltraNarrowScreen ? 6.0 : 10.0,
                            ),
                          ),
                          obscureText: _obscurePassword,
                          validator: _validatePassword,
                          style: TextStyle(
                            fontSize: isUltraNarrowScreen ? 12.0 : isExtremelyNarrowScreen ? 13.0 : 14.0,
                          ),
                        ),
                      ),
                      SizedBox(height: fieldSpacing),
                      SizedBox(
                        height: formFieldHeight,
                        child: TextFormField(
                          controller: _confirmPasswordController,
                          decoration: InputDecoration(
                            labelText: 'Confirm Password',
                            prefixIcon: const Icon(Icons.lock_outline, size: 18),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(borderRadius),
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                                size: isUltraNarrowScreen ? 16.0 : 18.0,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscureConfirmPassword = !_obscureConfirmPassword;
                                });
                              },
                              padding: EdgeInsets.zero,
                              constraints: BoxConstraints(
                                minWidth: isUltraNarrowScreen ? 30.0 : 36.0,
                                minHeight: isUltraNarrowScreen ? 30.0 : 36.0,
                              ),
                            ),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: isUltraNarrowScreen ? 8.0 : 12.0,
                              vertical: isUltraNarrowScreen ? 6.0 : 10.0,
                            ),
                          ),
                          obscureText: _obscureConfirmPassword,
                          validator: _validateConfirmPassword,
                          style: TextStyle(
                            fontSize: isUltraNarrowScreen ? 12.0 : isExtremelyNarrowScreen ? 13.0 : 14.0,
                          ),
                        ),
                      ),
                      SizedBox(height: buttonSpacing),
                      ElevatedButton(
                        onPressed: () async {
                          if (_formKey.currentState!.validate()) {
                            setState(() {
                              _isSubmitting = true;
                            });
                            setSubmitting(true);

                            // Store context references before async operations
                            final navigator = Navigator.of(context);
                            final scaffoldMessenger = ScaffoldMessenger.of(context);
                            final email = _emailController.text.trim();
                            final password = _passwordController.text.trim();
                            final name = _nameController.text.trim();

                            try {
                              // Enhanced pre-check: Verify if user is already logged in
                              final initialAuthStatus = await FirebaseService.getAuthStatus();
                              if (initialAuthStatus['authenticated'] == true) {
                                Logger.debug('User already authenticated, logging out before registration');
                                await FirebaseService.logout();
                                // Brief delay to ensure logout completes
                                await Future.delayed(const Duration(milliseconds: 500));
                              }

                              // Show loading indicator for better UX
                              if (mounted) {
                                scaffoldMessenger.showSnackBar(
                                  SnackBar(
                                    content: Row(
                                      children: [
                                        SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: isUltraNarrowScreen ? 1.5 : 2,
                                            valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                                          ),
                                        ),
                                        SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'Creating your account...',
                                            style: TextStyle(
                                              fontSize: isUltraNarrowScreen ? 12.0 : 14.0,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                    backgroundColor: Colors.teal,
                                    duration: const Duration(seconds: 10),
                                    behavior: SnackBarBehavior.floating,
                                    margin: EdgeInsets.all(isUltraNarrowScreen ? 8.0 : 16.0),
                                  ),
                                );
                              }

                              // Initialize result with a default error value
                              Map<String, dynamic> result = {
                                'success': false,
                                'message': 'Registration failed. Please try again.'
                              };

                              // Attempt registration with retry mechanism
                              int retryCount = 0;
                              const maxRetries = 2;

                              do {
                                try {
                                  result = await FirebaseService.registerUser(
                                    email, 
                                    password, 
                                    name
                                  );
                                  break; // Success, don't retry
                                } catch (registerError) {
                                  Logger.error('Registration attempt error: $registerError');
                                  
                                  // If it's a network error and we have retries left, retry
                                  if (retryCount < maxRetries && 
                                      (registerError.toString().contains('network') || 
                                       registerError.toString().contains('unknown'))) {
                                    retryCount++;
                                    Logger.debug('Retrying registration due to network error (attempt $retryCount)');
                                    await Future.delayed(Duration(milliseconds: 1500 * retryCount));
                                  } else {
                                    // For other errors or max retries reached, return error result
                                    result = {
                                      'success': false,
                                      'message': 'Registration failed. Please try again.'
                                    };
                                    break;
                                  }
                                }
                              } while (retryCount <= maxRetries);

                              // Clear the loading message
                              if (mounted) {
                                scaffoldMessenger.hideCurrentSnackBar();
                              }

                              if (mounted) {
                                if (result['success'] == true) {
                                  // Registration reported success - verify authentication
                                  final authStatus = await FirebaseService.getAuthStatus();

                                  if (authStatus['authenticated'] == true) {
                                    debugPrint('Registration successful, user authenticated: ${authStatus['userId']}');

                                    // Navigate directly to user info page without any dialog
                                    if (mounted) {
                                      Navigator.pushAndRemoveUntil(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => const _AppRestartWrapper(
                                            child: UserInfoFormPage(),
                                          ),
                                        ),
                                        (route) => false,
                                      );
                                    }
                                  } else {
                                    // Registration reported success but user not authenticated - inconsistent state
                                    debugPrint('Registration success but authentication failed: ${authStatus['message']}');

                                    // Try to get auth status one more time after a brief delay
                                    await Future.delayed(const Duration(seconds: 1));
                                    final retryAuthStatus = await FirebaseService.getAuthStatus();

                                    if (retryAuthStatus['authenticated'] == true) {
                                      debugPrint('Authentication successful on retry');
                                      // Navigate directly to user info page without any dialog
                                      if (mounted) {
                                        Navigator.pushAndRemoveUntil(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => const _AppRestartWrapper(
                                              child: UserInfoFormPage(),
                                            ),
                                          ),
                                          (route) => false,
                                        );
                                      }
                                    } else {
                                      // Still not authenticated - show error and suggest sign in
                                      if (mounted) {
                                        scaffoldMessenger.showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              isUltraNarrowScreen
                                                  ? 'Account created but auth failed. Try signing in.'
                                                  : 'Account may have been created but authentication failed. '
                                                      'Please try signing in with your email and password.',
                                              style: TextStyle(
                                                fontSize: isUltraNarrowScreen ? 12.0 : 14.0,
                                              ),
                                            ),
                                            backgroundColor: Colors.orange,
                                            duration: const Duration(seconds: 6),
                                            behavior: SnackBarBehavior.floating,
                                            margin: EdgeInsets.all(isUltraNarrowScreen ? 8.0 : 16.0),
                                            action: SnackBarAction(
                                              label: 'Sign In',
                                              textColor: Colors.white,
                                              onPressed: () {
                                                navigator.pushReplacement(
                                                  MaterialPageRoute(builder: (context) => const LoginPage()),
                                                );
                                              },
                                            ),
                                          ),
                                        );
                                      }
                                    }
                                  }
                                } else {
                                  // Registration failed - show error message
                                  final errorMessage = result['message'] ?? 'Registration failed';
                                  debugPrint('Registration failed: $errorMessage');

                                  if (mounted) {
                                    scaffoldMessenger.showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          isUltraNarrowScreen 
                                              ? 'Registration failed. Try again.' 
                                              : errorMessage,
                                          style: TextStyle(
                                            fontSize: isUltraNarrowScreen ? 12.0 : 14.0,
                                          ),
                                        ),
                                        backgroundColor: Colors.red,
                                        duration: const Duration(seconds: 4),
                                        behavior: SnackBarBehavior.floating,
                                        margin: EdgeInsets.all(isUltraNarrowScreen ? 8.0 : 16.0),
                                      ),
                                    );
                                  }
                                }
                              }
                            } catch (error) {
                              debugPrint('Registration error: $error');

                              // Clear any loading messages
                              if (mounted) {
                                scaffoldMessenger.hideCurrentSnackBar();
                              }

                              // Check if user was partially created despite the error
                              try {
                                final authStatus = await FirebaseService.getAuthStatus();
                                if (authStatus['authenticated'] == true) {
                                  debugPrint('User authenticated despite error - proceeding to user info');
                                  // Navigate directly to user info page without any dialog
                                  if (mounted) {
                                    Navigator.pushAndRemoveUntil(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => const _AppRestartWrapper(
                                          child: UserInfoFormPage(),
                                        ),
                                      ),
                                      (route) => false,
                                    );
                                  }
                                  return;
                                }
                              } catch (authCheckError) {
                                debugPrint('Auth check error: $authCheckError');
                              }

                              if (mounted) {
                                scaffoldMessenger.showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      isUltraNarrowScreen 
                                          ? 'Registration failed. Try again.' 
                                          : 'Registration failed: ${error.toString()}',
                                      style: TextStyle(
                                        fontSize: isUltraNarrowScreen ? 12.0 : 14.0,
                                      ),
                                    ),
                                    backgroundColor: Colors.red,
                                    duration: const Duration(seconds: 4),
                                    behavior: SnackBarBehavior.floating,
                                    margin: EdgeInsets.all(isUltraNarrowScreen ? 8.0 : 16.0),
                                  ),
                                );
                              }
                            } finally {
                              if (mounted) {
                                setState(() {
                                  _isSubmitting = false;
                                });
                                setSubmitting(false);
                              }
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          minimumSize: Size(double.infinity, buttonHeight),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(borderRadius),
                          ),
                          padding: EdgeInsets.zero,
                        ),
                        child: _isSubmitting
                            ? SizedBox(
                                height: isUltraNarrowScreen ? 16 : 20,
                                width: isUltraNarrowScreen ? 16 : 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: isUltraNarrowScreen ? 1.5 : 2,
                                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : Padding(
                                padding: EdgeInsets.all(buttonPadding),
                                child: Text(
                                  isUltraNarrowScreen ? 'Create' : 'Create Account',
                                  style: TextStyle(fontSize: buttonFontSize),
                                ),
                              ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            isUltraNarrowScreen ? 'Existing?' : 'Existing User?',
                            style: TextStyle(fontSize: bottomTextFontSize),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(width: 4),
                          GestureDetector(
                            onTap: () {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(builder: (context) => const LoginPage()),
                              );
                            },
                            child: Text(
                              'Sign in',
                              style: TextStyle(
                                fontSize: bottomTextFontSize,
                                color: Colors.teal,
                                fontWeight: FontWeight.bold,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
}

/// A wrapper widget that ensures a clean restart of the app after login
/// This helps avoid tutorial dependency issues during hot reloads
class _AppRestartWrapper extends StatefulWidget {
  final Widget child;

  const _AppRestartWrapper({required this.child});

  @override
  State<_AppRestartWrapper> createState() => _AppRestartWrapperState();
}

class _AppRestartWrapperState extends State<_AppRestartWrapper> {
  @override
  void initState() {
    super.initState();
    // Completely reset the tutorial system to prevent any dependency issues
    // Perform cleanup asynchronously to avoid blocking the UI
    _performAsyncCleanup();
  }

  /// Perform cleanup asynchronously to avoid blocking the UI
  void _performAsyncCleanup() {
    // Use Future.microtask to ensure cleanup happens after the widget is built
    Future.microtask(() async {
      try {
        // Perform aggressive cleanup without blocking the UI
        await TutorialErrorHandler.aggressiveCleanup();
        
        // Only force a rebuild if the widget is still mounted
        if (mounted) {
          setState(() {
            // Force rebuild after cleanup
          });
        }
      } catch (e) {
        debugPrint('Error in async cleanup: $e');
        // Even if cleanup fails, continue
        if (mounted) {
          setState(() {
            // Force rebuild even if cleanup failed
          });
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Add a key to force widget rebuild
    return KeyedSubtree(
      key: ValueKey(DateTime.now().millisecondsSinceEpoch),
      child: widget.child,
    );
  }
}