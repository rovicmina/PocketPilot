import 'dart:collection';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/transaction.dart';
import 'data_cache_service.dart';

/// Category analysis result with frequency, averages, and recency information
class CategoryAnalysis {
  final String category;
  final double averageAmount;
  final int frequency; // Number of months category appeared
  final DateTime lastSeen; // Last month category appeared
  final List<double> monthlyAmounts; // Amounts per month (for calculating average)
  final bool isActive; // Whether category is active (seen within last 6 months)

  CategoryAnalysis({
    required this.category,
    required this.averageAmount,
    required this.frequency,
    required this.lastSeen,
    required this.monthlyAmounts,
    required this.isActive,
  });
}

/// Internal class for tracking category history
class _CategoryHistory {
  final String category;
  final List<double> monthlyAmounts;
  final int frequency;
  final DateTime lastSeen;

  _CategoryHistory({
    required this.category,
    required this.monthlyAmounts,
    required this.frequency,
    required this.lastSeen,
  });
}

/// Service for analyzing transaction categories and implementing category preservation rules
class CategoryAnalyzer {
  static final DataCacheService _cacheService = DataCacheService();
  static const int _maxLookbackMonths = 12; // Look back up to 12 months for category history
  static const int _inactiveThresholdMonths = 6; // 6-month inactivity threshold

  /// Analyze all categories across multiple months to determine preservation status
  static Future<Map<String, CategoryAnalysis>> analyzeCategories(DateTime baseMonth) async {
    debugPrint('CategoryAnalyzer: Analyzing categories for base month: $baseMonth');
    
    // Get transaction data for the base month
    final baseMonthData = await _cacheService.getMonthlyTransactions(baseMonth);
    final baseMonthCategories = _getCategorySpending(baseMonthData);
    
    // Look back through previous months to build category history
    final categoryHistory = await _buildCategoryHistory(baseMonth);
    
    // Combine base month data with historical data for preservation
    final Map<String, CategoryAnalysis> result = {};
    
    // Process all categories that have appeared in the user's history
    for (final entry in categoryHistory.entries) {
      final category = entry.key;
      final history = entry.value;
      
      // Calculate average amount from historical data
      double averageAmount = 0.0;
      if (history.monthlyAmounts.isNotEmpty) {
        final sum = history.monthlyAmounts.fold(0.0, (a, b) => a + b);
        averageAmount = sum / history.monthlyAmounts.length;
      }
      
      // Determine if category is active (seen within last 6 months)
      final monthsSinceLastSeen = _monthsDifference(baseMonth, history.lastSeen);
      final isActive = monthsSinceLastSeen < _inactiveThresholdMonths;
      
      result[category] = CategoryAnalysis(
        category: category,
        averageAmount: averageAmount,
        frequency: history.frequency,
        lastSeen: history.lastSeen,
        monthlyAmounts: List.unmodifiable(history.monthlyAmounts),
        isActive: isActive,
      );
    }
    
    // Add any categories from base month that weren't in history
    for (final entry in baseMonthCategories.entries) {
      final category = entry.key;
      if (!result.containsKey(category)) {
        result[category] = CategoryAnalysis(
          category: category,
          averageAmount: entry.value,
          frequency: 1,
          lastSeen: baseMonth,
          monthlyAmounts: [entry.value],
          isActive: true, // Active since it's in the base month
        );
      }
    }
    
    debugPrint('CategoryAnalyzer: Analyzed ${result.length} categories');
    return result;
  }

  /// Get preserved categories for budget computation based on the new rules
  static Future<Map<String, double>> getPreservedCategories(
    DateTime baseMonth,
    Map<String, double> baseMonthCategories,
  ) async {
    debugPrint('CategoryAnalyzer: Getting preserved categories for base month: $baseMonth');
    
    // Analyze all categories
    final categoryAnalysis = await analyzeCategories(baseMonth);
    
    final Map<String, double> preservedCategories = {};
    
    // Process each category according to preservation rules
    for (final entry in categoryAnalysis.entries) {
      final category = entry.key;
      final analysis = entry.value;
      
      // Rule: Exclude categories that haven't appeared in the last 6 months
      if (!analysis.isActive) {
        debugPrint('CategoryAnalyzer: Excluding inactive category: $category (last seen ${analysis.lastSeen})');
        continue;
      }
      
      // Rule: If category exists in base month, use that value
      if (baseMonthCategories.containsKey(category)) {
        preservedCategories[category] = baseMonthCategories[category]!;
        debugPrint('CategoryAnalyzer: Using base month value for $category: ${baseMonthCategories[category]}');
        continue;
      }
      
      // Rule: If category existed in previous month but not in base month, include with estimated value
      // Rule: If category didn't appear last month but was frequent in earlier months, include with average
      if (analysis.averageAmount > 0) {
        preservedCategories[category] = analysis.averageAmount;
        debugPrint('CategoryAnalyzer: Using estimated value for $category: ${analysis.averageAmount}');
      }
    }
    
    debugPrint('CategoryAnalyzer: Preserved ${preservedCategories.length} categories');
    return preservedCategories;
  }

