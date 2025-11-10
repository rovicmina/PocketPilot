import 'package:shared_preferences/shared_preferences.dart';

/// Represents notification categories
enum NotificationCategory {
  essential, // Budget Exceeded, Daily Reminder
  optional,  // Budgeting Tips, Goal Progress, Weekly Summary
}

/// Represents specific notification types
enum NotificationType {
  budgetExceeded,
  dailyReminder,
  budgetingTips,
  goalProgress,
  weeklySummary,
}

/// Model for storing user notification preferences
class NotificationSettings {
  // Essential notifications
  final bool budgetExceededEnabled;
  final bool dailyReminderEnabled;
  
  // Optional notifications
  final bool budgetingTipsEnabled;
  final bool goalProgressEnabled;
  final bool weeklySummaryEnabled;

  const NotificationSettings({
    this.budgetExceededEnabled = true,
    this.dailyReminderEnabled = true,
    this.budgetingTipsEnabled = true,
    this.goalProgressEnabled = true,
    this.weeklySummaryEnabled = true,
  });

  /// Check if a notification type is enabled based on user settings
  bool isNotificationEnabled(NotificationType type) {
    switch (type) {
      case NotificationType.budgetExceeded:
        return budgetExceededEnabled;
      case NotificationType.dailyReminder:
        return dailyReminderEnabled;
      case NotificationType.budgetingTips:
        return budgetingTipsEnabled;
      case NotificationType.goalProgress:
        return goalProgressEnabled;
      case NotificationType.weeklySummary:
        return weeklySummaryEnabled;
    }
  }

  /// Check if a notification category is enabled
  bool isCategoryEnabled(NotificationCategory category) {
    switch (category) {
      case NotificationCategory.essential:
        return budgetExceededEnabled || dailyReminderEnabled;
      case NotificationCategory.optional:
        return budgetingTipsEnabled || goalProgressEnabled || weeklySummaryEnabled;
    }
  }

  /// Save settings to shared preferences
  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_budget_exceeded', budgetExceededEnabled);
    await prefs.setBool('notifications_daily_reminder', dailyReminderEnabled);
    await prefs.setBool('notifications_budgeting_tips', budgetingTipsEnabled);
    await prefs.setBool('notifications_goal_progress', goalProgressEnabled);
    await prefs.setBool('notifications_weekly_summary', weeklySummaryEnabled);
  }

  /// Load settings from shared preferences
  static Future<NotificationSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    return NotificationSettings(
      budgetExceededEnabled: prefs.getBool('notifications_budget_exceeded') ?? true,
      dailyReminderEnabled: prefs.getBool('notifications_daily_reminder') ?? true,
      budgetingTipsEnabled: prefs.getBool('notifications_budgeting_tips') ?? true,
      goalProgressEnabled: prefs.getBool('notifications_goal_progress') ?? true,
      weeklySummaryEnabled: prefs.getBool('notifications_weekly_summary') ?? true,
    );
  }

  /// Factory method to create settings with all notifications disabled
  static NotificationSettings none() {
    return const NotificationSettings(
      budgetExceededEnabled: false,
      dailyReminderEnabled: false,
      budgetingTipsEnabled: false,
      goalProgressEnabled: false,
      weeklySummaryEnabled: false,
    );
  }

  /// Create a copy with modified values
  NotificationSettings copyWith({
    bool? budgetExceededEnabled,
    bool? dailyReminderEnabled,
    bool? budgetingTipsEnabled,
    bool? goalProgressEnabled,
    bool? weeklySummaryEnabled,
  }) {
    return NotificationSettings(
      budgetExceededEnabled: budgetExceededEnabled ?? this.budgetExceededEnabled,
      dailyReminderEnabled: dailyReminderEnabled ?? this.dailyReminderEnabled,
      budgetingTipsEnabled: budgetingTipsEnabled ?? this.budgetingTipsEnabled,
      goalProgressEnabled: goalProgressEnabled ?? this.goalProgressEnabled,
      weeklySummaryEnabled: weeklySummaryEnabled ?? this.weeklySummaryEnabled,
    );
  }
}