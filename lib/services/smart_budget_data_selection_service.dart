import 'package:flutter/foundation.dart';
import '../models/transaction.dart';
import 'data_cache_service.dart';

/// Service for smart selection of transaction data for budget computation
/// Implements intelligent data selection based on transaction density and carry-forward logic
class SmartBudgetDataSelectionService {
  static final DataCacheService _cacheService = DataCacheService();

  /// Results of data selection analysis
  static const int _maxLookbackMonths = 12; // Look back up to 12 months for data

  /// Find the best month to use for budget computation based on the new rules
  /// Updated Monthly Data Rule Implementation:
  /// ≥ 50% of days (or 15+ transactions) - Month is considered usable, can generate budget
  /// ≥ 70% of days (or 20+ transactions) - Month is considered strong, more reliable but cannot be carried over
  /// ≥ 80% of days (or 25+ transactions) - Month is considered reliable, can be carried over
  /// Below 50% of days (or fewer than 15 transactions) - Data is insufficient, falls back to last reliable month
  static Future<MonthDataSelectionResult> findBestDataMonth(DateTime targetMonth) async {
    debugPrint('SmartBudgetDataSelection: Finding best data month for target: $targetMonth');
    
    // Handle month boundaries properly (e.g., January -> December of previous year)
    final previousMonth = targetMonth.month == 1 
        ? DateTime(targetMonth.year - 1, 12, 1)
        : DateTime(targetMonth.year, targetMonth.month - 1, 1);
    
    debugPrint('SmartBudgetDataSelection: Checking previous month: $previousMonth');
    
    // Rule 1: Check if previous month meets the reliable data criteria (80% or 25+ transactions)
    final previousMonthResult = await _analyzeMonthData(previousMonth);
    final meetsReliableCriteria = _meetsReliableDataCriteria(previousMonthResult);
    
    if (meetsReliableCriteria) {
      debugPrint('SmartBudgetDataSelection: Previous month meets reliable data criteria, using it');
      return MonthDataSelectionResult(
        selectedMonth: previousMonth,
        transactionCount: previousMonthResult.transactionCount,
        daysWithData: previousMonthResult.daysWithData,
        totalDaysInMonth: previousMonthResult.totalDaysInMonth,
        dataCompleteness: previousMonthResult.dataCompleteness,
        categorySpending: previousMonthResult.categorySpending,
        selectionReason: 'Reliable data available: Previous month has ${previousMonthResult.dataCompleteness.toStringAsFixed(1)}% days filled (${previousMonthResult.transactionCount} transactions). Excellent! This month\'s data is reliable and will be used for future budgets if needed.',
        ruleApplied: BudgetDataSelectionRule.carryForward,
      );
    }
    
    // Rule 2: Check if previous month meets the strong data criteria (70% or 20+ transactions)
    final meetsStrongCriteria = _meetsStrongDataCriteria(previousMonthResult);
    
    if (meetsStrongCriteria) {
      debugPrint('SmartBudgetDataSelection: Previous month meets strong data criteria, using it');
      return MonthDataSelectionResult(
        selectedMonth: previousMonth,
        transactionCount: previousMonthResult.transactionCount,
        daysWithData: previousMonthResult.daysWithData,
        totalDaysInMonth: previousMonthResult.totalDaysInMonth,
        dataCompleteness: previousMonthResult.dataCompleteness,
        categorySpending: previousMonthResult.categorySpending,
        selectionReason: 'Strong data available: Previous month has ${previousMonthResult.dataCompleteness.toStringAsFixed(1)}% days filled (${previousMonthResult.transactionCount} transactions). Great job! To make this month reliable and carry-over ready, aim for 80%.',
        ruleApplied: BudgetDataSelectionRule.carryForward,
      );
    }
    
    // Rule 3: Check if previous month meets the usable data criteria (50% or 15+ transactions)
    final meetsUsableCriteria = _meetsUsableDataCriteria(previousMonthResult);
    
    if (meetsUsableCriteria) {
      debugPrint('SmartBudgetDataSelection: Previous month meets usable data criteria, using it');
      return MonthDataSelectionResult(
        selectedMonth: previousMonth,
        transactionCount: previousMonthResult.transactionCount,
        daysWithData: previousMonthResult.daysWithData,
        totalDaysInMonth: previousMonthResult.totalDaysInMonth,
        dataCompleteness: previousMonthResult.dataCompleteness,
        categorySpending: previousMonthResult.categorySpending,
        selectionReason: 'Usable data available: Previous month has ${previousMonthResult.dataCompleteness.toStringAsFixed(1)}% days filled (${previousMonthResult.transactionCount} transactions). The app can generate a budget based on this data.',
        ruleApplied: BudgetDataSelectionRule.carryForward,
      );
    }
    
    debugPrint('SmartBudgetDataSelection: Previous month does not meet usable data criteria, looking for last reliable month');
    
    // Rule 4: Find the last month that met the reliable data criteria
    final lastReliableMonth = await _findLastReliableDataMonth(targetMonth);
    
    if (lastReliableMonth != null) {
      debugPrint('SmartBudgetDataSelection: Found last reliable month: ${lastReliableMonth.selectedMonth}');
      return lastReliableMonth.copyWith(
        selectionReason: 'Carry-over: Last month with reliable data (${lastReliableMonth.dataCompleteness.toStringAsFixed(1)}% days filled, ${lastReliableMonth.transactionCount} transactions)',
        ruleApplied: BudgetDataSelectionRule.mostPopulated,
      );
    }
    
    // Fallback: Use previous month even if it has minimal data
    debugPrint('SmartBudgetDataSelection: No suitable data found, falling back to previous month');
    return MonthDataSelectionResult(
      selectedMonth: previousMonth,
      transactionCount: previousMonthResult.transactionCount,
      daysWithData: previousMonthResult.daysWithData,
      totalDaysInMonth: previousMonthResult.totalDaysInMonth,
      dataCompleteness: previousMonthResult.dataCompleteness,
      categorySpending: previousMonthResult.categorySpending,
      selectionReason: 'Fallback: No sufficient historical data found. Tip: Log more transactions to improve budget accuracy.',
      ruleApplied: BudgetDataSelectionRule.fallback,
    );
  }

