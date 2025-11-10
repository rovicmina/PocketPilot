import 'package:flutter/material.dart';
import '../models/notification_settings.dart';
import '../../utils/responsive_utils.dart';
import '../../widgets/responsive_container.dart';

class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({super.key});

  @override
  State<NotificationSettingsPage> createState() => _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  late NotificationSettings _settings;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final settings = await NotificationSettings.load();
      setState(() {
        _settings = settings;
        _isLoading = false;
      });
    } catch (e) {
      // Handle error
      setState(() {
        _settings = const NotificationSettings();
        _isLoading = false;
      });
    }
  }

  Future<void> _saveSettings() async {
    try {
      await _settings.save();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notification settings saved')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save settings')),
        );
      }
    }
  }

  void _updateSetting(NotificationType type, bool value) {
    setState(() {
      switch (type) {
        case NotificationType.budgetExceeded:
          _settings = _settings.copyWith(budgetExceededEnabled: value);
          break;
        case NotificationType.dailyReminder:
          _settings = _settings.copyWith(dailyReminderEnabled: value);
          break;
        case NotificationType.budgetingTips:
          _settings = _settings.copyWith(budgetingTipsEnabled: value);
          break;
        case NotificationType.goalProgress:
          _settings = _settings.copyWith(goalProgressEnabled: value);
          break;
        case NotificationType.weeklySummary:
          _settings = _settings.copyWith(weeklySummaryEnabled: value);
          break;
      }
    });
    _saveSettings();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: ResponsiveLayoutBuilder(
          builder: (context, layoutInfo) {
            final titleFontSize = layoutInfo.fontSize(small: 18, medium: 20, large: 22);
            
            return Text(
              'Notification Settings',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: titleFontSize,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            );
          },
        ),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ResponsiveLayoutBuilder(
              builder: (context, layoutInfo) {
                return SingleChildScrollView(
                  padding: EdgeInsets.all(layoutInfo.padding(small: 12, medium: 16, large: 20)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ResponsiveText(
                        'Customize which notifications you receive',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                        smallFontSize: 14,
                        mediumFontSize: 16,
                        largeFontSize: 18,
                      ),
                      SizedBox(height: layoutInfo.spacing(small: 16, medium: 24, large: 32)),
                      
                      // Essential Notifications Section
                      ResponsiveText(
                        '🔔 Essential',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                        smallFontSize: 16,
                        mediumFontSize: 18,
                        largeFontSize: 20,
                      ),
                      SizedBox(height: layoutInfo.spacing(small: 12, medium: 16, large: 20)),
                      
                      _buildNotificationToggle(
                        title: 'Budget Exceeded',
                        subtitle: 'Alert when you overspend',
                        type: NotificationType.budgetExceeded,
                      ),
                      
                      SizedBox(height: layoutInfo.spacing(small: 12, medium: 16, large: 20)),
                      
                      _buildNotificationToggle(
                        title: 'Daily Reminder',
                        subtitle: 'Log today\'s expenses',
                        type: NotificationType.dailyReminder,
                      ),
                      
                      SizedBox(height: layoutInfo.spacing(small: 24, medium: 32, large: 40)),
                      
                      // Optional Notifications Section
                      ResponsiveText(
                        '📘 Optional',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                        smallFontSize: 16,
                        mediumFontSize: 18,
                        largeFontSize: 20,
                      ),
                      SizedBox(height: layoutInfo.spacing(small: 12, medium: 16, large: 20)),
                      
                      _buildNotificationToggle(
                        title: 'Budgeting Tips',
                        subtitle: 'Once per day weekly',
                        type: NotificationType.budgetingTips,
                      ),
                      
                      SizedBox(height: layoutInfo.spacing(small: 12, medium: 16, large: 20)),
                      
                      _buildNotificationToggle(
                        title: 'Goal Progress',
                        subtitle: 'Emergency fund progress, savings progress',
                        type: NotificationType.goalProgress,
                      ),
                      
                      SizedBox(height: layoutInfo.spacing(small: 12, medium: 16, large: 20)),
                      
                      _buildNotificationToggle(
                        title: 'Weekly Summary',
                        subtitle: 'Spending vs. budget',
                        type: NotificationType.weeklySummary,
                      ),
                      
                      SizedBox(height: layoutInfo.spacing(small: 24, medium: 32, large: 40)),
                      
                      // Turn All Off Button
                      Center(
                        child: OutlinedButton(
                          onPressed: _turnAllNotificationsOff,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                          ),
                          child: ResponsiveText(
                            'Turn All Notifications Off',
                            smallFontSize: 14,
                            mediumFontSize: 16,
                            largeFontSize: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _buildNotificationToggle({
    required String title,
    required String subtitle,
    required NotificationType type,
  }) {
    return ResponsiveLayoutBuilder(
      builder: (context, layoutInfo) {
        return Container(
          padding: EdgeInsets.all(layoutInfo.padding(small: 12, medium: 16, large: 20)),
          decoration: BoxDecoration(
            color: Theme.of(context).cardTheme.color,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).dividerColor,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ResponsiveText(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                      smallFontSize: 14,
                      mediumFontSize: 16,
                      largeFontSize: 18,
                    ),
                    SizedBox(height: layoutInfo.spacing(small: 2, medium: 4, large: 6)),
                    ResponsiveText(
                      subtitle,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                      smallFontSize: 12,
                      mediumFontSize: 14,
                      largeFontSize: 16,
                    ),
                  ],
                ),
              ),
              Switch(
                value: _settings.isNotificationEnabled(type),
                onChanged: (value) => _updateSetting(type, value),
                activeColor: Colors.green,
              ),
            ],
          ),
        );
      },
    );
  }

  void _turnAllNotificationsOff() {
    setState(() {
      _settings = NotificationSettings.none();
    });
    _saveSettings();
  }
}