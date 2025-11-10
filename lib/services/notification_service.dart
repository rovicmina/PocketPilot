import 'dart:async';
import '../models/reminder.dart' as reminder_model;
import 'firebase_service.dart';

class NotificationService {
  static final List<PaymentReminder> _reminders = [];
  static Timer? _reminderTimer;

  static void initialize() {
    // Check for reminders every hour
    _reminderTimer = Timer.periodic(const Duration(hours: 1), (timer) {
      _checkForReminders();
    });
    
    // Initial check
    _checkForReminders();
  }

  static void dispose() {
    _reminderTimer?.cancel();
  }

  static Future<void> _checkForReminders() async {
    _reminders.clear(); 
    
    // Check custom reminders
    final customReminders = await FirebaseService.getReminders();
    for (final reminder in customReminders) {
      if (!reminder.isCompleted) {
        final now = DateTime.now();
        final reminderDate = DateTime(reminder.date.year, reminder.date.month, reminder.date.day);
        final today = DateTime(now.year, now.month, now.day);
        final daysUntilDue = reminderDate.difference(today).inDays;
        
        if (daysUntilDue <= 7 && daysUntilDue >= -7) { // Show reminders within a week range
          _reminders.add(PaymentReminder(
            id: reminder.id,
            title: reminder.title,
            amount: 0.0, // Custom reminders don't have amounts
            dueDate: reminder.date,
            type: _mapCustomReminderTypeToPaymentReminderType(reminder.type),
            category: reminder.typeDisplayName,
            isOverdue: reminder.isOverdue,
            priority: _calculatePriority(daysUntilDue, reminder.isOverdue),
          ));
        }
      }
    }
    
    // Check debts with enhanced tracking
    final debts = await FirebaseService.getDebts();
    for (final debt in debts) {
      if (!debt.isPaidOff) {
        // Add debt deadline reminders
        if (debt.dueDate != null) {
          final daysUntilDeadline = debt.daysUntilDue;
          if (daysUntilDeadline <= 30 && daysUntilDeadline >= -7) {
            _reminders.add(PaymentReminder(
              id: '${debt.id}_deadline',
              title: '${debt.name} Deadline',
              amount: debt.remainingAmount,
              dueDate: debt.dueDate!,
              type: ReminderType.debtDeadline,
              category: 'Debt Deadline',
              isOverdue: debt.isOverdue,
              priority: _calculatePriority(daysUntilDeadline, debt.isOverdue),
            ));
          }
        }
        
        // Add regular payment reminders
        if (debt.nextPaymentDate != null) {
          final daysUntilPayment = debt.nextPaymentDate!.difference(DateTime.now()).inDays;
          if (daysUntilPayment <= 7 && daysUntilPayment >= -1) {
            _reminders.add(PaymentReminder(
              id: debt.id,
              title: '${debt.name} Payment',
              amount: debt.amountPerFrequency,
              dueDate: debt.nextPaymentDate!,
              type: ReminderType.debtPayment,
              category: 'Debt Payment',
              isOverdue: daysUntilPayment < 0,
              priority: _calculatePriority(daysUntilPayment, daysUntilPayment < 0),
            ));
          }
        }
      }
    }

    // Check savings goals with enhanced tracking
    final goals = await FirebaseService.getGoals();
    for (final goal in goals) {
      if (!goal.isCompleted && goal.nextDepositDate != null) {
        final daysUntilDue = goal.nextDepositDate!.difference(DateTime.now()).inDays;
        if (daysUntilDue <= 3 && daysUntilDue >= -1) {
          _reminders.add(PaymentReminder(
            id: goal.id,
            title: '${goal.name} Savings',
            amount: goal.amountPerFrequency,
            dueDate: goal.nextDepositDate!,
            type: ReminderType.savingsGoal,
            category: 'Savings',
            isOverdue: daysUntilDue < 0,
            priority: _calculatePriority(daysUntilDue, daysUntilDue < 0),
          ));
        }
        
        // Add goal deadline reminders
        final daysUntilGoalEnd = goal.endDate.difference(DateTime.now()).inDays;
        if (daysUntilGoalEnd <= 30 && daysUntilGoalEnd >= 0 && goal.progressPercentage < 80) {
          _reminders.add(PaymentReminder(
            id: '${goal.id}_deadline',
            title: '${goal.name} Goal Ending Soon',
            amount: goal.remainingAmount,
            dueDate: goal.endDate,
            type: ReminderType.goalDeadline,
            category: 'Goal Deadline',
            isOverdue: false,
            priority: _calculatePriority(daysUntilGoalEnd, false),
          ));
        }
      }
    }

    // Sort by priority first, then by due date
    _reminders.sort((a, b) {
      final priorityComparison = b.priority.compareTo(a.priority);
      if (priorityComparison != 0) return priorityComparison;
      return a.dueDate.compareTo(b.dueDate);
    });
  }

