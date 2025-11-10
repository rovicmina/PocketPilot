import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../models/transaction.dart';
import '../models/reminder.dart';
import '../services/firebase_service.dart';
import '../services/data_cache_service.dart';
import '../services/transaction_notifier.dart';
import '../utils/category_colors.dart';
import '../widgets/add_reminder_modal.dart';
import '../widgets/custom_tutorial.dart';
import '../widgets/page_tutorials.dart';
import '../widgets/tutorial_cleanup.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage>
    with TickerProviderStateMixin {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, double> _dailySpending = {};
  List<Transaction> _selectedDayTransactions = [];
  List<Reminder> _selectedDayReminders = [];

  // Animation controllers for smooth transitions
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Cache service for fast data loading
  final DataCacheService _cacheService = DataCacheService();

  // Transaction notifier for real-time updates
  final TransactionNotifier _transactionNotifier = TransactionNotifier();

  // Scroll controller for tutorial scrolling
  final ScrollController _scrollController = ScrollController();

  // Store scroll position during tutorial to prevent any movement
  double? _tutorialScrollPosition;

  // Flag to trigger rebuild when tutorial state changes
  bool _tutorialRunning = false;

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime.now();

    // Initialize animation controllers
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.3, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    _loadCalendarData();

    // Listen for transaction changes
    _transactionNotifier.addListener(_onTransactionChanged);

    // Start aggressive preloading for better performance
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _cacheService.preloadAdjacentMonths(_focusedDay);
      // Removed automatic tutorial start - users can click the help button to start tutorial
    });
    
    // Set the callback for calendar tutorial
    PageTutorials.onCalendarTutorialSelectToday = selectTodayForTutorial;
  }

  /// Select today for tutorial purposes
  void selectTodayForTutorial() {
    setState(() {
      _selectedDay = DateTime.now();
      _focusedDay = DateTime.now();
    });
  }

  /// Prevent scrolling during calendar tutorial
  void _preventTutorialScrolling() {
    // Only prevent manual scrolling, not programmatic scrolling
    if (PageTutorials.isRunning && _tutorialScrollPosition != null) {
      // Allow some flexibility in scrolling (within 50 pixels)
      if ((_scrollController.position.pixels - _tutorialScrollPosition!).abs() > 50) {
        _scrollController.jumpTo(_tutorialScrollPosition!);
      }
    }
    // If tutorial is not running but we still have a scroll position saved, clear it
    else if (!PageTutorials.isRunning && _tutorialScrollPosition != null) {
      _tutorialScrollPosition = null;
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _scrollController.removeListener(_preventTutorialScrolling);
    _scrollController.dispose();
    _transactionNotifier.removeListener(_onTransactionChanged);
    super.dispose();
  }

  /// Called when transaction notifier signals a change
  void _onTransactionChanged() {
    if (mounted) {
      // Transaction change detected, refreshing data
      // Invalidate cache for the current month
      _cacheService.invalidateMonth(_selectedDay ?? DateTime.now());
      _loadCalendarData();
    }
  }

  Future<void> _loadCalendarData() async {
    debugPrint('CalendarPage: Loading data for focused day: $_focusedDay, selected day: $_selectedDay');
    debugPrint('CalendarPage: Cache stats: ${_cacheService.getCacheStats()}');

    try {
      // Use cache service for much faster loading
      final results = await Future.wait([
        _cacheService.getDailySpending(_focusedDay),
        _cacheService.getTransactionsForDate(_selectedDay ?? DateTime.now()),
        _cacheService.getRemindersForDate(_selectedDay ?? DateTime.now()),
      ]);

      final dailySpending = results[0] as Map<DateTime, double>;
      final selectedDayTransactions = results[1] as List<Transaction>;
      final selectedDayReminders = results[2] as List<Reminder>;

      debugPrint('CalendarPage: Loaded ${dailySpending.length} days with spending, '
          '${selectedDayTransactions.length} transactions, ${selectedDayReminders.length} reminders');

      if (mounted) {
        setState(() {
          _dailySpending = dailySpending;
          _selectedDayTransactions = selectedDayTransactions;
          _selectedDayReminders = selectedDayReminders;
        });

        // Start animations after data is loaded
        _fadeController.forward();
        _slideController.forward();

        // Preload adjacent months for faster navigation
        _cacheService.preloadAdjacentMonths(_focusedDay);
      }
    } catch (e) {
      debugPrint('CalendarPage: Error loading data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e')),
        );
      }
    }
  }

  double _getSpendingForDay(DateTime day) {
    final normalizedDay = DateTime(day.year, day.month, day.day);
    return _dailySpending[normalizedDay] ?? 0.0;
  }

  bool _hasRemindersForDay(DateTime day) {
    return _cacheService.hasRemindersForDay(day);
  }

  Set<TransactionType> _getTransactionTypesForDay(DateTime day) {
    return _cacheService.getTransactionTypesForDay(day);
  }

  Color _getColorForAmount(double amount) {
    if (amount == 0) return Colors.transparent;
    if (amount < 50) return Colors.green.withValues(alpha: 0.3);
    if (amount < 100) return Colors.yellow.withValues(alpha: 0.5);
    if (amount < 200) return Colors.orange.withValues(alpha: 0.6);
    return Colors.red.withValues(alpha: 0.7);
  }

  /// Get background decoration for a day based on transaction types
  BoxDecoration _getDayDecoration(DateTime day, {bool isSelected = false, bool isToday = false}) {
    final transactionTypes = _getTransactionTypesForDay(day);
    final amount = _getSpendingForDay(day);

    Color backgroundColor;
    if (isSelected) {
      // Selected day always gets primary color, regardless of transactions
      backgroundColor = Theme.of(context).colorScheme.primary;
    } else if (transactionTypes.isEmpty && amount == 0) {
      // No transactions - transparent background
      backgroundColor = Colors.transparent;
    } else if (transactionTypes.length == 1) {
      // Single transaction type - use type color
      backgroundColor = CategoryColors.getTransactionTypeColor(transactionTypes.first).withValues(alpha: 0.3);
    } else if (transactionTypes.length > 1) {
      // Multiple transaction types - use mixed color based on priority
      backgroundColor = _getMixedTransactionTypeColor(transactionTypes).withValues(alpha: 0.3);
    } else {
      // No transaction types but has spending - use amount-based color
      backgroundColor = _getColorForAmount(amount);
    }

    return BoxDecoration(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(8),
      border: isToday ? Border.all(color: Theme.of(context).colorScheme.primary, width: 2) : null,
    );
  }

  /// Get mixed color for multiple transaction types (prioritize expenses)
  Color _getMixedTransactionTypeColor(Set<TransactionType> types) {
    // Priority order: expense > debt > savings > income
    if (types.contains(TransactionType.expense) || types.contains(TransactionType.recurringExpense)) {
      return CategoryColors.getTransactionTypeColor(TransactionType.expense);
    } else if (types.contains(TransactionType.debt) || types.contains(TransactionType.debtPayment)) {
      return CategoryColors.getTransactionTypeColor(TransactionType.debt);
    } else if (types.contains(TransactionType.savings)) {
      return CategoryColors.getTransactionTypeColor(TransactionType.savings);
    } else {
      return CategoryColors.getTransactionTypeColor(TransactionType.income);
    }
  }

  /// Build transaction type indicators for a day
  Widget _buildTransactionTypeIndicators(Set<TransactionType> types) {
    if (types.isEmpty) return const SizedBox.shrink();

    // Show up to 4 transaction type dots (green, red, blue, orange)
    final displayTypes = types.take(4).toList();

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: displayTypes.map((type) {
        return Container(
          width: 6,
          height: 6,
          margin: const EdgeInsets.symmetric(horizontal: 1),
          decoration: BoxDecoration(
            color: CategoryColors.getTransactionTypeColor(type),
            shape: BoxShape.circle,
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: LayoutBuilder(
          builder: (context, constraints) {
            final isNarrowScreen = MediaQuery.of(context).size.width < 600;
            final isVeryNarrowScreen = MediaQuery.of(context).size.width < 400;
            final titleFontSize = isVeryNarrowScreen ? 18.0 : isNarrowScreen ? 20.0 : 22.0; // Section Heading range (18–24sp)

            return Text(
              'Calendar',
              style: TextStyle(
                color: theme.appBarTheme.foregroundColor,
                fontWeight: FontWeight.bold,
                fontSize: titleFontSize,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            );
          },
        ),
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.help_outline, color: theme.appBarTheme.foregroundColor),
            onPressed: () async {
              try {
                // Update local state to indicate tutorial is running
                setState(() {
                  _tutorialRunning = true;
                });
                
                // Save current scroll position before starting tutorial
                _tutorialScrollPosition = _scrollController.position.pixels;
                // Add listener to prevent scrolling during tutorial
                _scrollController.addListener(_preventTutorialScrolling);
                await PageTutorials.startCalendarTutorial(context, _scrollController);
              } finally {
                // Update local state to indicate tutorial has completed
                setState(() {
                  _tutorialRunning = false;
                });
                
                // Clean up when tutorial completes
                _scrollController.removeListener(_preventTutorialScrolling);
                _tutorialScrollPosition = null;
              }
            },
            tooltip: 'Show Tutorial',
          ),
          IconButton(
            icon: Icon(Icons.refresh, color: theme.appBarTheme.foregroundColor),
            onPressed: () => _loadCalendarData(),
          ),
        ],
      ),
      body: RefreshIndicator(
              onRefresh: () => _loadCalendarData(),
              child: SingleChildScrollView(
                controller: _scrollController,
                physics: (_tutorialRunning || PageTutorials.isRunning)
                    ? const NeverScrollableScrollPhysics()
                    : const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                // Calendar with smooth animations
                AnimatedBuilder(
                  animation: _fadeAnimation,
                  builder: (context, child) {
                    return FadeTransition(
                      opacity: _fadeAnimation,
                      child: SlideTransition(
                        position: _slideAnimation,
                        child: TutorialHighlight(
                          highlightKey: PageTutorials.calendarOverviewKey,
                          child: Container(
                            margin: const EdgeInsets.all(16),
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
                            child: TableCalendar<Transaction>(
                              key: PageTutorials.calendarKey,
                              firstDay: DateTime.utc(2020, 1, 1),
                              lastDay: DateTime.utc(2030, 12, 31),
                              focusedDay: _focusedDay,
                              calendarFormat: _calendarFormat,
                              // Disable page transitions during tutorial
                              pageJumpingEnabled: !PageTutorials.isRunning,
                              pageAnimationEnabled: !PageTutorials.isRunning,
                              pageAnimationDuration: const Duration(milliseconds: 300),
                              pageAnimationCurve: Curves.easeInOut,
                              selectedDayPredicate: (day) {
                                return isSameDay(_selectedDay, day);
                              },
                              onDaySelected: (selectedDay, focusedDay) async {
                                debugPrint('CalendarPage: Day selected - selected: $selectedDay, focused: $focusedDay');
                                if (!isSameDay(_selectedDay, selectedDay)) {
                                  setState(() {
                                    _selectedDay = selectedDay;
                                    _focusedDay = focusedDay;
                                  });

                                  // Use cache service for faster loading
                                  debugPrint('CalendarPage: Loading data for selected day: $selectedDay');
                                  final results = await Future.wait([
                                    _cacheService.getTransactionsForDate(selectedDay),
                                    _cacheService.getRemindersForDate(selectedDay),
                                  ]);

                                  debugPrint('CalendarPage: Loaded ${results[0].length} transactions and ${results[1].length} reminders for selected day');

                                  setState(() {
                                    _selectedDayTransactions = results[0] as List<Transaction>;
                                    _selectedDayReminders = results[1] as List<Reminder>;
                                  });
                                }
                              },
                              onFormatChanged: (format) {
                                if (_calendarFormat != format) {
                                  setState(() {
                                    _calendarFormat = format;
                                  });
                                }
                              },
                              onPageChanged: (focusedDay) async {
                                debugPrint('CalendarPage: Page changed to $focusedDay');
                                // Check if we've moved to a different month
                                final isDifferentMonth = _focusedDay.month != focusedDay.month ||
                                                  _focusedDay.year != focusedDay.year;

                                debugPrint('CalendarPage: Different month: $isDifferentMonth '
                                    '(${_focusedDay.month}/${_focusedDay.year} -> ${focusedDay.month}/${focusedDay.year})');

                                setState(() {
                                  _focusedDay = focusedDay;
                                  // Reset selected day if it's not in the current month
                                  if (_selectedDay != null &&
                                      (_selectedDay!.month != focusedDay.month || _selectedDay!.year != focusedDay.year)) {
                                    debugPrint('CalendarPage: Resetting selected day to focused day');
                                    _selectedDay = focusedDay;
                                  }
                                });


                                // If we've moved to a different month, reload data in background
                                if (isDifferentMonth) {
                                  debugPrint('CalendarPage: Invalidating cache for new month');
                                  // Invalidate cache for both the previous and new month
                                  _cacheService.invalidateMonth(_focusedDay);
                                  // Load data in background
                                  _loadCalendarData();
                                } else {
                                  // Just reload data without invalidating cache
                                  debugPrint('CalendarPage: Loading data for same month');
                                  _loadCalendarData();
                                }
                              },

                              calendarBuilders: CalendarBuilders(
                                defaultBuilder: (context, day, focusedDay) {
                                  final hasReminders = _hasRemindersForDay(day);
                                  final transactionTypes = _getTransactionTypesForDay(day);

                                  return LayoutBuilder(
                                    builder: (context, constraints) {
                                      final isNarrowScreen = MediaQuery.of(context).size.width < 600;
                                      final isVeryNarrowScreen = MediaQuery.of(context).size.width < 400;
                                      final dayFontSize = isVeryNarrowScreen ? 10.0 : isNarrowScreen ? 12.0 : 14.0; // Secondary Text range
                                      final iconSize = isVeryNarrowScreen ? 6.0 : isNarrowScreen ? 8.0 : 10.0;

                                      return Container(
                                        margin: const EdgeInsets.all(4),
                                        decoration: _getDayDecoration(day),
                                        child: Center(
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                '${day.day}',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: dayFontSize,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  if (transactionTypes.isNotEmpty)
                                                    _buildTransactionTypeIndicators(transactionTypes),
                                                  if (hasReminders && transactionTypes.isNotEmpty)
                                                    const SizedBox(width: 4),
                                                  if (hasReminders)
                                                    Icon(
                                                      Icons.push_pin,
                                                      size: iconSize,
                                                      color: theme.colorScheme.primary,
                                                    ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  );
                                },
                                selectedBuilder: (context, day, focusedDay) {
                                  final hasReminders = _hasRemindersForDay(day);
                                  final transactionTypes = _getTransactionTypesForDay(day);

                                  return LayoutBuilder(
                                    builder: (context, constraints) {
                                      final isNarrowScreen = MediaQuery.of(context).size.width < 600;
                                      final isVeryNarrowScreen = MediaQuery.of(context).size.width < 400;
                                      final dayFontSize = isVeryNarrowScreen ? 10.0 : isNarrowScreen ? 12.0 : 14.0; // Secondary Text range
                                      final iconSize = isVeryNarrowScreen ? 6.0 : isNarrowScreen ? 8.0 : 10.0;

                                      return Container(
                                        margin: const EdgeInsets.all(4),
                                        decoration: _getDayDecoration(day, isSelected: true),
                                        child: Center(
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                '${day.day}',
                                                style: TextStyle(
                                                  color: theme.colorScheme.onPrimary,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: dayFontSize,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  if (transactionTypes.isNotEmpty)
                                                    Row(
                                                      children: transactionTypes.take(4).map((type) {
                                                        return Container(
                                                          width: 6,
                                                          height: 6,
                                                          margin: const EdgeInsets.symmetric(horizontal: 1),
                                                          decoration: BoxDecoration(
                                                            color: theme.colorScheme.onPrimary,
                                                            shape: BoxShape.circle,
                                                          ),
                                                        );
                                                      }).toList(),
                                                    ),
                                                  if (hasReminders && transactionTypes.isNotEmpty)
                                                    const SizedBox(width: 4),
                                                  if (hasReminders)
                                                    Icon(
                                                      Icons.push_pin,
                                                      size: iconSize,
                                                      color: theme.colorScheme.onPrimary,
                                                    ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  );
                                },
                                todayBuilder: (context, day, focusedDay) {
                                  final hasReminders = _hasRemindersForDay(day);
                                  final transactionTypes = _getTransactionTypesForDay(day);

                                  return LayoutBuilder(
                                    builder: (context, constraints) {
                                      final isNarrowScreen = MediaQuery.of(context).size.width < 600;
                                      final isVeryNarrowScreen = MediaQuery.of(context).size.width < 400;
                                      final dayFontSize = isVeryNarrowScreen ? 10.0 : isNarrowScreen ? 12.0 : 14.0; // Secondary Text range
                                      final iconSize = isVeryNarrowScreen ? 6.0 : isNarrowScreen ? 8.0 : 10.0;

                                      return Container(
                                        margin: const EdgeInsets.all(4),
                                        decoration: _getDayDecoration(day, isToday: true),
                                        child: Center(
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                '${day.day}',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: theme.colorScheme.primary,
                                                  fontSize: dayFontSize,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  if (transactionTypes.isNotEmpty)
                                                    _buildTransactionTypeIndicators(transactionTypes),
                                                  if (hasReminders && transactionTypes.isNotEmpty)
                                                    const SizedBox(width: 4),
                                                  if (hasReminders)
                                                    Icon(
                                                      Icons.push_pin,
                                                      size: iconSize,
                                                      color: theme.colorScheme.primary,
                                                    ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  );
                                },
                              ),
                              headerStyle: HeaderStyle(
                                formatButtonVisible: true,
                                titleCentered: true,
                                formatButtonShowsNext: false,
                                headerMargin: const EdgeInsets.symmetric(vertical: 8.0),
                                titleTextStyle: TextStyle(
                                  fontSize: 14.0, // Smaller responsive size
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.onSurface,
                                ),
                                formatButtonDecoration: BoxDecoration(
                                  color: theme.colorScheme.primary,
                                  borderRadius: const BorderRadius.all(Radius.circular(12.0)),
                                ),
                                formatButtonTextStyle: TextStyle(
                                  color: theme.colorScheme.onPrimary,
                                  fontSize: 10.0, // Smaller caption size
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              calendarStyle: CalendarStyle(
                                outsideDaysVisible: false,
                                weekendTextStyle: const TextStyle(
                                  color: Colors.red,
                                  fontSize: 10.0, // Smaller consistent size
                                ),
                                holidayTextStyle: const TextStyle(
                                  color: Colors.red,
                                  fontSize: 10.0, // Smaller consistent size
                                ),
                                defaultTextStyle: TextStyle(
                                  color: theme.colorScheme.onSurface,
                                  fontSize: 10.0, // Smaller consistent size
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),

                // Selected Day Content with animations
                if (_selectedDay != null) ...[
                  const SizedBox(height: 8),
                  AnimatedBuilder(
                    animation: _fadeAnimation,
                    builder: (context, child) {
                      return FadeTransition(
                        opacity: _fadeAnimation,
                        child: SlideTransition(
                          position: _slideAnimation,
                          child: TutorialHighlight(
                            highlightKey: PageTutorials.selectedDayDetailsKey,
                            child: Container(
                              margin: const EdgeInsets.all(16),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: theme.cardTheme.color,
                                borderRadius: BorderRadius.circular(12),
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
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  LayoutBuilder(
                                    builder: (context, constraints) {
                                      final isNarrowScreen = constraints.maxWidth < 600;
                                      final fontSize = isNarrowScreen ? 16.0 : 18.0; // Body Text range

                                      return Text(
                                        'Details for ${DateFormat('MMM dd, yyyy').format(_selectedDay!)}',
                                        style: TextStyle(
                                          fontSize: fontSize,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 16),
                                  DefaultTabController(
                                    length: 2,
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        LayoutBuilder(
                                          builder: (context, constraints) {
                                            final isNarrowScreen = constraints.maxWidth < 600;
                                            final tabLabelSize = isNarrowScreen ? 14.0 : 16.0; // Body Text range

                                            return TabBar(
                                              labelColor: theme.colorScheme.primary,
                                              unselectedLabelColor: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                              indicatorColor: theme.colorScheme.primary,
                                              labelStyle: TextStyle(fontSize: tabLabelSize, fontWeight: FontWeight.w600),
                                              unselectedLabelStyle: TextStyle(fontSize: tabLabelSize),
                                              tabs: const [
                                                Tab(text: 'Transactions'),
                                                Tab(text: 'Reminders'),
                                              ],
                                            );
                                          },
                                        ),
                                        const SizedBox(height: 16),
                                        SizedBox(
                                          height: 300,
                                          child: TabBarView(
                                            children: [
                                              // Transactions Tab
                                              _selectedDayTransactions.isEmpty
                                                  ? Center(
                                                      child: Column(
                                                        mainAxisAlignment: MainAxisAlignment.center,
                                                        children: [
                                                          Icon(
                                                            Icons.receipt_long,
                                                            size: 48,
                                                            color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                                                          ),
                                                          const SizedBox(height: 16),
                                                          LayoutBuilder(
                                                            builder: (context, constraints) {
                                                              final isNarrowScreen = constraints.maxWidth < 600;
                                                              final fontSize = isNarrowScreen ? 14.0 : 16.0; // Body Text range (14–16sp)

                                                              return Text(
                                                                'No transactions on this day',
                                                                style: TextStyle(
                                                                  fontSize: fontSize,
                                                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                                                ),
                                                                maxLines: 1,
                                                                overflow: TextOverflow.ellipsis,
                                                              );
                                                            },
                                                          ),
                                                        ],
                                                      ),
                                                    )
                                                  : ListView.builder(
                                                      shrinkWrap: true,
                                                      itemCount: _selectedDayTransactions.length,
                                                      itemBuilder: (context, index) {
                                                        final transaction = _selectedDayTransactions[index];
                                                        return LayoutBuilder(
                                                          builder: (context, constraints) {
                                                            final isNarrowScreen = constraints.maxWidth < 600;
                                                            final isVeryNarrowScreen = constraints.maxWidth < 400;
                                                            final titleFontSize = isVeryNarrowScreen ? 12.0 : isNarrowScreen ? 14.0 : 16.0; // Body Text range
                                                            final subtitleFontSize = isVeryNarrowScreen ? 10.0 : isNarrowScreen ? 12.0 : 14.0; // Secondary Text range
                                                            final amountFontSize = isVeryNarrowScreen ? 11.0 : isNarrowScreen ? 13.0 : 15.0; // Between Secondary and Body

                                                            return ListTile(
                                                              leading: CircleAvatar(
                                                                backgroundColor: CategoryColors.getTransactionTypeColor(transaction.type).withValues(alpha: 0.2),
                                                                child: Icon(
                                                                  CategoryColors.getCategoryIcon(transaction.category),
                                                                  color: CategoryColors.getTransactionTypeColor(transaction.type),
                                                                  size: isVeryNarrowScreen ? 14 : isNarrowScreen ? 18 : 20,
                                                                ),
                                                              ),
                                                              title: Text(
                                                                transaction.description,
                                                                style: TextStyle(fontSize: titleFontSize),
                                                                maxLines: 1,
                                                                overflow: TextOverflow.ellipsis,
                                                              ),
                                                              subtitle: Row(
                                                                children: [
                                                                  Container(
                                                                    width: 8,
                                                                    height: 8,
                                                                    decoration: BoxDecoration(
                                                                      color: CategoryColors.getTransactionTypeColor(transaction.type),
                                                                      shape: BoxShape.circle,
                                                                    ),
                                                                  ),
                                                                  const SizedBox(width: 6),
                                                                  Expanded(
                                                                    child: Text(
                                                                      transaction.category,
                                                                      style: TextStyle(fontSize: subtitleFontSize),
                                                                      maxLines: 1,
                                                                      overflow: TextOverflow.ellipsis,
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                              trailing: Text(
                                                                transaction.formattedAmount,
                                                                style: TextStyle(
                                                                  fontWeight: FontWeight.bold,
                                                                  fontSize: amountFontSize,
                                                                  color: CategoryColors.getTransactionTypeColor(transaction.type),
                                                                ),
                                                                maxLines: 1,
                                                                overflow: TextOverflow.ellipsis,
                                                              ),
                                                            );
                                                          },
                                                        );
                                                      },
                                                    ),
                                              // Reminders Tab
                                              _selectedDayReminders.isEmpty
                                                  ? Center(
                                                      child: Column(
                                                        mainAxisAlignment: MainAxisAlignment.center,
                                                        children: [
                                                          Icon(
                                                            Icons.notifications_none,
                                                            size: 48,
                                                            color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                                                          ),
                                                          const SizedBox(height: 16),
                                                          LayoutBuilder(
                                                            builder: (context, constraints) {
                                                              final isNarrowScreen = constraints.maxWidth < 600;
                                                              final fontSize = isNarrowScreen ? 14.0 : 16.0; // Body Text range (14–16sp)

                                                              return Text(
                                                                'No reminders on this day',
                                                                style: TextStyle(
                                                                  fontSize: fontSize,
                                                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                                                ),
                                                                maxLines: 1,
                                                                overflow: TextOverflow.ellipsis,
                                                              );
                                                            },
                                                          ),
                                                        ],
                                                      ),
                                                    )
                                                  : ListView.builder(
                                                      shrinkWrap: true,
                                                      itemCount: _selectedDayReminders.length,
                                                      itemBuilder: (context, index) {
                                                        final reminder = _selectedDayReminders[index];
                                                        return LayoutBuilder(
                                                          builder: (context, constraints) {
                                                            final isNarrowScreen = constraints.maxWidth < 600;
                                                            final isVeryNarrowScreen = constraints.maxWidth < 400;
                                                            final titleFontSize = isVeryNarrowScreen ? 12.0 : isNarrowScreen ? 14.0 : 16.0; // Body Text range
                                                            final subtitleFontSize = isVeryNarrowScreen ? 10.0 : isNarrowScreen ? 12.0 : 14.0; // Secondary Text range
                                                            final iconSize = isVeryNarrowScreen ? 16.0 : isNarrowScreen ? 20.0 : 24.0;

                                                            return Card(
                                                              margin: const EdgeInsets.only(bottom: 8),
                                                              child: ListTile(
                                                                leading: Text(
                                                                  reminder.typeIcon,
                                                                  style: TextStyle(fontSize: iconSize),
                                                                ),
                                                                title: Text(
                                                                  reminder.title,
                                                                  style: TextStyle(
                                                                    fontSize: titleFontSize,
                                                                    decoration: reminder.isCompleted
                                                                        ? TextDecoration.lineThrough
                                                                        : null,
                                                                  ),
                                                                  maxLines: 1,
                                                                  overflow: TextOverflow.ellipsis,
                                                                ),
                                                                subtitle: Column(
                                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                                  mainAxisSize: MainAxisSize.min,
                                                                  children: [
                                                                    Text(
                                                                      reminder.description,
                                                                      style: TextStyle(fontSize: subtitleFontSize),
                                                                      maxLines: 2,
                                                                      overflow: TextOverflow.ellipsis,
                                                                    ),
                                                                    const SizedBox(height: 4),
                                                                    Wrap(
                                                                      spacing: 8,
                                                                      children: [
                                                                        Container(
                                                                          padding: const EdgeInsets.symmetric(
                                                                            horizontal: 8,
                                                                            vertical: 2,
                                                                          ),
                                                                          decoration: BoxDecoration(
                                                                            color: Colors.teal.withValues(alpha: 0.1),
                                                                            borderRadius: BorderRadius.circular(12),
                                                                          ),
                                                                          child: Text(
                                                                            reminder.typeDisplayName,
                                                                            style: TextStyle(
                                                                              fontSize: isVeryNarrowScreen ? 8.0 : isNarrowScreen ? 10.0 : 12.0, // Captions range
                                                                              color: Colors.teal,
                                                                            ),
                                                                            maxLines: 1,
                                                                            overflow: TextOverflow.ellipsis,
                                                                          ),
                                                                        ),
                                                                        if (reminder.recurrence != RecurrenceType.single)
                                                                          Container(
                                                                            padding: const EdgeInsets.symmetric(
                                                                              horizontal: 8,
                                                                              vertical: 2,
                                                                            ),
                                                                            decoration: BoxDecoration(
                                                                              color: Colors.purple.withValues(alpha: 0.1),
                                                                              borderRadius: BorderRadius.circular(12),
                                                                            ),
                                                                            child: Text(
                                                                              reminder.recurrenceDisplayName,
                                                                              style: TextStyle(
                                                                                fontSize: isVeryNarrowScreen ? 8.0 : isNarrowScreen ? 10.0 : 12.0, // Captions range
                                                                                color: Colors.purple,
                                                                              ),
                                                                              maxLines: 1,
                                                                              overflow: TextOverflow.ellipsis,
                                                                            ),
                                                                          ),
                                                                      ],
                                                                    ),
                                                                  ],
                                                                ),
                                                                trailing: reminder.isCompleted
                                                                    ? const Icon(Icons.check_circle, color: Colors.green)
                                                                    : IconButton(
                                                                        icon: const Icon(Icons.check),
                                                                        onPressed: () => _markReminderCompleted(reminder.id),
                                                                      ),
                                                              ),
                                                            );
                                                          },
                                                        );
                                                      },
                                                    ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
                  ],
                ),
              ),
            ),
      floatingActionButton: TutorialHighlight(
        highlightKey: PageTutorials.addReminderKey,
        child: FloatingActionButton(
          key: PageTutorials.addReminderKey,
          onPressed: _showAddReminderModal,
          backgroundColor: theme.colorScheme.primary,
          child: Icon(Icons.add_alert, color: theme.colorScheme.onPrimary),
        ),
      ),
    );
  }

  Future<void> _showAddReminderModal() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AddReminderModal(
          selectedDate: _selectedDay ?? DateTime.now(),
          onReminderAdded: () {
            // Invalidate cache for the current month
            _cacheService.invalidateMonth(_selectedDay ?? DateTime.now());
            _loadCalendarData();
          },
        ),
      ),
    );
  }

  Future<void> _markReminderCompleted(String reminderId) async {
    await FirebaseService.markReminderAsCompleted(reminderId);
    _loadCalendarData();
  }

  // Removed automatic tutorial start - users can click the help button to start tutorial

}
