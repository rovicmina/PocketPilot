import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/budget_prescription.dart';
import '../services/budget_prescription_service.dart';
import '../services/data_cache_service.dart';
import '../services/firebase_service.dart';
import '../services/transaction_service.dart';
import '../services/transaction_notifier.dart';
import '../services/user_notifier.dart';
import '../models/user.dart' as user_models;
import '../widgets/page_tutorials.dart';
import '../widgets/custom_tutorial.dart';
import '../widgets/tutorial_cleanup.dart';
import 'add_transaction_page.dart';

class BudgetPage extends StatefulWidget {
  const BudgetPage({super.key});

  @override
  State<BudgetPage> createState() => _BudgetPageState();
}

class _BudgetPageState extends State<BudgetPage> with WidgetsBindingObserver {
  BudgetPrescription? _prescription;
  bool _isLoading = true;
  bool _hasPreviousMonthData = false;
  DateTime? _lastDataUpdate;
  bool _needsRefresh = false;
  user_models.User? _currentUser;
  double _maxHistoricalMonthlyExpenses = 0.0;

  // Current month spending data for emergency fund calculations
  // ignore: unused_field
  Map<String, double> _currentMonthCategorySpending = {};
  // ignore: unused_field
  Map<String, double> _categoryBudgets = {};

  final DataCacheService _cacheService = DataCacheService();
  
  // Transaction notifier for real-time updates
  final TransactionNotifier _transactionNotifier = TransactionNotifier();
  
  // User notifier for profile updates
  final UserNotifier _userNotifier = UserNotifier();

  // Scroll controller for tutorial scrolling
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // Listen for transaction changes for real-time updates
    _transactionNotifier.addListener(_onTransactionChanged);
    
    // Listen for user profile changes for emergency fund and monthly net updates
    _userNotifier.addListener(_onUserProfileChanged);
    
    // Load budget data
    _loadBudgetDataWithTimeout().then((_) {
      if (mounted) {
        _refreshBudgetData();
      }
    });

    // Set up periodic refresh
    _setupPeriodicRefresh();

