import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/transaction.dart';
import '../models/budget_prescription.dart';
import '../models/notification_type.dart'; // Add this import
import 'firebase_service.dart';
import 'transaction_service.dart';
import 'budget_prescription_service.dart';
import 'transaction_notifier.dart';

class SmartNotificationService {
  static final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  static bool _isInitialized = false;

  // Notification IDs
  static const int _dailyReminderId = 1000;
  static const int _dailyCoachingId = 1001;
  static const int _weeklyInsightId = 2000;
  static const int _weeklyCoachingId = 2001;
  static const int _weeklyAchievementId = 2002;
  static const int _monthlyWarningId = 3000;
  static const int _monthlyAchievementId = 3001;
  static const int _monthlyResetId = 3002;
  static const int _budgetOverspendingId = 4000;
  static const int _instantMilestoneId = 5000;
  static const int _dailyBudgetExceededId = 6000;
  static const int _dailyCategoryExceededId = 6100;
  static const int _monthlyBudgetExceededId = 6200;
  
  // New notification IDs for the requested features
  static const int _budgetingTipId = 7000;
  static const int _goalProgressId = 7001;
  static const int _weeklySummaryId = 7002;
  
  // Transaction notifier for real-time monitoring
  static final TransactionNotifier _transactionNotifier = TransactionNotifier();

  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Initialize timezone data first
      tz.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation('Asia/Manila'));

      // Initialize notifications plugin
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const DarwinInitializationSettings initializationSettingsIOS =
          DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const InitializationSettings initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsIOS,
      );

      await _notifications.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      // Request permissions (only for mobile platforms)
      if (defaultTargetPlatform == TargetPlatform.android || 
          defaultTargetPlatform == TargetPlatform.iOS) {
        await _requestPermissions();
      }

      // Start notification scheduling (only for mobile platforms)
      if (defaultTargetPlatform == TargetPlatform.android || 
          defaultTargetPlatform == TargetPlatform.iOS) {
        await _scheduleAllNotifications();
        _startPeriodicChecks();
      }

      _isInitialized = true;
      debugPrint('📱 SmartNotificationService initialized successfully');
    } catch (e) {
      debugPrint('❌ SmartNotificationService initialization failed: $e');
      // Mark as initialized even if it fails to prevent repeated attempts
      _isInitialized = true;
    }
  }

  static Future<void> _requestPermissions() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          _notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      
      // Request basic notification permission
      await androidImplementation?.requestNotificationsPermission();
      
      // Check if exact alarms are available
      final bool canScheduleExactAlarms = await androidImplementation?.canScheduleExactNotifications() ?? false;
      
      if (!canScheduleExactAlarms) {
        debugPrint('⚠️ Exact alarms not permitted. Notifications will use inexact scheduling.');
        // You could show a dialog here to inform the user about less precise notifications
      } else {
        debugPrint('✅ Exact alarms permitted');
      }
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      final IOSFlutterLocalNotificationsPlugin? iosImplementation =
          _notifications.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      
      await iosImplementation?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
    }
  }

  static void _onNotificationTapped(NotificationResponse notificationResponse) {
    debugPrint('📱 Notification tapped: ${notificationResponse.payload}');
    // Handle notification tap (e.g., navigate to specific pages)
  }

  // ==================== NOTIFICATION SCHEDULING ====================

  static Future<void> _scheduleAllNotifications() async {
    await _cancelAllNotifications();
    
    // Schedule recurring notifications
    await _scheduleDailyNotifications();
    await _scheduleWeeklyNotifications();
    await _scheduleMonthlyNotifications();
    
    debugPrint('🔔 All notifications scheduled');
  }

  // ==================== DAILY NOTIFICATIONS ====================

  static Future<void> _scheduleDailyNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final lastReminderSent = prefs.getString('last_daily_reminder') ?? '';
    final lastCoachingSent = prefs.getString('last_daily_coaching') ?? '';
    final today = DateTime.now().toIso8601String().split('T')[0];

    // Daily Reminder (8:00 PM - 9:00 PM)
    if (lastReminderSent != today) {
      await _scheduleNotification(
        id: _dailyReminderId,
        title: '📝 Daily Expense Reminder',
        body: 'Log today\'s expenses to stay on track.',
        scheduledTime: _getRandomTimeInRange(20, 0, 21, 0), // 8:00 PM - 9:00 PM
        payload: 'daily_reminder',
      );
    }

    // Daily Coaching (12:00 NN or 7:00 PM alternating)
    if (lastCoachingSent != today && await _shouldSendDailyCoaching()) {
      final coachingMessages = [
        '₱100 a day = ₱3,000 saved monthly.',
        'Daily logging keeps your finances sharp.',
        'Small savings today, big dreams tomorrow.',
        'Track expenses, track progress.',
        'Every peso counts towards your goals.',
        'Mindful spending leads to financial freedom.',
        'Your future self will thank you for saving today.',
      ];

      final message = coachingMessages[Random().nextInt(coachingMessages.length)];
      final isEvening = DateTime.now().hour > 12;
      final hour = isEvening ? 19 : 12; // 7 PM or 12 NN

      await _scheduleNotification(
        id: _dailyCoachingId,
        title: '💡 Daily Budgeting Tip',
        body: message,
        scheduledTime: _getTodayAt(hour, 0),
        payload: 'daily_budgeting_tip',
      );
    }
    
    // Schedule daily budgeting tip from user's budget prescription (once per day)
    await _scheduleDailyBudgetingTip();
  }
  
  /// Schedule a personalized budgeting tip based on user's budget prescription
  static Future<void> _scheduleDailyBudgetingTip() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastTipSent = prefs.getString('last_budgeting_tip_sent') ?? '';
      final today = DateTime.now().toIso8601String().split('T')[0];
      
      // Only send one budgeting tip per day
      if (lastTipSent == today) return;
      
      // Get user's budget prescription
      final budgetPrescription = await BudgetPrescriptionService.getBudgetPrescription(DateTime.now());
      if (budgetPrescription == null || budgetPrescription.budgetingTips.isEmpty) return;
      
      // Select a tip based on priority or randomly
      BudgetingTip? selectedTip;
      
      // First, try to find a high-priority tip
      for (final tip in budgetPrescription.budgetingTips) {
        if (tip.priority != null && tip.priority! <= 2) { // Priority 1 or 2 are high priority
          selectedTip = tip;
          break;
        }
      }
      
      // If no high-priority tip found, select a random tip
      selectedTip ??= budgetPrescription.budgetingTips[Random().nextInt(budgetPrescription.budgetingTips.length)];
      
      // Schedule the notification for mid-day (12:00 PM)
      await _scheduleNotification(
        id: _budgetingTipId,
        title: '${selectedTip.icon} ${selectedTip.title}',
        body: selectedTip.message,
        scheduledTime: _getTodayAt(12, 0),
        payload: 'budgeting_tip',
      );
      
      // Mark that we've sent a tip today
      await prefs.setString('last_budgeting_tip_sent', today);
    } catch (e) {
      debugPrint('Error scheduling daily budgeting tip: $e');
    }
  }

  static Future<bool> _shouldSendDailyCoaching() async {
    // Balance rule: Only 1 notification per day (reminder OR coaching)
    final prefs = await SharedPreferences.getInstance();
    final lastReminderSent = prefs.getString('last_daily_reminder') ?? '';
    final today = DateTime.now().toIso8601String().split('T')[0];
    
    // If reminder already sent today, skip coaching
    if (lastReminderSent == today) return false;
    
    // Send coaching every other day to maintain balance
    final lastCoachingDate = prefs.getString('last_daily_coaching_date') ?? '';
    if (lastCoachingDate == today) return false;
    
    final daysSinceLastCoaching = lastCoachingDate.isEmpty ? 2 : 
        DateTime.now().difference(DateTime.parse('${lastCoachingDate}T00:00:00')).inDays;
    
    return daysSinceLastCoaching >= 1;
  }

  // ==================== WEEKLY NOTIFICATIONS ====================

  static Future<void> _scheduleWeeklyNotifications() async {
    // Weekly Insights (Saturday 10:00 AM)
    await _scheduleWeeklyInsights();
    
    // Weekly Coaching (Wednesday 8:00 PM)
    await _scheduleWeeklyBudgetingTips();
    
    // Weekly Achievement (Sunday 7:00 PM)
    await _scheduleWeeklyAchievement();
    
    // Weekly Summary (Sunday 8:00 PM)
    await _scheduleWeeklySummary();
    
    // Goal Progress (Saturday 9:00 AM)
    await _scheduleGoalProgress();
  }
  
  /// Schedule weekly summary notification
  static Future<void> _scheduleWeeklySummary() async {
    final nextSunday = _getNextWeekday(DateTime.sunday);
    final scheduledTime = DateTime(nextSunday.year, nextSunday.month, nextSunday.day, 20, 0); // 8:00 PM

    await _scheduleNotification(
      id: _weeklySummaryId,
      title: '📊 Weekly Summary',
      body: 'Review your weekly spending vs. budget.',
      scheduledTime: scheduledTime,
      payload: 'weekly_summary',
    );
  }
  
  /// Schedule goal progress notification
  static Future<void> _scheduleGoalProgress() async {
    final nextSaturday = _getNextWeekday(DateTime.saturday);
    final scheduledTime = DateTime(nextSaturday.year, nextSaturday.month, nextSaturday.day, 9, 0); // 9:00 AM

    await _scheduleNotification(
      id: _goalProgressId,
      title: '🎯 Goal Progress Update',
      body: 'Check your emergency fund and savings progress.',
      scheduledTime: scheduledTime,
      payload: 'goal_progress',
    );
  }

  static Future<void> _scheduleWeeklyInsights() async {
    final nextSaturday = _getNextWeekday(DateTime.saturday);
    final scheduledTime = DateTime(nextSaturday.year, nextSaturday.month, nextSaturday.day, 10, 0);

    final insight = await _generateWeeklyInsight();
    
    await _scheduleNotification(
      id: _weeklyInsightId,
      title: '📊 Weekly Spending Insight',
      body: insight,
      scheduledTime: scheduledTime,
      payload: 'weekly_insight',
    );
  }

  static Future<void> _scheduleWeeklyBudgetingTips() async {
    final nextWednesday = _getNextWeekday(DateTime.wednesday);
    final scheduledTime = DateTime(nextWednesday.year, nextWednesday.month, nextWednesday.day, 20, 0);

    final budgetingTips = [
      'Tip: Save bonuses before spending.',
      'Review your week\'s expenses for patterns.',
      'Set aside emergency funds regularly.',
      'Compare prices before major purchases.',
      'Automate your savings for consistency.',
      'Plan your weekend spending in advance.',
    ];

    final tip = budgetingTips[Random().nextInt(budgetingTips.length)];

    await _scheduleNotification(
      id: _weeklyCoachingId,
      title: '💡 Midweek Budgeting Tip',
      body: tip,
      scheduledTime: scheduledTime,
      payload: 'weekly_budgeting_tip',
    );
  }

  static Future<void> _scheduleWeeklyAchievement() async {
    final nextSunday = _getNextWeekday(DateTime.sunday);
    final scheduledTime = DateTime(nextSunday.year, nextSunday.month, nextSunday.day, 19, 0);

    final achievement = await _generateWeeklyAchievement();

    await _scheduleNotification(
      id: _weeklyAchievementId,
      title: '🎉 Weekly Achievement',
      body: achievement,
      scheduledTime: scheduledTime,
      payload: 'weekly_achievement',
    );
  }

  // ==================== MONTHLY NOTIFICATIONS ====================

  static Future<void> _scheduleMonthlyNotifications() async {
    // Monthly Reset (First day of month, 9:00 AM)
    await _scheduleMonthlyReset();
    
    // Monthly Achievement (First day of month, varies)
    await _scheduleMonthlyAchievement();
  }

  static Future<void> _scheduleMonthlyReset() async {
    final now = DateTime.now();
    final nextMonth = DateTime(now.year, now.month + 1, 1, 9, 0);

    await _scheduleNotification(
      id: _monthlyResetId,
      title: '🆕 New Month, Fresh Start',
      body: 'New month, fresh start. Set your budget now.',
      scheduledTime: nextMonth,
      payload: 'monthly_reset',
    );
  }

  static Future<void> _scheduleMonthlyAchievement() async {
    final achievement = await _generateMonthlyAchievement();
    final now = DateTime.now();
    final nextMonth = DateTime(now.year, now.month + 1, 1, 9, 30);

    await _scheduleNotification(
      id: _monthlyAchievementId,
      title: '🎯 Monthly Achievement',
      body: achievement,
      scheduledTime: nextMonth,
      payload: 'monthly_achievement',
    );
  }

  // ==================== REAL-TIME MONITORING ====================

  static void _startPeriodicChecks() {
    // Check for budget overspending every 30 minutes
    Timer.periodic(const Duration(minutes: 30), (timer) async {
      await _checkBudgetAlerts();
      await _checkInstantMilestones();
    });

    // Daily timer for resetting daily notifications
    Timer.periodic(const Duration(hours: 1), (timer) async {
      final now = DateTime.now();
      if (now.hour == 0 && now.minute < 5) { // Around midnight
        await _scheduleDailyNotifications();
      }
    });

    // Setup real-time transaction monitoring
    _setupTransactionMonitoring();
  }
  
  /// Setup real-time transaction monitoring for immediate budget alerts
  static void _setupTransactionMonitoring() {
    _transactionNotifier.addListener(_onTransactionChanged);
    debugPrint('🗺 Transaction monitoring enabled for budget alerts');
  }
  
  /// Called when a transaction is added/updated/deleted - check for budget violations
  static void _onTransactionChanged() async {
    debugPrint('🗺 Transaction changed - checking budget violations');
    await _checkDailyBudgetViolations();
    await _checkMonthlyBudgetViolations();
  }

  static Future<void> _checkBudgetAlerts() async {
    try {
      final budget = await FirebaseService.getBudget();
      if (budget == null) return;

      final now = DateTime.now();
      final monthStart = DateTime(now.year, now.month, 1);
      final transactions = await TransactionService.getTransactionsByDateRange(monthStart, now);

      // Calculate spending by category
      final categorySpending = <String, double>{};
      for (final transaction in transactions) {
        if (transaction.type == TransactionType.expense) {
          categorySpending[transaction.category] = 
              (categorySpending[transaction.category] ?? 0) + transaction.amount;
        }
      }

      // Check for overspending alerts
      for (final entry in budget.categoryBudgets.entries) {
        final category = entry.key;
        final budgetAmount = entry.value;
        final spent = categorySpending[category] ?? 0;
        final percentage = (spent / budgetAmount) * 100;

        // 70% threshold alert (monthly)
        if (percentage >= 70 && percentage < 90) {
          await _sendBudgetAlert(category, percentage, spent, budgetAmount, '70% budget warning');
        }
        // 90% threshold alert (critical)
        else if (percentage >= 90 && percentage < 100) {
          await _sendBudgetAlert(category, percentage, spent, budgetAmount, 'Budget almost exceeded');
        }
        // Over budget alert
        else if (percentage >= 100) {
          await _sendBudgetAlert(category, percentage, spent, budgetAmount, 'Budget exceeded');
        }
      }

      // Check total monthly budget
      final totalSpent = categorySpending.values.fold(0.0, (sum, amount) => sum + amount);
      final totalBudget = budget.monthlyBudget;
      final totalPercentage = (totalSpent / totalBudget) * 100;

      if (totalPercentage >= 95) {
        final daysLeft = DateTime(now.year, now.month + 1, 1).difference(now).inDays;
        await _sendCriticalBudgetAlert(totalPercentage, daysLeft);
      }

    } catch (e) {
      debugPrint('Error checking budget alerts: $e');
    }
  }

  static Future<void> _sendBudgetAlert(String category, double percentage, double spent, 
      double budget, String alertType) async {
    final prefs = await SharedPreferences.getInstance();
    final alertKey = 'budget_alert_${category}_${percentage.round()}';
    final lastSent = prefs.getString(alertKey);
    final today = DateTime.now().toIso8601String().split('T')[0];

    // Avoid duplicate alerts on the same day
    if (lastSent == today) return;

    String message;
    if (category.toLowerCase().contains('food')) {
      message = '${percentage.round()}% of food budget spent — cook at home?';
    } else if (category.toLowerCase().contains('transport')) {
      message = 'Transport costs up ${percentage.round()}% — want saving tips?';
    } else if (category.toLowerCase().contains('entertainment')) {
      message = 'Entertainment budget almost exceeded.';
    } else {
      message = '${percentage.round()}% of $category budget fully used — ₱${(budget - spent).toStringAsFixed(0)} remaining.';
    }

    await _showNotification(
      id: _budgetOverspendingId + category.hashCode,
      title: '⚠️ Budget Alert',
      body: message,
      payload: 'budget_alert_$category',
    );

    await prefs.setString(alertKey, today);
  }

  static Future<void> _sendCriticalBudgetAlert(double percentage, int daysLeft) async {
    final prefs = await SharedPreferences.getInstance();
    const alertKey = 'critical_budget_alert';
    final lastSent = prefs.getString(alertKey);
    final today = DateTime.now().toIso8601String().split('T')[0];

    if (lastSent == today) return;

    await _showNotification(
      id: _monthlyWarningId,
      title: '🚨 Critical Budget Alert',
      body: '${percentage.round()}% of budget fully used — $daysLeft days left!',
      payload: 'critical_budget',
    );

    await prefs.setString(alertKey, today);
  }
  
  /// Check for daily budget violations triggered by real-time transactions
  static Future<void> _checkDailyBudgetViolations() async {
    try {
      // Get budget prescription for daily allocations
      final budgetPrescription = await BudgetPrescriptionService.getBudgetPrescription(DateTime.now());
      if (budgetPrescription?.dailyAllocations.isEmpty != false) return;
      
      // Get today's transactions
      final todayTransactions = await TransactionService.getTodayTransactions();
      
      // Calculate today's spending by category
      final todaySpending = <String, double>{};
      double totalDailySpending = 0.0;
      
      for (final transaction in todayTransactions) {
        if (transaction.type == TransactionType.expense || transaction.type == TransactionType.recurringExpense) {
          todaySpending[transaction.category] = 
              (todaySpending[transaction.category] ?? 0) + transaction.amount;
          
          // Only count daily categories for total daily spending
          if (['Food', 'Transportation'].contains(transaction.category)) {
            totalDailySpending += transaction.amount;
          }
        }
      }
      
      // Check individual daily category budgets
      for (final allocation in budgetPrescription!.dailyAllocations) {
        final spent = todaySpending[allocation.category] ?? 0.0;
        final budget = allocation.dailyAmount;
        
        if (budget > 0 && spent > budget) {
          final excess = spent - budget;
          await _sendDailyBudgetExceededAlert(
            allocation.category, 
            spent, 
            budget, 
            excess
          );
        }
      }
      
      // Check total daily budget
      final totalDailyBudget = budgetPrescription.totalDailyBudget;
      if (totalDailyBudget > 0 && totalDailySpending > totalDailyBudget) {
        final excess = totalDailySpending - totalDailyBudget;
        await _sendTotalDailyBudgetExceededAlert(totalDailySpending, totalDailyBudget, excess);
      }
      
    } catch (e) {
      debugPrint('Error checking daily budget violations: $e');
    }
  }
  
  /// Check for monthly budget violations
  static Future<void> _checkMonthlyBudgetViolations() async {
    try {
      final budget = await FirebaseService.getBudget();
      if (budget == null) return;

      final now = DateTime.now();
      final monthStart = DateTime(now.year, now.month, 1);
      final transactions = await TransactionService.getTransactionsByDateRange(monthStart, now);

      // Calculate spending by category
      final categorySpending = <String, double>{};
      double totalSpent = 0.0;
      
      for (final transaction in transactions) {
        if (transaction.type == TransactionType.expense || transaction.type == TransactionType.recurringExpense) {
          categorySpending[transaction.category] = 
              (categorySpending[transaction.category] ?? 0) + transaction.amount;
          totalSpent += transaction.amount;
        }
      }

      // Check for category budget exceeded (100% threshold)
      for (final entry in budget.categoryBudgets.entries) {
        final category = entry.key;
        final budgetAmount = entry.value;
        final spent = categorySpending[category] ?? 0;
        
        if (budgetAmount > 0 && spent > budgetAmount) {
          final excess = spent - budgetAmount;
          await _sendMonthlyBudgetExceededAlert(category, spent, budgetAmount, excess);
        }
      }
      
      // Check total monthly budget exceeded
      if (budget.monthlyBudget > 0 && totalSpent > budget.monthlyBudget) {
        final excess = totalSpent - budget.monthlyBudget;
        await _sendTotalMonthlyBudgetExceededAlert(totalSpent, budget.monthlyBudget, excess);
      }

    } catch (e) {
      debugPrint('Error checking monthly budget violations: $e');
    }
  }
  
  /// Send daily budget exceeded alert for specific category
  static Future<void> _sendDailyBudgetExceededAlert(String category, double spent, double budget, double excess) async {
    final prefs = await SharedPreferences.getInstance();
    final alertKey = 'daily_budget_exceeded_$category';
    final lastSent = prefs.getString(alertKey);
    final today = DateTime.now().toIso8601String().split('T')[0];

    // Avoid duplicate alerts on the same day for the same category
    if (lastSent == today) return;

    String message = '🚨 $category budget exceeded!';
    String body;
    
    if (category.toLowerCase().contains('food')) {
      body = 'Spent ₱${spent.toStringAsFixed(0)} today (budget: ₱${budget.toStringAsFixed(0)}). Try cooking at home!';
    } else if (category.toLowerCase().contains('transport')) {
      body = 'Spent ₱${spent.toStringAsFixed(0)} on transport today (budget: ₱${budget.toStringAsFixed(0)}). Consider alternative transport.';
    } else {
      body = 'Spent ₱${spent.toStringAsFixed(0)} on $category today. Budget was ₱${budget.toStringAsFixed(0)} (+₱${excess.toStringAsFixed(0)}).';
    }

    await _showNotification(
      id: _dailyCategoryExceededId + category.hashCode,
      title: message,
      body: body,
      payload: 'daily_budget_exceeded',
    );
    
    // Email alert for budget exceeded has been removed - only local notifications are sent

    await prefs.setString(alertKey, today);
  }
  
  /// Send total daily budget exceeded alert
  static Future<void> _sendTotalDailyBudgetExceededAlert(double spent, double budget, double excess) async {
    final prefs = await SharedPreferences.getInstance();
    const alertKey = 'total_daily_budget_exceeded';
    final lastSent = prefs.getString(alertKey);
    final today = DateTime.now().toIso8601String().split('T')[0];

    if (lastSent == today) return;

    await _showNotification(
      id: _dailyBudgetExceededId,
      title: '🚨 Daily Budget Exceeded!',
      body: 'Spent ₱${spent.toStringAsFixed(0)} today on daily expenses. Budget was ₱${budget.toStringAsFixed(0)} (+₱${excess.toStringAsFixed(0)}).',
      payload: 'total_daily_budget_exceeded',
    );
    
    // Email alert for budget exceeded has been removed - only local notifications are sent

    await prefs.setString(alertKey, today);
  }
  
  /// Send monthly budget exceeded alert for specific category
  static Future<void> _sendMonthlyBudgetExceededAlert(String category, double spent, double budget, double excess) async {
    final prefs = await SharedPreferences.getInstance();
    final alertKey = 'monthly_budget_exceeded_$category';
    final lastSent = prefs.getString(alertKey);
    final today = DateTime.now().toIso8601String().split('T')[0];

    // Send alert only once per day to avoid spam
    if (lastSent == today) return;

    String message;
    if (category.toLowerCase().contains('food')) {
      message = 'Monthly food budget exceeded by ₱${excess.toStringAsFixed(0)}. Plan meals carefully!';
    } else if (category.toLowerCase().contains('transport')) {
      message = 'Monthly transport budget exceeded by ₱${excess.toStringAsFixed(0)}. Review transport options.';
    } else {
      message = 'Monthly $category budget exceeded by ₱${excess.toStringAsFixed(0)}.';
    }

    await _showNotification(
      id: _monthlyBudgetExceededId + category.hashCode,
      title: '🚨 Monthly Budget Alert',
      body: message,
      payload: 'monthly_budget_exceeded_$category',
    );
    
    // Email alert for budget exceeded has been removed - only local notifications are sent

    await prefs.setString(alertKey, today);
  }
  
  /// Send total monthly budget exceeded alert
  static Future<void> _sendTotalMonthlyBudgetExceededAlert(double spent, double budget, double excess) async {
    final prefs = await SharedPreferences.getInstance();
    const alertKey = 'total_monthly_budget_exceeded';
    final lastSent = prefs.getString(alertKey);
    final today = DateTime.now().toIso8601String().split('T')[0];

    if (lastSent == today) return;

    await _showNotification(
      id: _monthlyBudgetExceededId,
      title: '🚨 Critical: Monthly Budget Exceeded!',
      body: 'Total monthly spending: ₱${spent.toStringAsFixed(0)}. Budget: ₱${budget.toStringAsFixed(0)} (+₱${excess.toStringAsFixed(0)}).',
      payload: 'total_monthly_budget_exceeded',
    );
    
    // Email alert for budget exceeded has been removed - only local notifications are sent

    await prefs.setString(alertKey, today);
  }
  


  static Future<void> _checkInstantMilestones() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Check tracking streak
      final trackingStreak = await _calculateTrackingStreak();
      if (trackingStreak == 7) {
        const alertKey = 'tracking_milestone_7';
        final lastSent = prefs.getString(alertKey);
        final today = DateTime.now().toIso8601String().split('T')[0];
        
        if (lastSent != today) {
          await _showNotification(
            id: _instantMilestoneId,
            title: '🎉 Achievement Unlocked!',
            body: '7 days straight of tracking — great job!',
            payload: 'tracking_milestone',
          );
          await prefs.setString(alertKey, today);
        }
      }

      // Check savings milestones
      final goals = await FirebaseService.getGoals();
      for (final goal in goals) {
        if (goal.isCompleted) {
          final alertKey = 'goal_completed_${goal.id}';
          final lastSent = prefs.getBool(alertKey) ?? false;
          
          if (!lastSent) {
            await _showNotification(
              id: _instantMilestoneId + goal.id.hashCode,
              title: '🎯 Goal Achieved!',
              body: 'Savings goal achieved — well done!',
              payload: 'goal_completed',
            );
            await prefs.setBool(alertKey, true);
          }
        }
      }

    } catch (e) {
      debugPrint('Error checking instant milestones: $e');
    }
  }

  // ==================== MESSAGE GENERATORS ====================

  static Future<String> _generateWeeklyInsight() async {
    try {
      final now = DateTime.now();
      final weekStart = now.subtract(Duration(days: now.weekday - 1));
      final transactions = await TransactionService.getTransactionsByDateRange(weekStart, now);

      final thisWeekSpending = <String, double>{};
      for (final transaction in transactions) {
        if (transaction.type == TransactionType.expense) {
          thisWeekSpending[transaction.category] = 
              (thisWeekSpending[transaction.category] ?? 0) + transaction.amount;
        }
      }

      // Compare with last week
      final lastWeekStart = weekStart.subtract(const Duration(days: 7));
      final lastWeekEnd = weekStart.subtract(const Duration(days: 1));
      final lastWeekTransactions = await TransactionService.getTransactionsByDateRange(lastWeekStart, lastWeekEnd);

      final lastWeekSpending = <String, double>{};
      for (final transaction in lastWeekTransactions) {
        if (transaction.type == TransactionType.expense) {
          lastWeekSpending[transaction.category] = 
              (lastWeekSpending[transaction.category] ?? 0) + transaction.amount;
        }
      }

      // Find the biggest difference
      String bestCategory = 'dining';
      double biggestSaving = 0;
      for (final category in thisWeekSpending.keys) {
        final thisWeek = thisWeekSpending[category] ?? 0;
        final lastWeek = lastWeekSpending[category] ?? 0;
        final saving = lastWeek - thisWeek;
        if (saving > biggestSaving) {
          biggestSaving = saving;
          bestCategory = category;
        }
      }

      if (biggestSaving > 100) {
        return 'Nice! ₱${biggestSaving.toStringAsFixed(0)} less on $bestCategory this week.';
      } else {
        // Default positive message
        return 'Transport costs up 20% — want saving tips?';
      }
    } catch (e) {
      return 'Nice! ₱500 less on dining this week.';
    }
  }

  static Future<String> _generateWeeklyAchievement() async {
    try {
      final now = DateTime.now();
      final monthStart = DateTime(now.year, now.month, 1);
      final transactions = await TransactionService.getTransactionsByDateRange(monthStart, now);
      
      // Calculate total spending this month
      double totalSpending = 0;
      for (final transaction in transactions) {
        if (transaction.type == TransactionType.expense) {
          totalSpending += transaction.amount;
        }
      }
      
      // Get user's monthly budget
      final budget = await FirebaseService.getBudget();
      if (budget != null && budget.monthlyBudget > 0) {
        final budgetUsed = (totalSpending / budget.monthlyBudget) * 100;
        
        if (budgetUsed <= 80) {
          return 'Great job! You\'re under budget this month.';
        } else if (budgetUsed <= 100) {
          return 'Good work staying within budget this month.';
        } else {
          return 'You\'re working hard to get back on track.';
        }
      }
      
      return 'Keep up the good work on your financial journey!';
    } catch (e) {
      return 'Keep up the good work on your financial journey!';
    }
  }

  static Future<String> _generateMonthlyAchievement() async {
    try {
      final now = DateTime.now();
      final lastMonth = DateTime(now.year, now.month - 1, 1);
      final lastMonthStart = DateTime(lastMonth.year, lastMonth.month, 1);
      final lastMonthEnd = DateTime(lastMonth.year, lastMonth.month + 1, 0);
      final transactions = await TransactionService.getTransactionsByDateRange(lastMonthStart, lastMonthEnd);
      
      // Calculate total spending last month
      double totalSpending = 0;
      for (final transaction in transactions) {
        if (transaction.type == TransactionType.expense) {
          totalSpending += transaction.amount;
        }
      }
      
      // Get user's monthly budget
      final budget = await FirebaseService.getBudget();
      if (budget != null && budget.monthlyBudget > 0) {
        final budgetUsed = (totalSpending / budget.monthlyBudget) * 100;
        
        if (budgetUsed <= 80) {
          return 'Outstanding! You stayed under budget last month.';
        } else if (budgetUsed <= 100) {
          return 'Well done! You stayed within budget last month.';
        } else {
          return 'You made progress last month - keep going!';
        }
      }
      
      return 'New month, fresh start. Set your budget now.';
    } catch (e) {
      return 'New month, fresh start. Set your budget now.';
    }
  }

  // ==================== UTILITY FUNCTIONS ====================

  static DateTime _getNextWeekday(int weekday) {
    final now = DateTime.now();
    final daysUntilNext = (weekday - now.weekday + 7) % 7;
    if (daysUntilNext == 0) return now.add(const Duration(days: 7));
    return now.add(Duration(days: daysUntilNext));
  }

  static DateTime _getTodayAt(int hour, int minute) {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, hour, minute);
  }

  static DateTime _getRandomTimeInRange(int startHour, int startMinute, int endHour, int endMinute) {
    final now = DateTime.now();
    final random = Random();
    final start = DateTime(now.year, now.month, now.day, startHour, startMinute);
    final end = DateTime(now.year, now.month, now.day, endHour, endMinute);
    final difference = end.difference(start).inMinutes;
    final randomMinutes = random.nextInt(difference);
    return start.add(Duration(minutes: randomMinutes));
  }

  static Future<void> _scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
    String? payload,
  }) async {
    try {
      // Convert DateTime to timezone-aware time
      final tz.TZDateTime tzScheduledTime = tz.TZDateTime.from(scheduledTime, tz.local);
      
      const AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
        'pocket_pilot_channel_id',
        'Pocket Pilot Notifications',
        channelDescription: 'Notifications for budget tracking and financial insights',
        importance: Importance.max,
        priority: Priority.high,
        showWhen: true,
      );

      const NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics,
      );

      // Schedule the notification for the specified time
      await _notifications.zonedSchedule(
        id,
        title,
        body,
        tzScheduledTime,
        platformChannelSpecifics,
        payload: payload,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
      
      debugPrint('🔔 Scheduled notification ID $id for ${scheduledTime.toString()}');
    } catch (e) {
      debugPrint('Error scheduling notification: $e');
    }
  }

  static Future<void> _showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    try {
      const AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
        'pocket_pilot_channel_id',
        'Pocket Pilot Notifications',
        channelDescription: 'Notifications for budget tracking and financial insights',
        importance: Importance.max,
        priority: Priority.high,
        showWhen: true,
      );

      const NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics,
      );

      await _notifications.show(
        id,
        title,
        body,
        platformChannelSpecifics,
        payload: payload,
      );
      
      // Store notification for in-app display
      await _storeNotificationForDisplay(id, title, body, payload);
    } catch (e) {
      debugPrint('Error showing notification: $e');
    }
  }
  
  static Future<void> _storeNotificationForDisplay(int id, String title, String body, String? payload) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final notificationsList = prefs.getStringList('stored_notifications') ?? [];
      
      final notificationData = {
        'id': id.toString(),
        'title': title,
        'body': body,
        'payload': payload ?? '',
        'date': DateTime.now().toIso8601String(),
        'type': _getNotificationTypeFromPayload(payload).toString().split('.').last,
      };
      
      // Convert map to JSON-like string
      final notificationString = 
          '${notificationData['id']}|${notificationData['title']}|${notificationData['body']}|${notificationData['payload']}|${notificationData['date']}|${notificationData['type']}';
      
      // Add to list (keep only last 50 notifications)
      notificationsList.insert(0, notificationString);
      if (notificationsList.length > 50) {
        notificationsList.removeRange(50, notificationsList.length);
      }
      
      await prefs.setStringList('stored_notifications', notificationsList);
    } catch (e) {
      debugPrint('Error storing notification: $e');
    }
  }
  
  // Notification type enum for internal use
  // Moved to separate file: lib/models/notification_type.dart
  
  static InternalNotificationType _getNotificationTypeFromPayload(String? payload) {
    if (payload == null) return InternalNotificationType.dailyReminder;
    
    switch (payload) {
      case 'budget_alert':
        return InternalNotificationType.budgetAlert;
      case 'daily_reminder':
        return InternalNotificationType.dailyReminder;
      case 'budgeting_tip':
        return InternalNotificationType.budgetingTip;
      case 'goal_progress':
        return InternalNotificationType.goalAchievement;
      case 'weekly_summary':
        return InternalNotificationType.weeklyInsight;
      default:
        return InternalNotificationType.dailyReminder;
    }
  }
  
  static Future<List<Map<String, dynamic>>> getStoredNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final notificationsList = prefs.getStringList('stored_notifications') ?? [];
      
      final notifications = <Map<String, dynamic>>[];
      for (final notificationString in notificationsList) {
        final parts = notificationString.split('|');
        if (parts.length >= 6) {
          notifications.add({
            'id': parts[0],
            'title': parts[1],
            'body': parts[2],
            'payload': parts[3],
            'date': parts[4],
            'type': parts[5],
          });
        }
      }
      
      return notifications;
    } catch (e) {
      return [];
    }
  }
  
  static Future<void> sendTestNotification() async {
    await _showNotification(
      id: 9999,
      title: '🔔 Test Notification',
      body: 'This is a test notification from Pocket Pilot!',
      payload: 'test',
    );
  }
  
  static Future<bool> canScheduleExactAlarms() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          _notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      return await androidImplementation?.canScheduleExactNotifications() ?? false;
    }
    return true; // iOS doesn't have this limitation
  }
  
  static Future<void> requestExactAlarms() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          _notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await androidImplementation?.requestExactAlarmsPermission();
    }
  }
  
  static Future<void> refreshNotifications() async {
    await _scheduleAllNotifications();
  }
  
  static Future<void> _cancelAllNotifications() async {
    // In a real implementation, this would cancel all scheduled notifications
    // For now, we'll just log that this was called
    debugPrint('Cancelling all scheduled notifications');
  }
  
  static Future<int> _calculateTrackingStreak() async {
    try {
      final now = DateTime.now();
      int streak = 0;
      
      // Check for transactions in the last 30 days
      for (int i = 0; i < 30; i++) {
        final date = now.subtract(Duration(days: i));
        final transactions = await TransactionService.getTransactionsByDate(date);
        
        // If we find transactions, increment streak
        if (transactions.isNotEmpty) {
          streak++;
        } else {
          // Break the streak if no transactions on a day
          break;
        }
      }
      
      return streak;
    } catch (e) {
      return 0;
    }
  }
}