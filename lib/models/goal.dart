class Goal {
  final String id;
  final String name;
  final double targetAmount;
  final double currentAmount;
  final DateTime startDate;
  final DateTime endDate;
  final String frequency; // daily, weekly, biweekly, monthly
  final double amountPerFrequency;
  final int totalDepositsNeeded;
  final List<DateTime> missedDeposits;
  final bool isCompleted;
  final DateTime createdAt;

  Goal({
    required this.id,
    required this.name,
    required this.targetAmount,
    this.currentAmount = 0.0,
    required this.startDate,
    required this.endDate,
    required this.frequency,
    required this.amountPerFrequency,
    required this.totalDepositsNeeded,
    this.missedDeposits = const [],
    this.isCompleted = false,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'targetAmount': targetAmount,
      'currentAmount': currentAmount,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'frequency': frequency,
      'amountPerFrequency': amountPerFrequency,
      'totalDepositsNeeded': totalDepositsNeeded,
      'missedDeposits': missedDeposits.map((d) => d.toIso8601String()).toList(),
      'isCompleted': isCompleted,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Goal.fromJson(Map<String, dynamic> json) {
    return Goal(
      id: json['id'],
      name: json['name'],
      targetAmount: (json['targetAmount'] as num).toDouble(),
      currentAmount: (json['currentAmount'] as num?)?.toDouble() ?? 0.0,
      startDate: DateTime.parse(json['startDate']),
      endDate: DateTime.parse(json['endDate']),
      frequency: json['frequency'],
      amountPerFrequency: (json['amountPerFrequency'] as num).toDouble(),
      totalDepositsNeeded: json['totalDepositsNeeded'],
      missedDeposits: (json['missedDeposits'] as List<dynamic>?)
          ?.map((d) => DateTime.parse(d))
          .toList() ?? [],
      isCompleted: json['isCompleted'] ?? false,
      createdAt: DateTime.parse(json['createdAt']),
    );
  }

  double get progressPercentage {
    if (targetAmount == 0) return 0.0;
    return (currentAmount / targetAmount * 100).clamp(0.0, 100.0);
  }

  double get remainingAmount {
    return (targetAmount - currentAmount).clamp(0.0, double.infinity);
  }

  int get remainingDeposits {
    final totalDays = endDate.difference(DateTime.now()).inDays;
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
    final remaining = remainingDeposits;
    if (remaining <= 0) return 0.0;
    return remainingAmount / remaining;
  }

  DateTime? get nextDepositDate {
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

  Goal copyWith({
    String? id,
    String? name,
    double? targetAmount,
    double? currentAmount,
    DateTime? startDate,
    DateTime? endDate,
    String? frequency,
    double? amountPerFrequency,
    int? totalDepositsNeeded,
    List<DateTime>? missedDeposits,
    bool? isCompleted,
    DateTime? createdAt,
  }) {
    return Goal(
      id: id ?? this.id,
      name: name ?? this.name,
      targetAmount: targetAmount ?? this.targetAmount,
      currentAmount: currentAmount ?? this.currentAmount,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      frequency: frequency ?? this.frequency,
      amountPerFrequency: amountPerFrequency ?? this.amountPerFrequency,
      totalDepositsNeeded: totalDepositsNeeded ?? this.totalDepositsNeeded,
      missedDeposits: missedDeposits ?? this.missedDeposits,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  static Goal calculateGoal({
    required String name,
    required double targetAmount,
    required DateTime endDate,
    required String frequency,
    DateTime? startDate,
  }) {
    final start = startDate ?? DateTime.now();
    final totalDays = endDate.difference(start).inDays;
    
    int totalDeposits;
    switch (frequency) {
      case 'daily':
        totalDeposits = totalDays;
        break;
      case 'weekly':
        totalDeposits = (totalDays / 7).ceil();
        break;
      case 'biweekly':
        totalDeposits = (totalDays / 14).ceil();
        break;
      case 'monthly':
        totalDeposits = (totalDays / 30).ceil();
        break;
      default:
        totalDeposits = 1;
    }

    final amountPerFrequency = totalDeposits > 0 ? targetAmount / totalDeposits : targetAmount;

    return Goal(
      id: 'goal_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      targetAmount: targetAmount,
      startDate: start,
      endDate: endDate,
      frequency: frequency,
      amountPerFrequency: amountPerFrequency,
      totalDepositsNeeded: totalDeposits,
      createdAt: DateTime.now(),
    );
  }
}
