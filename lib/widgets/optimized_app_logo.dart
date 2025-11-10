import 'package:flutter/material.dart';
import '../services/optimized_image_cache_service.dart';

/// Optimized logo widget with better caching and memory management
class OptimizedAppLogo extends StatefulWidget {
  final double size;
  final Color? color;
  final bool fallbackToIcon;

  const OptimizedAppLogo({
    super.key,
    this.size = 48,
    this.color,
    this.fallbackToIcon = true,
  });

  @override
  State<OptimizedAppLogo> createState() => _OptimizedAppLogoState();
}

class _OptimizedAppLogoState extends State<OptimizedAppLogo> {
  ImageProvider? _imageProvider;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    try {
      final cacheService = OptimizedImageCacheService();
      final imageProvider = await cacheService.getCachedImage('assets/logo.png');
      
      if (mounted) {
        setState(() {
          _imageProvider = imageProvider;
        });
      }
    } catch (e) {
      // Ignore errors and use fallback
    }
  }

  @override
  void dispose() {
    // Dispose of image provider if needed
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.1),
      ),
      child: _imageProvider != null
          ? Image(
              image: _imageProvider!,
              width: widget.size,
              height: widget.size,
              color: widget.color,
              colorBlendMode: widget.color != null ? BlendMode.srcIn : null,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                // Fallback to default icon if logo image fails to load
                if (widget.fallbackToIcon) {
                  return _buildFallbackIcon();
                }
                return SizedBox(width: widget.size, height: widget.size);
              },
            )
          : _buildFallbackIcon(),
    );
  }

  Widget _buildFallbackIcon() {
    if (!widget.fallbackToIcon) {
      return SizedBox(width: widget.size, height: widget.size);
    }

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        Icons.account_balance_wallet,
        size: widget.size * 0.7,
        color: widget.color ?? Theme.of(context).colorScheme.primary,
      ),
    );
  }
}

/// Optimized logo with text for branding
class OptimizedAppLogoWithText extends StatelessWidget {
  final double logoSize;
  final double fontSize;
  final Color? color;
  final MainAxisAlignment alignment;
  final bool showSubtitle;

  const OptimizedAppLogoWithText({
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
        OptimizedAppLogo(
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

/// Small optimized logo for app bars and compact spaces
class OptimizedAppLogoCompact extends StatelessWidget {
  final double size;
  final Color? color;

  const OptimizedAppLogoCompact({
    super.key,
    this.size = 32,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return OptimizedAppLogo(
      size: size,
      color: color,
      fallbackToIcon: true,
    );
  }
}