class Debt {
  final String id;
  final String name;
  final double totalAmount;
  final double remainingAmount;
  final DateTime startDate;
  final DateTime? dueDate;
  final String frequency; // daily, weekly, biweekly, monthly
  final double? interestRate;
  final double amountPerFrequency;
  final List<DateTime> missedPayments;
  final bool isPaidOff;
  final DateTime createdAt;

  Debt({
    required this.id,
    required this.name,
    required this.totalAmount,
    required this.remainingAmount,
    required this.startDate,
    this.dueDate,
    required this.frequency,
    this.interestRate,
    required this.amountPerFrequency,
    this.missedPayments = const [],
    this.isPaidOff = false,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'totalAmount': totalAmount,
      'remainingAmount': remainingAmount,
      'startDate': startDate.toIso8601String(),
      'dueDate': dueDate?.toIso8601String(),
      'frequency': frequency,
      'interestRate': interestRate,
      'amountPerFrequency': amountPerFrequency,
      'missedPayments': missedPayments.map((d) => d.toIso8601String()).toList(),
      'isPaidOff': isPaidOff,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Debt.fromJson(Map<String, dynamic> json) {
    return Debt(
      id: json['id'],
      name: json['name'],
      totalAmount: (json['totalAmount'] as num).toDouble(),
      remainingAmount: (json['remainingAmount'] as num).toDouble(),
      startDate: DateTime.parse(json['startDate']),
      dueDate: json['dueDate'] != null ? DateTime.parse(json['dueDate']) : null,
      frequency: json['frequency'],
      interestRate: (json['interestRate'] as num?)?.toDouble(),
      amountPerFrequency: (json['amountPerFrequency'] as num).toDouble(),
      missedPayments: (json['missedPayments'] as List<dynamic>?)
          ?.map((d) => DateTime.parse(d))
          .toList() ?? [],
      isPaidOff: json['isPaidOff'] ?? false,
      createdAt: DateTime.parse(json['createdAt']),
    );
  }

  double get paidAmount {
    return totalAmount - remainingAmount;
  }

  double get progressPercentage {
    if (totalAmount == 0) return 0.0;
    return (paidAmount / totalAmount * 100).clamp(0.0, 100.0);
  }

  int get remainingPayments {
    if (dueDate == null) return -1; // Indefinite
    
    final totalDays = dueDate!.difference(DateTime.now()).inDays;
    if (totalDays <= 0) return 0;
    
    switch (frequency) {
      case 'daily':
        return totalDays;
      case 'weekly':
        return (totalDays / 7).ceil();
      case 'biweekly':
        return (totalDays / 14).ceil();
      case 'monthly':
        return (totalDays / 30).ceil();
      default:
        return 0;
    }
  }

  double get recalculatedAmountPerFrequency {
    final remaining = remainingPayments;
    if (remaining <= 0 || remaining == -1) return amountPerFrequency;
    return remainingAmount / remaining;
  }

  DateTime? get nextPaymentDate {
    final now = DateTime.now();
    switch (frequency) {
      case 'daily':
        return now.add(const Duration(days: 1));
      case 'weekly':
        return now.add(const Duration(days: 7));
      case 'biweekly':
        return now.add(const Duration(days: 14));
      case 'monthly':
        return DateTime(now.year, now.month + 1, now.day);
      default:
        return null;
    }
  }

  bool get isOverdue {
    if (dueDate == null) return false;
    return DateTime.now().isAfter(dueDate!) && !isPaidOff;
  }

  int get daysUntilDue {
    if (dueDate == null) return -1;
    return dueDate!.difference(DateTime.now()).inDays;
  }

  String get statusText {
    if (isPaidOff) return 'Paid Off';
    if (isOverdue) return 'Overdue';
    if (dueDate == null) return 'No Due Date';
    
    final days = daysUntilDue;
    if (days < 0) return 'Overdue';
    if (days == 0) return 'Due Today';
    if (days == 1) return 'Due Tomorrow';
    return 'Due in $days days';
  }

  Debt copyWith({
    String? id,
    String? name,
    double? totalAmount,
    double? remainingAmount,
    DateTime? startDate,
    DateTime? dueDate,
    String? frequency,
    double? interestRate,
    double? amountPerFrequency,
    List<DateTime>? missedPayments,
    bool? isPaidOff,
    DateTime? createdAt,
  }) {
    return Debt(
      id: id ?? this.id,
      name: name ?? this.name,
      totalAmount: totalAmount ?? this.totalAmount,
      remainingAmount: remainingAmount ?? this.remainingAmount,
      startDate: startDate ?? this.startDate,
      dueDate: dueDate ?? this.dueDate,
      frequency: frequency ?? this.frequency,
      interestRate: interestRate ?? this.interestRate,
      amountPerFrequency: amountPerFrequency ?? this.amountPerFrequency,
      missedPayments: missedPayments ?? this.missedPayments,
      isPaidOff: isPaidOff ?? this.isPaidOff,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  static Debt calculateDebt({
    required String name,
    required double totalAmount,
    required String frequency,
    DateTime? startDate,
    DateTime? dueDate,
    double? interestRate,
  }) {
    final start = startDate ?? DateTime.now();
    
    double amountPerFrequency;
    if (dueDate != null) {
      final totalDays = dueDate.difference(start).inDays;
      int totalPayments;
      
      switch (frequency) {
        case 'daily':
          totalPayments = totalDays;
          break;
        case 'weekly':
          totalPayments = (totalDays / 7).ceil();
          break;
        case 'biweekly':
          totalPayments = (totalDays / 14).ceil();
          break;
        case 'monthly':
          totalPayments = (totalDays / 30).ceil();
          break;
        default:
          totalPayments = 1;
      }
      
      amountPerFrequency = totalPayments > 0 ? totalAmount / totalPayments : totalAmount;
    } else {
      // No due date, suggest a reasonable payment amount
      amountPerFrequency = totalAmount * 0.1; // 10% of total as default
    }

    return Debt(
      id: 'debt_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      totalAmount: totalAmount,
      remainingAmount: totalAmount,
      startDate: start,
      dueDate: dueDate,
      frequency: frequency,
      interestRate: interestRate,
      amountPerFrequency: amountPerFrequency,
      createdAt: DateTime.now(),
    );
  }
}