  /// Check if month data meets the usable criteria (≥ 50% days or 15+ transactions)
  static bool _meetsUsableDataCriteria(MonthAnalysisResult result) {
    return result.dataCompleteness >= 50.0 || result.transactionCount >= 15;
  }

  /// Check if month data meets the strong criteria (≥ 70% days or 20+ transactions)
  static bool _meetsStrongDataCriteria(MonthAnalysisResult result) {
    return result.dataCompleteness >= 70.0 || result.transactionCount >= 20;
  }

  /// Check if month data meets the reliable criteria (≥ 80% days or 25+ transactions)
  static bool _meetsReliableDataCriteria(MonthAnalysisResult result) {
    return result.dataCompleteness >= 80.0 || result.transactionCount >= 25;
  }

  /// Analyze transaction data for a specific month
  static Future<MonthAnalysisResult> _analyzeMonthData(DateTime month) async {
    try {
      final transactions = await _cacheService.getMonthlyTransactions(month);
      final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
      
      // Calculate category spending and count expense transactions
      final categorySpending = <String, double>{};
      final daysWithData = <int>{};
      int expenseCount = 0;
      
      for (final transaction in transactions) {
        if (transaction.type == TransactionType.expense || 
            transaction.type == TransactionType.recurringExpense) {
          categorySpending[transaction.category] = 
            (categorySpending[transaction.category] ?? 0) + transaction.amount;
          daysWithData.add(transaction.date.day);
          expenseCount++;
        }
      }
      
      final dataCompleteness = (daysWithData.length / daysInMonth) * 100;
      
      debugPrint('SmartBudgetDataSelection: Month $month analysis:');
      debugPrint('  - Transactions: $expenseCount');
      debugPrint('  - Days with data: ${daysWithData.length}/$daysInMonth');
      debugPrint('  - Data completeness: ${dataCompleteness.toStringAsFixed(1)}%');
      debugPrint('  - Categories: ${categorySpending.length}');
      
      return MonthAnalysisResult(
        month: month,
        transactionCount: expenseCount,
        daysWithData: daysWithData.length,
        totalDaysInMonth: daysInMonth,
        dataCompleteness: dataCompleteness,
        categorySpending: categorySpending,
        hasSignificantData: _meetsUsableDataCriteria(MonthAnalysisResult(
          month: month,
          transactionCount: expenseCount,
          daysWithData: daysWithData.length,
          totalDaysInMonth: daysInMonth,
          dataCompleteness: dataCompleteness,
          categorySpending: categorySpending,
          hasSignificantData: false, // Not used here
        )),
      );
    } catch (e) {
      debugPrint('SmartBudgetDataSelection: Error analyzing month $month: $e');
      return MonthAnalysisResult(
        month: month,
        transactionCount: 0,
        daysWithData: 0,
        totalDaysInMonth: DateTime(month.year, month.month + 1, 0).day,
        dataCompleteness: 0.0,
        categorySpending: {},
        hasSignificantData: false,
      );
    }
  }

