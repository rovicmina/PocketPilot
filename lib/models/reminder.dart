import 'package:intl/intl.dart';

enum ReminderType {
  saveForToday,
  billPayment,
  debtPayment,
  generalNote,
}

enum RecurrenceType {
  single,
  daily,
  weekly,
  monthly,
}

class Reminder {
  final String id;
  final String title;
  final String description;
  final DateTime date;
  final ReminderType type;
  final RecurrenceType recurrence;
  final bool isCompleted;
  final DateTime createdAt;
  final DateTime? completedAt;
  final DateTime? endDate; // For recurring reminders - when to stop recurring
  final int? maxOccurrences; // Alternative to endDate - max number of occurrences

  Reminder({
    required this.id,
    required this.title,
    required this.description,
    required this.date,
    required this.type,
    required this.recurrence,
    this.isCompleted = false,
    required this.createdAt,
    this.completedAt,
    this.endDate,
    this.maxOccurrences,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'date': date.toIso8601String(),
      'type': type.toString(),
      'recurrence': recurrence.toString(),
      'isCompleted': isCompleted,
      'createdAt': createdAt.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'maxOccurrences': maxOccurrences,
    };
  }

  factory Reminder.fromJson(Map<String, dynamic> json) {
    return Reminder(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      date: DateTime.parse(json['date']),
      type: ReminderType.values.firstWhere(
        (e) => e.toString() == json['type'],
      ),
      recurrence: RecurrenceType.values.firstWhere(
        (e) => e.toString() == json['recurrence'],
      ),
      isCompleted: json['isCompleted'] ?? false,
      createdAt: DateTime.parse(json['createdAt']),
      completedAt: json['completedAt'] != null 
          ? DateTime.parse(json['completedAt']) 
          : null,
      endDate: json['endDate'] != null 
          ? DateTime.parse(json['endDate']) 
          : null,
      maxOccurrences: json['maxOccurrences'],
    );
  }

  String get formattedDate {
    return DateFormat('MMM dd, yyyy').format(date);
  }

  String get formattedTime {
    return DateFormat('h:mm a').format(date);
  }

  String get typeDisplayName {
    switch (type) {
      case ReminderType.saveForToday:
        return 'Save for Today';
      case ReminderType.billPayment:
        return 'Bill Payment';
      case ReminderType.debtPayment:
        return 'Debt Payment';
      case ReminderType.generalNote:
        return 'General Note';
    }
  }

  String get recurrenceDisplayName {
    switch (recurrence) {
      case RecurrenceType.single:
        return 'One-time';
      case RecurrenceType.daily:
        return 'Daily';
      case RecurrenceType.weekly:
        return 'Weekly';
      case RecurrenceType.monthly:
        return 'Monthly';
    }
  }

  String get typeIcon {
    switch (type) {
      case ReminderType.saveForToday:
        return '💰';
      case ReminderType.billPayment:
        return '💡';
      case ReminderType.debtPayment:
        return '💳';
      case ReminderType.generalNote:
        return '📝';
    }
  }

  bool get isOverdue {
    final now = DateTime.now();
    final reminderDate = DateTime(date.year, date.month, date.day);
    final today = DateTime(now.year, now.month, now.day);
    return reminderDate.isBefore(today) && !isCompleted;
  }

  bool get isDueToday {
    final now = DateTime.now();
    final reminderDate = DateTime(date.year, date.month, date.day);
    final today = DateTime(now.year, now.month, now.day);
    return reminderDate.isAtSameMomentAs(today);
  }

  String get dueDateText {
    final now = DateTime.now();
    final reminderDate = DateTime(date.year, date.month, date.day);
    final today = DateTime(now.year, now.month, now.day);
    final difference = reminderDate.difference(today).inDays;
    
    if (isCompleted) return 'Completed';
    if (isOverdue) return 'Overdue';
    if (isDueToday) return 'Due Today';
    if (difference == 1) return 'Due Tomorrow';
    if (difference > 0) return 'Due in $difference days';
    return 'Past due';
  }

  Reminder copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? date,
    ReminderType? type,
    RecurrenceType? recurrence,
    bool? isCompleted,
    DateTime? createdAt,
    DateTime? completedAt,
    DateTime? endDate,
    int? maxOccurrences,
  }) {
    return Reminder(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      date: date ?? this.date,
      type: type ?? this.type,
      recurrence: recurrence ?? this.recurrence,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
      endDate: endDate ?? this.endDate,
      maxOccurrences: maxOccurrences ?? this.maxOccurrences,
    );
  }

  Reminder markAsCompleted() {
    return copyWith(
      isCompleted: true,
      completedAt: DateTime.now(),
    );
  }

  // Generate next occurrence for recurring reminders
  Reminder? generateNextOccurrence() {
    if (recurrence == RecurrenceType.single) return null;

    DateTime nextDate;
    switch (recurrence) {
      case RecurrenceType.daily:
        nextDate = date.add(const Duration(days: 1));
        break;
      case RecurrenceType.weekly:
        nextDate = date.add(const Duration(days: 7));
        break;
      case RecurrenceType.monthly:
        nextDate = DateTime(
          date.year,
          date.month + 1,
          date.day,
          date.hour,
          date.minute,
        );
        break;
      case RecurrenceType.single:
        return null;
    }

    return copyWith(
      id: '${id}_${nextDate.millisecondsSinceEpoch}',
      date: nextDate,
      isCompleted: false,
      completedAt: null,
    );
  }

  // Generate all occurrences for a recurring reminder within a time period
  List<Reminder> generateAllOccurrences({int monthsAhead = 12}) {
    if (recurrence == RecurrenceType.single) return [this];

    final List<Reminder> occurrences = [this];
    final defaultEndDate = DateTime.now().add(Duration(days: monthsAhead * 30));
    
    // Determine the actual end date based on endDate or maxOccurrences
    DateTime actualEndDate = defaultEndDate;
    int? remainingOccurrences = maxOccurrences;
    
    if (endDate != null) {
      actualEndDate = endDate!.isBefore(defaultEndDate) ? endDate! : defaultEndDate;
    }
    
    DateTime currentDate = date;
    int occurrenceCount = 1; // Start with 1 since we already have the first occurrence

    while (currentDate.isBefore(actualEndDate)) {
      // Check if we've reached max occurrences
      if (remainingOccurrences != null && occurrenceCount >= remainingOccurrences) {
        break;
      }

      late DateTime nextDate;
      switch (recurrence) {
        case RecurrenceType.daily:
          nextDate = currentDate.add(const Duration(days: 1));
          break;
        case RecurrenceType.weekly:
          nextDate = currentDate.add(const Duration(days: 7));
          break;
        case RecurrenceType.monthly:
          nextDate = DateTime(
            currentDate.year,
            currentDate.month + 1,
            currentDate.day,
            currentDate.hour,
            currentDate.minute,
          );
          break;
        case RecurrenceType.single:
          return occurrences; // Exit early for single reminders
      }

      if (nextDate.isAfter(actualEndDate)) break;

      final nextReminder = copyWith(
        id: '${id}_${nextDate.millisecondsSinceEpoch}',
        date: nextDate,
        isCompleted: false,
        completedAt: null,
      );

      occurrences.add(nextReminder);
      currentDate = nextDate;
      occurrenceCount++;
    }

    return occurrences;
  }

  // Check if this reminder is part of a recurring series
  bool get isRecurringInstance {
    return id.contains('_') && recurrence != RecurrenceType.single;
  }

  // Get the base ID for recurring reminders
  String get baseId {
    if (isRecurringInstance) {
      return id.split('_').first;
    }
    return id;
  }
}
