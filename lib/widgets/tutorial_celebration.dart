import 'package:flutter/material.dart';

class TutorialCelebration extends StatefulWidget {
  final VoidCallback onDismiss;

  const TutorialCelebration({super.key, required this.onDismiss});

  @override
  State<TutorialCelebration> createState() => _TutorialCelebrationState();
}

class _TutorialCelebrationState extends State<TutorialCelebration>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.elasticOut,
      ),
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );

    _controller.forward();

    // Auto-dismiss after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        try {
          Navigator.of(context).pop();
          widget.onDismiss();
        } catch (e) {
          // Ignore navigation errors
          debugPrint("Error dismissing tutorial celebration: $e");
        }
      }
    });
  }

  @override
  void dispose() {
    try {
      _controller.dispose();
    } catch (e) {
      debugPrint("Error disposing celebration controller: $e");
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenSize = MediaQuery.of(context).size;
    
    // Adjust sizes based on screen size
    final double iconSize = screenSize.width > 600 ? 80.0 : 60.0;
    final double padding = screenSize.width > 600 ? 32.0 : 24.0;
    final double titleFontSize = screenSize.width > 600 ? 28.0 : 22.0;
    final double messageFontSize = screenSize.width > 600 ? 18.0 : 16.0;
    final double buttonPadding = screenSize.width > 600 ? 20.0 : 16.0;

    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: 0.5),
      body: Center(
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: FadeTransition(
            opacity: _opacityAnimation,
            child: Container(
              padding: EdgeInsets.all(padding),
              decoration: BoxDecoration(
                color: theme.cardTheme.color,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.celebration,
                    size: iconSize,
                    color: Colors.orange,
                  ),
                  SizedBox(height: screenSize.width > 600 ? 20 : 16),
                  Text(
                    'Tutorial Completed!',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                      fontSize: titleFontSize,
                    ),
                  ),
                  SizedBox(height: screenSize.width > 600 ? 12 : 8),
                  Text(
                    'Great job! You\'ve completed this tutorial.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontSize: messageFontSize,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: screenSize.width > 600 ? 20 : 16),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      widget.onDismiss();
                    },
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(
                        horizontal: buttonPadding * 1.5,
                        vertical: buttonPadding,
                      ),
                    ),
                    child: Text(
                      'Continue',
                      style: TextStyle(
                        fontSize: messageFontSize,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}