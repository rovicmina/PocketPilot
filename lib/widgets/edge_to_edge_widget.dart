import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A widget that properly handles edge-to-edge display for Android 15+
/// This widget should wrap your main app content to ensure proper inset handling
class EdgeToEdgeWidget extends StatefulWidget {
  final Widget child;
  
  const EdgeToEdgeWidget({super.key, required this.child});

  @override
  State<EdgeToEdgeWidget> createState() => _EdgeToEdgeWidgetState();
}

class _EdgeToEdgeWidgetState extends State<EdgeToEdgeWidget> {
  @override
  void initState() {
    super.initState();
    _applyEdgeToEdge();
  }

  void _applyEdgeToEdge() {
    // Apply edge-to-edge system UI flags for better Android 15+ compatibility
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
      overlays: SystemUiOverlay.values,
    );
    
    // Set system UI overlay style for proper status bar and navigation bar appearance
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}