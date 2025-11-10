import 'package:flutter/material.dart';

enum TimeFrame { daily, weekly, monthly }

class TimeFrameFilter extends StatelessWidget {
  final TimeFrame selectedTimeFrame;
  final Function(TimeFrame) onTimeFrameChanged;

  const TimeFrameFilter({
    super.key,
    required this.selectedTimeFrame,
    required this.onTimeFrameChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withValues(alpha: 0.1),
            spreadRadius: 0.5,
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Icon(
              Icons.filter_list,
              color: theme.colorScheme.primary,
              size: 18,
            ),
            const SizedBox(width: 6),
            Text(
              'View:',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurface,
                fontSize: 14,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Row(
                children: TimeFrame.values.map((timeFrame) {
                  final isSelected = selectedTimeFrame == timeFrame;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => onTimeFrameChanged(timeFrame),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 1),
                        padding: const EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected ? theme.colorScheme.primary : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isSelected ? theme.colorScheme.primary : theme.dividerColor,
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          _getTimeFrameDisplayName(timeFrame),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: isSelected ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getTimeFrameDisplayName(TimeFrame timeFrame) {
    switch (timeFrame) {
      case TimeFrame.daily:
        return 'Daily';
      case TimeFrame.weekly:
        return 'Weekly';
      case TimeFrame.monthly:
        return 'Monthly';
    }
  }
}

class TimeFrameHelper {
  static DateTime getStartDate(TimeFrame timeFrame, DateTime referenceDate) {
    switch (timeFrame) {
      case TimeFrame.daily:
        return DateTime(referenceDate.year, referenceDate.month, referenceDate.day);
      case TimeFrame.weekly:
        // Get start of week (Monday)
        final daysFromMonday = referenceDate.weekday - 1;
        return DateTime(referenceDate.year, referenceDate.month, referenceDate.day)
            .subtract(Duration(days: daysFromMonday));
      case TimeFrame.monthly:
        return DateTime(referenceDate.year, referenceDate.month, 1);
    }
  }

  static DateTime getEndDate(TimeFrame timeFrame, DateTime referenceDate) {
    switch (timeFrame) {
      case TimeFrame.daily:
        return DateTime(referenceDate.year, referenceDate.month, referenceDate.day, 23, 59, 59);
      case TimeFrame.weekly:
        // Get end of week (Sunday)
        final daysFromMonday = referenceDate.weekday - 1;
        final startOfWeek = DateTime(referenceDate.year, referenceDate.month, referenceDate.day)
            .subtract(Duration(days: daysFromMonday));
        return startOfWeek.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
      case TimeFrame.monthly:
        return DateTime(referenceDate.year, referenceDate.month + 1, 0, 23, 59, 59);
    }
  }

  static String getDisplayText(TimeFrame timeFrame, DateTime referenceDate) {
    switch (timeFrame) {
      case TimeFrame.daily:
        return _formatDate(referenceDate);
      case TimeFrame.weekly:
        final startOfWeek = getStartDate(timeFrame, referenceDate);
        final endOfWeek = getEndDate(timeFrame, referenceDate);
        return '${_formatDate(startOfWeek)} - ${_formatDate(endOfWeek)}';
      case TimeFrame.monthly:
        final months = [
          'January', 'February', 'March', 'April', 'May', 'June',
          'July', 'August', 'September', 'October', 'November', 'December'
        ];
        return '${months[referenceDate.month - 1]} ${referenceDate.year}';
    }
  }

  static String _formatDate(DateTime date) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}';
  }

  static DateTime getPreviousPeriod(TimeFrame timeFrame, DateTime currentDate) {
    switch (timeFrame) {
      case TimeFrame.daily:
        return currentDate.subtract(const Duration(days: 1));
      case TimeFrame.weekly:
        return currentDate.subtract(const Duration(days: 7));
      case TimeFrame.monthly:
        return DateTime(currentDate.year, currentDate.month - 1, currentDate.day);
    }
  }

  static DateTime getNextPeriod(TimeFrame timeFrame, DateTime currentDate) {
    switch (timeFrame) {
      case TimeFrame.daily:
        return currentDate.add(const Duration(days: 1));
      case TimeFrame.weekly:
        return currentDate.add(const Duration(days: 7));
      case TimeFrame.monthly:
        return DateTime(currentDate.year, currentDate.month + 1, currentDate.day);
    }
  }

  static bool canGoToNextPeriod(TimeFrame timeFrame, DateTime currentDate) {
    final nextPeriod = getNextPeriod(timeFrame, currentDate);
    final now = DateTime.now();
    
    switch (timeFrame) {
      case TimeFrame.daily:
        return nextPeriod.isBefore(now) || 
               (nextPeriod.year == now.year && 
                nextPeriod.month == now.month && 
                nextPeriod.day == now.day);
      case TimeFrame.weekly:
        final nextWeekStart = getStartDate(timeFrame, nextPeriod);
        return nextWeekStart.isBefore(now);
      case TimeFrame.monthly:
        return nextPeriod.year < now.year || 
               (nextPeriod.year == now.year && nextPeriod.month <= now.month);
    }
  }

  static List<DateTime> getDatesInPeriod(TimeFrame timeFrame, DateTime referenceDate) {
    final startDate = getStartDate(timeFrame, referenceDate);
    final endDate = getEndDate(timeFrame, referenceDate);
    
    final dates = <DateTime>[];
    var currentDate = startDate;
    
    while (currentDate.isBefore(endDate) || currentDate.isAtSameMomentAs(endDate)) {
      dates.add(DateTime(currentDate.year, currentDate.month, currentDate.day));
      currentDate = currentDate.add(const Duration(days: 1));
    }
    
    return dates;
  }
}

class TimeFrameNavigator extends StatelessWidget {
  final TimeFrame timeFrame;
  final DateTime currentDate;
  final Function(DateTime) onDateChanged;

  const TimeFrameNavigator({
    super.key,
    required this.timeFrame,
    required this.currentDate,
    required this.onDateChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canGoNext = TimeFrameHelper.canGoToNextPeriod(timeFrame, currentDate);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withValues(alpha: 0.1),
            spreadRadius: 0.5,
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            GestureDetector(
              onTap: () {
                final previousDate = TimeFrameHelper.getPreviousPeriod(timeFrame, currentDate);
                onDateChanged(previousDate);
              },
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  Icons.chevron_left,
                  color: theme.colorScheme.primary,
                  size: 18,
                ),
              ),
            ),
            Expanded(
              child: Text(
                TimeFrameHelper.getDisplayText(timeFrame, currentDate),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
            GestureDetector(
              onTap: canGoNext ? () {
                final nextDate = TimeFrameHelper.getNextPeriod(timeFrame, currentDate);
                onDateChanged(nextDate);
              } : null,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: canGoNext 
                    ? theme.colorScheme.primary.withValues(alpha: 0.1)
                    : theme.colorScheme.onSurface.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  Icons.chevron_right,
                  color: canGoNext ? theme.colorScheme.primary : theme.colorScheme.onSurface.withValues(alpha: 0.4),
                  size: 18,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
