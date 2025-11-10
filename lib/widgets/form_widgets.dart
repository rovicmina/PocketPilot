import 'package:flutter/material.dart';

class MultiSelectChipField<T> extends StatefulWidget {
  final String title;
  final List<T> options;
  final List<T> selectedValues;
  final void Function(List<T>) onChanged;
  final String Function(T) getDisplayName;
  final bool isRequired;
  final T? exclusiveOption; // Option that excludes all others when selected

  const MultiSelectChipField({
    super.key,
    required this.title,
    required this.options,
    required this.selectedValues,
    required this.onChanged,
    required this.getDisplayName,
    this.isRequired = false,
    this.exclusiveOption,
  });

  @override
  State<MultiSelectChipField<T>> createState() => _MultiSelectChipFieldState<T>();
}

class _MultiSelectChipFieldState<T> extends State<MultiSelectChipField<T>> {
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrowScreen = constraints.maxWidth < 600;
        final isVeryNarrowScreen = constraints.maxWidth < 400;
        final labelFontSize = isNarrowScreen ? 14.0 : 16.0;
        final errorFontSize = isVeryNarrowScreen ? 10.0 : 12.0;
        final chipSpacing = isVeryNarrowScreen ? 6.0 : 8.0;
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title,
              style: TextStyle(
                fontSize: labelFontSize,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            SizedBox(height: isVeryNarrowScreen ? 6.0 : 8.0),
            Wrap(
              spacing: chipSpacing,
              runSpacing: chipSpacing,
              children: widget.options.map((option) {
                final isSelected = widget.selectedValues.contains(option);
                return FilterChip(
                  label: Text(
                    widget.getDisplayName(option),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: isNarrowScreen ? 13.0 : 14.0,
                    ),
                  ),
                  selected: isSelected,
                  onSelected: (selected) {
                    final newValues = List<T>.from(widget.selectedValues);
                    
                    if (widget.exclusiveOption != null) {
                      if (option == widget.exclusiveOption) {
                        // If selecting the exclusive option, clear all others and select only this one
                        if (selected) {
                          newValues.clear();
                          newValues.add(option);
                        } else {
                          newValues.remove(option);
                        }
                      } else {
                        // If selecting a non-exclusive option, remove the exclusive option first
                        if (selected) {
                          newValues.remove(widget.exclusiveOption);
                          newValues.add(option);
                        } else {
                          newValues.remove(option);
                        }
                      }
                    } else {
                      // Normal multi-select behavior
                      if (selected) {
                        newValues.add(option);
                      } else {
                        newValues.remove(option);
                      }
                    }
                    
                    widget.onChanged(newValues);
                  },
                  selectedColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                  checkmarkColor: Theme.of(context).colorScheme.primary,
                  padding: EdgeInsets.symmetric(
                    horizontal: isVeryNarrowScreen ? 8.0 : 12.0,
                    vertical: isVeryNarrowScreen ? 4.0 : 6.0,
                  ),
                );
              }).toList(),
            ),
            if (widget.isRequired && widget.selectedValues.isEmpty) ...[
              SizedBox(height: isVeryNarrowScreen ? 6.0 : 8.0),
              Text(
                'Please select at least one ${widget.title.toLowerCase()}',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: errorFontSize,
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class ToggleField extends StatelessWidget {
  final String title;
  final bool? value;
  final void Function(bool) onChanged;
  final bool isRequired;

  const ToggleField({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.isRequired = false,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrowScreen = constraints.maxWidth < 600;
        final isVeryNarrowScreen = constraints.maxWidth < 400;
        final labelFontSize = isNarrowScreen ? 14.0 : 16.0;
        final buttonFontSize = isNarrowScreen ? 14.0 : 16.0;
        final errorFontSize = isVeryNarrowScreen ? 10.0 : 12.0;
        final buttonPadding = isVeryNarrowScreen ? 10.0 : 12.0;
        final buttonSpacing = isNarrowScreen ? 10.0 : 12.0;
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: labelFontSize,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            SizedBox(height: isVeryNarrowScreen ? 6.0 : 8.0),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => onChanged(true),
                    child: Container(
                      padding: EdgeInsets.all(buttonPadding),
                      decoration: BoxDecoration(
                        color: value == true ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.2) : Theme.of(context).disabledColor.withValues(alpha: 0.1),
                        border: Border.all(
                          color: value == true ? Theme.of(context).colorScheme.primary : Theme.of(context).disabledColor,
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          'Yes',
                          style: TextStyle(
                            fontSize: buttonFontSize,
                            fontWeight: FontWeight.w500,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: buttonSpacing),
                Expanded(
                  child: GestureDetector(
                    onTap: () => onChanged(false),
                    child: Container(
                      padding: EdgeInsets.all(buttonPadding),
                      decoration: BoxDecoration(
                        color: value == false ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.2) : Theme.of(context).disabledColor.withValues(alpha: 0.1),
                        border: Border.all(
                          color: value == false ? Theme.of(context).colorScheme.primary : Theme.of(context).disabledColor,
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          'No',
                          style: TextStyle(
                            fontSize: buttonFontSize,
                            fontWeight: FontWeight.w500,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (isRequired && value == null) ...[
              SizedBox(height: isVeryNarrowScreen ? 6.0 : 8.0),
              Text(
                'Please select an option for $title',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: errorFontSize,
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  
  const SectionHeader({
    super.key,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrowScreen = constraints.maxWidth < 600;
        final isVeryNarrowScreen = constraints.maxWidth < 400;
        final fontSize = isNarrowScreen ? 18.0 : 20.0;
        // Minimal top padding for section headers to reduce space at the top of the screen
        final topPadding = isVeryNarrowScreen ? 4.0 : 8.0;
        final bottomPadding = isVeryNarrowScreen ? 12.0 : 16.0;
        
        return Padding(
          padding: EdgeInsets.only(top: topPadding, bottom: bottomPadding),
          child: Text(
            title,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        );
      },
    );
  }
}