  static int _calculatePriority(int daysUntilDue, bool isOverdue) {
    if (isOverdue) return 100;
    if (daysUntilDue == 0) return 90;
    if (daysUntilDue == 1) return 80;
    if (daysUntilDue <= 3) return 70;
    if (daysUntilDue <= 7) return 60;
    return 50;
  }

  static List<PaymentReminder> getUpcomingReminders() {
    return List.from(_reminders);
  }

  static List<PaymentReminder> getTodayReminders() {
    final today = DateTime.now();
    return _reminders.where((reminder) {
      return reminder.dueDate.year == today.year &&
             reminder.dueDate.month == today.month &&
             reminder.dueDate.day == today.day;
    }).toList();
  }

  static List<PaymentReminder> getOverdueReminders() {
    return _reminders.where((reminder) => reminder.isOverdue).toList();
  }

  static int get totalRemindersCount => _reminders.length;
  static int get todayRemindersCount => getTodayReminders().length;
  static int get overdueRemindersCount => getOverdueReminders().length;

  static ReminderType _mapCustomReminderTypeToPaymentReminderType(reminder_model.ReminderType reminderType) {
    switch (reminderType) {
      case reminder_model.ReminderType.saveForToday:
        return ReminderType.savingsGoal;
      case reminder_model.ReminderType.billPayment:
        return ReminderType.debtPayment;
      case reminder_model.ReminderType.debtPayment:
        return ReminderType.debtPayment;
      case reminder_model.ReminderType.generalNote:
        return ReminderType.debtPayment; // Default mapping
    }
  }

  static Future<void> markReminderAsHandled(String reminderId, ReminderType type) async {
    switch (type) {
      case ReminderType.debtPayment:
        // This would be handled by adding a debt payment transaction
        break;
      case ReminderType.debtDeadline:
        // This would be handled by updating debt status or adding payment
        break;
      case ReminderType.savingsGoal:
        // Check if it's a custom reminder first
        final customReminders = await FirebaseService.getReminders();
        final customReminder = customReminders.where((r) => r.id == reminderId).firstOrNull;
        if (customReminder != null) {
          await FirebaseService.markReminderAsCompleted(reminderId);
        } else {
          // This would be handled by adding a savings transaction
        }
        break;
      case ReminderType.goalDeadline:
        // This would be handled by updating goal or extending deadline
        break;
    }
    
    // Refresh reminders
    await _checkForReminders();
  }

  static Future<void> refreshReminders() async {
    await _checkForReminders();
  }
}

enum ReminderType {
  debtPayment,
  debtDeadline,
  savingsGoal,
  goalDeadline,
}

class PaymentReminder {
  final String id;
  final String title;
  final double amount;
  final DateTime dueDate;
  final ReminderType type;
  final String category;
  final bool isOverdue;
  final int priority;

  PaymentReminder({
    required this.id,
    required this.title,
    required this.amount,
    required this.dueDate,
    required this.type,
    required this.category,
    required this.isOverdue,
    required this.priority,
  });

  String get formattedAmount => '₱${amount.toStringAsFixed(2)}';
  
  String get dueDateText {
    final now = DateTime.now();
    final difference = dueDate.difference(now).inDays;
    
    if (isOverdue) return 'Overdue';
    if (difference == 0) return 'Due Today';
    if (difference == 1) return 'Due Tomorrow';
    return 'Due in $difference days';
  }

  String get typeDisplayName {
    switch (type) {
      case ReminderType.debtPayment:
        return 'Debt Payment';
      case ReminderType.debtDeadline:
        return 'Debt Deadline';
      case ReminderType.savingsGoal:
        return 'Savings Goal';
      case ReminderType.goalDeadline:
        return 'Goal Deadline';
    }
  }

  String get icon {
    switch (type) {
      case ReminderType.debtPayment:
      case ReminderType.debtDeadline:
        return 'ðŸ’³';
      case ReminderType.savingsGoal:
      case ReminderType.goalDeadline:
        return 'ðŸŽ¯';
    }
  }
}