  /// Build category history by looking back through previous months and forward to future months
  static Future<Map<String, _CategoryHistory>> _buildCategoryHistory(DateTime baseMonth) async {
    final Map<String, _CategoryHistory> categoryHistory = {};
    
    // Look back through previous months
    for (int i = 1; i <= _maxLookbackMonths; i++) {
      // Handle month and year boundaries properly
      DateTime checkMonth;
      if (baseMonth.month - i <= 0) {
        // We need to go back to previous year(s)
        final monthsBack = baseMonth.month - i;
        final yearsBack = (monthsBack.abs() / 12).floor();
        final finalMonth = 12 - (monthsBack.abs() % 12);
        checkMonth = DateTime(baseMonth.year - yearsBack - 1, finalMonth, 1);
      } else {
        checkMonth = DateTime(baseMonth.year, baseMonth.month - i, 1);
      }
      
      // Stop if we go too far back (more than 2 years)
      if (baseMonth.difference(checkMonth).inDays > 730) {
        break;
      }
      
      // Get transaction data for this month
      final monthData = await _cacheService.getMonthlyTransactions(checkMonth);
      final monthCategories = _getCategorySpending(monthData);
      
      // Update category history
      for (final entry in monthCategories.entries) {
        final category = entry.key;
        final amount = entry.value;
        
        if (categoryHistory.containsKey(category)) {
          // Update existing category history
          final existing = categoryHistory[category]!;
          categoryHistory[category] = _CategoryHistory(
            category: category,
            monthlyAmounts: [...existing.monthlyAmounts, amount],
            frequency: existing.frequency + 1,
            lastSeen: checkMonth.isAfter(existing.lastSeen) ? checkMonth : existing.lastSeen,
          );
        } else {
          // Add new category to history
          categoryHistory[category] = _CategoryHistory(
            category: category,
            monthlyAmounts: [amount],
            frequency: 1,
            lastSeen: checkMonth,
          );
        }
      }
    }
    
    // Also look forward to include more recent months (up to current month)
    final currentMonth = DateTime.now();
    DateTime forwardMonth = DateTime(baseMonth.year, baseMonth.month + 1, 1);
    
    // Continue forward until we reach the current month or exceed the lookback limit
    int forwardCount = 0;
    while (forwardMonth.isBefore(DateTime(currentMonth.year, currentMonth.month + 1, 1)) && 
           forwardCount < _maxLookbackMonths) {
      // Get transaction data for this month
      final monthData = await _cacheService.getMonthlyTransactions(forwardMonth);
      final monthCategories = _getCategorySpending(monthData);
      
      // Update category history
      for (final entry in monthCategories.entries) {
        final category = entry.key;
        final amount = entry.value;
        
        if (categoryHistory.containsKey(category)) {
          // Update existing category history
          final existing = categoryHistory[category]!;
          categoryHistory[category] = _CategoryHistory(
            category: category,
            monthlyAmounts: [...existing.monthlyAmounts, amount],
            frequency: existing.frequency + 1,
            lastSeen: forwardMonth.isAfter(existing.lastSeen) ? forwardMonth : existing.lastSeen,
          );
        } else {
          // Add new category to history
          categoryHistory[category] = _CategoryHistory(
            category: category,
            monthlyAmounts: [amount],
            frequency: 1,
            lastSeen: forwardMonth,
          );
        }
      }
      
      // Move to next month
      if (forwardMonth.month == 12) {
        forwardMonth = DateTime(forwardMonth.year + 1, 1, 1);
      } else {
        forwardMonth = DateTime(forwardMonth.year, forwardMonth.month + 1, 1);
      }
      forwardCount++;
    }
    
    return categoryHistory;
  }

  /// Extract category spending from transaction list
  static Map<String, double> _getCategorySpending(List<Transaction> transactions) {
    final Map<String, double> categorySpending = {};
    
    for (final transaction in transactions) {
      if (transaction.type == TransactionType.expense || 
          transaction.type == TransactionType.recurringExpense) {
        categorySpending[transaction.category] = 
          (categorySpending[transaction.category] ?? 0) + transaction.amount;
      }
    }
    
    return categorySpending;
  }

  /// Calculate months difference between two dates
  static int _monthsDifference(DateTime date1, DateTime date2) {
    // Calculate the actual difference in months between two dates
    final yearsDifference = (date1.year - date2.year);
    final monthsDifference = (date1.month - date2.month);
    return (yearsDifference * 12 + monthsDifference).abs();
  }
}