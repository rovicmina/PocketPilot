import 'package:flutter/material.dart';
import '../models/reminder.dart';
import '../services/firebase_service.dart';
import '../widgets/add_reminder_modal.dart';

class RemindersPage extends StatefulWidget {
  const RemindersPage({super.key});

  @override
  State<RemindersPage> createState() => _RemindersPageState();
}

class _RemindersPageState extends State<RemindersPage> {
  List<Reminder> _reminders = [];
  bool _isLoading = true;
  String _selectedFilter = 'All';

  @override
  void initState() {
    super.initState();
    _loadReminders();
  }

  Future<void> _loadReminders() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final reminders = await FirebaseService.getReminders();
      setState(() {
        _reminders = reminders;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading reminders: $e')),
        );
      }
    }
  }

  Future<void> _showAddReminderModal() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddReminderModal(
        selectedDate: DateTime.now(),
        onReminderAdded: () {
          _loadReminders();
        },
      ),
    );
  }

  Future<void> _showEditReminderModal(Reminder reminder) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddReminderModal(
        selectedDate: reminder.date,
        reminder: reminder,
        onReminderAdded: () {
          _loadReminders();
        },
      ),
    );
  }

  List<Reminder> get _filteredReminders {
    switch (_selectedFilter) {
      case 'Active':
        return _reminders.where((r) => !r.isCompleted).toList();
      case 'Completed':
        return _reminders.where((r) => r.isCompleted).toList();
      case 'Overdue':
        return _reminders.where((r) => r.isOverdue && !r.isCompleted).toList();
      case 'Today':
        return _reminders.where((r) => r.isDueToday && !r.isCompleted).toList();
      case 'Recurring':
        return _reminders.where((r) => r.recurrence != RecurrenceType.single).toList();
      default:
        return _reminders;
    }
  }

  Future<void> _deleteReminder(String reminderId) async {
    try {
      await FirebaseService.deleteReminder(reminderId);
      await _loadReminders();
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
      await _loadReminders();
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
                color: Colors.grey[300],
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
            ListTile(
              leading: const Icon(Icons.edit, color: Colors.blue),
              title: const Text('Edit Reminder'),
              onTap: () {
                Navigator.pop(context);
                _showEditReminderModal(reminder);
              },
            ),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: LayoutBuilder(
          builder: (context, constraints) {
            final isNarrowScreen = MediaQuery.of(context).size.width < 600;
            final isVeryNarrowScreen = MediaQuery.of(context).size.width < 400;
            final titleFontSize = isNarrowScreen ? 18.0 : 22.0; // Section Heading range (18–24sp)
            
            return Text(
              'Reminders',
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
            onPressed: _loadReminders,
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrowScreen = constraints.maxWidth < 600;
          final isVeryNarrowScreen = constraints.maxWidth < 400;
          final horizontalPadding = isVeryNarrowScreen ? 12.0 : isNarrowScreen ? 14.0 : 16.0;
          
          return _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    // Filter Chips with responsive padding
                    Container(
                      padding: EdgeInsets.all(horizontalPadding),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            'All',
                            'Active',
                            'Completed',
                            'Overdue',
                            'Today',
                            'Recurring'
                          ].map((filter) {
                            return Padding(
                              padding: EdgeInsets.only(right: isVeryNarrowScreen ? 6.0 : 8.0),
                              child: FilterChip(
                                label: Text(
                                  filter,
                                  style: TextStyle(
                                    fontSize: isVeryNarrowScreen ? 12.0 : 14.0,
                                  ),
                                ),
                                selected: _selectedFilter == filter,
                                onSelected: (selected) {
                                  setState(() {
                                    _selectedFilter = filter;
                                  });
                                },
                                selectedColor: theme.colorScheme.primary.withValues(alpha: 0.2),
                                checkmarkColor: theme.colorScheme.primary,
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),

                    // Reminders List
                    Expanded(
                      child: _filteredReminders.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.notifications_none,
                                    size: isVeryNarrowScreen ? 50.0 : 64.0,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No reminders found',
                                    style: TextStyle(
                                      fontSize: isVeryNarrowScreen ? 16.0 : 18.0,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Tap the + button to add a reminder',
                                    style: TextStyle(
                                      fontSize: isVeryNarrowScreen ? 12.0 : 14.0,
                                      color: Colors.grey[500],
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                              itemCount: _filteredReminders.length,
                              itemBuilder: (context, index) {
                                final reminder = _filteredReminders[index];
                                return _buildReminderCard(reminder, isNarrowScreen, isVeryNarrowScreen);
                              },
                            ),
                    ),
                  ],
                );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _showAddReminderModal();
        },
        backgroundColor: theme.colorScheme.primary,
        child: Icon(Icons.add, color: theme.colorScheme.onPrimary),
      ),
    );
  }

  Widget _buildReminderCard(Reminder reminder, bool isNarrowScreen, bool isVeryNarrowScreen) {
    final isExtremelyNarrowScreen = MediaQuery.of(context).size.width < 320;
    final iconSize = isExtremelyNarrowScreen ? 35.0 : isVeryNarrowScreen ? 40.0 : isNarrowScreen ? 45.0 : 50.0;
    final titleFontSize = isExtremelyNarrowScreen ? 13.0 : isVeryNarrowScreen ? 14.0 : isNarrowScreen ? 15.0 : 16.0;
    final descriptionFontSize = isExtremelyNarrowScreen ? 11.0 : isVeryNarrowScreen ? 12.0 : isNarrowScreen ? 13.0 : 14.0;
    final typeFontSize = isExtremelyNarrowScreen ? 9.0 : isVeryNarrowScreen ? 10.0 : isNarrowScreen ? 11.0 : 12.0;
    final dateFontSize = isExtremelyNarrowScreen ? 9.0 : isVeryNarrowScreen ? 10.0 : isNarrowScreen ? 11.0 : 12.0;
    final borderRadius = isExtremelyNarrowScreen ? 8.0 : isVeryNarrowScreen ? 10.0 : 12.0;
    final padding = isExtremelyNarrowScreen ? 10.0 : isVeryNarrowScreen ? 12.0 : isNarrowScreen ? 14.0 : 16.0;
    final spacing = isExtremelyNarrowScreen ? 8.0 : isVeryNarrowScreen ? 10.0 : isNarrowScreen ? 11.0 : 12.0;
    final elementSpacing = isExtremelyNarrowScreen ? 6.0 : isVeryNarrowScreen ? 8.0 : isNarrowScreen ? 12.0 : 16.0;

    return Container(
      margin: EdgeInsets.only(bottom: spacing),
      child: GestureDetector(
        onLongPress: () => _showReminderOptions(reminder),
        child: Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          child: Container(
            padding: EdgeInsets.all(padding),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(borderRadius),
              border: reminder.isOverdue && !reminder.isCompleted
                  ? Border.all(color: Colors.red.withValues(alpha: 0.3), width: isVeryNarrowScreen ? 1.5 : 2.0)
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
                            : Colors.teal.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(borderRadius),
                  ),
                  child: Center(
                    child: reminder.isCompleted
                        ? Icon(Icons.check_circle, color: Colors.green, size: isVeryNarrowScreen ? 20.0 : 24.0)
                        : Text(
                            reminder.typeIcon,
                            style: TextStyle(fontSize: isVeryNarrowScreen ? 18.0 : 20.0),
                          ),
                  ),
                ),
                SizedBox(width: elementSpacing),

                // Reminder details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        reminder.title,
                        style: TextStyle(
                          fontSize: titleFontSize,
                          fontWeight: FontWeight.w600,
                          decoration: reminder.isCompleted
                              ? TextDecoration.lineThrough
                              : null,
                          color: reminder.isCompleted
                              ? Colors.grey[600]
                              : null,
                        ),
                      ),
                      if (reminder.description.isNotEmpty) ...[
                        SizedBox(height: isExtremelyNarrowScreen ? 1.0 : isVeryNarrowScreen ? 2.0 : 4.0),
                        Text(
                          reminder.description,
                          style: TextStyle(
                            fontSize: descriptionFontSize,
                            color: Colors.grey[600],
                            decoration: reminder.isCompleted
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                          maxLines: isExtremelyNarrowScreen ? 1 : isVeryNarrowScreen ? 1 : 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      SizedBox(height: isExtremelyNarrowScreen ? 3.0 : isVeryNarrowScreen ? 4.0 : 8.0),
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: isExtremelyNarrowScreen ? 4.0 : isVeryNarrowScreen ? 6.0 : 8.0, 
                              vertical: isExtremelyNarrowScreen ? 1.0 : isVeryNarrowScreen ? 2.0 : 4.0
                            ),
                            decoration: BoxDecoration(
                              color: Colors.teal.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(isExtremelyNarrowScreen ? 3.0 : isVeryNarrowScreen ? 4.0 : 6.0),
                            ),
                            child: Text(
                              reminder.typeDisplayName,
                              style: TextStyle(
                                fontSize: typeFontSize,
                                color: Colors.teal,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          SizedBox(width: isExtremelyNarrowScreen ? 2.0 : isVeryNarrowScreen ? 4.0 : 8.0),
                          if (reminder.recurrence != RecurrenceType.single)
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: isExtremelyNarrowScreen ? 4.0 : isVeryNarrowScreen ? 6.0 : 8.0, 
                                vertical: isExtremelyNarrowScreen ? 1.0 : isVeryNarrowScreen ? 2.0 : 4.0
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(isExtremelyNarrowScreen ? 3.0 : isVeryNarrowScreen ? 4.0 : 6.0),
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
                          const Spacer(),
                          Text(
                            reminder.dueDateText,
                            style: TextStyle(
                              fontSize: dateFontSize,
                              color: reminder.isOverdue && !reminder.isCompleted
                                  ? Colors.red
                                  : Colors.grey[600],
                              fontWeight: FontWeight.w500,
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
                    color: Colors.grey[600],
                    size: isVeryNarrowScreen ? 20.0 : 24.0,
                  ),
                  onPressed: () => _showReminderOptions(reminder),
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(
                    minWidth: isVeryNarrowScreen ? 36.0 : 40.0,
                    minHeight: isVeryNarrowScreen ? 36.0 : 40.0,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
