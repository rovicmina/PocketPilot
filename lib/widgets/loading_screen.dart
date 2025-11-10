import 'package:flutter/material.dart';
import 'tutorial_error_handler.dart';
import 'package:flutter/scheduler.dart';

class LoadingScreen extends StatefulWidget {
  final String message;
  final VoidCallback? onLoadingComplete;

  const LoadingScreen({
    super.key,
    this.message = 'Loading...',
    this.onLoadingComplete,
  });

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen> {
  bool _isDisposed = false;
  bool _hasCompleted = false;

  @override
  void initState() {
    super.initState();
    _isDisposed = false;
    _hasCompleted = false;
    
    // Start the loading process with timeout protection
    _startLoadingProcess();
  }

  void _startLoadingProcess() {
    // Set a timeout to ensure the loading screen doesn't get stuck
    Future.delayed(const Duration(seconds: 5), () {
      if (!_hasCompleted && !_isDisposed && mounted) {
        debugPrint('Loading screen timeout - forcing completion');
        _completeLoading();
      }
    });
    
    // Perform cleanup with timeout
    Future.any([
      TutorialErrorHandler.aggressiveCleanup(),
      Future.delayed(const Duration(seconds: 3)) // Timeout after 3 seconds
    ]).then((_) {
      // Automatically close this screen after a delay to simulate loading
      // Using SchedulerBinding to ensure we're not trying to update during build
      SchedulerBinding.instance.addPostFrameCallback((_) {
        Future.delayed(const Duration(seconds: 2), () {
          if (!_hasCompleted && !_isDisposed && mounted) {
            _completeLoading();
          }
        });
      });
    }).catchError((error) {
      debugPrint('Error during loading screen cleanup: $error');
      // Even if cleanup fails, continue with navigation after a delay
      // Using SchedulerBinding to ensure we're not trying to update during build
      SchedulerBinding.instance.addPostFrameCallback((_) {
        Future.delayed(const Duration(seconds: 2), () {
          if (!_hasCompleted && !_isDisposed && mounted) {
            _completeLoading();
          }
        });
      });
    });
  }

  void _completeLoading() {
    // Prevent multiple completions
    if (_hasCompleted || _isDisposed || !mounted) {
      return;
    }
    
    _hasCompleted = true;
    
    try {
      // Call the completion callback if provided
      if (widget.onLoadingComplete != null) {
        // Using SchedulerBinding to ensure we're not trying to update during build
        SchedulerBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            widget.onLoadingComplete!();
          }
        });
      } else {
        // Default behavior: pop the screen
        if (mounted && Navigator.canPop(context)) {
          SchedulerBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              Navigator.pop(context);
            }
          });
        }
      }
    } catch (e) {
      debugPrint('Error completing loading screen: $e');
      // Fallback: try to pop the screen
      if (mounted && Navigator.canPop(context)) {
        SchedulerBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            Navigator.pop(context);
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    
    return LayoutBuilder(
      builder: (context, constraints) {
        // Determine responsive layout parameters based on screen size
        final isNarrowScreen = constraints.maxWidth < 600;
        final isVeryNarrowScreen = constraints.maxWidth < 400;
        final isExtremelyNarrowScreen = constraints.maxWidth < 320;
        final isUltraNarrowScreen = constraints.maxWidth < 280;
        
        // Responsive sizing
        final logoSize = isUltraNarrowScreen ? 60.0 : isExtremelyNarrowScreen ? 65.0 : isVeryNarrowScreen ? 70.0 : isNarrowScreen ? 75.0 : 80.0;
        final iconSize = isUltraNarrowScreen ? 30.0 : isExtremelyNarrowScreen ? 32.0 : isVeryNarrowScreen ? 34.0 : isNarrowScreen ? 36.0 : 40.0;
        final titleFontSize = isUltraNarrowScreen ? 14.0 : isExtremelyNarrowScreen ? 15.0 : isVeryNarrowScreen ? 16.0 : isNarrowScreen ? 17.0 : 18.0;
        final statusFontSize = isUltraNarrowScreen ? 10.0 : isExtremelyNarrowScreen ? 11.0 : isVeryNarrowScreen ? 12.0 : isNarrowScreen ? 13.0 : 14.0;
        final spacingAfterLogo = isUltraNarrowScreen ? 20.0 : isExtremelyNarrowScreen ? 22.0 : isVeryNarrowScreen ? 24.0 : isNarrowScreen ? 26.0 : 32.0;
        final spacingAfterTitle = isUltraNarrowScreen ? 16.0 : isExtremelyNarrowScreen ? 18.0 : isVeryNarrowScreen ? 20.0 : isNarrowScreen ? 22.0 : 24.0;
        final progressIndicatorSize = isUltraNarrowScreen ? 30.0 : isExtremelyNarrowScreen ? 32.0 : isVeryNarrowScreen ? 34.0 : isNarrowScreen ? 36.0 : 40.0;
        final spacingAfterProgress = isUltraNarrowScreen ? 20.0 : isExtremelyNarrowScreen ? 22.0 : isVeryNarrowScreen ? 24.0 : isNarrowScreen ? 26.0 : 32.0;
        
        return PopScope(
          canPop: false,
          child: Scaffold(
            backgroundColor: isDarkMode ? Colors.grey[900] : Colors.grey[50],
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // App logo or icon
                  Container(
                    width: logoSize,
                    height: logoSize,
                    decoration: BoxDecoration(
                      color: Colors.teal,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.account_balance_wallet,
                      color: Colors.white,
                      size: iconSize,
                    ),
                  ),
                  SizedBox(height: spacingAfterLogo),
                  
                  // Loading message
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: isUltraNarrowScreen ? 16.0 : isExtremelyNarrowScreen ? 20.0 : isVeryNarrowScreen ? 24.0 : isNarrowScreen ? 28.0 : 32.0),
                    child: Text(
                      widget.message,
                      style: TextStyle(
                        fontSize: titleFontSize,
                        fontWeight: FontWeight.w500,
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                      // Ensure text doesn't get truncated on small screens
                      maxLines: isUltraNarrowScreen ? 3 : isExtremelyNarrowScreen ? 2 : null,
                    ),
                  ),
                  SizedBox(height: spacingAfterTitle),
                  
                  // Progress indicator
                  SizedBox(
                    width: progressIndicatorSize,
                    height: progressIndicatorSize,
                    child: CircularProgressIndicator(
                      strokeWidth: isUltraNarrowScreen ? 2.0 : isExtremelyNarrowScreen ? 2.5 : 3.0,
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.teal),
                    ),
                  ),
                  
                  SizedBox(height: spacingAfterProgress),
                  
                  // Status message
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: isUltraNarrowScreen ? 16.0 : isExtremelyNarrowScreen ? 20.0 : isVeryNarrowScreen ? 24.0 : isNarrowScreen ? 28.0 : 32.0),
                    child: Text(
                      'Preparing your experience...',
                      style: TextStyle(
                        fontSize: statusFontSize,
                        color: isDarkMode ? Colors.white70 : Colors.black54,
                      ),
                      textAlign: TextAlign.center,
                      // Ensure text doesn't get truncated on small screens
                      maxLines: isUltraNarrowScreen ? 2 : null,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}