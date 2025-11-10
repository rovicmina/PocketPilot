import 'package:flutter/material.dart';

/// Standard responsive breakpoints and utilities for the PocketPilot app
class ResponsiveUtils {
  // Standard breakpoints
  static const double ultraNarrowScreenWidth = 280;
  static const double extremelyNarrowScreenWidth = 320;
  static const double veryNarrowScreenWidth = 400;
  static const double narrowScreenWidth = 600;
  static const double wideScreenWidth = 1200;

  // Screen size checks
  static bool isUltraNarrowScreen(BuildContext context) {
    return MediaQuery.of(context).size.width < ultraNarrowScreenWidth;
  }

  static bool isExtremelyNarrowScreen(BuildContext context) {
    return MediaQuery.of(context).size.width < extremelyNarrowScreenWidth;
  }

  static bool isVeryNarrowScreen(BuildContext context) {
    return MediaQuery.of(context).size.width < veryNarrowScreenWidth;
  }

  static bool isNarrowScreen(BuildContext context) {
    return MediaQuery.of(context).size.width < narrowScreenWidth;
  }

  static bool isWideScreen(BuildContext context) {
    return MediaQuery.of(context).size.width > wideScreenWidth;
  }

  // Get responsive font size based on screen width
  static double responsiveFontSize(BuildContext context, {double small = 12, double medium = 14, double large = 16, double extraLarge = 18}) {
    if (isUltraNarrowScreen(context)) {
      return small * 0.9;
    } else if (isExtremelyNarrowScreen(context)) {
      return small;
    } else if (isVeryNarrowScreen(context)) {
      return small;
    } else if (isNarrowScreen(context)) {
      return medium;
    } else {
      return large;
    }
  }

  // Get responsive spacing based on screen width
  static double responsiveSpacing(BuildContext context, {double small = 8, double medium = 12, double large = 16, double extraLarge = 20}) {
    if (isUltraNarrowScreen(context)) {
      return small * 0.8;
    } else if (isExtremelyNarrowScreen(context)) {
      return small;
    } else if (isVeryNarrowScreen(context)) {
      return small;
    } else if (isNarrowScreen(context)) {
      return medium;
    } else {
      return large;
    }
  }

  // Get responsive padding based on screen width
  static double responsivePadding(BuildContext context, {double small = 12, double medium = 16, double large = 20, double extraLarge = 24}) {
    if (isUltraNarrowScreen(context)) {
      return small * 0.9;
    } else if (isExtremelyNarrowScreen(context)) {
      return small;
    } else if (isVeryNarrowScreen(context)) {
      return small;
    } else if (isNarrowScreen(context)) {
      return medium;
    } else {
      return large;
    }
  }
}

/// A widget that provides responsive layout information to its child
class ResponsiveLayoutBuilder extends StatelessWidget {
  final Widget Function(BuildContext context, ResponsiveLayoutInfo layoutInfo) builder;

  const ResponsiveLayoutBuilder({super.key, required this.builder});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final layoutInfo = ResponsiveLayoutInfo(
          screenWidth: constraints.maxWidth,
          screenHeight: constraints.maxHeight,
          isUltraNarrowScreen: constraints.maxWidth < ResponsiveUtils.ultraNarrowScreenWidth,
          isExtremelyNarrowScreen: constraints.maxWidth < ResponsiveUtils.extremelyNarrowScreenWidth,
          isVeryNarrowScreen: constraints.maxWidth < ResponsiveUtils.veryNarrowScreenWidth,
          isNarrowScreen: constraints.maxWidth < ResponsiveUtils.narrowScreenWidth,
          isWideScreen: constraints.maxWidth > ResponsiveUtils.wideScreenWidth,
        );
        return builder(context, layoutInfo);
      },
    );
  }
}

/// Provides information about the current layout constraints
class ResponsiveLayoutInfo {
  final double screenWidth;
  final double screenHeight;
  final bool isUltraNarrowScreen;
  final bool isExtremelyNarrowScreen;
  final bool isVeryNarrowScreen;
  final bool isNarrowScreen;
  final bool isWideScreen;

  const ResponsiveLayoutInfo({
    required this.screenWidth,
    required this.screenHeight,
    required this.isUltraNarrowScreen,
    required this.isExtremelyNarrowScreen,
    required this.isVeryNarrowScreen,
    required this.isNarrowScreen,
    required this.isWideScreen,
  });

  /// Get responsive font size based on screen width
  double fontSize({double small = 12, double medium = 14, double large = 16, double extraLarge = 18}) {
    if (isUltraNarrowScreen) {
      return small * 0.9;
    } else if (isExtremelyNarrowScreen) {
      return small;
    } else if (isVeryNarrowScreen) {
      return small;
    } else if (isNarrowScreen) {
      return medium;
    } else {
      return large;
    }
  }

  /// Get responsive spacing based on screen width
  double spacing({double small = 8, double medium = 12, double large = 16, double extraLarge = 20}) {
    if (isUltraNarrowScreen) {
      return small * 0.8;
    } else if (isExtremelyNarrowScreen) {
      return small;
    } else if (isVeryNarrowScreen) {
      return small;
    } else if (isNarrowScreen) {
      return medium;
    } else {
      return large;
    }
  }

  /// Get responsive padding based on screen width
  double padding({double small = 12, double medium = 16, double large = 20, double extraLarge = 24}) {
    if (isUltraNarrowScreen) {
      return small * 0.9;
    } else if (isExtremelyNarrowScreen) {
      return small;
    } else if (isVeryNarrowScreen) {
      return small;
    } else if (isNarrowScreen) {
      return medium;
    } else {
      return large;
    }
  }
}