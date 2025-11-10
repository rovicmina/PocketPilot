import 'package:flutter/material.dart';
import '../utils/responsive_utils.dart';

/// A responsive container that adapts its padding, margin, and child layout based on screen size
class ResponsiveContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final double? width;
  final double? height;
  final BoxDecoration? decoration;
  final Alignment? alignment;
  final bool constrainWidth;
  final bool constrainHeight;

  const ResponsiveContainer({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.decoration,
    this.alignment,
    this.constrainWidth = false,
    this.constrainHeight = false,
  });

  @override
  Widget build(BuildContext context) {
    return ResponsiveLayoutBuilder(
      builder: (context, layoutInfo) {
        // Calculate responsive padding if not provided
        final responsivePadding = padding ?? EdgeInsets.all(layoutInfo.padding());
        
        // Calculate responsive margin if not provided
        final responsiveMargin = margin ?? EdgeInsets.all(layoutInfo.spacing(small: 8, medium: 12, large: 16));
        
        // Constrain width/height if requested
        Widget constrainedChild = child;
        if (constrainWidth && width != null) {
          constrainedChild = ConstrainedBox(
            constraints: BoxConstraints(maxWidth: width!),
            child: child,
          );
        }
        
        if (constrainHeight && height != null) {
          constrainedChild = ConstrainedBox(
            constraints: BoxConstraints(maxHeight: height!),
            child: constrainedChild,
          );
        }

        return Container(
          width: width,
          height: height,
          padding: responsivePadding,
          margin: responsiveMargin,
          decoration: decoration,
          alignment: alignment,
          child: constrainedChild,
        );
      },
    );
  }
}

/// A responsive column that adjusts spacing and padding based on screen size
class ResponsiveColumn extends StatelessWidget {
  final List<Widget> children;
  final MainAxisAlignment mainAxisAlignment;
  final CrossAxisAlignment crossAxisAlignment;
  final MainAxisSize mainAxisSize;
  final VerticalDirection verticalDirection;
  final TextDirection? textDirection;
  final EdgeInsets? padding;

  const ResponsiveColumn({
    super.key,
    required this.children,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.crossAxisAlignment = CrossAxisAlignment.center,
    this.mainAxisSize = MainAxisSize.max,
    this.verticalDirection = VerticalDirection.down,
    this.textDirection,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return ResponsiveLayoutBuilder(
      builder: (context, layoutInfo) {
        final responsivePadding = padding ?? EdgeInsets.all(layoutInfo.padding());
        
        return Padding(
          padding: responsivePadding,
          child: Column(
            mainAxisAlignment: mainAxisAlignment,
            crossAxisAlignment: crossAxisAlignment,
            mainAxisSize: mainAxisSize,
            verticalDirection: verticalDirection,
            textDirection: textDirection,
            children: children,
          ),
        );
      },
    );
  }
}

/// A responsive row that adjusts spacing and padding based on screen size
class ResponsiveRow extends StatelessWidget {
  final List<Widget> children;
  final MainAxisAlignment mainAxisAlignment;
  final CrossAxisAlignment crossAxisAlignment;
  final MainAxisSize mainAxisSize;
  final VerticalDirection verticalDirection;
  final TextDirection? textDirection;
  final EdgeInsets? padding;

  const ResponsiveRow({
    super.key,
    required this.children,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.crossAxisAlignment = CrossAxisAlignment.center,
    this.mainAxisSize = MainAxisSize.max,
    this.verticalDirection = VerticalDirection.down,
    this.textDirection,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return ResponsiveLayoutBuilder(
      builder: (context, layoutInfo) {
        final responsivePadding = padding ?? EdgeInsets.all(layoutInfo.padding());
        
        return Padding(
          padding: responsivePadding,
          child: Row(
            mainAxisAlignment: mainAxisAlignment,
            crossAxisAlignment: crossAxisAlignment,
            mainAxisSize: mainAxisSize,
            verticalDirection: verticalDirection,
            textDirection: textDirection,
            children: children,
          ),
        );
      },
    );
  }
}

/// A responsive text widget that automatically adjusts font size based on screen size
class ResponsiveText extends StatelessWidget {
  final String data;
  final TextStyle? style;
  final TextAlign? textAlign;
  final TextOverflow? overflow;
  final int? maxLines;
  final double? smallFontSize;
  final double? mediumFontSize;
  final double? largeFontSize;
  final double? extraLargeFontSize;

  const ResponsiveText(
    this.data, {
    super.key,
    this.style,
    this.textAlign,
    this.overflow,
    this.maxLines,
    this.smallFontSize,
    this.mediumFontSize,
    this.largeFontSize,
    this.extraLargeFontSize,
  });

  @override
  Widget build(BuildContext context) {
    return ResponsiveLayoutBuilder(
      builder: (context, layoutInfo) {
        final baseFontSize = style?.fontSize ?? 14.0;
        final responsiveFontSize = layoutInfo.fontSize(
          small: smallFontSize ?? baseFontSize * 0.85,
          medium: mediumFontSize ?? baseFontSize,
          large: largeFontSize ?? baseFontSize * 1.15,
          extraLarge: extraLargeFontSize ?? baseFontSize * 1.3,
        );
        
        return Text(
          data,
          style: style?.copyWith(fontSize: responsiveFontSize) ?? TextStyle(fontSize: responsiveFontSize),
          textAlign: textAlign,
          overflow: overflow,
          maxLines: maxLines,
        );
      },
    );
  }
}