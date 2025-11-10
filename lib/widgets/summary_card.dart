import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class SummaryCard extends StatelessWidget {
  final String title;
  final double amount;
  final IconData icon;
  final Color color;

  const SummaryCard({
    super.key,
    required this.title,
    required this.amount,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        // Determine responsive layout parameters
        final isNarrowScreen = constraints.maxWidth < 150; // Summary cards are small, adjust threshold
        
        // Responsive sizing following typography standards
        final titleFontSize = isNarrowScreen ? 12.0 : 14.0; // Secondary Text range (12–14sp)
        final amountFontSize = isNarrowScreen ? 14.0 : 16.0; // Body Text range (14–16sp) - reduced to fit 6 digits
        final iconSize = isNarrowScreen ? 18.0 : 20.0;
        final containerPadding = isNarrowScreen ? 12.0 : 16.0;
        final iconPadding = isNarrowScreen ? 6.0 : 8.0;
        final spacingAfterIcon = isNarrowScreen ? 10.0 : 12.0;
        final spacingAfterTitle = isNarrowScreen ? 2.0 : 4.0;
        
        return Container(
          padding: EdgeInsets.all(containerPadding),
          decoration: BoxDecoration(
            color: theme.cardTheme.color,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: theme.shadowColor,
                spreadRadius: 1,
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(iconPadding),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      icon,
                      color: color,
                      size: iconSize,
                    ),
                  ),
                  const Spacer(),
                ],
              ),
              SizedBox(height: spacingAfterIcon),
              Text(
                title,
                style: TextStyle(
                  fontSize: titleFontSize,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: spacingAfterTitle),
              Text(
                NumberFormat.currency(symbol: '₱').format(amount.abs()),
                style: TextStyle(
                  fontSize: amountFontSize,
                  fontWeight: FontWeight.bold,
                  color: amount < 0 ? Colors.red : theme.colorScheme.onSurface,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      },
    );
  }
}
