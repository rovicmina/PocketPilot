import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/transaction.dart';
import '../services/transaction_service.dart';
import '../services/budget_prescription_service.dart';
import '../services/native_widget_bridge.dart';

/// Service for providing data to home screen widgets
class WidgetDataService {
  static const String _todayBudgetKey = 'widget_today_budget';
  static const String _todayExpensesKey = 'widget_today_expenses';
  static const String _lastUpdateKey = 'widget_last_update';
  static const String _selectedWidgetsKey = 'selected_widgets';
  
  /// Update widget data for home screen display
  static Future<void> updateWidgetData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      
      // Get today's budget and expenses
      final todayData = await getTodayBudgetAndExpenses();
      
      // Store data for widget consumption
      await prefs.setDouble(_todayBudgetKey, todayData['budget'] ?? 0.0);
      await prefs.setDouble(_todayExpensesKey, todayData['expenses'] ?? 0.0);
      await prefs.setString(_lastUpdateKey, now.toIso8601String());
      
      // Update native widgets
      await _updateNativeWidgets(todayData);
      
    } catch (e) {
      // print('Error updating widget data: $e');
    }
  }
  
  /// Get today's budget and expenses data
  static Future<Map<String, double>> getTodayBudgetAndExpenses() async {
    try {
      // Get today's budget from prescription
      double todayBudget = 0.0;
      try {
        final prescription = await BudgetPrescriptionService.getBudgetPrescription(DateTime.now());
        if (prescription != null) {
          todayBudget = prescription.totalDailyBudget;
        }
      } catch (e) {
        // If no prescription available, use a default or cached value
        final prefs = await SharedPreferences.getInstance();
        todayBudget = prefs.getDouble('fallback_daily_budget') ?? 500.0;
      }
      
      // Get today's expenses
      final todayTransactions = await TransactionService.getTodayTransactions();
      final todayExpenses = todayTransactions
          .where((t) => t.type == TransactionType.expense || t.type == TransactionType.recurringExpense)
          .fold(0.0, (total, transaction) => total + transaction.amount);
      
      return {
        'budget': todayBudget,
        'expenses': todayExpenses,
      };
    } catch (e) {
      // print('Error getting today data: $e');
      return {
        'budget': 0.0,
        'expenses': 0.0,
      };
    }
  }
  
  /// Get cached widget data for offline display
  static Future<Map<String, dynamic>> getCachedWidgetData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final budget = prefs.getDouble(_todayBudgetKey) ?? 0.0;
      final expenses = prefs.getDouble(_todayExpensesKey) ?? 0.0;
      final lastUpdate = prefs.getString(_lastUpdateKey);
      final selectedWidgets = prefs.getStringList(_selectedWidgetsKey) ?? ['app_logo'];
      
      return {
        'budget': budget,
        'expenses': expenses,
        'remaining': budget - expenses,
        'percentage': budget > 0 ? (expenses / budget * 100) : 0.0,
        'lastUpdate': lastUpdate != null ? DateTime.parse(lastUpdate) : null,
        'selectedWidgets': selectedWidgets,
      };
    } catch (e) {
      // print('Error getting cached widget data: $e');
      return {
        'budget': 0.0,
        'expenses': 0.0,
        'remaining': 0.0,
        'percentage': 0.0,
        'lastUpdate': null,
        'selectedWidgets': ['app_logo'],
      };
    }
  }
  
  /// Update native platform widgets (Android/iOS)
  static Future<void> _updateNativeWidgets(Map<String, double> data) async {
    try {
      final budget = data['budget'] ?? 0.0;
      final expenses = data['expenses'] ?? 0.0;
      final remaining = budget - expenses;
      final percentage = budget > 0 ? (expenses / budget * 100) : 0.0;
      
      // Get selected widgets
      final prefs = await SharedPreferences.getInstance();
      final selectedWidgets = prefs.getStringList(_selectedWidgetsKey) ?? ['app_logo'];
      
      // Update native widgets through method channel
      await NativeWidgetBridge.updateHomeScreenWidget(
        todayBudget: budget,
        todayExpenses: expenses,
        remaining: remaining,
        percentage: percentage,
        showAppLogo: selectedWidgets.contains('app_logo'),
      );
      
      // Store enhanced data for fallback access
      final widgetData = {
        'budget': budget,
        'expenses': expenses,
        'remaining': remaining,
        'percentage': percentage.clamp(0.0, 100.0),
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'isOverBudget': remaining < 0,
        'budgetStatus': _getBudgetStatus(remaining, budget),
        'selectedWidgets': selectedWidgets,
      };
      
      await prefs.setString('native_widget_data', jsonEncode(widgetData));
    } catch (e) {
      // print('Error updating native widgets: $e');
    }
  }
  
  /// Get budget status for widget display
  static String _getBudgetStatus(double remaining, double budget) {
    if (budget <= 0) return 'No budget set';
    if (remaining < 0) return 'Over budget';
    if (remaining == 0) return 'Budget fully used';
    final percentage = (remaining / budget * 100);
    if (percentage > 50) return 'On track';
    if (percentage > 20) return 'Watch spending';
    return 'Almost done';
  }
  
  /// Initialize widget data on app start
  static Future<void> initializeWidgetData() async {
    try {
      // First check if we already have widget data
      final prefs = await SharedPreferences.getInstance();
      final existingData = prefs.getString('native_widget_data');

      if (existingData == null || existingData.isEmpty) {
        // No existing data, set up initial defaults
        await _setInitialWidgetData();
      }
      // Note: Removed immediate updateWidgetData() call to avoid blocking startup
      // Widget data will be updated in background after app starts
    } catch (e) {
      // print('Error initializing widget data: $e');
      // Fallback to initial data setup
      await _setInitialWidgetData();
    }
  }
  
  /// Set up initial widget data for first-time users
  static Future<void> _setInitialWidgetData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Set default selected widgets
      await prefs.setStringList(_selectedWidgetsKey, ['app_logo']);
      
      final initialData = {
        'budget': 500.0,  // Default ₱500 daily budget
        'expenses': 0.0,
        'remaining': 500.0,
        'percentage': 0.0,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'isOverBudget': false,
        'budgetStatus': 'Getting started',
        'selectedWidgets': ['app_logo'],
      };
      
      await prefs.setString('native_widget_data', jsonEncode(initialData));
      // print('Initial widget data set: ₱500 budget, ₱0 expenses');
      
      // Update native widgets with initial data
      await NativeWidgetBridge.updateHomeScreenWidget(
        todayBudget: 500.0,
        todayExpenses: 0.0,
        remaining: 500.0,
        percentage: 0.0,
        showAppLogo: true,
      );
    } catch (e) {
      // print('Error setting initial widget data: $e');
    }
  }
  
  /// Schedule periodic widget updates
  static Future<void> scheduleWidgetUpdates() async {
    // Update widget data every time transactions change
    // This will be called by the transaction service
    await updateWidgetData();
  }
}