    // Removed automatic tutorial start - users can click the help button to start tutorial
  }
  
  // Removed automatic tutorial start - users can click the help button to start tutorial

  /// Load current month spending data for pie chart
  Future<void> _loadCurrentMonthSpendingData() async {
    if (_prescription == null) return;

    try {
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);
      final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

      // Get current month category spending
      final categorySpending = await TransactionService.getExpenseCategoryTotals(
        startDate: startOfMonth,
        endDate: endOfMonth,
      );

      // Calculate category budgets from prescription
      final categoryBudgets = <String, double>{};
      final daysInMonth = DateTime(now.year, now.month + 1, 0).day;

      // Add daily allocations (multiplied by days in month)
      for (final allocation in _prescription!.dailyAllocations) {
        categoryBudgets[allocation.category] = allocation.dailyAmount * daysInMonth;
      }

      // Add monthly allocations
      for (final allocation in _prescription!.monthlyAllocations) {
        categoryBudgets[allocation.category] = allocation.monthlyAmount;
      }

      // Calculate total spent and total budget (for emergency fund calculations)
      // final totalSpent = categorySpending.values.fold(0.0, (sum, amount) => sum + amount);
      // final totalBudget = categoryBudgets.values.fold(0.0, (sum, amount) => sum + amount);

      if (mounted) {
        setState(() {
          _currentMonthCategorySpending = categorySpending;
          _categoryBudgets = categoryBudgets;
        });
      }
    } catch (e) {
      // Silent error handling
      debugPrint('Error loading current month spending data: $e');
    }
  }

  /// Load user data for emergency fund card
  Future<void> _loadUserDataForEmergencyFund() async {
    try {
      final user = await FirebaseService.getUser();
      if (mounted) {
        setState(() {
          _currentUser = user;
        });
        _loadHistoricalExpensesInBackground();
      }
    } catch (e) {
      // Silent error handling
    }
  }
  
  /// Fetch historical monthly expenses to find the maximum
  Future<double> _getMaxHistoricalMonthlyExpenses() async {
    try {
      final now = DateTime.now();
      double maxExpenses = 0.0;

      // Check the current month and last 11 months for historical data (12 months total)
      for (int i = 0; i <= 11; i++) {
        // Handle month and year boundaries properly
        DateTime monthDate;
        if (now.month - i <= 0) {
          // We need to go back to previous year(s)
          final monthsBack = now.month - i;
          final yearsBack = (monthsBack.abs() / 12).floor();
          final finalMonth = 12 - (monthsBack.abs() % 12);
          monthDate = DateTime(now.year - yearsBack - 1, finalMonth, 1);
        } else {
          monthDate = DateTime(now.year, now.month - i, 1);
        }

        try {
          final startOfMonth = DateTime(monthDate.year, monthDate.month, 1);
          final endOfMonth = DateTime(monthDate.year, monthDate.month + 1, 0);

          final categoryTotals = await TransactionService.getExpenseCategoryTotals(
            startDate: startOfMonth,
            endDate: endOfMonth,
          );

          final monthTotal = categoryTotals.values.fold(0.0, (sum, amount) => sum + amount);

          if (monthTotal > maxExpenses) {
            maxExpenses = monthTotal;
          }
        } catch (e) {
          continue;
        }
      }

      return maxExpenses;
    } catch (e) {
      return 0.0;
    }
  }

  /// Load historical expenses in background
  Future<void> _loadHistoricalExpensesInBackground() async {
    try {
      final maxExpenses = await _getMaxHistoricalMonthlyExpenses();
      if (mounted) {
        setState(() {
          _maxHistoricalMonthlyExpenses = maxExpenses;
        });

        // Always update user's maxMonthlyExpense with the recalculated max
        // This ensures that when large transactions are deleted, the max is properly recalculated
        if (_currentUser != null) {
          final updatedUser = _currentUser!.copyWith(maxMonthlyExpense: maxExpenses);
          await FirebaseService.saveUser(updatedUser);
          if (mounted) {
            setState(() {
              _currentUser = updatedUser;
            });
          }
        }
      }
    } catch (e) {
      // Silent error handling
    }
  }

  /// Load budget data with simple error handling
  Future<void> _loadBudgetDataWithTimeout() async {
    if (!mounted) return;
    
    try {
      await _loadBudgetDataOptimized();
    } catch (e) {
      if (mounted) {
        await _tryLoadCachedData();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _scrollController.dispose();
    _transactionNotifier.removeListener(_onTransactionChanged);
    _userNotifier.removeListener(_onUserProfileChanged);
    super.dispose();
  }
  
  /// Called when transaction notifier signals a change
  void _onTransactionChanged() {
    if (mounted) {
      final now = DateTime.now();
      _cacheService.invalidateMonth(now);
      _refreshBudgetData();
      // Also refresh user data to update emergency fund amount
      _loadUserDataForEmergencyFund();
    }
  }
  
  /// Called when user profile notifier signals a change
  void _onUserProfileChanged() {
    if (mounted) {
      // User profile change detected, refreshing data
      _loadUserDataForEmergencyFund();
      // Also refresh budget data as monthly net affects budget prescriptions
      _refreshBudgetData();
    }
  }

  Timer? _timer;
  
  void _setupPeriodicRefresh() {
    // Refresh current month data every 15 minutes when app is active (increased from 10 minutes to reduce load even more)
    _timer = Timer.periodic(const Duration(minutes: 15), (timer) {
      if (mounted && _prescription != null) {
        // Only refresh if prescription is older than 30 minutes
        final age = DateTime.now().difference(_lastDataUpdate ?? DateTime.now());
        if (age.inMinutes > 30) {
          _refreshBudgetData();
        }
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Only refresh if we've been away for more than 30 minutes or if refresh is needed (increased threshold again)
      final now = DateTime.now();
      final shouldRefresh = _lastDataUpdate == null || 
                           now.difference(_lastDataUpdate!).inMinutes > 30 ||
                           _needsRefresh;
      
      if (shouldRefresh) {
        _refreshBudgetData();
      }
    }
  }

  /// Try to load any cached data as fallback
  Future<void> _tryLoadCachedData() async {
    try {
      final now = DateTime.now();
      final prescription = await BudgetPrescriptionService.getBudgetPrescription(now);
      if (prescription != null && mounted) {
        setState(() {
          _prescription = prescription;
          _lastDataUpdate = prescription.lastUpdated;
          _isLoading = false;
        });
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Simplified and robust budget data loading
  Future<void> _loadBudgetDataOptimized() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      final now = DateTime.now();
      
      // Step 1: Load user data first
      final user = await FirebaseService.getUser();
      if (mounted) {
        setState(() {
          _currentUser = user;
        });
      }
      
      // Step 2: Check for cached prescription
      final cachedPrescription = await BudgetPrescriptionService.getBudgetPrescription(now);
      
      if (cachedPrescription != null && mounted) {
        setState(() {
          _prescription = cachedPrescription;
          _lastDataUpdate = cachedPrescription.lastUpdated;
          _hasPreviousMonthData = true;
          _isLoading = false;
        });

        // Load current month spending data for pie chart
        _loadCurrentMonthSpendingData();
        
        // If data is recent enough, we're done
        final age = now.difference(cachedPrescription.lastUpdated);
        if (age.inHours < 6) {
          return;
        }
      }
      
      // Step 3: Check for any transaction data
      bool hasAnyData = false;
      
      // Check multiple months for any data
      for (int i = 0; i <= 12; i++) {
        final checkMonth = DateTime(now.year, now.month - i, 1);
        try {
          final transactions = await _cacheService.getMonthlyTransactions(checkMonth);
          if (transactions.isNotEmpty) {
            hasAnyData = true;
            break;
          }
        } catch (e) {
          continue;
        }
      }

      if (mounted) {
        setState(() {
          _hasPreviousMonthData = hasAnyData;
        });
      }

      // Step 4: Generate prescription if we have data but no cached one
      if (hasAnyData && cachedPrescription == null && mounted) {
        final newPrescription = await BudgetPrescriptionService.generateBudgetPrescription();
        
        if (newPrescription != null && mounted) {
          // Save in background
          BudgetPrescriptionService.saveBudgetPrescription(newPrescription);

          setState(() {
            _prescription = newPrescription;
            _lastDataUpdate = DateTime.now();
            _hasPreviousMonthData = true;
          });

          // Load current month spending data for pie chart
          _loadCurrentMonthSpendingData();
        }
      }

    } catch (e) {
      // Try cached data as fallback
      if (mounted) {
        await _tryLoadCachedData();
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }




  /// Ultra-fast refresh that updates current month data
  Future<void> _refreshBudgetData() async {
    if (_prescription == null) {
      _loadBudgetDataWithTimeout();
      return;
    }

    try {
      final updatedPrescription = await BudgetPrescriptionService.updatePrescriptionWithCurrentData(_prescription!).timeout(
        const Duration(seconds: 3),
      );
      
      if (updatedPrescription != null && mounted) {
        setState(() {
          _prescription = updatedPrescription;
          _lastDataUpdate = DateTime.now();
        });

        // Reload current month spending data
        _loadCurrentMonthSpendingData();
      }
    } catch (e) {
      // Silent error handling for background refresh
    }
  }


  /// Manual refresh with user feedback
  Future<void> _regeneratePrescription() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final now = DateTime.now();
      
      // Force regenerate with minimal cache invalidation
      _cacheService.invalidateMonth(now);
      
      final prescription = await BudgetPrescriptionService.generateBudgetPrescription();
      
      if (prescription != null) {
        await BudgetPrescriptionService.saveBudgetPrescription(prescription);
        
        setState(() {
          _prescription = prescription;
          _lastDataUpdate = DateTime.now();
          _needsRefresh = false;
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Budget updated successfully!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Unable to update budget. Check your transaction data.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating budget: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Budget',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: theme.appBarTheme.foregroundColor,
          ),
        ),
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.help_outline, color: theme.appBarTheme.foregroundColor),
            onPressed: () {
              // Show appropriate tutorial based on current view
              if (!_hasPreviousMonthData) {
                // No data view - show no data tutorial
                PageTutorials.startBudgetNoDataTutorial(context);
              } else if (_prescription == null) {
                // Loading/analyzing view - no specific tutorial needed
              } else {
                // Data view - show regular budget tutorial
                PageTutorials.startBudgetTutorial(context, _scrollController);
              }
            },
            tooltip: 'Show Tutorial',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : () {
              _regeneratePrescription();
            },
            tooltip: 'Refresh Budget',
          ),
        ],
      ),
      body: _isLoading
          ? _buildLoadingView()
          : !_hasPreviousMonthData
              ? _buildNoPreviousDataView()
              : _prescription == null
                  ? _buildNoPrescriptionView()
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        // Determine responsive layout parameters
                        final isNarrowScreen = constraints.maxWidth < 600;
                        final isVeryNarrowScreen = constraints.maxWidth < 400;
                        final isExtremelyNarrowScreen = constraints.maxWidth < 320;
                        final horizontalPadding = isExtremelyNarrowScreen ? 10.0 : isNarrowScreen ? 12.0 : 16.0;
                        
                        return _buildPrescriptionView(isNarrowScreen, isVeryNarrowScreen, horizontalPadding);
                      },
                    ),
    );
  }

  Widget _buildLoadingView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.indigo.shade500, Colors.indigo.shade700],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Column(
                children: [
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(height: 16),
                  Text(
                    'Loading Budget...',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Analyzing your spending patterns',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoPrescriptionView() {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.analytics_outlined,
              size: 120,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 24),
            Text(
              'Analyzing Your Data',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'We\'re processing your previous month\'s spending patterns to create a personalized budget prescription. This may take a moment.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrescriptionView([bool isNarrowScreen = false, bool isVeryNarrowScreen = false, double horizontalPadding = 16.0]) {
    final prescription = _prescription!;
    final theme = Theme.of(context);
    
    return RefreshIndicator(
      onRefresh: _refreshBudgetData,
      child: SingleChildScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(horizontalPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildBudgetOverviewHeader(prescription, theme, isNarrowScreen, isVeryNarrowScreen),
            SizedBox(height: isNarrowScreen ? 12 : 16),
            _buildConfidenceBanner(prescription, theme),
            SizedBox(height: isNarrowScreen ? 12 : 16),
            if (prescription.exceedsMonthlyNet) 
              _buildBudgetWarningBanner(prescription, theme),
            if (prescription.exceedsMonthlyNet)
              SizedBox(height: isNarrowScreen ? 12 : 16),
            TutorialHighlight(
              highlightKey: PageTutorials.dailyAllocationsKey,
              child: _buildDailyAllocations(prescription, theme),
            ),
            SizedBox(height: isNarrowScreen ? 16 : 20),
            TutorialHighlight(
              highlightKey: PageTutorials.monthlyAllocationsKey,
              child: _buildMonthlyAllocations(prescription, theme),
            ),
            SizedBox(height: isNarrowScreen ? 16 : 20),
            TutorialHighlight(
              highlightKey: PageTutorials.budgetSummaryKey,
              child: _buildBudgetSummaryCard(prescription, theme, isNarrowScreen, isVeryNarrowScreen),
            ),
            SizedBox(height: isNarrowScreen ? 16 : 20),


            // Emergency Fund Progress (separate from budget allocation summary)
            if (_currentUser != null && _shouldShowEmergencyFundCard()) ...[
              TutorialHighlight(
                highlightKey: PageTutorials.emergencyFundKey,
                child: _buildEmergencyFundCard(theme, isNarrowScreen, isVeryNarrowScreen),
              ),
              SizedBox(height: isNarrowScreen ? 16 : 20),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBudgetOverviewHeader(BudgetPrescription prescription, ThemeData theme, [bool isNarrowScreen = false, bool isVeryNarrowScreen = false]) {
    final currentMonth = prescription.month;
    final dataSourceMonth = prescription.dataSourceMonth;
    
    // Responsive sizing for header following typography standards
    final isExtremelyNarrowScreen = MediaQuery.of(context).size.width < 320;
    final isUltraNarrowScreen = MediaQuery.of(context).size.width < 280; // Added for ultra narrow screens
    final headerPadding = isUltraNarrowScreen ? 12.0 : isExtremelyNarrowScreen ? 13.0 : isVeryNarrowScreen ? 14.0 : isNarrowScreen ? 15.0 : 16.0;
    final iconSize = isUltraNarrowScreen ? 18.0 : isExtremelyNarrowScreen ? 19.0 : isVeryNarrowScreen ? 20.0 : isNarrowScreen ? 21.0 : 22.0;
    final titleFontSize = isUltraNarrowScreen ? 16.0 : isExtremelyNarrowScreen ? 17.0 : isVeryNarrowScreen ? 18.0 : isNarrowScreen ? 19.0 : 20.0; // Display/Title range
    final subtitleFontSize = isUltraNarrowScreen ? 10.0 : isExtremelyNarrowScreen ? 11.0 : isVeryNarrowScreen ? 12.0 : isNarrowScreen ? 13.0 : 14.0; // Body Text range
    final descriptionFontSize = isUltraNarrowScreen ? 8.0 : isExtremelyNarrowScreen ? 9.0 : isVeryNarrowScreen ? 10.0 : isNarrowScreen ? 11.0 : 12.0; // Secondary Text range
    final infoFontSize = isUltraNarrowScreen ? 6.0 : isExtremelyNarrowScreen ? 7.0 : isVeryNarrowScreen ? 8.0 : isNarrowScreen ? 9.0 : 10.0; // Captions range
    final infoIconSize = isUltraNarrowScreen ? 10.0 : isExtremelyNarrowScreen ? 11.0 : isVeryNarrowScreen ? 12.0 : isNarrowScreen ? 13.0 : 14.0;
    final analyticsIconSize = isUltraNarrowScreen ? 12.0 : isExtremelyNarrowScreen ? 13.0 : isVeryNarrowScreen ? 14.0 : isNarrowScreen ? 15.0 : 16.0;
    
    return TutorialHighlight(
      highlightKey: PageTutorials.budgetOverviewKey,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(headerPadding),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.teal.shade600, Colors.teal.shade800],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.teal.shade800.withValues(alpha: 0.3),
              spreadRadius: 1,
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_awesome, color: theme.colorScheme.onPrimary, size: iconSize),
                SizedBox(width: isNarrowScreen ? 10 : 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your Personalized Budget',
                        style: TextStyle(
                          color: theme.colorScheme.onPrimary,
                          fontSize: titleFontSize,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: isNarrowScreen ? 2 : 4),
                      Text(
                        'For ${DateFormat('MMMM yyyy').format(currentMonth)}',
                        style: TextStyle(
                          color: theme.colorScheme.onPrimary.withValues(alpha: 0.7),
                          fontSize: subtitleFontSize,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: isNarrowScreen ? 12 : 16),
            Container(
              padding: EdgeInsets.all(isNarrowScreen ? 10 : 12),
              decoration: BoxDecoration(
                color: theme.colorScheme.onPrimary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.analytics, color: theme.colorScheme.onPrimary.withValues(alpha: 0.7), size: analyticsIconSize),
                  SizedBox(width: isNarrowScreen ? 6 : 8),
                  Expanded(
                    child: Text(
                      'Based on your spending in ${DateFormat('MMMM yyyy').format(dataSourceMonth)}',
                      style: TextStyle(
                        color: theme.colorScheme.onPrimary,
                        fontSize: descriptionFontSize,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Show data selection reason if it's not a simple carry-forward
            if (prescription.dataSourceReason.isNotEmpty && !prescription.dataSourceReason.startsWith('Carry-forward')) ...[
              SizedBox(height: isNarrowScreen ? 6 : 8),
              Container(
                padding: EdgeInsets.all(isNarrowScreen ? 6 : 8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.onPrimary.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: theme.colorScheme.onPrimary.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: theme.colorScheme.onPrimary.withValues(alpha: 0.6), size: infoIconSize),
                    SizedBox(width: isNarrowScreen ? 4 : 6),
                    Expanded(
                      child: Text(
                        prescription.dataSourceReason,
                        style: TextStyle(
                          color: theme.colorScheme.onPrimary.withValues(alpha: 0.8),
                          fontSize: infoFontSize,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBudgetSummaryCard(BudgetPrescription prescription, ThemeData theme, [bool isNarrowScreen = false, bool isVeryNarrowScreen = false]) {
    final totalDailyBudget = prescription.totalDailyBudget;
    final totalMonthlyBudget = prescription.totalMonthlyBudget;
    final totalBudgetAllocated = prescription.totalMonthlyBudgetIncludingDaily;
    final daysInMonth = DateTime(prescription.month.year, prescription.month.month + 1, 0).day;

    // Responsive text sizes following typography standards
    final titleFontSize = isVeryNarrowScreen ? 16.0 : isNarrowScreen ? 18.0 : 20.0; // Section Heading range
    final labelFontSize = isVeryNarrowScreen ? 12.0 : isNarrowScreen ? 14.0 : 16.0; // Body Text range
    final amountFontSize = isVeryNarrowScreen ? 12.0 : isNarrowScreen ? 14.0 : 16.0; // Body Text range
    final breakdownFontSize = isVeryNarrowScreen ? 10.0 : isNarrowScreen ? 12.0 : 14.0; // Secondary Text range
    final cardPadding = isVeryNarrowScreen ? 14.0 : isNarrowScreen ? 16.0 : 20.0;
    
    return Container(
      key: PageTutorials.budgetSummaryKey,
      width: double.infinity,
      padding: EdgeInsets.all(cardPadding),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withValues(alpha: 0.1),
            spreadRadius: 1,
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.account_balance_wallet, color: Colors.blue, size: isNarrowScreen ? 20 : 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Budget Allocation Summary',
                  style: TextStyle(
                    fontSize: titleFontSize,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SizedBox(height: isNarrowScreen ? 12 : 16),
          
          // Monthly Net Income
          _buildSummaryRow(
            'Monthly Net Income',
            '₱${NumberFormat('#,##0.00').format(prescription.monthlyNetIncome)}',
            Colors.green,
            Icons.trending_up,
            theme,
            labelFontSize,
            amountFontSize,
          ),
          SizedBox(height: isNarrowScreen ? 8 : 12),
          
          // Total Budget Allocated
          _buildSummaryRow(
            'Total Budget Allocated',
            '₱${NumberFormat('#,##0.00').format(totalBudgetAllocated)}',
            Colors.blue,
            Icons.pie_chart,
            theme,
            labelFontSize,
            amountFontSize,
          ),
          SizedBox(height: isNarrowScreen ? 6 : 8),
          
          // Budget breakdown
          Padding(
            padding: EdgeInsets.only(left: isNarrowScreen ? 16 : 24),
            child: Column(
              children: [
                _buildBreakdownRow(
                  isVeryNarrowScreen ? 'Daily × $daysInMonth days' : 'Daily Budget × $daysInMonth days',
                  '₱${NumberFormat('#,##0.00').format(totalDailyBudget * daysInMonth)}',
                  theme,
                  breakdownFontSize,
                ),
                _buildBreakdownRow(
                  isVeryNarrowScreen ? 'Monthly Expenses' : 'Fixed Monthly Expenses',
                  '₱${NumberFormat('#,##0.00').format(totalMonthlyBudget)}',
                  theme,
                  breakdownFontSize,
                ),
              ],
            ),
          ),
          
          SizedBox(height: isNarrowScreen ? 8 : 12),
          
          // Remaining Budget
          Container(
            padding: EdgeInsets.all(isNarrowScreen ? 8 : 12),
            decoration: BoxDecoration(
              color: prescription.exceedsMonthlyNet 
                  ? Colors.red.withValues(alpha: 0.1)
                  : Colors.green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: _buildSummaryRow(
              prescription.exceedsMonthlyNet ? 'Budget Excess' : 'Remaining Budget',
              '₱${NumberFormat('#,##0.00').format(prescription.remainingBudget.abs())}',
              prescription.exceedsMonthlyNet ? Colors.red : Colors.green,
              prescription.exceedsMonthlyNet ? Icons.warning : Icons.savings,
              theme,
              labelFontSize,
              amountFontSize,
            ),
          ),
          
          SizedBox(height: isNarrowScreen ? 6 : 8),
          
          // Budget utilization percentage
          Container(
            padding: EdgeInsets.all(isNarrowScreen ? 8.0 : 10.0),
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                Icon(Icons.analytics_outlined, size: isNarrowScreen ? 12 : 14, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                SizedBox(width: isNarrowScreen ? 6 : 8),
                Expanded(
                  child: Text(
                    isVeryNarrowScreen 
                        ? 'Budget Use: ${prescription.budgetUtilizationPercentage.toStringAsFixed(1)}%'
                        : 'Budget Utilization: ${prescription.budgetUtilizationPercentage.toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: isNarrowScreen ? 10.0 : 12.0, // Captions range
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  
}

  Widget _buildSummaryRow(String label, String amount, Color color, IconData icon, ThemeData theme, [double labelFontSize = 14.0, double amountFontSize = 14.0]) {
    return Column(
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: labelFontSize,
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.onSurface,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              amount,
              style: TextStyle(
                fontSize: amountFontSize,
                fontWeight: FontWeight.bold,
                color: color,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBreakdownRow(String label, String amount, ThemeData theme, [double fontSize = 12.0]) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        children: [
          Icon(Icons.subdirectory_arrow_right, size: 14, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: Text(
              label,
              style: TextStyle(
                fontSize: fontSize,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: Text(
              amount,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBudgetWarningBanner(BudgetPrescription prescription, ThemeData theme) {
    final excess = prescription.totalMonthlyBudgetIncludingDaily - prescription.monthlyNetIncome;
    
    return LayoutBuilder(
      builder: (context, constraints) {
        // Determine responsive layout parameters
        final isNarrowScreen = constraints.maxWidth < 600;
        final isVeryNarrowScreen = constraints.maxWidth < 400;
        
        // Responsive sizing following typography standards
        final titleFontSize = isNarrowScreen ? 16.0 : 18.0; // Subheading range (16–20sp)
        final descriptionFontSize = isNarrowScreen ? 14.0 : 16.0; // Body Text range (14–16sp)
        final iconSize = isNarrowScreen ? 22.0 : 24.0;
        final containerPadding = isNarrowScreen ? 12.0 : 16.0;
        final iconSpacing = isNarrowScreen ? 10.0 : 12.0;
        
        return Container(
          width: double.infinity,
          padding: EdgeInsets.all(containerPadding),
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.warning, color: Colors.red, size: iconSize),
              SizedBox(width: iconSpacing),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Budget Too High',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                        fontSize: titleFontSize,
                      ),
                      maxLines: isVeryNarrowScreen ? 2 : 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isVeryNarrowScreen
                          ? 'Your budget is ₱${NumberFormat('#,##0.00').format(excess.abs())} over your income. Try reducing some expenses.'
                          : 'Your budget is ₱${NumberFormat('#,##0.00').format(excess.abs())} higher than your monthly income. Consider reducing some expenses to make it more realistic.',
                      style: TextStyle(
                        color: Colors.red.withValues(alpha: 0.8),
                        fontSize: descriptionFontSize,
                      ),
                      maxLines: isVeryNarrowScreen ? 3 : 2,
                      overflow: TextOverflow.ellipsis,
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

  Widget _buildConfidenceBanner(BudgetPrescription prescription, ThemeData theme) {
    Color bannerColor;
    IconData bannerIcon;
    String coverageText;
    String coverageDescription;

    switch (prescription.confidence) {
      case ConfidenceLevel.high:
        bannerColor = Colors.green;
        bannerIcon = Icons.check_circle;
        coverageText = 'High';
        coverageDescription = 'Great! We have lots of your spending data to work with.';
        break;
      case ConfidenceLevel.medium:
        bannerColor = Colors.orange;
        bannerIcon = Icons.warning;
        coverageText = 'Medium';
        coverageDescription = 'We have some of your data, but more would help make your budget even better.';
        break;
      case ConfidenceLevel.low:
        bannerColor = Colors.red;
        bannerIcon = Icons.info;
        coverageText = 'Low';
        coverageDescription = 'We need more of your spending data to create a more accurate budget.';
        break;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Determine responsive layout parameters
        final isNarrowScreen = constraints.maxWidth < 600;
        final isVeryNarrowScreen = constraints.maxWidth < 400;
        
        // Responsive sizing following typography standards
        final titleFontSize = isNarrowScreen ? 16.0 : 18.0; // Subheading range (16–20sp)
        final subtitleFontSize = isNarrowScreen ? 14.0 : 16.0; // Body Text range (14–16sp)
        final smallTextFontSize = isNarrowScreen ? 12.0 : 14.0; // Secondary Text range (12–14sp)
        final iconSize = isNarrowScreen ? 22.0 : 24.0;
        final smallIconSize = isNarrowScreen ? 14.0 : 16.0;
        final containerPadding = isNarrowScreen ? 12.0 : 16.0;
        final iconSpacing = isNarrowScreen ? 10.0 : 12.0;
        
        return Container(
          width: double.infinity,
          padding: EdgeInsets.all(containerPadding),
          decoration: BoxDecoration(
            color: bannerColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: bannerColor.withValues(alpha: 0.3)),
          ),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(bannerIcon, color: bannerColor, size: iconSize),
                  SizedBox(width: iconSpacing),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Data Coverage: $coverageText',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: bannerColor,
                            fontSize: titleFontSize,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          isVeryNarrowScreen
                              ? '${prescription.dataCompleteness.toStringAsFixed(0)}% of month tracked (${prescription.daysFilled}/${prescription.totalDaysInMonth} days)'
                              : '${prescription.dataCompleteness.toStringAsFixed(0)}% of this month tracked (${prescription.daysFilled}/${prescription.totalDaysInMonth} days)',
                          style: TextStyle(
                            color: bannerColor.withValues(alpha: 0.8),
                            fontSize: subtitleFontSize,
                          ),
                          maxLines: isVeryNarrowScreen ? 2 : 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          coverageDescription,
                          style: TextStyle(
                            color: bannerColor.withValues(alpha: 0.6),
                            fontSize: smallTextFontSize,
                            fontStyle: FontStyle.italic,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (_lastDataUpdate != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.access_time, color: Colors.grey[600], size: smallIconSize),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'Last updated: ${_getLastUpdateText()}',
                        style: TextStyle(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                          fontSize: smallTextFontSize,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }


  /// Force refresh current budget data (public method)
  void refreshBudget() {
    _needsRefresh = true;
    _refreshBudgetData();
  }

  String _getLastUpdateText() {
    if (_lastDataUpdate == null) return 'Unknown';
    
    final now = DateTime.now();
    final difference = now.difference(_lastDataUpdate!);
    
    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }


  Widget _buildDailyAllocations(BudgetPrescription prescription, ThemeData theme) {
    final daysInMonth = DateTime(prescription.month.year, prescription.month.month + 1, 0).day;
    final totalDailyForMonth = prescription.totalDailyBudget * daysInMonth;

    return TutorialHighlight(
      highlightKey: PageTutorials.dailyAllocationsKey,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.cardTheme.color,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: theme.shadowColor.withValues(alpha: 0.1),
              spreadRadius: 1,
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.today, color: theme.colorScheme.primary, size: 24),
              const SizedBox(width: 8),
              Text(
                'Daily Budget Allowance',
                style: TextStyle(
                  fontSize: 18, // Section Heading range (reduced from 20)
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Flexible spending for each day (₱${NumberFormat('#,##0').format(totalDailyForMonth)} total for $daysInMonth days)',
            style: TextStyle(
              fontSize: 14, // Body Text range
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 16),
          
          // Daily total
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today, color: theme.colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Daily Total',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const Spacer(),
                Text(
                  '₱${NumberFormat('#,##0').format(prescription.totalDailyBudget)}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Daily allocations
          ...prescription.dailyAllocations.map((allocation) {
            final percentage = (allocation.dailyAmount / prescription.totalDailyBudget * 100);
            return _buildAllocationCard(
              allocation.icon,
              allocation.category,
              allocation.dailyAmount,
              allocation.description,
              theme,
              isDaily: true,
              percentage: percentage,
            );
          }),
        ],
      ),
    ));
  }

  Widget _buildAllocationCard(String icon, String category, double amount, String description, ThemeData theme, {bool isDaily = false, double? percentage}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: (theme.cardTheme.color ?? theme.colorScheme.surface).withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: theme.dividerColor.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: isDaily ? theme.colorScheme.primary.withValues(alpha: 0.1) : theme.colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(icon, style: const TextStyle(fontSize: 20)),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  if (percentage != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: LinearProgressIndicator(
                            value: percentage / 100,
                            backgroundColor: theme.dividerColor.withValues(alpha: 0.2),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              isDaily ? theme.colorScheme.primary : theme.colorScheme.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${percentage.toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (isDaily && (category == 'Food' || category == 'Transportation'))
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Based on last month\'s spending analysis',
                        style: TextStyle(
                          fontSize: 10,
                          color: theme.colorScheme.primary,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  if (!isDaily && (category == 'Housing & Utilities' || category == 'Insurance' || category == 'Subscriptions'))
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Exact amount from last month',
                        style: TextStyle(
                          fontSize: 10,
                          color: theme.colorScheme.primary,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '₱${NumberFormat('#,##0').format(amount)}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isDaily ? theme.colorScheme.primary : theme.colorScheme.primary,
                  ),
                ),
                Text(
                  isDaily ? 'per day' : 'per month',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthlyAllocations(BudgetPrescription prescription, ThemeData theme) {
    return TutorialHighlight(
      highlightKey: PageTutorials.monthlyAllocationsKey,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.cardTheme.color,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: theme.shadowColor.withValues(alpha: 0.1),
              spreadRadius: 1,
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.calendar_month, color: theme.colorScheme.primary, size: 24),
              const SizedBox(width: 8),
              Text(
                'Fixed Monthly Expenses',
                style: TextStyle(
                  fontSize: 18, // Section Heading range (reduced from 20)
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Recurring expenses and savings goals (₱${NumberFormat('#,##0').format(prescription.totalMonthlyBudget)} total)',
            style: TextStyle(
              fontSize: 14,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 16),
          
          // Monthly total
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.account_balance, color: theme.colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Monthly Total',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const Spacer(),
                Text(
                  '₱${NumberFormat('#,##0').format(prescription.totalMonthlyBudget)}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Monthly allocations
          ...prescription.monthlyAllocations.map((allocation) {
            final percentage = prescription.totalMonthlyBudget > 0 
                ? (allocation.monthlyAmount / prescription.totalMonthlyBudget * 100)
                : 0.0;
            return _buildAllocationCard(
              allocation.icon,
              allocation.category,
              allocation.monthlyAmount,
              allocation.description,
              theme,
              isDaily: false,
              percentage: percentage,
            );
          }),
        ],
      ),
    ));
  }

  /// Check if emergency fund card should be displayed
  bool _shouldShowEmergencyFundCard() {
    if (_currentUser == null) {
      return false;
    }
    
    // Show if user has emergency fund amount > 0
    if (_currentUser!.emergencyFundAmount != null && _currentUser!.emergencyFundAmount! > 0) {
      return true;
    }
    
    // Show if user has selected emergency fund in savings & investments
    final hasEmergencyFund = _currentUser!.savingsInvestments.any((investment) => 
        investment == user_models.SavingsInvestments.emergencyFund);
    
    return hasEmergencyFund;
  }

  Widget _buildEmergencyFundCard(ThemeData theme, [bool isNarrowScreen = false, bool isVeryNarrowScreen = false]) {
    final currentAmount = _currentUser?.emergencyFundAmount ?? 0.0;

    // Always use the recalculated max historical monthly expenses for the most accurate emergency fund goal
    // This ensures that when transactions are deleted, the goal updates properly
    final maxMonthlyExpenses = _maxHistoricalMonthlyExpenses;

    // Use expense data from the budget prescription's data source month as fallback
    final prescriptionMonthlyExpenses = _prescription?.previousMonthSpending.values.fold(0.0, (a, b) => a + b) ?? 0.0;

    // Use the highest of: recalculated max, prescription data, or historical max
    final highestMonthlyExpenses = [
      maxMonthlyExpenses,
      prescriptionMonthlyExpenses,
      _maxHistoricalMonthlyExpenses
    ].reduce((a, b) => a > b ? a : b);

    // If no expense data available, estimate based on monthly net income
    final estimatedMonthlyExpenses = highestMonthlyExpenses > 0
        ? highestMonthlyExpenses
        : (_prescription?.monthlyNetIncome ?? _currentUser?.monthlyNet ?? 0.0) / 3.0;

    final roundedExpenses = ((estimatedMonthlyExpenses / 1000).round() * 1000.0); // Round to nearest thousand
    final emergencyFundGoal = roundedExpenses * 3; // 3 months of expenses
    
    // Calculate progress percentage
    final progressPercentage = emergencyFundGoal > 0 ? (currentAmount / emergencyFundGoal).clamp(0.0, 1.0) : 0.0;

    const emergencyFundColor = Colors.green;
    
    // Responsive sizing following typography standards
    final cardPadding = isVeryNarrowScreen ? 10.0 : isNarrowScreen ? 12.0 : 16.0;
    final titleFontSize = isVeryNarrowScreen ? 14.0 : isNarrowScreen ? 16.0 : 18.0; // Section Heading range
    final subtitleFontSize = isVeryNarrowScreen ? 10.0 : isNarrowScreen ? 12.0 : 14.0; // Secondary Text range
    final amountFontSize = isVeryNarrowScreen ? 14.0 : isNarrowScreen ? 16.0 : 18.0; // Section Heading range (important info)
    final smallTextFontSize = isVeryNarrowScreen ? 8.0 : isNarrowScreen ? 10.0 : 12.0; // Captions range
    final iconSize = isVeryNarrowScreen ? 12.0 : isNarrowScreen ? 14.0 : 16.0;
    
    return Container(
      key: PageTutorials.emergencyFundKey,
      padding: EdgeInsets.all(cardPadding),
      decoration: BoxDecoration(
        color: emergencyFundColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: emergencyFundColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: isNarrowScreen ? 32 : 40,
                height: isNarrowScreen ? 32 : 40,
                decoration: BoxDecoration(
                  color: emergencyFundColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text('💰', style: TextStyle(fontSize: iconSize)),
                ),
              ),
              SizedBox(width: isNarrowScreen ? 8 : 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isVeryNarrowScreen ? 'Emergency Fund' : 'Emergency Fund Progress',
                      style: TextStyle(
                        fontSize: titleFontSize,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      emergencyFundGoal > 0 
                          ? isVeryNarrowScreen 
                              ? '3-month goal'
                              : '3-month safety net'
                          : 'Add data for goal',
                      style: TextStyle(
                        fontSize: subtitleFontSize,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // Current amount
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '₱${NumberFormat('#,##0').format(currentAmount)}',
                    style: TextStyle(
                      fontSize: amountFontSize,
                      fontWeight: FontWeight.bold,
                      color: emergencyFundColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (emergencyFundGoal > 0)
                    Text(
                      'of ₱${NumberFormat('#,##0').format(emergencyFundGoal)}',
                      style: TextStyle(
                        fontSize: smallTextFontSize,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    )
                  else
                    Text(
                      'No goal set',
                      style: TextStyle(
                        fontSize: smallTextFontSize,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                ],
              ),
            ],
          ),
          
          if (emergencyFundGoal > 0) ...[
            SizedBox(height: isNarrowScreen ? 8 : 12),
            // Progress bar
            Row(
              children: [
                Expanded(
                  child: LinearProgressIndicator(
                    value: progressPercentage,
                    backgroundColor: theme.dividerColor.withValues(alpha: 0.2),
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
                    minHeight: 6,
                  ),
                ),
                SizedBox(width: isNarrowScreen ? 8 : 12),
                Text(
                  '${(progressPercentage * 100).toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontSize: isNarrowScreen ? 14.0 : 16.0, // Body Text range
                    fontWeight: FontWeight.w600,
                    color: emergencyFundColor,
                  ),
                ),
              ],
            ),
            SizedBox(height: isNarrowScreen ? 6 : 8),
            Container(
              padding: EdgeInsets.all(isNarrowScreen ? 6.0 : 8.0),
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: isNarrowScreen ? 10 : 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      emergencyFundGoal > 0
                          ? isVeryNarrowScreen
                              ? 'Based on ₱${NumberFormat('#,##0').format(roundedExpenses)} highest expense × 3'
                              : 'Based on ₱${NumberFormat('#,##0').format(roundedExpenses)} highest monthly expense × 3 months'
                          : 'No expense data available',
                      style: TextStyle(
                        fontSize: isNarrowScreen ? 10.0 : 12.0, // Captions range
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        fontStyle: FontStyle.italic,
                      ),
                      maxLines: isVeryNarrowScreen ? 2 : 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNoPreviousDataView() {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final previousMonth = DateTime(now.year, now.month - 1, 1);
    final monthName = DateFormat('MMMM yyyy').format(previousMonth);
    final currentMonthName = DateFormat('MMMM yyyy').format(now);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              key: PageTutorials.budgetNoDataKey,
              child: Icon(
                Icons.timeline_outlined,
                size: 120,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Previous Month Data',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'To generate a budget for $currentMonthName, we need spending data from $monthName.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              key: PageTutorials.budgetNoDataInfoKey,
              child: Text(
                'Please add some transactions for $monthName to get personalized budget recommendations.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              key: PageTutorials.budgetNoDataAddTransactionKey,
              onPressed: () {
                // Navigate to add transaction page via main navigation
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const AddTransactionPage(),
                  ),
                );
              },
              child: const Text('Add Transactions'),
            ),
          ],
        ),
      ),
    );
  }
}