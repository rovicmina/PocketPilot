import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart'; // Add connectivity import
import '../models/transaction.dart';
import '../models/budget_prescription.dart';
import '../models/user.dart' as user_models;
import '../services/transaction_service.dart';
import '../services/firebase_service.dart';
import '../services/budget_prescription_service.dart';
import '../services/budget_strategy_tips_service.dart';
import '../services/comprehensive_budgeting_tips_service.dart';
import '../services/profile_sync_service.dart';
import '../widgets/tutorial_cleanup.dart';
import '../widgets/tutorial_hotfix.dart'; // Add this import

import '../services/transaction_notifier.dart';
import '../widgets/summary_card.dart';
import '../widgets/timeframe_filter.dart';
import '../widgets/income_expense_bar_chart.dart';
import '../widgets/custom_tutorial.dart';
import '../widgets/page_tutorials.dart';
import 'notifications_reminders_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  static const Duration _cacheExpiration = Duration(minutes: 5); // Cache expires after 5 minutes
  
  double _periodIncome = 0.0;
  double _periodExpenses = 0.0;
  double _periodSavings = 0.0;
  double _periodDebt = 0.0;
  Map<String, double> _categoryTotals = {};

  bool _isLoading = true;
  TimeFrame _selectedTimeFrame = TimeFrame.daily;
  DateTime _selectedDate = DateTime.now();

  // Financial insights data
  double _savingsGoalTarget = 10000; // default target
  List<BudgetingTip> _budgetingTips = []; // budgeting tips

  // User data
  user_models.User? _currentUser;
  BudgetPrescription? _budgetPrescription;
  File? _cachedProfileImage;
  
  // Previous month comparison data
  bool _hasPreviousMonthData = false;

  // Debouncing and caching
  Timer? _debounceTimer;
  final Map<String, dynamic> _dataCache = {};
  
  // Transaction notifier for real-time updates
  final TransactionNotifier _transactionNotifier = TransactionNotifier();

  // Scroll controller for tutorial scrolling
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Show page structure immediately, but indicate that data is loading
    _isLoading = true;
    // Load data with loading indicator on first load
    _loadDashboardData(showLoading: true);
    
    // Listen for transaction changes
    _transactionNotifier.addListener(_onTransactionChanged);
    
    // Removed automatic tutorial start - users can click the help button to start tutorial
  }
  
  /// Wrapper method for backward compatibility
  Future<void> _loadDashboardData({bool showLoading = true}) async {
    await _loadDashboardDataOptimized(showLoading: showLoading, useCache: false);
  }
  
  @override
  void dispose() {
    _transactionNotifier.removeListener(_onTransactionChanged);
    _scrollController.dispose();
    // Ensure tooltip is removed when widget is disposed
    _hideCustomTooltip();
    // Cancel any pending debounce timers
    _debounceTimer?.cancel();
    super.dispose();
  }

  /// Optimized data loading with debouncing and caching
  Future<void> _loadDashboardDataOptimized({bool showLoading = true, bool useCache = true}) async {
    // Generate cache key based on current filters
    final cacheKey = '${_selectedTimeFrame.name}_${DateFormat('yyyy-MM-dd').format(_selectedDate)}';
    
    // Check if we have cached data and can use it
    if (useCache && _dataCache.containsKey(cacheKey) && !showLoading) {
      final cachedData = _dataCache[cacheKey] as Map<String, dynamic>;
      
      // Check if cached data is still valid (not expired)
      final timestamp = cachedData['timestamp'] as DateTime?;
      final isExpired = timestamp != null && 
          DateTime.now().difference(timestamp) > _cacheExpiration;
      
      if (!isExpired) {
        // Only update state if data actually changed to avoid unnecessary rebuilds
        bool dataChanged = false;
        if (mounted) {
          setState(() {
            if (_periodIncome != (cachedData['income'] ?? 0.0)) {
              _periodIncome = cachedData['income'] ?? 0.0;
              dataChanged = true;
            }
            if (_periodExpenses != (cachedData['expenses'] ?? 0.0)) {
              _periodExpenses = cachedData['expenses'] ?? 0.0;
              dataChanged = true;
            }
            if (_periodSavings != (cachedData['savings'] ?? 0.0)) {
              _periodSavings = cachedData['savings'] ?? 0.0;
              dataChanged = true;
            }
            if (_periodDebt != (cachedData['debt'] ?? 0.0)) {
              _periodDebt = cachedData['debt'] ?? 0.0;
              dataChanged = true;
            }
            if (_categoryTotals != (cachedData['categoryTotals'] ?? {})) {
              _categoryTotals = cachedData['categoryTotals'] ?? {};
              dataChanged = true;
            }
            if (_budgetPrescription != cachedData['budgetPrescription']) {
              _budgetPrescription = cachedData['budgetPrescription'];
              dataChanged = true;
            }
            if (_hasPreviousMonthData != (cachedData['hasPreviousMonthData'] ?? false)) {
              _hasPreviousMonthData = cachedData['hasPreviousMonthData'] ?? false;
              dataChanged = true;
            }
            if (_budgetingTips != (cachedData['budgetingTips'] ?? [])) {
              _budgetingTips = cachedData['budgetingTips'] ?? [];
              dataChanged = true;
            }
            // Keep existing user and savings target to prevent flickering
            if (dataChanged) {
              _isLoading = false; // Hide loading indicator when using cached data
            }
          });
        }
      }
      
      // Don't show loading for cached data, but still refresh in background
      // When refreshing in background, we need to update the UI when data is ready
      _refreshDashboardData(showLoading: false, cacheKey: cacheKey).then((_) {
        // After background refresh completes, if we're still mounted, update the UI with fresh data
        if (mounted && _dataCache.containsKey(cacheKey)) {
          final freshData = _dataCache[cacheKey] as Map<String, dynamic>;
          
          // Only update state if data actually changed to avoid unnecessary rebuilds
          bool dataChanged = false;
          setState(() {
            if (_periodIncome != (freshData['income'] ?? 0.0)) {
              _periodIncome = freshData['income'] ?? 0.0;
              dataChanged = true;
            }
            if (_periodExpenses != (freshData['expenses'] ?? 0.0)) {
              _periodExpenses = freshData['expenses'] ?? 0.0;
              dataChanged = true;
            }
            if (_periodSavings != (freshData['savings'] ?? 0.0)) {
              _periodSavings = freshData['savings'] ?? 0.0;
              dataChanged = true;
            }
            if (_periodDebt != (freshData['debt'] ?? 0.0)) {
              _periodDebt = freshData['debt'] ?? 0.0;
              dataChanged = true;
            }
            if (_categoryTotals != (freshData['categoryTotals'] ?? {})) {
              _categoryTotals = freshData['categoryTotals'] ?? {};
              dataChanged = true;
            }
            if (_budgetPrescription != freshData['budgetPrescription']) {
              _budgetPrescription = freshData['budgetPrescription'];
              dataChanged = true;
            }
            if (_hasPreviousMonthData != (freshData['hasPreviousMonthData'] ?? false)) {
              _hasPreviousMonthData = freshData['hasPreviousMonthData'] ?? false;
              dataChanged = true;
            }
            if (_budgetingTips != (freshData['budgetingTips'] ?? [])) {
              _budgetingTips = freshData['budgetingTips'] ?? [];
              dataChanged = true;
            }
            if (dataChanged) {
              _isLoading = false;
            }
          });
        }
      });
      return;
    }
    
    // Show loading indicator if requested
    if (showLoading && mounted) {
      setState(() {
        _isLoading = true;
      });
    }
    
    // Perform full data refresh
    await _refreshDashboardData(showLoading: showLoading, cacheKey: cacheKey);
  }
  
  /// Refresh dashboard data from source
  Future<void> _refreshDashboardData({bool showLoading = true, required String cacheKey}) async {
    try {
      // Check connectivity before making network calls
      final connectivityResult = await (Connectivity().checkConnectivity());
      final isConnected = connectivityResult.first != ConnectivityResult.none;
      
      if (!isConnected) {
        // If offline, use cached data if available
        if (_dataCache.containsKey(cacheKey)) {
          final cachedData = _dataCache[cacheKey] as Map<String, dynamic>;
          if (mounted) {
            setState(() {
              _periodIncome = cachedData['income'] ?? 0.0;
              _periodExpenses = cachedData['expenses'] ?? 0.0;
              _periodSavings = cachedData['savings'] ?? 0.0;
              _periodDebt = cachedData['debt'] ?? 0.0;
              _categoryTotals = cachedData['categoryTotals'] ?? {};
              _budgetPrescription = cachedData['budgetPrescription'];
              _hasPreviousMonthData = cachedData['hasPreviousMonthData'] ?? false;
              _budgetingTips = cachedData['budgetingTips'] ?? [];
              if (showLoading) {
                _isLoading = false;
              }
            });
          }
          // Show offline notification
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.wifi_off, color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Expanded(child: Text('Showing cached data - you are offline')),
                  ],
                ),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 2),
              ),
            );
          }
          return;
        } else {
          // No cached data and offline - show error
          if (mounted) {
            setState(() {
              if (showLoading) {
                _isLoading = false;
              }
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.error, color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Expanded(child: Text('No cached data available - please connect to the internet')),
                  ],
                ),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 3),
              ),
            );
          }
          return;
        }
      }
      
      final startDate = TimeFrameHelper.getStartDate(_selectedTimeFrame, _selectedDate);
      final endDate = TimeFrameHelper.getEndDate(_selectedTimeFrame, _selectedDate);

      // Get user first so we can use it for budgeting tips
      final user = await FirebaseService.getUser();

      // Load all data concurrently with minimal Firebase calls
      List<dynamic> results;
      List<BudgetingTip> loadedBudgetingTips = [];
      try {
        results = await Future.wait([
          TransactionService.getTotalIncomeWithDebt(startDate: startDate, endDate: endDate),
          TransactionService.getTotalByType(TransactionType.expense, startDate: startDate, endDate: endDate),
          TransactionService.getTotalByType(TransactionType.savings, startDate: startDate, endDate: endDate),
          TransactionService.getTotalByType(TransactionType.debt, startDate: startDate, endDate: endDate),
          TransactionService.getExpenseCategoryTotals(startDate: startDate, endDate: endDate),
          BudgetPrescriptionService.getBudgetPrescription(DateTime.now()),
          _checkPreviousMonthData(),
          // Load budgeting tips
          ComprehensiveBudgetingTipsService.getDailyTips(user),
        ]);
        // Extract budgeting tips from results
        loadedBudgetingTips = results[7] as List<BudgetingTip>;
      } catch (e) {
        debugPrint('Error loading some dashboard data, using fallback: $e');
        // Load data without budgeting tips and use fallback tips
        results = await Future.wait([
          TransactionService.getTotalIncomeWithDebt(startDate: startDate, endDate: endDate),
          TransactionService.getTotalByType(TransactionType.expense, startDate: startDate, endDate: endDate),
          TransactionService.getTotalByType(TransactionType.savings, startDate: startDate, endDate: endDate),
          TransactionService.getTotalByType(TransactionType.debt, startDate: startDate, endDate: endDate),
          TransactionService.getExpenseCategoryTotals(startDate: startDate, endDate: endDate),
          BudgetPrescriptionService.getBudgetPrescription(DateTime.now()),
          _checkPreviousMonthData(),
        ]);
        // Use fallback tips
        loadedBudgetingTips = _getFallbackCoachingTips();
      }

      final income = results[0] as double;
      final expenses = results[1] as double;
      final savings = results[2] as double;
      final debt = results[3] as double;
      final categoryTotals = results[4] as Map<String, double>;
      final budgetPrescription = results[5] as BudgetPrescription?;
      final hasPreviousMonthData = results[6] as bool;

      // Cache the loaded data
      _dataCache[cacheKey] = {
        'income': income,
        'expenses': expenses,
        'savings': savings,
        'debt': debt,
        'categoryTotals': categoryTotals,
        'budgetPrescription': budgetPrescription,
        'hasPreviousMonthData': hasPreviousMonthData,
        'budgetingTips': loadedBudgetingTips,
        'timestamp': DateTime.now(),
      };

      // Clean up old cache entries (keep only last 20 entries)
      if (_dataCache.length > 20) {
        final oldestKey = _dataCache.keys.first;
        _dataCache.remove(oldestKey);
      }

      if (mounted) {
        setState(() {
          _periodIncome = income;
          _periodExpenses = expenses;
          _periodSavings = savings; // Use total savings transactions here
          _periodDebt = debt;
          _categoryTotals = categoryTotals;
          // Calculate savings goal based on user's budget strategy
          _savingsGoalTarget = _calculateSavingsTarget(user);
          _currentUser = user;
          _budgetPrescription = budgetPrescription;
          _hasPreviousMonthData = hasPreviousMonthData;
          _budgetingTips = loadedBudgetingTips;
          // Hide loading indicator when data is loaded
          if (showLoading) {
            _isLoading = false;
          }
        });
        
        // Load profile image asynchronously to avoid blocking UI
        if (user != null) {
          ProfileSyncService.getProfilePicture(user).then((profileImage) {
            if (mounted) {
              setState(() {
                _cachedProfileImage = profileImage;
              });
            }
          }).catchError((e) {
            // Error loading profile picture - clear cached image
            debugPrint('Error loading profile picture: $e');
            if (mounted) {
              setState(() {
                _cachedProfileImage = null;
              });
            }
          });
        }
        
        // Preload data for the next likely time period to improve perceived performance
        _preloadAdjacentPeriods(startDate, endDate, user);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          // Hide loading indicator even when there's an error
          if (showLoading) {
            _isLoading = false;
          }
        });
        // Error loading dashboard data
        // Show non-intrusive error handling
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.warning, color: Colors.white, size: 20),
                SizedBox(width: 8),
                const Expanded(child: const Text('Some data may be outdated')),
              ],
            ),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }
  
  /// Preload data for adjacent time periods to improve perceived performance
  Future<void> _preloadAdjacentPeriods(DateTime startDate, DateTime endDate, user_models.User? user) async {
    try {
      // Preload previous period
      final prevStartDate = TimeFrameHelper.getStartDate(_selectedTimeFrame, 
          TimeFrameHelper.getPreviousPeriod(_selectedTimeFrame, _selectedDate));
      final prevEndDate = TimeFrameHelper.getEndDate(_selectedTimeFrame, 
          TimeFrameHelper.getPreviousPeriod(_selectedTimeFrame, _selectedDate));
      
      // Preload next period (if it's not in the future)
      final nextDate = TimeFrameHelper.getNextPeriod(_selectedTimeFrame, _selectedDate);
      if (TimeFrameHelper.canGoToNextPeriod(_selectedTimeFrame, _selectedDate)) {
        final nextStartDate = TimeFrameHelper.getStartDate(_selectedTimeFrame, nextDate);
        final nextEndDate = TimeFrameHelper.getEndDate(_selectedTimeFrame, nextDate);
        
        // Load data for next period in background (don't await)
        _preloadPeriodData(nextStartDate, nextEndDate, user, 'next');
      }
      
      // Load data for previous period in background (don't await)
      _preloadPeriodData(prevStartDate, prevEndDate, user, 'previous');
    } catch (e) {
      // Silently ignore preload errors
      debugPrint('Error preloading adjacent periods: $e');
    }
  }
  
  /// Preload data for a specific time period
  Future<void> _preloadPeriodData(DateTime startDate, DateTime endDate, user_models.User? user, String periodType) async {
    try {
      // Generate cache key for this period
      final cacheKey = '${_selectedTimeFrame.name}_${DateFormat('yyyy-MM-dd').format(startDate)}';
      
      // Check if data is already cached
      if (_dataCache.containsKey(cacheKey)) {
        final cachedData = _dataCache[cacheKey] as Map<String, dynamic>;
        final timestamp = cachedData['timestamp'] as DateTime?;
        final isExpired = timestamp != null && 
            DateTime.now().difference(timestamp) > _cacheExpiration;
        
        // If data is not expired, no need to preload
        if (!isExpired) {
          return;
        }
      }
      
      // Load data for this period
      final results = await Future.wait([
        TransactionService.getTotalIncomeWithDebt(startDate: startDate, endDate: endDate),
        TransactionService.getTotalByType(TransactionType.expense, startDate: startDate, endDate: endDate),
        TransactionService.getTotalByType(TransactionType.savings, startDate: startDate, endDate: endDate),
        TransactionService.getTotalByType(TransactionType.debt, startDate: startDate, endDate: endDate),
        TransactionService.getExpenseCategoryTotals(startDate: startDate, endDate: endDate),
        BudgetPrescriptionService.getBudgetPrescription(DateTime.now()),
        _checkPreviousMonthData(),
        // Load budgeting tips
        ComprehensiveBudgetingTipsService.getDailyTips(user),
      ]);
      
      final income = results[0] as double;
      final expenses = results[1] as double;
      final savings = results[2] as double;
      final debt = results[3] as double;
      final categoryTotals = results[4] as Map<String, double>;
      final budgetPrescription = results[5] as BudgetPrescription?;
      final hasPreviousMonthData = results[6] as bool;
      final budgetingTips = results[7] as List<BudgetingTip>;
      
      // Cache the preloaded data
      _dataCache[cacheKey] = {
        'income': income,
        'expenses': expenses,
        'savings': savings,
        'debt': debt,
        'categoryTotals': categoryTotals,
        'budgetPrescription': budgetPrescription,
        'hasPreviousMonthData': hasPreviousMonthData,
        'budgetingTips': budgetingTips,
        'timestamp': DateTime.now(),
      };
      
      debugPrint('Preloaded $periodType period data for ${DateFormat('yyyy-MM-dd').format(startDate)}');
    } catch (e) {
      // Silently ignore preload errors
      debugPrint('Error preloading $periodType period data: $e');
    }
  }

  /// Called when transaction notifier signals a change
  void _onTransactionChanged() {
    if (mounted) {
      // Transaction change detected, refreshing data seamlessly (no loading indicator)
      _loadDashboardDataOptimized(showLoading: false, useCache: false);
    }
  }

  /// Get daily randomized budgeting tips based on user's framework
  List<BudgetingTip> _getDateFilteredBudgetingTips() {
    try {
      // Return the loaded budgeting tips
      return _budgetingTips;
    } catch (e) {
      // Error generating tips, provide fallback coaching tips
      debugPrint('Error generating comprehensive tips: $e');
      return _getFallbackCoachingTips();
    }
  }
  
  /// Provide fallback coaching tips when tip generation fails
  List<BudgetingTip> _getFallbackCoachingTips() {
    return [
      const BudgetingTip(
        category: 'Getting Started',
        title: 'Welcome to Smart Budgeting',
        message: 'Start by tracking your daily expenses to build awareness of your spending habits.',
        action: 'Record every purchase, no matter how small, to understand where your money goes.',
        icon: '🎯',
      ),
      const BudgetingTip(
        category: 'Savings Strategy',
        title: 'Start Your Emergency Fund',
        message: 'An emergency fund protects you from unexpected expenses and financial stress.',
        action: 'Begin by saving 500 pesos monthly until you have at least 10,000 pesos saved.',
        icon: '🛡️',
      ),
      const BudgetingTip(
        category: 'Smart Shopping',
        title: 'Think Before You Buy',
        message: 'Every purchase is a choice between your current wants and future financial goals.',
        action: 'Ask yourself: Do I need this now, or can I wait and save the money instead?',
        icon: '🤔',
      ),
    ];
  }

  // Remove _fetchSavingsGoalTarget method as it's replaced by shared method

  /// Calculate savings target based on user's budget strategy
  double _calculateSavingsTarget(user_models.User? user) {
    if (user == null || (user.monthlyNet ?? 0.0) <= 0) {
      return 0.0;
    }
    
    final monthlyNet = user.monthlyNet!;
    
    // Determine user's budget strategy
    final strategy = BudgetStrategyTipsService.determineBudgetStrategy(user);
    
    // Get strategy-specific allocations
    final allocations = BudgetStrategyTipsService.getStrategyAllocations(
      strategy, 
      numberOfChildren: user.numberOfChildren,
    );
    
    // Get savings percentage for this strategy
    final savingsPercentage = allocations['Savings'] ?? 20.0; // Default to 20% if not found
    
    // Calculate target as percentage of monthly net income
    return monthlyNet * (savingsPercentage / 100.0);
  }
  
  /// Get savings percentage text based on user's budget strategy
  String _getSavingsPercentageText() {
    if (_currentUser == null) {
      return '20% of net income'; // Default
    }
    
    // Determine user's budget strategy
    final strategy = BudgetStrategyTipsService.determineBudgetStrategy(_currentUser!);
    
    // Get strategy-specific allocations
    final allocations = BudgetStrategyTipsService.getStrategyAllocations(
      strategy, 
      numberOfChildren: _currentUser!.numberOfChildren,
    );
    
    // Get savings percentage for this strategy
    final savingsPercentage = allocations['Savings'] ?? 20.0;
    
    return '${savingsPercentage.toStringAsFixed(0)}% of net income';
  }
  
  /// Get user-friendly explanation for their savings target
  String _getSavingsExplanation() {
    if (_currentUser == null) {
      return 'Based on your profile';
    }
    
    final user = _currentUser!;
    final strategy = BudgetStrategyTipsService.determineBudgetStrategy(user);
    final allocations = BudgetStrategyTipsService.getStrategyAllocations(
      strategy, 
      numberOfChildren: user.numberOfChildren,
    );
    final savingsPercentage = allocations['Savings'] ?? 20.0;
    
    // Generate user-friendly explanation based on their profile
    switch (strategy) {
      case BudgetStrategy.debtHeavyRecovery:
        return 'As someone managing debt, ${savingsPercentage.toStringAsFixed(0)}% helps build emergency savings while paying down debt';
      
      case BudgetStrategy.familyCentric:
        if (user.hasKids == true) {
          return 'As a parent, ${savingsPercentage.toStringAsFixed(0)}% ensures your family\'s financial security and future needs';
        } else {
          return 'With family responsibilities, ${savingsPercentage.toStringAsFixed(0)}% provides stability for your household';
        }
      
      case BudgetStrategy.riskControl:
        if (user.isBusinessOwner == true) {
          return 'As a business owner with variable income, ${savingsPercentage.toStringAsFixed(0)}% creates a crucial safety buffer';
        } else {
          return 'With irregular income, ${savingsPercentage.toStringAsFixed(0)}% helps smooth out financial ups and downs';
        }
      
      case BudgetStrategy.conservative:
        if (user.profession?.toString().contains('retired') == true) {
          return 'In retirement, ${savingsPercentage.toStringAsFixed(0)}% preserves your wealth and maintains financial independence';
        } else {
          final age = user.birthYear != null ? DateTime.now().year - user.birthYear! : null;
          if (age != null && age >= 55) {
            return 'Approaching retirement, ${savingsPercentage.toStringAsFixed(0)}% focuses on wealth preservation and security';
          } else {
            return 'With a conservative approach, ${savingsPercentage.toStringAsFixed(0)}% prioritizes financial stability';
          }
        }
      
      case BudgetStrategy.builder:
        final age = user.birthYear != null ? DateTime.now().year - user.birthYear! : null;
        if (age != null && age >= 25 && age <= 40) {
          return 'In your prime building years, ${savingsPercentage.toStringAsFixed(0)}% maximizes your wealth-building potential';
        } else {
          return 'As someone building wealth, ${savingsPercentage.toStringAsFixed(0)}% supports your financial growth goals';
        }
      
      case BudgetStrategy.balanced:
        final age = user.birthYear != null ? DateTime.now().year - user.birthYear! : null;
        if (age != null && age <= 30) {
          return 'Starting your financial journey, ${savingsPercentage.toStringAsFixed(0)}% builds good money habits';
        } else {
          return 'With a balanced lifestyle, ${savingsPercentage.toStringAsFixed(0)}% supports both present and future goals';
        }
    }
  }

  Future<bool> _checkPreviousMonthData() async {
    try {
      // Check for the month before the currently selected period, not just the previous month from now
      final selectedMonth = _selectedTimeFrame == TimeFrame.monthly 
          ? _selectedDate
          : DateTime.now(); // For daily/weekly, use current month as reference
      
      final prevMonth = selectedMonth.month == 1 
          ? DateTime(selectedMonth.year - 1, 12, 1) // Handle January -> December of previous year
          : DateTime(selectedMonth.year, selectedMonth.month - 1, 1);
      final prevMonthEnd = selectedMonth.month == 1
          ? DateTime(selectedMonth.year - 1, 12, 31, 23, 59, 59) // December 31st of previous year
          : DateTime(selectedMonth.year, selectedMonth.month, 0, 23, 59, 59); // Last day of previous month
      
      final prevMonthTransactions = await FirebaseService.getTransactionsByDateRange(prevMonth, prevMonthEnd);
      return prevMonthTransactions.isNotEmpty;
    } catch (e) {
      // Error checking previous month data
      return false;
    }
  }


  String _generateSpecialTip() {
    // Check if we don't have data from last month for comparison - highest priority
    if (!_hasPreviousMonthData) {
      // Determine which month we're checking for comparison
      final selectedMonth = _selectedTimeFrame == TimeFrame.monthly 
          ? _selectedDate
          : DateTime.now(); // For daily/weekly, use current month as reference
      
      final prevMonthDate = selectedMonth.month == 1 
          ? DateTime(selectedMonth.year - 1, 12, 1) // Handle January -> December of previous year
          : DateTime(selectedMonth.year, selectedMonth.month - 1, 1);
      final prevMonthName = DateFormat('MMMM yyyy').format(prevMonthDate);
      return "I don't have data from $prevMonthName to compare";
    }
    
    final monthlyNet = _currentUser?.monthlyNet ?? 0.0;
    
    if (monthlyNet <= 0) {
      return "Set up your monthly net income in your profile to get personalized financial insights.";
    }

    // Calculate percentages
    final expensePercentage = (monthlyNet > 0) ? (_periodExpenses / monthlyNet * 100) : 0.0;
    final savingsPercentage = (monthlyNet > 0) ? (_periodSavings / monthlyNet * 100) : 0.0;
    
    // Calculate wants spending (Food, Entertainment, Others categories)
    final wantsCategories = ['Food', 'Entertainment & Lifestyle', 'Others'];
    final wantsSpending = wantsCategories.fold(0.0, (sum, category) => 
        sum + (_categoryTotals[category] ?? 0.0));
    final wantsPercentage = (monthlyNet > 0) ? (wantsSpending / monthlyNet * 100) : 0.0;
    
    // Calculate needs spending (Housing, Groceries, Transportation, etc.)
    final needsCategories = ['Housing & Utilities', 'Groceries', 'Transportation', 
        'Health & Personal Care', 'Debt/Loans'];
    final needsSpending = needsCategories.fold(0.0, (sum, category) => 
        sum + (_categoryTotals[category] ?? 0.0));
    final needsPercentage = (monthlyNet > 0) ? (needsSpending / monthlyNet * 100) : 0.0;
    
    // Get budget prescription and daily spending analysis
    final dailyBudget = _budgetPrescription?.totalDailyBudget ?? 0.0;
    final today = DateTime.now();

    // For daily timeframe, check if we're looking at today specifically
    final isViewingToday = _selectedTimeFrame == TimeFrame.daily &&
        _selectedDate.year == today.year &&
        _selectedDate.month == today.month &&
        _selectedDate.day == today.day;
    
    // For daily timeframe viewing today, compare today's spending vs daily budget
    // Only consider daily categories (Food and Transportation) for daily budget comparison
    if (isViewingToday && dailyBudget > 0) {
      final dailyCategories = ['Food', 'Transportation'];
      final dailyCategorySpending = dailyCategories.fold(0.0, (sum, category) => 
          sum + (_categoryTotals[category] ?? 0.0));
      
      // Check individual category budgets if budget prescription is available
      if (_budgetPrescription?.dailyAllocations.isNotEmpty == true) {
        final foodSpending = _categoryTotals['Food'] ?? 0.0;
        final transportSpending = _categoryTotals['Transportation'] ?? 0.0;
        
        // Get specific budgets for each category
        final foodAllocation = _budgetPrescription!.dailyAllocations
            .firstWhere((allocation) => allocation.category == 'Food',
                       orElse: () => const DailyAllocation(category: 'Food', dailyAmount: 0, icon: '🍽️', description: ''));
        final transportAllocation = _budgetPrescription!.dailyAllocations
            .firstWhere((allocation) => allocation.category == 'Transportation',
                       orElse: () => const DailyAllocation(category: 'Transportation', dailyAmount: 0, icon: '🚗', description: ''));
        
        final foodBudget = foodAllocation.dailyAmount;
        final transportBudget = transportAllocation.dailyAmount;
        
        final foodExceeded = foodBudget > 0 && foodSpending > foodBudget;
        final transportExceeded = transportBudget > 0 && transportSpending > transportBudget;
        
        if (foodExceeded && transportExceeded) {
          final foodExcess = foodSpending - foodBudget;
          final transportExcess = transportSpending - transportBudget;
          return "Both Food (₱${foodSpending.toStringAsFixed(0)} vs ₱${foodBudget.toStringAsFixed(0)} budget, +₱${foodExcess.toStringAsFixed(0)}) and Transportation (₱${transportSpending.toStringAsFixed(0)} vs ₱${transportBudget.toStringAsFixed(0)} budget, +₱${transportExcess.toStringAsFixed(0)}) exceeded today.";
        } else if (foodExceeded) {
          final foodExcess = foodSpending - foodBudget;
          if (transportBudget > 0 && transportSpending <= transportBudget) {
            final transportRemaining = transportBudget - transportSpending;
            return "Food budget exceeded: ₱${foodSpending.toStringAsFixed(0)} vs ₱${foodBudget.toStringAsFixed(0)} budget (+₱${foodExcess.toStringAsFixed(0)}). Transportation is within budget with ₱${transportRemaining.toStringAsFixed(0)} remaining.";
          } else {
            return "Food budget exceeded: ₱${foodSpending.toStringAsFixed(0)} vs ₱${foodBudget.toStringAsFixed(0)} budget (+₱${foodExcess.toStringAsFixed(0)}).";
          }
        } else if (transportExceeded) {
          final transportExcess = transportSpending - transportBudget;
          if (foodBudget > 0 && foodSpending <= foodBudget) {
            final foodRemaining = foodBudget - foodSpending;
            return "Transportation budget exceeded: ₱${transportSpending.toStringAsFixed(0)} vs ₱${transportBudget.toStringAsFixed(0)} budget (+₱${transportExcess.toStringAsFixed(0)}). Food is within budget with ₱${foodRemaining.toStringAsFixed(0)} remaining.";
          } else {
            return "Transportation budget exceeded: ₱${transportSpending.toStringAsFixed(0)} vs ₱${transportBudget.toStringAsFixed(0)} budget (+₱${transportExcess.toStringAsFixed(0)}).";
          }
        } else if (foodBudget > 0 && transportBudget > 0) {
          // Both within budget, provide specific feedback
          final foodRemaining = foodBudget - foodSpending;
          final transportRemaining = transportBudget - transportSpending;
          final foodPercentage = (foodSpending / foodBudget * 100);
          final transportPercentage = (transportSpending / transportBudget * 100);
          
          if (foodPercentage >= 80 || transportPercentage >= 80) {
            return "Close to limits: Food ₱${foodSpending.toStringAsFixed(0)}/₱${foodBudget.toStringAsFixed(0)} (${foodPercentage.toStringAsFixed(0)}%), Transportation ₱${transportSpending.toStringAsFixed(0)}/₱${transportBudget.toStringAsFixed(0)} (${transportPercentage.toStringAsFixed(0)}%).";
          } else {
            return "Good spending control: Food ₱${foodRemaining.toStringAsFixed(0)} remaining, Transportation ₱${transportRemaining.toStringAsFixed(0)} remaining.";
          }
        }
      }
      
      // Fallback to general daily budget comparison if no specific allocations
      final budgetExceeded = dailyCategorySpending > dailyBudget;
      final spendingRatio = dailyCategorySpending / dailyBudget;
      
      if (budgetExceeded) {
        final excess = dailyCategorySpending - dailyBudget;
        return "You've spent ₱${dailyCategorySpending.toStringAsFixed(0)} today on daily expenses (Food & Transportation), which exceeds your daily budget of ₱${dailyBudget.toStringAsFixed(0)} by ₱${excess.toStringAsFixed(0)}.";
      } else if (spendingRatio >= 0.8) {
        final remaining = dailyBudget - dailyCategorySpending;
        return "You've fully used ${(spendingRatio * 100).toStringAsFixed(0)}% of today's daily budget (Food & Transportation). ₱${remaining.toStringAsFixed(0)} remaining.";
      } else if (spendingRatio <= 0.5) {
        return "Great discipline! You're only at ${(spendingRatio * 100).toStringAsFixed(0)}% of today's daily spending budget.";
      } else {
        return "You're on track: daily spending is within your budget range.";
      }
    }
    
    // For daily timeframe but not today, show different message
    // Only consider daily categories (Food and Transportation) for daily budget comparison
    if (_selectedTimeFrame == TimeFrame.daily && !isViewingToday && dailyBudget > 0) {
      final dailyCategories = ['Food', 'Transportation'];
      final dailyCategorySpending = dailyCategories.fold(0.0, (sum, category) => 
          sum + (_categoryTotals[category] ?? 0.0));
      
      // Check individual category budgets if budget prescription is available
      if (_budgetPrescription?.dailyAllocations.isNotEmpty == true) {
        final foodSpending = _categoryTotals['Food'] ?? 0.0;
        final transportSpending = _categoryTotals['Transportation'] ?? 0.0;
        
        // Get specific budgets for each category
        final foodAllocation = _budgetPrescription!.dailyAllocations
            .firstWhere((allocation) => allocation.category == 'Food',
                       orElse: () => const DailyAllocation(category: 'Food', dailyAmount: 0, icon: '🍽️', description: ''));
        final transportAllocation = _budgetPrescription!.dailyAllocations
            .firstWhere((allocation) => allocation.category == 'Transportation',
                       orElse: () => const DailyAllocation(category: 'Transportation', dailyAmount: 0, icon: '🚗', description: ''));
        
        final foodBudget = foodAllocation.dailyAmount;
        final transportBudget = transportAllocation.dailyAmount;
        
        // Check for specific category overages
        final foodExceeded = foodBudget > 0 && foodSpending > foodBudget;
        final transportExceeded = transportBudget > 0 && transportSpending > transportBudget;
        
        if (foodExceeded && transportExceeded) {
          final foodExcess = foodSpending - foodBudget;
          final transportExcess = transportSpending - transportBudget;
          return "On ${_selectedDate.day}/${_selectedDate.month}, both Food (₱${foodSpending.toStringAsFixed(0)} vs ₱${foodBudget.toStringAsFixed(0)}, +₱${foodExcess.toStringAsFixed(0)}) and Transportation (₱${transportSpending.toStringAsFixed(0)} vs ₱${transportBudget.toStringAsFixed(0)}, +₱${transportExcess.toStringAsFixed(0)}) exceeded budget.";
        } else if (foodExceeded) {
          final foodExcess = foodSpending - foodBudget;
          return "On ${_selectedDate.day}/${_selectedDate.month}, Food exceeded budget: ₱${foodSpending.toStringAsFixed(0)} vs ₱${foodBudget.toStringAsFixed(0)} (+₱${foodExcess.toStringAsFixed(0)}).";
        } else if (transportExceeded) {
          final transportExcess = transportSpending - transportBudget;
          return "On ${_selectedDate.day}/${_selectedDate.month}, Transportation exceeded budget: ₱${transportSpending.toStringAsFixed(0)} vs ₱${transportBudget.toStringAsFixed(0)} (+₱${transportExcess.toStringAsFixed(0)}).";
        } else {
          return "On ${_selectedDate.day}/${_selectedDate.month}, you stayed within daily budget with ₱${dailyCategorySpending.toStringAsFixed(0)} spent on Food & Transportation.";
        }
      }
      
      // Fallback to general comparison
      final budgetExceeded = dailyCategorySpending > dailyBudget;
      if (budgetExceeded) {
        final excess = dailyCategorySpending - dailyBudget;
        return "On ${_selectedDate.day}/${_selectedDate.month}, you spent ₱${dailyCategorySpending.toStringAsFixed(0)} on daily expenses (Food & Transportation), exceeding the daily budget by ₱${excess.toStringAsFixed(0)}.";
      } else {
        return "On ${_selectedDate.day}/${_selectedDate.month}, you stayed within daily budget with ₱${dailyCategorySpending.toStringAsFixed(0)} spent on Food & Transportation.";
      }
    }
    
    // For weekly/monthly, calculate expected spending vs actual for the selected period
    // Only consider daily categories (Food and Transportation) for daily budget comparison
    if (dailyBudget > 0 && _selectedTimeFrame != TimeFrame.daily) {
      final daysInPeriod = _selectedTimeFrame == TimeFrame.weekly ? 7 : 
          DateTime(_selectedDate.year, _selectedDate.month + 1, 0).day; // Actual days in selected month
      final expectedDailySpending = dailyBudget * daysInPeriod;
      
      final dailyCategories = ['Food', 'Transportation'];
      final dailyCategorySpending = dailyCategories.fold(0.0, (sum, category) => 
          sum + (_categoryTotals[category] ?? 0.0));
      
      // Provide category-specific analysis if budget prescription is available
      if (_budgetPrescription?.dailyAllocations.isNotEmpty == true) {
        final foodSpending = _categoryTotals['Food'] ?? 0.0;
        final transportSpending = _categoryTotals['Transportation'] ?? 0.0;
        
        // Get specific budgets for each category
        final foodAllocation = _budgetPrescription!.dailyAllocations
            .firstWhere((allocation) => allocation.category == 'Food',
                       orElse: () => const DailyAllocation(category: 'Food', dailyAmount: 0, icon: '🍽️', description: ''));
        final transportAllocation = _budgetPrescription!.dailyAllocations
            .firstWhere((allocation) => allocation.category == 'Transportation',
                       orElse: () => const DailyAllocation(category: 'Transportation', dailyAmount: 0, icon: '🚗', description: ''));
        
        final foodBudget = foodAllocation.dailyAmount * daysInPeriod;
        final transportBudget = transportAllocation.dailyAmount * daysInPeriod;
        
        final foodExceeded = foodBudget > 0 && foodSpending > foodBudget;
        final transportExceeded = transportBudget > 0 && transportSpending > transportBudget;
        
        if (foodExceeded && transportExceeded) {
          final foodExcess = foodSpending - foodBudget;
          final transportExcess = transportSpending - transportBudget;
          return "Both categories over budget this ${_selectedTimeFrame == TimeFrame.weekly ? 'week' : 'month'}: Food +₱${foodExcess.toStringAsFixed(0)}, Transportation +₱${transportExcess.toStringAsFixed(0)}. Consider scaling back.";
        } else if (foodExceeded) {
          final foodExcess = foodSpending - foodBudget;
          return "Food spending exceeded budget by ₱${foodExcess.toStringAsFixed(0)} this ${_selectedTimeFrame == TimeFrame.weekly ? 'week' : 'month'}. Transportation is within budget.";
        } else if (transportExceeded) {
          final transportExcess = transportSpending - transportBudget;
          return "Transportation spending exceeded budget by ₱${transportExcess.toStringAsFixed(0)} this ${_selectedTimeFrame == TimeFrame.weekly ? 'week' : 'month'}. Food is within budget.";
        } else if (foodBudget > 0 && transportBudget > 0) {
          return "Excellent! Both Food and Transportation are within budget for this ${_selectedTimeFrame == TimeFrame.weekly ? 'week' : 'month'}.";
        }
      }
      
      // Fallback to general comparison
      if (dailyCategorySpending > expectedDailySpending * 1.2) { // 20% over budget
        final excess = dailyCategorySpending - expectedDailySpending;
        return "Your daily expenses (Food & Transportation) are ₱${excess.toStringAsFixed(0)} over budget for this ${_selectedTimeFrame == TimeFrame.weekly ? 'week' : 'month'}. Consider scaling back.";
      } else if (dailyCategorySpending <= expectedDailySpending * 0.8) { // 20% under budget
        return "Excellent! Your daily expenses (Food & Transportation) are well below budget with disciplined spending.";
      } else if (dailyCategorySpending <= expectedDailySpending * 1.1) { // Within 10% tolerance
        return "You're on track: daily expenses are within your prescribed budget range.";
      }
    }
    
    // Check specific category overspending for Food (when viewing today)
    // Only provide food-specific warnings if daily budget comparison hasn't already triggered
    if (isViewingToday && dailyBudget > 0) {
      final dailyCategories = ['Food', 'Transportation'];
      final dailyCategorySpending = dailyCategories.fold(0.0, (sum, category) => 
          sum + (_categoryTotals[category] ?? 0.0));
      
      // Only show food-specific warning if overall daily spending is within budget
      if (dailyCategorySpending <= dailyBudget) {
        final foodSpending = _categoryTotals['Food'] ?? 0.0;
        if (foodSpending > 0) {
          // Rough estimate: 60% of daily budget typically goes to food (Food is usually larger than Transportation)
          final estimatedFoodBudget = dailyBudget * 0.6;
          if (estimatedFoodBudget > 0 && foodSpending > estimatedFoodBudget * 1.5) {
            return "Today's food spending (₱${foodSpending.toStringAsFixed(0)}) is quite high compared to your ₱${estimatedFoodBudget.toStringAsFixed(0)} estimated food budget.";
          }
        }
      }
    }
    
    // Priority order for tips (most important first)
    
    // 1. High savings achievement (≥15%)
    if (savingsPercentage >= 15) {
      return "Great job! You've already set aside ${savingsPercentage.toStringAsFixed(0)}% for savings this month.";
    }
    
    // 2. High wants spending (>30%)
    if (wantsPercentage > 30) {
      return "Your Wants spending is higher than average — try keeping it under 30%.";
    }
    
    // 3. High needs spending (>65%)
    if (needsPercentage > 65) {
      return "Needs are taking ${needsPercentage.toStringAsFixed(0)}% of your income — consider trimming recurring costs.";
    }
    
    // 4. Good savings rate (10-14%)
    if (savingsPercentage >= 10 && savingsPercentage < 15) {
      return "You're saving ${savingsPercentage.toStringAsFixed(0)}% — great progress toward financial goals!";
    }
    
    // 5. Low savings rate (<10%)
    if (savingsPercentage < 10 && savingsPercentage > 0) {
      return "Try to boost your savings rate to at least 10% of your income for better financial health.";
    }
    
    // 6. High overall spending
    if (expensePercentage > 80) {
      return "You're spending ${expensePercentage.toStringAsFixed(0)}% of your income — try to keep it under 80%.";
    }
    
    // 7. Good spending balance
    if (expensePercentage <= 70 && savingsPercentage >= 5) {
      return "Well balanced! You're keeping expenses low and building savings.";
    }
    
    // 8. Default encouragement
    if (_periodIncome > 0) {
      return "Track more transactions to get personalized insights about your spending patterns.";
    }
    
    return "Add some transactions to see personalized financial insights here.";
  }

  Widget _buildSpecialTip() {
    final tip = _generateSpecialTip();
    
    // Determine tip color based on content
    Color tipColor = Colors.blue;
    IconData tipIcon = Icons.lightbulb;
    
    if (tip.contains('Great job') || tip.contains('on track') || tip.contains('Well balanced') || tip.contains('Excellent') || tip.contains('Great discipline')) {
      tipColor = Colors.green;
      tipIcon = Icons.check_circle;
    } else if (tip.contains('higher than average') || tip.contains('quite high') || tip.contains('used') && tip.contains('%')) {
      tipColor = Colors.orange;
      tipIcon = Icons.warning;
    } else if (tip.contains('exceeds') || tip.contains('over your') || tip.contains('consider trimming') || tip.contains('scaling back')) {
      tipColor = Colors.red;
      tipIcon = Icons.error;
    }
    
    return LayoutBuilder(
      builder: (context, constraints) {
        // Determine responsive layout parameters
        final isNarrowScreen = constraints.maxWidth < 600;
        final isVeryNarrowScreen = constraints.maxWidth < 400;
        final isExtremelyNarrowScreen = constraints.maxWidth < 320;
        final isUltraNarrowScreen = constraints.maxWidth < 280; // Added for ultra narrow screens
        
        // Responsive sizing following typography standards
        final iconSize = isUltraNarrowScreen ? 20.0 : isExtremelyNarrowScreen ? 22.0 : isNarrowScreen ? 24.0 : 28.0;
        final textFontSize = isUltraNarrowScreen ? 12.0 : isExtremelyNarrowScreen ? 13.0 : isNarrowScreen ? 14.0 : 16.0; // Subheading range (12–16sp)
        final containerPadding = isUltraNarrowScreen ? 10.0 : isExtremelyNarrowScreen ? 12.0 : isNarrowScreen ? 14.0 : 20.0;
        final iconSpacing = isUltraNarrowScreen ? 6.0 : isExtremelyNarrowScreen ? 8.0 : isNarrowScreen ? 10.0 : 12.0;
        
        return Container(
          width: double.infinity,
          padding: EdgeInsets.all(containerPadding),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [tipColor, tipColor.withValues(alpha: 0.7)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: tipColor.withValues(alpha: 0.3),
                spreadRadius: 2,
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(
                tipIcon,
                color: Colors.white,
                size: iconSize,
              ),
              SizedBox(width: iconSpacing),
              Expanded(
                child: Text(
                  tip,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: textFontSize,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                  maxLines: isVeryNarrowScreen ? 4 : 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInsights() {
    final theme = Theme.of(context);
    final savings = _periodSavings;
    final savingsGoalProgress = _savingsGoalTarget > 0 ? savings / _savingsGoalTarget : 0.0;
    final remainingToGoal = _savingsGoalTarget - savings;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Determine responsive layout parameters
        final isNarrowScreen = constraints.maxWidth < 600;
        final isVeryNarrowScreen = constraints.maxWidth < 400;
        
        // Responsive sizing following typography standards
        final titleFontSize = isNarrowScreen ? 22.0 : 24.0; // Increased from 20/22 to 22/24
        final tipTitleFontSize = isNarrowScreen ? 16.0 : 18.0; // Increased from 14/16 to 16/18
        final tipMessageFontSize = isNarrowScreen ? 14.0 : 16.0; // Increased from 12/14 to 14/16
        final tipActionFontSize = isNarrowScreen ? 13.0 : 15.0; // Increased from 11/13 to 13/15
        final iconSize = isNarrowScreen ? 24.0 : 26.0; // Increased from 22/24 to 24/26
        final tipIconSize = isNarrowScreen ? 20.0 : 22.0; // Increased from 18/20 to 20/22
        final containerPadding = isNarrowScreen ? 18.0 : 20.0; // Increased from 16/20 to 18/20
        final headerIconPadding = isNarrowScreen ? 12.0 : 14.0; // Increased from 10/12 to 12/14
        final tipIconPadding = isNarrowScreen ? 8.0 : 10.0; // Increased from 6/8 to 8/10
        final spacingAfterHeader = isNarrowScreen ? 18.0 : 20.0; // Increased from 16/20 to 18/20
        final tipMarginBottom = isNarrowScreen ? 14.0 : 16.0; // Increased from 12/16 to 14/16
        final tipSpacing = isNarrowScreen ? 14.0 : 16.0; // Increased from 12/16 to 14/16
        
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: theme.brightness == Brightness.dark
                  ? [
                      const Color(0xFF1E1E1E),
                      const Color(0xFF2C2C2C),
                    ]
                  : [
                      Colors.teal.shade50,
                      Colors.blue.shade50,
                    ],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: theme.shadowColor,
                spreadRadius: 2,
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(
              color: theme.colorScheme.primary.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: Padding(
            padding: EdgeInsets.all(containerPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with icon
                Row(
                  key: InteractiveTutorial.budgetingTipsKey,
                  children: [
                    Container(
                      padding: EdgeInsets.all(headerIconPadding),
                      decoration: BoxDecoration(
                        color: Colors.purple.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.psychology,
                        color: Colors.purple,
                        size: iconSize,
                      ),
                    ),
                    SizedBox(width: tipSpacing),
                    Expanded(
                      child: Text(
                        'Budgeting Tips',
                        style: TextStyle(
                          fontSize: titleFontSize,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: spacingAfterHeader),

                // Budgeting Framework Card
                if (_currentUser != null) ...[
                  _buildFrameworkCard(theme, isNarrowScreen, isVeryNarrowScreen),
                  SizedBox(height: tipSpacing),
                ],

                // Date-filtered Budgeting Tips
                if (_getDateFilteredBudgetingTips().isNotEmpty) ...[
                  ..._getDateFilteredBudgetingTips().map((tip) {
                    return Container(
                      margin: EdgeInsets.only(bottom: tipMarginBottom),
                      padding: EdgeInsets.all(tipSpacing),
                      decoration: BoxDecoration(
                        color: theme.cardTheme.color?.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.purple.withValues(alpha: 0.2),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: EdgeInsets.all(tipIconPadding),
                            decoration: BoxDecoration(
                              color: Colors.purple.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _getFixedIconForCategory(tip.category),
                              style: TextStyle(fontSize: tipIconSize),
                            ),
                          ),
                          SizedBox(width: tipSpacing),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  tip.title,
                                  style: TextStyle(
                                    fontSize: tipTitleFontSize,
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                  maxLines: isVeryNarrowScreen ? 3 : 2, // Increased from 2/1 to 3/2
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  tip.message,
                                  style: TextStyle(
                                    fontSize: tipMessageFontSize,
                                    color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                                  ),
                                  maxLines: isVeryNarrowScreen ? 6 : 4, // Increased from 4/3 to 6/4
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (tip.action.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    tip.action,
                                    style: TextStyle(
                                      fontSize: tipActionFontSize,
                                      color: Colors.purple[600],
                                      fontStyle: FontStyle.italic,
                                    ),
                                    maxLines: isVeryNarrowScreen ? 5 : 3, // Increased from 3/2 to 5/3
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ] else ...[
                  Container(
                    padding: EdgeInsets.all(tipSpacing),
                    decoration: BoxDecoration(
                      color: theme.cardTheme.color?.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.purple.withValues(alpha: 0.2),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(tipIconPadding),
                          decoration: BoxDecoration(
                            color: Colors.purple.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.info_outline,
                            color: Colors.purple,
                            size: tipIconSize,
                          ),
                        ),
                        SizedBox(width: tipSpacing),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'No Budgeting Tips Available',
                                style: TextStyle(
                                  fontSize: tipTitleFontSize,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.onSurface,
                                ),
                                maxLines: isVeryNarrowScreen ? 3 : 2, // Increased from 2/1 to 3/2
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                isVeryNarrowScreen 
                                    ? 'Add more data for tips.'
                                    : 'Add more transaction data to get personalized budgeting tips.',
                                style: TextStyle(
                                  fontSize: tipMessageFontSize,
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                ),
                                maxLines: isVeryNarrowScreen ? 3 : 2, // Increased from 2/1 to 3/2
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Savings Goal Progress Insights (keeping this part)
                if (savings > 0 && _savingsGoalTarget > 0) ...[
                  SizedBox(height: tipSpacing),
                  _buildInsightItem(
                    icon: Icons.flag,
                    iconColor: savingsGoalProgress >= 1.0 ? Colors.green : Colors.blue,
                    title: 'Savings Goal Progress',
                    content: savingsGoalProgress >= 1.0
                        ? 'Goal achieved! 🎉'
                        : '${(savingsGoalProgress * 100).toStringAsFixed(1)}% complete',
                    subtitle: savingsGoalProgress >= 1.0
                        ? 'You\'ve exceeded your savings target'
                        : '₱${NumberFormat('#,##0').format(remainingToGoal)} left to reach your goal',
                    isNarrowScreen: isNarrowScreen,
                    isVeryNarrowScreen: isVeryNarrowScreen,
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFrameworkCard(ThemeData theme, bool isNarrowScreen, bool isVeryNarrowScreen) {
    if (_currentUser == null) return const SizedBox.shrink();

    final strategy = BudgetStrategyTipsService.determineBudgetStrategy(_currentUser!);
    final allocations = BudgetStrategyTipsService.getStrategyAllocations(
      strategy, 
      numberOfChildren: _currentUser!.numberOfChildren,
    );
    final description = BudgetStrategyTipsService.getStrategyDescription(strategy);
    
    // Get framework name and explanation
    String frameworkName;
    String frameworkExplanation;
    
    switch (strategy) {
      case BudgetStrategy.debtHeavyRecovery:
        frameworkName = 'Debt Heavy Recovery';
        frameworkExplanation = 'You have multiple debt types requiring aggressive payoff. Focus 70% on needs, 20% on debt payments, and 10% on savings to eliminate debt quickly.';
        break;
      case BudgetStrategy.conservative:
        frameworkName = 'Conservative';
        frameworkExplanation = 'As someone retired or with fixed income, you should focus on stability. Allocate 75% to needs, 10% to wants, and 15% to savings.';
        break;
      case BudgetStrategy.familyCentric:
        frameworkName = 'Family Centric';
        if (_currentUser!.numberOfChildren != null) {
          if (_currentUser!.numberOfChildren! >= 6) {
            frameworkExplanation = 'With 6+ children, your budget focuses on essentials. Allocate 70% to needs, 15% to wants, and 15% to savings.';
          } else if (_currentUser!.numberOfChildren! >= 3) {
            frameworkExplanation = 'With 3-5 children, your budget balances family needs. Allocate 65% to needs, 20% to wants, and 15% to savings.';
          } else {
            frameworkExplanation = 'With 1-2 children, your budget allows for normal wants. Allocate 60% to needs, 25% to wants, and 15% to savings.';
          }
        } else {
          frameworkExplanation = 'As a family-focused budget, you prioritize needs and savings. Allocate 60% to needs, 25% to wants, and 15% to savings.';
        }
        break;
      case BudgetStrategy.riskControl:
        frameworkName = 'Risk Control';
        frameworkExplanation = 'With irregular income, you need a buffer. Allocate 40% to needs, 40% to buffer, and 20% to savings for financial stability.';
        break;
      case BudgetStrategy.builder:
        frameworkName = 'Builder';
        frameworkExplanation = 'In your prime building years, you maximize wealth growth. Allocate 60% to needs, 20% to wants, and 20% to savings.';
        break;
      case BudgetStrategy.balanced:
        frameworkName = 'Balanced';
        frameworkExplanation = 'With a balanced approach, you maintain harmony. Allocate 50% to needs, 30% to wants, and 20% to savings.';
        break;
    }

    // Responsive sizing
    final titleFontSize = isNarrowScreen ? 18.0 : 20.0; // Increased from 16/18 to 18/20
    final frameworkNameFontSize = isNarrowScreen ? 16.0 : 18.0; // Increased from 14/16 to 16/18
    final explanationFontSize = isNarrowScreen ? 14.0 : 16.0; // Increased from 13/14 to 14/16
    final allocationFontSize = isNarrowScreen ? 13.0 : 15.0; // Increased from 11/13 to 13/15
    final iconSize = isNarrowScreen ? 18.0 : 20.0; // Increased from 16/18 to 18/20
    final containerPadding = isNarrowScreen ? 14.0 : 16.0; // Increased from 12/16 to 14/16
    final spacing = isNarrowScreen ? 10.0 : 12.0; // Increased from 8/12 to 10/12

    return Container(
      padding: EdgeInsets.all(containerPadding),
      decoration: BoxDecoration(
        color: theme.cardTheme.color?.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.account_balance,
                  color: theme.colorScheme.primary,
                  size: iconSize,
                ),
              ),
              SizedBox(width: spacing),
              Expanded(
                child: Text(
                  'Your Budgeting Framework',
                  style: TextStyle(
                    fontSize: titleFontSize, // Increase font size slightly for better visibility
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                  maxLines: 2, // Allow 2 lines instead of 1 to prevent cutting
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SizedBox(height: spacing),
          Text(
            frameworkName,
            style: TextStyle(
              fontSize: frameworkNameFontSize,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.primary,
            ),
          ),
          SizedBox(height: spacing / 2),
          Text(
            frameworkExplanation,
            style: TextStyle(
              fontSize: explanationFontSize,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
            ),
            // Allow more lines for better text display on smaller screens
            maxLines: isVeryNarrowScreen ? 8 : 5,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: spacing),
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildAllocationItem(
                  'Needs',
                  '${allocations['Needs']?.toStringAsFixed(0) ?? '0'}%',
                  Colors.blue,
                  theme,
                  allocationFontSize,
                  (_currentUser!.monthlyNet ?? 0) * (allocations['Needs'] ?? 0) / 100,
                  'Essential expenses needed for basic living',
                  strategy == BudgetStrategy.debtHeavyRecovery || 
                  strategy == BudgetStrategy.balanced || 
                  strategy == BudgetStrategy.builder
                    ? ['Housing & Utilities', 'Food', 'Transportation', 'Groceries']
                    : strategy == BudgetStrategy.familyCentric
                      ? ['Housing & Utilities', 'Food', 'Transportation', 'Groceries', 'Education', 'Childcare']
                      : strategy == BudgetStrategy.conservative
                        ? ['Housing & Utilities', 'Food', 'Transportation', 'Groceries', 'Health & Personal Care']
                        : ['Housing & Utilities', 'Food', 'Transportation', 'Groceries'],
                  strategy,
                ),
                // Show appropriate label based on strategy
                _buildAllocationItem(
                  strategy == BudgetStrategy.debtHeavyRecovery 
                    ? 'Debt Payment' 
                    : strategy == BudgetStrategy.riskControl 
                      ? 'Buffer' 
                      : 'Wants',
                  '${allocations['Wants']?.toStringAsFixed(0) ?? '0'}%',
                  strategy == BudgetStrategy.debtHeavyRecovery 
                    ? Colors.red 
                    : strategy == BudgetStrategy.riskControl 
                      ? Colors.orange 
                      : Colors.orange,
                  theme,
                  allocationFontSize,
                  (_currentUser!.monthlyNet ?? 0) * (allocations['Wants'] ?? 0) / 100,
                  strategy == BudgetStrategy.debtHeavyRecovery 
                    ? 'Payments toward debts to eliminate them quickly' 
                    : strategy == BudgetStrategy.riskControl 
                      ? 'Save the budget for emergency situations' 
                      : 'Non-essential expenses for enjoyment and lifestyle',
                  strategy == BudgetStrategy.debtHeavyRecovery 
                    ? ['Debt Payment'] 
                    : strategy == BudgetStrategy.riskControl 
                      ? [] 
                      : ['Entertainment & Lifestyle', 'Others'],
                  strategy,
                ),
                _buildAllocationItem(
                  'Savings',
                  '${allocations['Savings']?.toStringAsFixed(0) ?? '0'}%',
                  Colors.green,
                  theme,
                  allocationFontSize,
                  (_currentUser!.monthlyNet ?? 0) * (allocations['Savings'] ?? 0) / 100,
                  'Money set aside for future financial security and goals',
                  ['Emergency Fund', 'Savings Goal'],
                  strategy,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Custom tooltip widget that displays detailed budget allocation information
  Widget _CustomBudgetTooltip({
    required double amount,
    required String label,
    required String value,
    required Color color,
    required ThemeData theme,
    required double fontSize,
    required String description,
    required List<String> categories,
    required BudgetStrategy strategy,
  }) {
    return Tooltip(
      message: '',
      child: GestureDetector(
        onTapDown: (details) {
          // Use a slight delay to ensure the render box is properly laid out
          Future.delayed(const Duration(milliseconds: 10), () {
            try {
              final overlay = Overlay.of(context);
              final renderBox = context.findRenderObject() as RenderBox;
              final position = renderBox.localToGlobal(Offset.zero);
              final size = renderBox.size;
              
              // Show custom tooltip
              _showCustomTooltip(
                overlay,
                position,
                size,
                amount,
                label,
                description,
                categories,
                strategy,
                theme,
              );
            } catch (e) {
              // Silently handle any positioning errors
              debugPrint('Error showing tooltip: $e');
            }
          });
        },
        onTapUp: (details) {
          // Add a small delay to prevent flickering
          Future.delayed(const Duration(milliseconds: 50), () {
            // Hide custom tooltip
            _hideCustomTooltip();
          });
        },
        onTapCancel: () {
          // Add a small delay to prevent flickering
          Future.delayed(const Duration(milliseconds: 50), () {
            // Hide custom tooltip
            _hideCustomTooltip();
          });
        },
        child: MouseRegion(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: fontSize - 2,
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          onEnter: (event) {
            // Use a slight delay to ensure the render box is properly laid out
            Future.delayed(const Duration(milliseconds: 10), () {
              try {
                final overlay = Overlay.of(context);
                final renderBox = context.findRenderObject() as RenderBox;
                final position = renderBox.localToGlobal(Offset.zero);
                final size = renderBox.size;
                
                // Show custom tooltip
                _showCustomTooltip(
                  overlay,
                  position,
                  size,
                  amount,
                  label,
                  description,
                  categories,
                  strategy,
                  theme,
                );
              } catch (e) {
                // Silently handle any positioning errors
                debugPrint('Error showing tooltip: $e');
              }
            });
          },
          onExit: (event) {
            // Add a small delay to prevent flickering
            Future.delayed(const Duration(milliseconds: 50), () {
              // Hide custom tooltip
              _hideCustomTooltip();
            });
          },
        ),
      ),
    );
  }

  // Overlay entry for custom tooltip
  OverlayEntry? _tooltipEntry;

  void _showCustomTooltip(
    OverlayState overlay,
    Offset position,
    Size size,
    double amount,
    String label,
    String description,
    List<String> categories,
    BudgetStrategy strategy,
    ThemeData theme,
  ) {
    // Check if we already have a tooltip entry to prevent duplicates
    if (_tooltipEntry != null) {
      _hideCustomTooltip();
    }
    
    // Get screen size to determine positioning
    final screenSize = MediaQuery.of(context).size;
    
    // Make tooltip responsive to screen size with better breakpoints
    final tooltipWidth = screenSize.width > 600 
        ? 400.0 
        : screenSize.width > 400 
            ? screenSize.width * 0.9 
            : screenSize.width * 0.95;
    final maxTooltipWidth = screenSize.width - 20;
    final responsiveTooltipWidth = tooltipWidth > maxTooltipWidth ? maxTooltipWidth : tooltipWidth;
    
    // Calculate height based on content - estimate based on number of categories
    // Base height: 180, plus additional space for categories
    final estimatedCategoryHeight = categories.length > 4 ? 80.0 : categories.length > 2 ? 60.0 : 40.0;
    final tooltipHeight = 180.0 + estimatedCategoryHeight;
    
    // Calculate position at the bottom of the screen, centered horizontally
    // Move it higher by increasing the offset from bottom to ensure full visibility
    double horizontalPosition = (screenSize.width - responsiveTooltipWidth) / 2;
    double verticalPosition = screenSize.height - tooltipHeight - 80; // Increased from 60 to 80 for even more space
    
    // Ensure tooltip stays within screen bounds
    if (horizontalPosition < 10) {
      horizontalPosition = 10;
    } else if (horizontalPosition + responsiveTooltipWidth > screenSize.width - 10) {
      horizontalPosition = screenSize.width - responsiveTooltipWidth - 10;
    }
    
    // Ensure vertical position doesn't go above the screen
    if (verticalPosition < 10) {
      verticalPosition = 10;
    } else if (verticalPosition + tooltipHeight > screenSize.height - 10) {
      // If tooltip would extend beyond screen, adjust to fit
      verticalPosition = screenSize.height - tooltipHeight - 10;
    }
    
    // Adjust text sizes based on screen width for better responsiveness
    final titleFontSize = screenSize.width > 600 ? 18.0 : 16.0;
    final amountFontSize = screenSize.width > 600 ? 20.0 : 18.0;
    final descriptionFontSize = screenSize.width > 600 ? 15.0 : 13.0;
    final categoryTitleFontSize = screenSize.width > 600 ? 14.0 : 12.0;
    final categoryFontSize = screenSize.width > 600 ? 13.0 : 11.0;
    final padding = screenSize.width > 600 ? 16.0 : 12.0;
    final innerPadding = screenSize.width > 600 ? 12.0 : 10.0;
    
    _tooltipEntry = OverlayEntry(
      builder: (context) => Positioned(
        left: horizontalPosition,
        top: verticalPosition,
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: responsiveTooltipWidth,
            padding: EdgeInsets.all(padding),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  theme.brightness == Brightness.dark 
                    ? Colors.teal.shade800 
                    : Colors.teal.shade600,
                  theme.brightness == Brightness.dark 
                    ? Colors.teal.shade900 
                    : Colors.teal.shade800,
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.teal.shade800.withValues(alpha: 0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: screenSize.width > 600 ? 10.0 : 8.0, 
                    vertical: screenSize.width > 600 ? 6.0 : 4.0
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: titleFontSize,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                SizedBox(height: screenSize.width > 600 ? 16.0 : 12.0),
                Container(
                  padding: EdgeInsets.all(innerPadding),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: descriptionFontSize,
                          height: 1.5,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Amount: ₱${NumberFormat('#,##0.00').format(amount)}',
                        style: TextStyle(
                          fontSize: amountFontSize,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                if (categories.isNotEmpty) ...[
                  SizedBox(height: screenSize.width > 600 ? 16.0 : 12.0),
                  Text(
                    'Suggested Expense Categories:',
                    style: TextStyle(
                      fontSize: categoryTitleFontSize,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: screenSize.width > 600 ? 8.0 : 6.0),
                  Wrap(
                    spacing: screenSize.width > 600 ? 8.0 : 6.0,
                    runSpacing: screenSize.width > 600 ? 8.0 : 6.0,
                    children: categories.map((category) {
                      return Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: screenSize.width > 600 ? 12.0 : 10.0,
                          vertical: screenSize.width > 600 ? 6.0 : 4.0,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.2),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          category,
                          style: TextStyle(
                            fontSize: categoryFontSize,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ] else ...[
                  SizedBox(height: screenSize.width > 600 ? 16.0 : 12.0),
                  Text(
                    'Suggested Expense Categories:',
                    style: TextStyle(
                      fontSize: categoryTitleFontSize,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: screenSize.width > 600 ? 8.0 : 6.0),
                  Text(
                    'None',
                    style: TextStyle(
                      fontSize: categoryFontSize,
                      fontStyle: FontStyle.italic,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
    
    overlay.insert(_tooltipEntry!);
  }

  void _hideCustomTooltip() {
    // Ensure we properly remove the tooltip entry
    try {
      _tooltipEntry?.remove();
    } catch (e) {
      // Ignore any errors during removal
      debugPrint('Error removing tooltip: $e');
    } finally {
      _tooltipEntry = null;
    }
  }

  Widget _buildAllocationItem(String label, String value, Color color, ThemeData theme, double fontSize, double amount, String description, List<String> categories, BudgetStrategy strategy) {
    return _CustomBudgetTooltip(
      amount: amount,
      label: label,
      value: value,
      color: color,
      theme: theme,
      fontSize: fontSize,
      description: description,
      categories: categories,
      strategy: strategy,
    );
  }

  Widget _buildInsightItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String content,
    required String subtitle,
    bool isNarrowScreen = false,
    bool isVeryNarrowScreen = false,
  }) {
    final theme = Theme.of(context);
    
    // Responsive sizing following typography standards
    final titleFontSize = isNarrowScreen ? 12.0 : 14.0; // Secondary Text range (12–14sp)
    final contentFontSize = isNarrowScreen ? 14.0 : 16.0; // Body Text range (14–16sp)
    final subtitleFontSize = isNarrowScreen ? 10.0 : 12.0; // Captions range (10–12sp)
    final iconSize = isNarrowScreen ? 18.0 : 20.0;
    final iconPadding = isNarrowScreen ? 6.0 : 8.0;
    final containerPadding = isNarrowScreen ? 12.0 : 16.0;
    final spacing = isNarrowScreen ? 12.0 : 16.0;

    return Container(
      padding: EdgeInsets.all(containerPadding),
      decoration: BoxDecoration(
        color: theme.cardTheme.color?.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: iconColor.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(iconPadding),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: iconSize,
            ),
          ),
          SizedBox(width: spacing),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: titleFontSize,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                  ),
                  maxLines: isVeryNarrowScreen ? 2 : 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  content,
                  style: TextStyle(
                    fontSize: contentFontSize,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: subtitleFontSize,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                  maxLines: isVeryNarrowScreen ? 2 : 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSavingsProgress() {
    final double savings = _periodSavings;
    final double target = _savingsGoalTarget;

    final theme = Theme.of(context);

    // Calculate progress, handle division by zero
    final double progress = target > 0 ? (savings / target).clamp(0, 1) : 0.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Determine responsive layout parameters
        final isNarrowScreen = constraints.maxWidth < 600;
        final isVeryNarrowScreen = constraints.maxWidth < 400;
        final isExtremelyNarrowScreen = constraints.maxWidth < 320;
        
        // Responsive sizing following typography standards
        final titleFontSize = isExtremelyNarrowScreen ? 14.0 : isNarrowScreen ? 16.0 : 18.0; // Subheading range (14–20sp)
        final progressTextFontSize = isExtremelyNarrowScreen ? 12.0 : isNarrowScreen ? 14.0 : 16.0; // Body Text range (12–16sp)
        final infoTextFontSize = isExtremelyNarrowScreen ? 10.0 : isNarrowScreen ? 12.0 : 14.0; // Secondary Text range (10–14sp)
        final congratsTextFontSize = isExtremelyNarrowScreen ? 10.0 : isNarrowScreen ? 12.0 : 14.0; // Secondary Text range
        final iconSize = isExtremelyNarrowScreen ? 16.0 : isNarrowScreen ? 18.0 : 20.0;
        final containerPadding = isExtremelyNarrowScreen ? 10.0 : isNarrowScreen ? 12.0 : 16.0;
        final spacingAfterTitle = isExtremelyNarrowScreen ? 8.0 : isNarrowScreen ? 10.0 : 12.0;
        final spacingAfterProgress = isExtremelyNarrowScreen ? 4.0 : isNarrowScreen ? 6.0 : 8.0;
        final spacingAfterText = isExtremelyNarrowScreen ? 4.0 : isNarrowScreen ? 6.0 : 8.0;
        
        return Container(
          padding: EdgeInsets.all(containerPadding),
          margin: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: theme.cardTheme.color,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: theme.shadowColor,
                spreadRadius: 1,
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.savings,
                    color: theme.colorScheme.primary,
                    size: iconSize,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Savings Progress',
                      style: TextStyle(
                        fontSize: titleFontSize,
                        fontWeight: FontWeight.bold
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              SizedBox(height: spacingAfterTitle),
              LinearProgressIndicator(
                value: progress,
                color: theme.colorScheme.primary,
                backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.2),
                minHeight: 12,
              ),
              SizedBox(height: spacingAfterProgress),
              Text(
                target > 0
                    ? isVeryNarrowScreen
                        ? '₱${savings.toStringAsFixed(2)} of ₱${target.toStringAsFixed(2)} target'
                        : '₱${savings.toStringAsFixed(2)} saved of ₱${target.toStringAsFixed(2)} monthly target (${_getSavingsPercentageText()})'
                    : savings > 0
                        ? '₱${savings.toStringAsFixed(2)} saved this period'
                        : 'No savings recorded for this period',
                style: TextStyle(
                  fontSize: progressTextFontSize
                ),
                maxLines: isVeryNarrowScreen ? 2 : 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (target > 0) ...[
                SizedBox(height: spacingAfterText / 2),
                Text(
                  _getSavingsExplanation(),
                  style: TextStyle(
                    fontSize: infoTextFontSize,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    fontStyle: FontStyle.italic,
                  ),
                  maxLines: isVeryNarrowScreen ? 3 : 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              if (target <= 0) ...[
                SizedBox(height: spacingAfterText),
                Text(
                  isVeryNarrowScreen
                      ? 'Set monthly net income in profile for savings goal.'
                      : 'Set up your monthly net income in your profile to enable automatic savings goal tracking (${_getSavingsPercentageText()}).',
                  style: TextStyle(
                    fontSize: infoTextFontSize,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                  maxLines: isVeryNarrowScreen ? 3 : 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ] else if (progress >= 1.0) ...[
                SizedBox(height: spacingAfterText / 2),
                Text(
                  'Congratulations! You\'ve reached your monthly savings goal! 🎉',
                  style: TextStyle(
                    fontSize: congratsTextFontSize,
                    color: Colors.green,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: isVeryNarrowScreen ? 2 : 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ] else if (progress >= 0.8) ...[
                SizedBox(height: spacingAfterText / 2),
                Text(
                  'You\'re almost there! Keep up the great work!',
                  style: TextStyle(
                    fontSize: congratsTextFontSize,
                    color: Colors.orange,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  List<PieChartSectionData> _getPieChartData() {
    final List<Color> colors = [
      Colors.teal,
      Colors.blue,
      Colors.red,
      Colors.orange,
      Colors.purple,
      Colors.green,
      Colors.indigo,
      Colors.amber,
      Colors.pink,
      Colors.cyan,
    ];

    final total = _categoryTotals.values.fold(0.0, (sum, amount) => sum + amount);

    // Sort categories by value in descending order (highest to lowest)
    final sortedEntries = _categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sortedEntries.asMap().entries.map((entry) {
      final index = entry.key; // Use the new sorted index
      final categoryEntry = entry.value;
      final percentage = total > 0 ? (categoryEntry.value / total * 100) : 0;

      return PieChartSectionData(
        color: colors[index % colors.length],
        value: categoryEntry.value,
        title: percentage >= 5 ? '${percentage.toStringAsFixed(1)}%' : '',
        radius: 60, // Increased from 40 to fit larger container
        titleStyle: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }).toList();
  }

  Widget _buildExpenseBreakdownChart() {
    final theme = Theme.of(context);
    
    return LayoutBuilder(
      builder: (context, constraints) {
        // Determine responsive layout parameters with adjusted sizes
        final isNarrowScreen = constraints.maxWidth < 600;
        final isVeryNarrowScreen = constraints.maxWidth < 400;
        final isExtremelyNarrowScreen = constraints.maxWidth < 320;
        
        // Adjusted sizing for better fit and layout stability
        final noDataIconSize = isExtremelyNarrowScreen ? 24.0 : isNarrowScreen ? 28.0 : 32.0;
        final noDataTextFontSize = isExtremelyNarrowScreen ? 8.0 : isNarrowScreen ? 10.0 : 12.0;
        final categoryTextFontSize = isExtremelyNarrowScreen ? 8.0 : isNarrowScreen ? 10.0 : 12.0;
        final amountTextFontSize = isExtremelyNarrowScreen ? 8.0 : isNarrowScreen ? 10.0 : 12.0;
        final containerPadding = isExtremelyNarrowScreen ? 10.0 : isNarrowScreen ? 12.0 : 16.0;
        final cardPadding = isExtremelyNarrowScreen ? 6.0 : isNarrowScreen ? 8.0 : 10.0;
        final chartHeight = isExtremelyNarrowScreen ? 150.0 : isNarrowScreen ? 180.0 : 220.0; // Increased from 150-180
        final legendSpacing = isExtremelyNarrowScreen ? 3.0 : isNarrowScreen ? 4.0 : 5.0;
        
        if (_categoryTotals.isEmpty) {
          return Container(
            width: double.infinity,
            padding: EdgeInsets.all(containerPadding),
            decoration: BoxDecoration(
              color: theme.cardTheme.color,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: theme.shadowColor.withValues(alpha: 0.1),
                  spreadRadius: 0.3,
                  blurRadius: 1,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.bar_chart,
                    size: noDataIconSize,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    isVeryNarrowScreen
                        ? 'No expenses'
                        : 'No expenses recorded',
                    style: TextStyle(
                      fontSize: noDataTextFontSize,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                    textAlign: TextAlign.center,
                    maxLines: isVeryNarrowScreen ? 2 : 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        }

        return Column(
          children: [
            Container(
              width: double.infinity,
              height: chartHeight,
              padding: EdgeInsets.all(cardPadding),
              decoration: BoxDecoration(
                color: theme.cardTheme.color,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: theme.shadowColor.withValues(alpha: 0.1),
                    spreadRadius: 0.3,
                    blurRadius: 1,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: PieChart(
                PieChartData(
                  sections: _getPieChartData(),
                  centerSpaceRadius: isNarrowScreen ? 25 : 30, // Increased from 20-25
                  sectionsSpace: 0.5,
                ),
              ),
            ),
            const SizedBox(height: 10),
            // Category Legend
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(cardPadding),
              decoration: BoxDecoration(
                color: theme.cardTheme.color,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: theme.shadowColor.withValues(alpha: 0.1),
                    spreadRadius: 0.3,
                    blurRadius: 1,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Column(
                children: () {
                  // Sort categories by value in descending order (highest to lowest)
                  final sortedEntries = _categoryTotals.entries.toList()
                    ..sort((a, b) => b.value.compareTo(a.value));
                  
                  final colors = [
                    Colors.teal,
                    Colors.blue,
                    Colors.red,
                    Colors.orange,
                    Colors.purple,
                    Colors.green,
                    Colors.indigo,
                    Colors.amber,
                    Colors.pink,
                    Colors.cyan,
                  ];

                  return sortedEntries.asMap().entries.map((entry) {
                    final index = entry.key; // Use the new sorted index
                    final categoryEntry = entry.value;

                    return Padding(
                      padding: EdgeInsets.symmetric(vertical: legendSpacing),
                      child: Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: colors[index % colors.length],
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              categoryEntry.key,
                              style: TextStyle(
                                fontSize: categoryTextFontSize,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: isVeryNarrowScreen ? 2 : 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            NumberFormat.currency(symbol: '₱').format(categoryEntry.value),
                            style: TextStyle(
                              fontSize: amountTextFontSize,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    );
                  }).toList();
                }(),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return TutorialHotfixWrapper( // Wrap the entire page with the hotfix
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          key: InteractiveTutorial.appBarKey,
          automaticallyImplyLeading: false,
          leading: TutorialHighlight(
            highlightKey: InteractiveTutorial.profileKey,
            additionalHighlightKeys: [InteractiveTutorial.appBarKey],
            child: _buildProfileButton(),
          ),
          title: LayoutBuilder(
            builder: (context, constraints) {
              final isNarrowScreen = MediaQuery.of(context).size.width < 600;
              final titleFontSize = isNarrowScreen ? 20.0 : 22.0;

              return Container(
                key: InteractiveTutorial.dashboardKey,
                child: Text(
                  'Dashboard',
                  style: TextStyle(
                    color: theme.appBarTheme.foregroundColor,
                    fontWeight: FontWeight.bold,
                    fontSize: titleFontSize,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              );
            },
          ),
          backgroundColor: theme.appBarTheme.backgroundColor,
          elevation: 0,
          actions: [
            TutorialHighlight(
              highlightKey: InteractiveTutorial.helpButtonKey,
              additionalHighlightKeys: [InteractiveTutorial.appBarKey],
              child: Container(
                key: InteractiveTutorial.helpButtonKey,
                child: IconButton(
                  icon: Icon(Icons.help_outline, color: theme.appBarTheme.foregroundColor),
                  onPressed: () {
                    InteractiveTutorial.startTutorial(context, scrollController: _scrollController);
                  },
                ),
              ),
            ),
            TutorialHighlight(
              highlightKey: InteractiveTutorial.notificationsKey,
              additionalHighlightKeys: [InteractiveTutorial.appBarKey],
              child: Container(
                key: InteractiveTutorial.notificationsKey,
                child: IconButton(
                  icon: Icon(Icons.notifications, color: theme.appBarTheme.foregroundColor),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const NotificationsRemindersPage(),
                      ),
                    );
                  },
                ),
              ),
            ),
            IconButton(
              icon: Icon(Icons.refresh, color: theme.appBarTheme.foregroundColor),
              onPressed: () => _loadDashboardData(showLoading: true),
            ),
          ],
        ),
        body: RefreshIndicator(
            onRefresh: _loadDashboardData,
            child: SingleChildScrollView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TimeFrameFilter(
                    selectedTimeFrame: _selectedTimeFrame,
                    onTimeFrameChanged: (timeFrame) {
                      // Cancel any pending debounce timer
                      _debounceTimer?.cancel();
                      
                      setState(() {
                        _selectedTimeFrame = timeFrame;
                        _selectedDate = DateTime.now(); // Reset to current date
                      });
                      
                      // Use different debounce times based on user interaction
                      // Faster response for time frame changes (150ms)
                      _debounceTimer = Timer(const Duration(milliseconds: 150), () {
                        _loadDashboardDataOptimized(showLoading: false, useCache: true);
                      });
                    },
                  ),
                  TimeFrameNavigator(
                    timeFrame: _selectedTimeFrame,
                    currentDate: _selectedDate,
                    onDateChanged: (date) {
                      // Cancel any pending debounce timer
                      _debounceTimer?.cancel();
                      
                      setState(() {
                        _selectedDate = date;
                      });
                      
                      // Use different debounce times based on user interaction
                      // Slightly longer for date changes (300ms) as they might be adjusted multiple times
                      _debounceTimer = Timer(const Duration(milliseconds: 300), () {
                        _loadDashboardDataOptimized(showLoading: false, useCache: true);
                      });
                    },
                  ),
                  if (_isLoading)
                    _buildSkeletonLoader() // Use skeleton loader instead of simple CircularProgressIndicator
                  else
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          // Determine responsive layout parameters
                          final isNarrowScreen = constraints.maxWidth < 600;
                          final isVeryNarrowScreen = constraints.maxWidth < 400;
                          final isExtremelyNarrowScreen = constraints.maxWidth < 320;

                          // Responsive sizing following typography standards
                          final sectionHeaderFontSize = isExtremelyNarrowScreen ? 18.0 : isNarrowScreen ? 20.0 : 22.0; // Section Heading range (18–24sp)
                          final spacingAfterTip = isExtremelyNarrowScreen ? 16.0 : isNarrowScreen ? 20.0 : 24.0;
                          final spacingAfterHeader = isExtremelyNarrowScreen ? 10.0 : isNarrowScreen ? 12.0 : 16.0;
                          final spacingBeforeCharts = isExtremelyNarrowScreen ? 24.0 : isNarrowScreen ? 28.0 : 32.0;
                          final spacingBeforeBreakdown = isExtremelyNarrowScreen ? 16.0 : isNarrowScreen ? 20.0 : 24.0;

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Special Financial Tip
                              _buildSpecialTip(),
                              SizedBox(height: spacingAfterTip),

                              // Period Overview
                              Text(
                                TimeFrameHelper.getDisplayText(_selectedTimeFrame, _selectedDate),
                                style: TextStyle(
                                  fontSize: sectionHeaderFontSize,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.onSurface,
                                ),
                                maxLines: isVeryNarrowScreen ? 2 : 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              SizedBox(height: spacingAfterHeader),
                              Row(
                                children: [
                                  Expanded(
                                    child: TutorialHighlight(
                                      highlightKey: InteractiveTutorial.incomeCardKey,
                                      child: SummaryCard(
                                        title: 'Income',
                                        amount: _periodIncome,
                                        icon: Icons.trending_up,
                                        color: Colors.green,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: TutorialHighlight(
                                      highlightKey: InteractiveTutorial.expensesCardKey,
                                      child: SummaryCard(
                                        title: 'Expenses',
                                        amount: _periodExpenses,
                                        icon: Icons.trending_down,
                                        color: Colors.red,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: TutorialHighlight(
                                      highlightKey: InteractiveTutorial.savingsCardKey,
                                      child: SummaryCard(
                                        title: 'Savings',
                                        amount: _periodSavings,
                                        icon: Icons.savings,
                                        color: Colors.blue,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: spacingBeforeCharts),

                              // Financial Insights
                              TutorialHighlight(
                                highlightKey: InteractiveTutorial.budgetingTipsKey,
                                child: _buildInsights(),
                              ),

                              // Savings Goal Progress
                              TutorialHighlight(
                                highlightKey: InteractiveTutorial.savingsProgressKey,
                                child: _buildSavingsProgress(),
                              ),

                              // Charts Section
                              SizedBox(height: spacingBeforeCharts),

                              // Financial Overview - Always show for tutorial compatibility
                              TutorialHighlight(
                                highlightKey: InteractiveTutorial.chartKey,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (_periodIncome > 0 || _periodExpenses > 0 || _periodSavings > 0 || _periodDebt > 0) ...[
                                      Text(
                                        'Financial Overview',
                                        style: TextStyle(
                                          fontSize: sectionHeaderFontSize - 2, // Smaller following typography rules
                                          fontWeight: FontWeight.bold,
                                          color: theme.colorScheme.onSurface,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      SizedBox(height: spacingBeforeBreakdown),
                                      IncomeExpenseBarChart(
                                        income: _periodIncome,
                                        expenses: _periodExpenses,
                                        savings: _periodSavings,
                                        debt: _periodDebt,
                                        timeFrameLabel: TimeFrameHelper.getDisplayText(_selectedTimeFrame, _selectedDate),
                                      ),
                                      SizedBox(height: spacingBeforeCharts),
                                    ] else ...[
                                      // Show placeholder when no data for tutorial
                                      Text(
                                        'Financial Overview',
                                        style: TextStyle(
                                          fontSize: sectionHeaderFontSize - 2,
                                          fontWeight: FontWeight.bold,
                                          color: theme.colorScheme.onSurface,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      SizedBox(height: spacingBeforeBreakdown),
                                      Container(
                                        height: 200,
                                        decoration: BoxDecoration(
                                          color: theme.cardTheme.color,
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(
                                            color: theme.dividerColor,
                                            width: 1,
                                          ),
                                        ),
                                        child: Center(
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.bar_chart,
                                                size: 48,
                                                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                                              ),
                                              const SizedBox(height: 16),
                                              Text(
                                                'No financial data yet',
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              Text(
                                                'Add transactions to see your financial overview',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                                                ),
                                                textAlign: TextAlign.center,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      SizedBox(height: spacingBeforeCharts),
                                    ],
                                  ],
                                ),
                              ),
                              
                              // Expense Breakdown
                              if (_categoryTotals.isNotEmpty) ...[
                                Text(
                                  'Expense Breakdown',
                                  style: TextStyle(
                                    fontSize: sectionHeaderFontSize - 2, // Smaller following typography rules
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                SizedBox(height: spacingBeforeBreakdown),
                                _buildExpenseBreakdownChart(),
                              ],
                              
                              // Add bottom padding to prevent overflow
                              SizedBox(height: isNarrowScreen ? 20.0 : 24.0),
                            ],
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
      ),
    );
  }

  Future<void> _refreshUserData() async {
    try {
      final user = await FirebaseService.getUser();
      if (user != null) {
        final profileImage = await ProfileSyncService.getProfilePicture(user);
        if (mounted) {
          setState(() {
            _currentUser = user;
            _cachedProfileImage = profileImage;
          });
        }
      }
    } catch (e) {
      // Error refreshing user data - handle silently
      debugPrint('Error refreshing user data: $e');
      if (mounted) {
        setState(() {
          _cachedProfileImage = null;
        });
      }
    }
  }

  Widget _buildProfileButton() {
    final theme = Theme.of(context);

    return Container(
      key: InteractiveTutorial.profileKey,
      margin: const EdgeInsets.all(8.0),
      child: GestureDetector(
        onTap: () async {
          final result = await Navigator.of(context).pushNamed('/profile');
          // If the profile was updated, refresh the user data
          if (result == true) {
            _refreshUserData();
          }
        },
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: theme.appBarTheme.foregroundColor!.withValues(alpha: 0.3),
              width: 2,
            ),
          ),
          child: ClipOval(
            child: _cachedProfileImage != null && _cachedProfileImage!.existsSync()
                ? Image.file(
                    _cachedProfileImage!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      // If image fails to load, show default icon
                      return Container(
                        decoration: BoxDecoration(
                          color: theme.cardTheme.color,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.person,
                          color: theme.colorScheme.primary,
                          size: 24,
                        ),
                      );
                    },
                  )
                : Container(
                    decoration: BoxDecoration(
                      color: theme.cardTheme.color,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.person,
                      color: theme.colorScheme.primary,
                      size: 24,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  /// Build skeleton loader for better loading experience
  Widget _buildSkeletonLoader() {
    final theme = Theme.of(context);
    
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrowScreen = constraints.maxWidth < 600;
        final cardHeight = isNarrowScreen ? 80.0 : 100.0;
        final spacing = isNarrowScreen ? 12.0 : 16.0;
        
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // TimeFrameFilter skeleton
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                height: 40,
                decoration: BoxDecoration(
                  color: theme.cardTheme.color?.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              
              // TimeFrameNavigator skeleton
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                height: 40,
                decoration: BoxDecoration(
                  color: theme.cardTheme.color?.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Period Overview skeleton
                    Container(
                      height: 24,
                      width: 150,
                      decoration: BoxDecoration(
                        color: theme.cardTheme.color?.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    SizedBox(height: spacing),
                    
                    // Summary cards skeleton
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: cardHeight,
                            decoration: BoxDecoration(
                              color: theme.cardTheme.color?.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Container(
                            height: cardHeight,
                            decoration: BoxDecoration(
                              color: theme.cardTheme.color?.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Container(
                            height: cardHeight,
                            decoration: BoxDecoration(
                              color: theme.cardTheme.color?.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: spacing * 2),
                    
                    // Financial Insights skeleton
                    Container(
                      height: 200,
                      decoration: BoxDecoration(
                        color: theme.cardTheme.color?.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    SizedBox(height: spacing * 2),
                    
                    // Savings Progress skeleton
                    Container(
                      height: 120,
                      decoration: BoxDecoration(
                        color: theme.cardTheme.color?.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    SizedBox(height: spacing * 2),
                    
                    // Financial Overview skeleton
                    Container(
                      height: 200,
                      decoration: BoxDecoration(
                        color: theme.cardTheme.color?.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    SizedBox(height: spacing * 2),
                    
                    // Expense Breakdown skeleton
                    Container(
                      height: 150,
                      decoration: BoxDecoration(
                        color: theme.cardTheme.color?.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Get fixed icon based on tip category to ensure consistency
  /// Using exactly 5 unique icons as requested: general, spending, savings, app general, motivational
  String _getFixedIconForCategory(String category) {
    switch (category.toLowerCase()) {
      case 'general':
        return '💡'; // Light bulb for general tips
      case 'spending':
        return '💰'; // Money bag for spending tips
      case 'savings':
        return '📈'; // Chart increasing for savings tips
      case 'app general':
        return '📱'; // Mobile phone for app general tips
      case 'motivational':
        return '✨'; // Sparkles for motivational tips
      default:
        // For any other categories, we'll use a default icon
        return '📌'; // Pushpin as default fallback
    }
  }
}
