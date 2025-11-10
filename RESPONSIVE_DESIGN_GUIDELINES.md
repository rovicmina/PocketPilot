# Responsive Design Guidelines for PocketPilot

## Overview

This document provides guidelines for implementing responsive design in the PocketPilot application. The goal is to ensure consistent user experience across different screen sizes and devices.

## Responsive Design Principles

### 1. Breakpoints
The application uses the following standard breakpoints:
- **Ultra Narrow Screen**: < 280px
- **Extremely Narrow Screen**: < 320px
- **Very Narrow Screen**: < 400px
- **Narrow Screen**: < 600px
- **Wide Screen**: > 1200px

### 2. Typography Standards
- **Display/Title**: 16-22sp
- **Section Heading**: 18-24sp
- **Subheading**: 16-20sp
- **Body Text**: 14-16sp
- **Secondary Text**: 12-14sp
- **Captions**: 10-12sp
- **Button Text**: 16-18sp

### 3. Spacing Standards
- **Padding**: 12-24dp
- **Margin**: 8-20dp
- **Element Spacing**: 8-16dp

## Implementation Patterns

### 1. Using LayoutBuilder
Most pages in the application use `LayoutBuilder` to adapt to different screen sizes:

```dart
LayoutBuilder(
  builder: (context, constraints) {
    final isNarrowScreen = constraints.maxWidth < 600;
    final titleFontSize = isNarrowScreen ? 20.0 : 22.0;
    
    return Text(
      'Page Title',
      style: TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: titleFontSize,
      ),
    );
  },
);
```

### 2. Using ResponsiveLayoutBuilder
For new implementations, use the standardized `ResponsiveLayoutBuilder`:

```dart
ResponsiveLayoutBuilder(
  builder: (context, layoutInfo) {
    final titleFontSize = layoutInfo.fontSize(small: 18, medium: 20, large: 22);
    
    return Text(
      'Page Title',
      style: TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: titleFontSize,
      ),
    );
  },
);
```

### 3. Using ResponsiveText
For text elements that need to adapt to screen sizes:

```dart
ResponsiveText(
  'This text will resize based on screen size',
  style: const TextStyle(fontWeight: FontWeight.w500),
  smallFontSize: 14,
  mediumFontSize: 16,
  largeFontSize: 18,
);
```

### 4. Using ResponsiveContainer
For containers that need responsive padding and margins:

```dart
ResponsiveContainer(
  padding: const EdgeInsets.all(16),
  child: Text('Responsive content'),
);
```

## Utility Classes

### ResponsiveUtils
Provides utility methods for checking screen sizes:

```dart
// Check if screen is narrow
final isNarrow = ResponsiveUtils.isNarrowScreen(context);

// Get responsive font size
final fontSize = ResponsiveUtils.responsiveFontSize(context, small: 12, medium: 14, large: 16);
```

### ResponsiveLayoutInfo
Provides information about the current layout constraints:

```dart
ResponsiveLayoutBuilder(
  builder: (context, layoutInfo) {
    if (layoutInfo.isNarrowScreen) {
      // Handle narrow screen layout
    } else {
      // Handle wide screen layout
    }
  },
);
```

## Best Practices

### 1. Content Prioritization
- Prioritize essential content on smaller screens
- Use progressive disclosure for secondary content
- Reorganize content flow for different screen sizes

### 2. Touch Targets
- Ensure touch targets are at least 48x48dp
- Provide adequate spacing between interactive elements
- Use visual feedback for touch interactions

### 3. Performance
- Avoid complex layouts on mobile devices
- Use efficient widget rebuilding
- Test performance on different devices

## Testing

### 1. Screen Sizes to Test
- 240x320 (Ultra narrow)
- 320x480 (Extremely narrow)
- 375x667 (iPhone SE)
- 414x896 (iPhone 11 Pro Max)
- 768x1024 (iPad)
- 1024x1366 (iPad Pro)
- 1920x1080 (Desktop)

### 2. Automated Testing
Use the comprehensive responsive tests in `test/comprehensive_responsive_test.dart` to verify responsive behavior.

## Migration Guide

### From Custom LayoutBuilder to ResponsiveLayoutBuilder
1. Replace `LayoutBuilder` with `ResponsiveLayoutBuilder`
2. Replace manual breakpoint checks with `layoutInfo` properties
3. Use `layoutInfo.fontSize()`, `layoutInfo.spacing()`, and `layoutInfo.padding()` methods

### Example Migration
**Before:**
```dart
LayoutBuilder(
  builder: (context, constraints) {
    final isNarrowScreen = constraints.maxWidth < 600;
    final titleFontSize = isNarrowScreen ? 20.0 : 22.0;
    
    return Text(
      'Title',
      style: TextStyle(fontSize: titleFontSize),
    );
  },
);
```

**After:**
```dart
ResponsiveLayoutBuilder(
  builder: (context, layoutInfo) {
    final titleFontSize = layoutInfo.fontSize(small: 20, medium: 22);
    
    return Text(
      'Title',
      style: TextStyle(fontSize: titleFontSize),
    );
  },
);
```

## Future Improvements

1. Add more comprehensive testing for edge cases
2. Implement adaptive layouts for tablet and desktop
3. Add support for foldable devices
4. Improve performance for complex responsive layouts