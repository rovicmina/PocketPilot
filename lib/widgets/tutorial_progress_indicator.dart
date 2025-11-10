import 'package:flutter/material.dart';

class TutorialProgressIndicator extends StatelessWidget {
  final int currentStep;
  final int totalSteps;
  final Color? color;

  const TutorialProgressIndicator({
    super.key,
    required this.currentStep,
    required this.totalSteps,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final indicatorColor = color ?? theme.colorScheme.primary;
    final screenSize = MediaQuery.of(context).size;
    
    // Adjust font sizes based on screen size
    final double titleFontSize = screenSize.width > 600 ? 20.0 : 16.0;
    final double progressFontSize = screenSize.width > 600 ? 14.0 : 12.0;
    
    // Adjust padding based on screen size
    final double padding = screenSize.width > 600 ? 20.0 : 16.0;

    return Container(
      padding: EdgeInsets.all(padding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Tutorial Progress',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: titleFontSize,
            ),
          ),
          SizedBox(height: screenSize.width > 600 ? 12 : 8),
          LinearProgressIndicator(
            value: totalSteps > 0 ? currentStep / totalSteps : 0,
            backgroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.2),
            color: indicatorColor,
            minHeight: screenSize.width > 600 ? 10 : 8,
          ),
          SizedBox(height: screenSize.width > 600 ? 12 : 8),
          Text(
            '$currentStep of $totalSteps steps completed',
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: progressFontSize,
            ),
          ),
        ],
      ),
    );
  }
}