  /// Find the last month that met the reliable data criteria (≥ 80% days or 25+ transactions)
  /// Handles year boundaries properly (e.g., January looking back to December)
  static Future<MonthDataSelectionResult?> _findLastReliableDataMonth(DateTime targetMonth) async {
    // Look back through previous months to find the last one that met reliable criteria
    for (int i = 1; i <= _maxLookbackMonths; i++) {
      // Handle month and year boundaries properly
      DateTime checkMonth;
      if (targetMonth.month - i <= 0) {
        // We need to go back to previous year(s)
        final monthsBack = targetMonth.month - i;
        final yearsBack = (monthsBack.abs() / 12).floor();
        final finalMonth = 12 - (monthsBack.abs() % 12);
        checkMonth = DateTime(targetMonth.year - yearsBack - 1, finalMonth, 1);
      } else {
        checkMonth = DateTime(targetMonth.year, targetMonth.month - i, 1);
      }
      
      // Stop if we go too far back (more than 2 years)
      if (targetMonth.difference(checkMonth).inDays > 730) {
        break;
      }
      
      final monthResult = await _analyzeMonthData(checkMonth);
      final meetsReliableCriteria = _meetsReliableDataCriteria(monthResult);
      
      if (meetsReliableCriteria) {
        debugPrint('SmartBudgetDataSelection: Found last reliable month: $checkMonth (${monthResult.transactionCount} transactions, ${monthResult.dataCompleteness.toStringAsFixed(1)}% completeness)');
        return MonthDataSelectionResult(
          selectedMonth: checkMonth,
          transactionCount: monthResult.transactionCount,
          daysWithData: monthResult.daysWithData,
          totalDaysInMonth: monthResult.totalDaysInMonth,
          dataCompleteness: monthResult.dataCompleteness,
          categorySpending: monthResult.categorySpending,
          selectionReason: '',
          ruleApplied: BudgetDataSelectionRule.mostPopulated,
        );
      }
    }
    
    return null;
  }

  /// Get transaction count statistics for recent months for debugging
  /// Handles year boundaries properly
  static Future<Map<String, int>> getRecentMonthsTransactionCounts(DateTime targetMonth) async {
    final counts = <String, int>{};
    
    for (int i = 1; i <= 6; i++) {
      // Handle month and year boundaries properly
      DateTime checkMonth;
      if (targetMonth.month - i <= 0) {
        // We need to go back to previous year(s)
        final monthsBack = targetMonth.month - i;
        final yearsBack = (monthsBack.abs() / 12).floor();
        final finalMonth = 12 - (monthsBack.abs() % 12);
        checkMonth = DateTime(targetMonth.year - yearsBack - 1, finalMonth, 1);
      } else {
        checkMonth = DateTime(targetMonth.year, targetMonth.month - i, 1);
      }
      
      final monthResult = await _analyzeMonthData(checkMonth);
      counts['${checkMonth.year}-${checkMonth.month.toString().padLeft(2, '0')}'] = monthResult.transactionCount;
    }
    
    return counts;
  }
}

/// Result of month data selection analysis
class MonthDataSelectionResult {
  final DateTime selectedMonth;
  final int transactionCount;
  final int daysWithData;
  final int totalDaysInMonth;
  final double dataCompleteness;
  final Map<String, double> categorySpending;
  final String selectionReason;
  final BudgetDataSelectionRule ruleApplied;

  MonthDataSelectionResult({
    required this.selectedMonth,
    required this.transactionCount,
    required this.daysWithData,
    required this.totalDaysInMonth,
    required this.dataCompleteness,
    required this.categorySpending,
    required this.selectionReason,
    required this.ruleApplied,
  });

  MonthDataSelectionResult copyWith({
    DateTime? selectedMonth,
    int? transactionCount,
    int? daysWithData,
    int? totalDaysInMonth,
    double? dataCompleteness,
    Map<String, double>? categorySpending,
    String? selectionReason,
    BudgetDataSelectionRule? ruleApplied,
  }) {
    return MonthDataSelectionResult(
      selectedMonth: selectedMonth ?? this.selectedMonth,
      transactionCount: transactionCount ?? this.transactionCount,
      daysWithData: daysWithData ?? this.daysWithData,
      totalDaysInMonth: totalDaysInMonth ?? this.totalDaysInMonth,
      dataCompleteness: dataCompleteness ?? this.dataCompleteness,
      categorySpending: categorySpending ?? this.categorySpending,
      selectionReason: selectionReason ?? this.selectionReason,
      ruleApplied: ruleApplied ?? this.ruleApplied,
    );
  }
}

/// Internal result of month analysis
class MonthAnalysisResult {
  final DateTime month;
  final int transactionCount;
  final int daysWithData;
  final int totalDaysInMonth;
  final double dataCompleteness;
  final Map<String, double> categorySpending;
  final bool hasSignificantData;

  MonthAnalysisResult({
    required this.month,
    required this.transactionCount,
    required this.daysWithData,
    required this.totalDaysInMonth,
    required this.dataCompleteness,
    required this.categorySpending,
    required this.hasSignificantData,
  });
}

/// Rules for budget data selection
enum BudgetDataSelectionRule {
  carryForward,     // Use previous month data (carry-forward rule)
  mostPopulated,    // Use month with highest transaction count
  fallback,         // Fallback to previous month when no good data found
}