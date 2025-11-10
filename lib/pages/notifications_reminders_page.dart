import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/reminder.dart';
import '../services/firebase_service.dart';
import '../services/smart_notification_service.dart';
import '../services/notification_sync_service.dart';

class NotificationsRemindersPage extends StatefulWidget {
  const NotificationsRemindersPage({super.key});

  @override
  State<NotificationsRemindersPage> createState() => _NotificationsRemindersPageState();
}

class _NotificationsRemindersPageState extends State<NotificationsRemindersPage> {
  List<Reminder> _reminders = [];
  List<NotificationItem> _notifications = [];
  bool _isLoading = true;
  String _selectedFilter = 'Notifications';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final reminders = await FirebaseService.getReminders();
      
      // Initialize notification sync service
      await NotificationSyncService.initialize();
      
      // Get only real notifications from the app's notification system
      final notifications = await _getStoredMobileNotifications();
      
      setState(() {
        _reminders = reminders;
        _notifications = notifications;
        _isLoading = false;
      });
      
      // Load notification states after setting notifications
      await _loadNotificationStates();
      
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e')),
        );
      }
    }
  }



  List<dynamic> get _filteredItems {
    List<dynamic> allItems = [];
    
    // Add both reminders and notifications based on category filter
    switch (_selectedFilter) {
      case 'Notifications':
        // Only show notifications that are NOT daily reminders
        allItems.addAll(_notifications.where((n) => n.isNotificationType).toList());
        break;
      case 'Reminders':
        // Only show notifications that are daily reminders
        allItems.addAll(_notifications.where((n) => n.isReminderType).toList());
        // Also show all user-created reminders
        allItems.addAll(_reminders);
        break;
      default:
        // For All, Seen, Unseen - add both types but avoid duplicates
        allItems.addAll(_reminders);
        allItems.addAll(_notifications);
    }

    // Apply status filter (after category filter)
    if (_selectedFilter != 'All' && _selectedFilter != 'Notifications' && _selectedFilter != 'Reminders') {
      switch (_selectedFilter) {
        case 'Seen':
          allItems = allItems.where((item) {
            if (item is Reminder) return item.isCompleted;
            if (item is NotificationItem) return item.isRead;
            return false;
          }).toList();
          break;
        case 'Unseen':
          allItems = allItems.where((item) {
            if (item is Reminder) return !item.isCompleted;
            if (item is NotificationItem) return !item.isRead;
            return false;
          }).toList();
          break;
      }
    }

    // Sort by date - newest first
    allItems.sort((a, b) {
      DateTime dateA = a is Reminder ? a.date : a.date;
      DateTime dateB = b is Reminder ? b.date : b.date;
      return dateB.compareTo(dateA);
    });

    return allItems;
  }

  Future<void> _deleteReminder(String reminderId) async {
    try {
      await FirebaseService.deleteReminder(reminderId);
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reminder deleted successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting reminder: $e')),
        );
      }
    }
  }

  Future<void> _markReminderCompleted(String reminderId) async {
    try {
      await FirebaseService.markReminderAsCompleted(reminderId);
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reminder marked as completed')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating reminder: $e')),
        );
      }
    }
  }

  void _markNotificationAsRead(String notificationId) {
    setState(() {
      final index = _notifications.indexWhere((n) => n.id == notificationId);
      if (index != -1) {
        _notifications[index] = _notifications[index].copyWith(isRead: true);
      }
    });
    
    // Save to shared preferences for persistence and sync to Firebase
    _saveNotificationState(notificationId, true);
    NotificationSyncService.syncNotificationReadState(notificationId, true);
  }

  Future<void> _deleteNotification(String notificationId) async {
    setState(() {
      _notifications.removeWhere((n) => n.id == notificationId);
    });
    
    // Save deletion to shared preferences and sync to Firebase
    await _saveDeletedNotification(notificationId);
    await NotificationSyncService.syncDeletedNotification(notificationId);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notification deleted successfully')),
      );
    }
  }

  Future<void> _saveNotificationState(String notificationId, bool isRead) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('notification_read_$notificationId', isRead);
    } catch (e) {
      // Error saving notification state
    }
  }

  Future<void> _saveDeletedNotification(String notificationId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final deletedList = prefs.getStringList('deleted_notifications') ?? [];
      if (!deletedList.contains(notificationId)) {
        deletedList.add(notificationId);
        await prefs.setStringList('deleted_notifications', deletedList);
      }
    } catch (e) {
      // Error saving deleted notification
    }
  }

  Future<void> _loadNotificationStates() async {
    try {
      // Apply Firebase notification states to local storage first
      await NotificationSyncService.applyFirebaseStatesToLocal();
      
      final prefs = await SharedPreferences.getInstance();
      final deletedList = prefs.getStringList('deleted_notifications') ?? [];
      
      // Remove deleted notifications
      _notifications.removeWhere((notification) => deletedList.contains(notification.id));
      
      // Update read states
      for (int i = 0; i < _notifications.length; i++) {
        final isRead = prefs.getBool('notification_read_${_notifications[i].id}') ?? false;
        if (isRead != _notifications[i].isRead) {
          _notifications[i] = _notifications[i].copyWith(isRead: isRead);
        }
      }
    } catch (e) {
      // Error loading notification states
    }
  }

  void _showNotificationOptions(NotificationItem notification) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              notification.title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            if (!notification.isRead)
              ListTile(
                leading: const Icon(Icons.mark_as_unread, color: Colors.blue),
                title: const Text('Mark as Read'),
                onTap: () {
                  Navigator.pop(context);
                  _markNotificationAsRead(notification.id);
                },
              ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete Notification'),
              onTap: () {
                Navigator.pop(context);
                _showDeleteNotificationConfirmation(notification);
              },
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  void _showDeleteNotificationConfirmation(NotificationItem notification) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Notification'),
          content: Text(
            'Are you sure you want to delete "${notification.title}"?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _deleteNotification(notification.id);
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _clearReadNotifications() async {
    final readNotifications = _notifications.where((n) => n.isRead).toList();
    
    if (readNotifications.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No read notifications to clear')),
        );
      }
      return;
    }
    
    setState(() {
      _notifications.removeWhere((n) => n.isRead);
    });
    
    // Save deletions to preferences
    for (final notification in readNotifications) {
      await _saveDeletedNotification(notification.id);
    }
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cleared ${readNotifications.length} read notifications')),
      );
    }
  }
  
  Future<void> _markAllNotificationsAsRead() async {
    final unreadCount = _notifications.where((n) => !n.isRead).length;
    
    if (unreadCount == 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All notifications are already read')),
        );
      }
      return;
    }
    
    setState(() {
      for (int i = 0; i < _notifications.length; i++) {
        if (!_notifications[i].isRead) {
          _notifications[i] = _notifications[i].copyWith(isRead: true);
          _saveNotificationState(_notifications[i].id, true);
        }
      }
    });
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Marked $unreadCount notifications as read')),
      );
    }
  }

  void _showReminderOptions(Reminder reminder) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              reminder.title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),

            if (!reminder.isCompleted)
              ListTile(
                leading: const Icon(Icons.check_circle, color: Colors.green),
                title: const Text('Mark as Completed'),
                onTap: () {
                  Navigator.pop(context);
                  _markReminderCompleted(reminder.id);
                },
              ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete Reminder'),
              onTap: () {
                Navigator.pop(context);
                _showDeleteConfirmation(reminder);
              },
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation(Reminder reminder) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Reminder'),
          content: Text(
            'Are you sure you want to delete "${reminder.title}"?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _deleteReminder(reminder.id);
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  String _getEmptyStateTitle() {
    switch (_selectedFilter) {
      case 'Notifications':
        return 'No Notifications';
      case 'Reminders':
        return 'No Reminders';
      case 'Seen':
        return 'No Read Items';
      case 'Unseen':
        return 'No Unread Items';
      default:
        return 'No Items Found';
    }
  }

  String _getEmptyStateSubtitle() {
    switch (_selectedFilter) {
      case 'Notifications':
        return 'You have no notifications at the moment.\nNew budget alerts and updates will appear here.';
      case 'Reminders':
        return 'You have no reminders set.\nCreate reminders to stay on top of your finances.';
      case 'Seen':
        return 'No read notifications or completed reminders to display.';
      case 'Unseen':
        return 'No unread notifications or pending reminders to display.';
      default:
        return 'No notifications or reminders to display for the selected filter.';
    }
  }

  Future<List<NotificationItem>> _getStoredMobileNotifications() async {
    try {
      final storedNotifications = await SmartNotificationService.getStoredNotifications();
      final notifications = <NotificationItem>[];
      
      for (final storedNotification in storedNotifications) {
        try {
          final date = DateTime.tryParse(storedNotification['date'] as String) ?? DateTime.now();
          final type = _stringToNotificationType(storedNotification['type'] as String);
          
          notifications.add(
            NotificationItem(
              id: storedNotification['id'] as String,
              title: storedNotification['title'] as String,
              description: storedNotification['body'] as String,
              date: date,
              isRead: false, // Will be updated by _loadNotificationStates
              type: type,
            ),
          );
        } catch (e) {
          // Handle parsing errors silently
        }
      }
      
      // Sort by date - newest first
      notifications.sort((a, b) => b.date.compareTo(a.date));
      
      return notifications;
    } catch (e) {
      return [];
    }
  }
  
  /// Convert string to NotificationType
  NotificationType _stringToNotificationType(String typeStr) {
    switch (typeStr) {
      case 'budgetAlert':
        return NotificationType.budgetAlert;
      case 'goalAchievement':
        return NotificationType.goalAchievement;
      case 'transactionAlert':
        return NotificationType.transactionAlert;
      case 'systemUpdate':
        return NotificationType.systemUpdate;
      case 'dailyReminder':
        return NotificationType.dailyReminder;
      case 'weeklyInsight':
        return NotificationType.weeklyInsight;
      case 'monthlyWarning':
        return NotificationType.monthlyWarning;
      case 'budgetingTip':
        return NotificationType.budgetingTip;
      case 'milestone':
        return NotificationType.milestone;
      default:
        return NotificationType.dailyReminder;
    }
  }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: LayoutBuilder(
          builder: (context, constraints) {
            final isNarrowScreen = MediaQuery.of(context).size.width < 600;
            final isVeryNarrowScreen = MediaQuery.of(context).size.width < 400;
            final isExtremelyNarrowScreen = MediaQuery.of(context).size.width < 320;
            final titleFontSize = isExtremelyNarrowScreen ? 16.0 : isNarrowScreen ? 18.0 : 20.0; // Section Heading range
            
            return Text(
              isExtremelyNarrowScreen ? 'Notif.' : isVeryNarrowScreen ? 'Notifications' : 'Notifications & Reminders',
              style: TextStyle(
                color: theme.appBarTheme.foregroundColor,
                fontWeight: FontWeight.bold,
                fontSize: titleFontSize,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            );
          },
        ),
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: theme.appBarTheme.foregroundColor),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Filter Section - Content Type Priority
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Content Type Filters (Primary)
                      Text(
                        'Filter by Content Type',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                setState(() {
                                  _selectedFilter = 'Notifications';
                                });
                              },
                              icon: const Icon(Icons.notifications, size: 18),
                              label: const Text('Notifications'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _selectedFilter == 'Notifications'
                                    ? Colors.green
                                    : theme.cardTheme.color,
                                foregroundColor: _selectedFilter == 'Notifications'
                                    ? Colors.white
                                    : Colors.green,
                                elevation: _selectedFilter == 'Notifications' ? 3 : 1,
                                side: BorderSide(
                                  color: Colors.green,
                                  width: _selectedFilter == 'Notifications' ? 2 : 1,
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                setState(() {
                                  _selectedFilter = 'Reminders';
                                });
                              },
                              icon: const Icon(Icons.alarm, size: 18),
                              label: const Text('Reminders'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _selectedFilter == 'Reminders'
                                    ? Colors.blue
                                    : theme.cardTheme.color,
                                foregroundColor: _selectedFilter == 'Reminders'
                                    ? Colors.white
                                    : Colors.blue,
                                elevation: _selectedFilter == 'Reminders' ? 3 : 1,
                                side: BorderSide(
                                  color: Colors.blue,
                                  width: _selectedFilter == 'Reminders' ? 2 : 1,
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      // Status Filters (Secondary)
                      Text(
                        'Filter by Status',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          'All',
                          'Seen',
                          'Unseen',
                        ].map((filter) {
                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ElevatedButton(
                                onPressed: () {
                                  setState(() {
                                    _selectedFilter = filter;
                                  });
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _selectedFilter == filter
                                      ? theme.colorScheme.primary
                                      : theme.cardTheme.color,
                                  foregroundColor: _selectedFilter == filter
                                      ? theme.colorScheme.onPrimary
                                      : theme.colorScheme.primary,
                                  elevation: _selectedFilter == filter ? 2 : 0,
                                  side: BorderSide(
                                    color: theme.colorScheme.primary,
                                    width: _selectedFilter == filter ? 2 : 1,
                                  ),
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                ),
                                child: Text(
                                  filter,
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
                
                // Notification Management Buttons
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _markAllNotificationsAsRead,
                              icon: const Icon(Icons.mark_email_read, color: Colors.white),
                              label: const Text('Mark All Read'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.purple,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _clearReadNotifications,
                              icon: const Icon(Icons.clear_all, color: Colors.white),
                              label: const Text('Clear Read'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Items List
                Expanded(
                  child: _filteredItems.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _selectedFilter == 'Notifications' 
                                    ? Icons.notifications_none
                                    : _selectedFilter == 'Reminders'
                                        ? Icons.alarm_off
                                        : Icons.inbox,
                                size: 64,
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _getEmptyStateTitle(),
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w500,
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _getEmptyStateSubtitle(),
                                style: TextStyle(
                                  fontSize: 14,
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          itemCount: _filteredItems.length,
                          itemBuilder: (context, index) {
                            final item = _filteredItems[index];
                            if (item is Reminder) {
                              return _buildReminderCard(item);
                            } else if (item is NotificationItem) {
                              return _buildNotificationCard(item);
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                ),
              ],
            ),

    );
  }

  Widget _buildReminderCard(Reminder reminder) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrowScreen = constraints.maxWidth < 600;
        final isVeryNarrowScreen = constraints.maxWidth < 400;
        final isExtremelyNarrowScreen = constraints.maxWidth < 320;
        
        final containerPadding = isExtremelyNarrowScreen ? 12.0 : isNarrowScreen ? 14.0 : 16.0;
        final iconSize = isExtremelyNarrowScreen ? 40.0 : isNarrowScreen ? 45.0 : 50.0;
        final titleFontSize = isExtremelyNarrowScreen ? 14.0 : isNarrowScreen ? 15.0 : 16.0;
        final descriptionFontSize = isExtremelyNarrowScreen ? 12.0 : isNarrowScreen ? 13.0 : 14.0;
        final typeFontSize = isExtremelyNarrowScreen ? 10.0 : isNarrowScreen ? 11.0 : 12.0;
        final dateFontSize = isExtremelyNarrowScreen ? 10.0 : isNarrowScreen ? 11.0 : 12.0;
        final borderRadius = isExtremelyNarrowScreen ? 10.0 : 12.0;
        final elementSpacing = isExtremelyNarrowScreen ? 8.0 : isNarrowScreen ? 12.0 : 16.0;
        
        return Container(
          margin: EdgeInsets.only(bottom: isExtremelyNarrowScreen ? 8.0 : isNarrowScreen ? 10.0 : 12.0),
          child: GestureDetector(
            onLongPress: () => _showReminderOptions(reminder),
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(borderRadius),
              ),
              child: Container(
                padding: EdgeInsets.all(containerPadding),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(borderRadius),
                  border: reminder.isOverdue && !reminder.isCompleted
                      ? Border.all(color: Colors.red.withValues(alpha: 0.3), width: isExtremelyNarrowScreen ? 1.5 : 2.0)
                      : null,
                ),
                child: Row(
                  children: [
                    // Reminder icon and type
                    Container(
                      width: iconSize,
                      height: iconSize,
                      decoration: BoxDecoration(
                        color: reminder.isCompleted
                            ? Colors.green.withValues(alpha: 0.1)
                            : reminder.isOverdue
                                ? Colors.red.withValues(alpha: 0.1)
                                : Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(borderRadius),
                      ),
                      child: Center(
                        child: reminder.isCompleted
                            ? Icon(Icons.check_circle, color: Colors.green, size: isExtremelyNarrowScreen ? 20.0 : 24.0)
                            : Text(
                                reminder.typeIcon,
                                style: TextStyle(fontSize: isExtremelyNarrowScreen ? 18.0 : 20.0),
                              ),
                      ),
                    ),
                    SizedBox(width: elementSpacing),

                    // Reminder details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: isExtremelyNarrowScreen ? 4.0 : 6.0,
                                  vertical: isExtremelyNarrowScreen ? 1.0 : 2.0,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(isExtremelyNarrowScreen ? 3.0 : 4.0),
                                ),
                                child: Text(
                                  'REMINDER',
                                  style: TextStyle(
                                    fontSize: isExtremelyNarrowScreen ? 8.0 : isNarrowScreen ? 9.0 : 10.0,
                                    color: Colors.blue,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              Text(
                                reminder.dueDateText,
                                style: TextStyle(
                                  fontSize: dateFontSize,
                                  color: reminder.isOverdue && !reminder.isCompleted
                                      ? Colors.red
                                      : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: isExtremelyNarrowScreen ? 2.0 : 4.0),
                          Text(
                            reminder.title,
                            style: TextStyle(
                              fontSize: titleFontSize,
                              fontWeight: FontWeight.w600,
                              decoration: reminder.isCompleted
                                  ? TextDecoration.lineThrough
                                  : null,
                              color: reminder.isCompleted
                                  ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)
                                  : Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          if (reminder.description.isNotEmpty) ...[
                            SizedBox(height: isExtremelyNarrowScreen ? 2.0 : 4.0),
                            Text(
                              reminder.description,
                              style: TextStyle(
                                fontSize: descriptionFontSize,
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                decoration: reminder.isCompleted
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                              maxLines: isExtremelyNarrowScreen ? 1 : 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          SizedBox(height: isExtremelyNarrowScreen ? 4.0 : 8.0),
                          Row(
                            children: [
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: isExtremelyNarrowScreen ? 6.0 : 8.0,
                                  vertical: isExtremelyNarrowScreen ? 2.0 : 4.0,
                                ),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(isExtremelyNarrowScreen ? 4.0 : 6.0),
                                ),
                                child: Text(
                                  reminder.typeDisplayName,
                                  style: TextStyle(
                                    fontSize: typeFontSize,
                                    color: Theme.of(context).colorScheme.primary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              SizedBox(width: isExtremelyNarrowScreen ? 4.0 : 8.0),
                              if (reminder.recurrence != RecurrenceType.single)
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: isExtremelyNarrowScreen ? 6.0 : 8.0,
                                    vertical: isExtremelyNarrowScreen ? 2.0 : 4.0,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(isExtremelyNarrowScreen ? 4.0 : 6.0),
                                  ),
                                  child: Text(
                                    reminder.recurrenceDisplayName,
                                    style: TextStyle(
                                      fontSize: typeFontSize,
                                      color: Colors.blue,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Action button
                    IconButton(
                      icon: Icon(
                        Icons.more_vert,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                        size: isExtremelyNarrowScreen ? 18.0 : 24.0,
                      ),
                      onPressed: () => _showReminderOptions(reminder),
                      padding: EdgeInsets.zero,
                      constraints: BoxConstraints(
                        minWidth: isExtremelyNarrowScreen ? 32.0 : 40.0,
                        minHeight: isExtremelyNarrowScreen ? 32.0 : 40.0,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNotificationCard(NotificationItem notification) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrowScreen = constraints.maxWidth < 600;
        final isVeryNarrowScreen = constraints.maxWidth < 400;
        final isExtremelyNarrowScreen = constraints.maxWidth < 320;
        
        final containerPadding = isExtremelyNarrowScreen ? 12.0 : isNarrowScreen ? 14.0 : 16.0;
        final iconSize = isExtremelyNarrowScreen ? 40.0 : isNarrowScreen ? 45.0 : 50.0;
        final titleFontSize = isExtremelyNarrowScreen ? 14.0 : isNarrowScreen ? 15.0 : 16.0;
        final descriptionFontSize = isExtremelyNarrowScreen ? 12.0 : isNarrowScreen ? 13.0 : 14.0;
        final typeFontSize = isExtremelyNarrowScreen ? 10.0 : isNarrowScreen ? 11.0 : 12.0;
        final dateFontSize = isExtremelyNarrowScreen ? 10.0 : isNarrowScreen ? 11.0 : 12.0;
        final borderRadius = isExtremelyNarrowScreen ? 10.0 : 12.0;
        final elementSpacing = isExtremelyNarrowScreen ? 8.0 : isNarrowScreen ? 12.0 : 16.0;
        
        return Container(
          margin: EdgeInsets.only(bottom: isExtremelyNarrowScreen ? 8.0 : isNarrowScreen ? 10.0 : 12.0),
          child: GestureDetector(
            onTap: () => _markNotificationAsRead(notification.id),
            onLongPress: () => _showNotificationOptions(notification),
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(borderRadius),
              ),
              child: Container(
                padding: EdgeInsets.all(containerPadding),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(borderRadius),
                  color: notification.isRead ? null : Colors.blue.withValues(alpha: 0.05),
                ),
                child: Row(
                  children: [
                    // Notification icon
                    Container(
                      width: iconSize,
                      height: iconSize,
                      decoration: BoxDecoration(
                        color: notification.typeColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(borderRadius),
                      ),
                      child: Center(
                        child: Icon(
                          notification.typeIcon,
                          color: notification.typeColor,
                          size: isExtremelyNarrowScreen ? 20.0 : 24.0,
                        ),
                      ),
                    ),
                    SizedBox(width: elementSpacing),

                    // Notification details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: isExtremelyNarrowScreen ? 4.0 : 6.0,
                                  vertical: isExtremelyNarrowScreen ? 1.0 : 2.0,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(isExtremelyNarrowScreen ? 3.0 : 4.0),
                                ),
                                child: Text(
                                  'NOTIFICATION',
                                  style: TextStyle(
                                    fontSize: isExtremelyNarrowScreen ? 8.0 : isNarrowScreen ? 9.0 : 10.0,
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              if (!notification.isRead)
                                Container(
                                  width: isExtremelyNarrowScreen ? 6.0 : 8.0,
                                  height: isExtremelyNarrowScreen ? 6.0 : 8.0,
                                  decoration: const BoxDecoration(
                                    color: Colors.blue,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              if (!notification.isRead)
                                SizedBox(width: isExtremelyNarrowScreen ? 4.0 : 8.0),
                              Text(
                                notification.timeAgo,
                                style: TextStyle(
                                  fontSize: dateFontSize,
                                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: isExtremelyNarrowScreen ? 2.0 : 4.0),
                          Text(
                            notification.title,
                            style: TextStyle(
                              fontSize: titleFontSize,
                              fontWeight: notification.isRead 
                                  ? FontWeight.normal 
                                  : FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: isExtremelyNarrowScreen ? 2.0 : 4.0),
                          Text(
                            notification.description,
                            style: TextStyle(
                              fontSize: descriptionFontSize,
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                            maxLines: isExtremelyNarrowScreen ? 1 : 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: isExtremelyNarrowScreen ? 4.0 : 8.0),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: isExtremelyNarrowScreen ? 6.0 : 8.0,
                              vertical: isExtremelyNarrowScreen ? 2.0 : 4.0,
                            ),
                            decoration: BoxDecoration(
                              color: notification.typeColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(isExtremelyNarrowScreen ? 4.0 : 6.0),
                            ),
                            child: Text(
                              notification.typeDisplayName,
                              style: TextStyle(
                                fontSize: typeFontSize,
                                color: notification.typeColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Action button
                    IconButton(
                      icon: Icon(
                        Icons.more_vert,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                        size: isExtremelyNarrowScreen ? 18.0 : 24.0,
                      ),
                      onPressed: () => _showNotificationOptions(notification),
                      padding: EdgeInsets.zero,
                      constraints: BoxConstraints(
                        minWidth: isExtremelyNarrowScreen ? 32.0 : 40.0,
                        minHeight: isExtremelyNarrowScreen ? 32.0 : 40.0,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// Notification model and enum
enum NotificationType {
  budgetAlert,
  goalAchievement,
  transactionAlert,
  systemUpdate,
  dailyReminder,
  weeklyInsight,
  monthlyWarning,
  budgetingTip,
  milestone,
}

class NotificationItem {
  final String id;
  final String title;
  final String description;
  final DateTime date;
  final bool isRead;
  final NotificationType type;

  NotificationItem({
    required this.id,
    required this.title,
    required this.description,
    required this.date,
    this.isRead = false,
    required this.type,
  });

  String get typeDisplayName {
    switch (type) {
      case NotificationType.budgetAlert:
        return 'Budget Alert';
      case NotificationType.goalAchievement:
        return 'Goal Achievement';
      case NotificationType.transactionAlert:
        return 'Transaction Alert';
      case NotificationType.systemUpdate:
        return 'System Update';
      case NotificationType.dailyReminder:
        return 'Daily Reminder';
      case NotificationType.weeklyInsight:
        return 'Weekly Insight';
      case NotificationType.monthlyWarning:
        return 'Monthly Warning';
      case NotificationType.budgetingTip:
        return 'Budgeting Tips';
      case NotificationType.milestone:
        return 'Milestone';
    }
  }

  IconData get typeIcon {
    switch (type) {
      case NotificationType.budgetAlert:
        return Icons.warning;
      case NotificationType.goalAchievement:
        return Icons.star;
      case NotificationType.transactionAlert:
        return Icons.payment;
      case NotificationType.systemUpdate:
        return Icons.system_update;
      case NotificationType.dailyReminder:
        return Icons.schedule;
      case NotificationType.weeklyInsight:
        return Icons.analytics;
      case NotificationType.monthlyWarning:
        return Icons.error_outline;
      case NotificationType.budgetingTip:
        return Icons.lightbulb;
      case NotificationType.milestone:
        return Icons.emoji_events;
    }
  }

  Color get typeColor {
    switch (type) {
      case NotificationType.budgetAlert:
        return Colors.orange;
      case NotificationType.goalAchievement:
        return Colors.green;
      case NotificationType.transactionAlert:
        return Colors.red;
      case NotificationType.systemUpdate:
        return Colors.blue;
      case NotificationType.dailyReminder:
        return Colors.teal;
      case NotificationType.weeklyInsight:
        return Colors.purple;
      case NotificationType.monthlyWarning:
        return Colors.deepOrange;
      case NotificationType.budgetingTip:
        return Colors.amber;
      case NotificationType.milestone:
        return Colors.green;
    }
  }

  // Check if this notification should be displayed in the Reminders section
  bool get isReminderType {
    return type == NotificationType.dailyReminder;
  }

  // Check if this notification should be displayed in the Notifications section
  bool get isNotificationType {
    return type != NotificationType.dailyReminder;
  }

  bool get isToday {
    final now = DateTime.now();
    final notificationDate = DateTime(date.year, date.month, date.day);
    final today = DateTime(now.year, now.month, now.day);
    return notificationDate.isAtSameMomentAs(today);
  }

  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  NotificationItem copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? date,
    bool? isRead,
    NotificationType? type,
  }) {
    return NotificationItem(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      date: date ?? this.date,
      isRead: isRead ?? this.isRead,
      type: type ?? this.type,
    );
  }
}
