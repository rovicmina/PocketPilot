import 'package:flutter/material.dart';

/// Reusable logo widget for consistent branding across the app
class AppLogo extends StatelessWidget {
  final double size;
  final Color? color;
  final bool fallbackToIcon;

  const AppLogo({
    super.key,
    this.size = 48,
    this.color,
    this.fallbackToIcon = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.1),
      ),
      child: Image.asset(
        'assets/logo.png',
        width: size,
        height: size,
        color: color,
        colorBlendMode: color != null ? BlendMode.srcIn : null,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          // Fallback to default icon if logo image is not found
          if (fallbackToIcon) {
            return Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.account_balance_wallet,
                size: size * 0.7,
                color: color ?? Theme.of(context).colorScheme.primary,
              ),
            );
          }
          return SizedBox(width: size, height: size);
        },
      ),
    );
  }
}

/// Logo with text for branding
class AppLogoWithText extends StatelessWidget {
  final double logoSize;
  final double fontSize;
  final Color? color;
  final MainAxisAlignment alignment;
  final bool showSubtitle;

  const AppLogoWithText({
    super.key,
    this.logoSize = 60,
    this.fontSize = 24,
    this.color,
    this.alignment = MainAxisAlignment.center,
    this.showSubtitle = false,
  });
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = color ?? theme.colorScheme.primary;
    
    return Column(
      mainAxisAlignment: alignment,
      children: [
        AppLogo(
          size: logoSize,
          color: color,
        ),
        const SizedBox(height: 16),
        Text(
          'PocketPilot',
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        if (showSubtitle) ...[
          const SizedBox(height: 8),
          Text(
            'Your Personal Financial Guide',
            style: TextStyle(
              fontSize: fontSize * 0.6,
              color: textColor.withValues(alpha: 0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}

/// Small logo for app bars and compact spaces
class AppLogoCompact extends StatelessWidget {
  final double size;
  final Color? color;

  const AppLogoCompact({
    super.key,
    this.size = 32,
    this.color,
  });
  
  @override
  Widget build(BuildContext context) {
    return AppLogo(
      size: size,
      color: color,
      fallbackToIcon: true,
    );
  }
}