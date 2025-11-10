import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/transaction.dart';
import '../services/transaction_service.dart';
import '../services/firebase_service.dart';
import '../services/transaction_notifier.dart';
import '../services/data_cache_service.dart';
import '../services/user_notifier.dart';
import '../services/real_time_update_service.dart';
import '../widgets/transaction_card.dart';
import '../widgets/timeframe_filter.dart';
import '../widgets/page_tutorials.dart';
import '../widgets/custom_tutorial.dart';
import '../widgets/tutorial_cleanup.dart';

class TransactionsPage extends StatefulWidget {
  const TransactionsPage({super.key});

  @override
  State<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends State<TransactionsPage> with TickerProviderStateMixin {
  List<Transaction> _transactions = [];
  Map<String, List<Transaction>> _transactionsByDate = {};
  bool _isLoading = true;
  String _searchQuery = '';
  TransactionType? _selectedType;
  TimeFrame _selectedTimeFrame = TimeFrame.monthly;
  DateTime _selectedDate = DateTime.now();

  // Animation controller for smooth delete animations
  late AnimationController _deleteAnimationController;

  // Transaction notifier for real-time updates
  final TransactionNotifier _transactionNotifier = TransactionNotifier();
  final DataCacheService _cacheService = DataCacheService();

  // User notifier for profile updates
  final UserNotifier _userNotifier = UserNotifier();

  // Scroll controller for tutorial scrolling
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _deleteAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    // Listen for transaction changes for real-time updates
    _transactionNotifier.addListener(_onTransactionChanged);

    _loadTransactions();

    // Removed automatic tutorial start - users can click the help button to start tutorial
  }
  
  // Removed automatic tutorial start - users can click the help button to start tutorial

  @override
  void dispose() {
    _deleteAnimationController.dispose();
    _scrollController.dispose();
    _transactionNotifier.removeListener(_onTransactionChanged);
    super.dispose();
  }

  /// Called when transaction notifier signals a change
  void _onTransactionChanged() {
    if (mounted) {
      // Transaction change detected, refreshing data
      // Invalidate cache for the current month
      _cacheService.invalidateMonth(_selectedDate);
      _loadTransactions(useCache: false);
    }
  }

  Future<void> _loadTransactions({bool useCache = false}) async {
    // Don't show loading if we're using cache (for faster UI updates)
    if (!useCache) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final startDate = TimeFrameHelper.getStartDate(_selectedTimeFrame, _selectedDate);
      final endDate = TimeFrameHelper.getEndDate(_selectedTimeFrame, _selectedDate);

      List<Transaction> transactions;
      if (_selectedTimeFrame == TimeFrame.monthly) {
        transactions = await TransactionService.getTransactionsByMonth(
          _selectedDate.year,
          _selectedDate.month
        );
      } else {
        transactions = await TransactionService.getTransactionsByDateRange(startDate, endDate);
      }

      // Filter by type if selected
      if (_selectedType != null) {
        transactions = transactions.where((t) => t.type == _selectedType).toList();
      }

      // Filter by search query
      if (_searchQuery.isNotEmpty) {
        transactions = transactions.where((t) =>
          t.description.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          t.category.toLowerCase().contains(_searchQuery.toLowerCase())
        ).toList();
      }

      // Hide income transactions that are related to emergency fund withdrawals
      // These are duplicates of the emergencyFundWithdrawal transactions
      transactions = transactions.where((t) => 
        !(t.type == TransactionType.income && t.category == 'Emergency Fund Withdrawal')
      ).toList();
      
      // Hide income transactions that are related to debt transactions
      // These are duplicates of the debt transactions
      transactions = transactions.where((t) => 
        !(t.type == TransactionType.income && t.category == 'Debt Income')
      ).toList();

      // Sort by date (newest first)
      transactions.sort((a, b) => b.date.compareTo(a.date));

      // Group by date more efficiently
      final groupedTransactions = <String, List<Transaction>>{};
      for (final transaction in transactions) {
        final dateKey = DateFormat('yyyy-MM-dd').format(transaction.date);
        groupedTransactions.putIfAbsent(dateKey, () => []).add(transaction);
      }

      setState(() {
        _transactions = transactions;
        _transactionsByDate = groupedTransactions;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        // Responsive error message sizing
        final screenWidth = MediaQuery.of(context).size.width;
        final isNarrowScreen = screenWidth < 600;
        final errorFontSize = isNarrowScreen ? 12.0 : 14.0; // Secondary Text range

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.warning, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Some transactions may not be up to date',
                    style: TextStyle(fontSize: errorFontSize),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  )
                ),
              ],
            ),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _showFilterOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => LayoutBuilder(
        builder: (context, constraints) {
          // Determine responsive layout parameters
          final isNarrowScreen = constraints.maxWidth < 600;

          // Responsive sizing following typography standards
          final titleFontSize = isNarrowScreen ? 16.0 : 18.0; // Subheading range (16–20sp)
          final containerPadding = isNarrowScreen ? 12.0 : 16.0;
          final spacingAfterTitle = isNarrowScreen ? 12.0 : 16.0;
          final spacingAfterFilters = isNarrowScreen ? 12.0 : 16.0;

          return Container(
            padding: EdgeInsets.all(containerPadding),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Filter by Type',
                  style: TextStyle(
                    fontSize: titleFontSize,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: spacingAfterTitle),
                Wrap(
                  spacing: 8,
                  children: [
                    _buildFilterChip('All', _selectedType == null, () {
                      setState(() {
                        _selectedType = null;
                      });
                      Navigator.pop(context);
                      _loadTransactions();
                    }),
                    ...TransactionType.values.map((type) => _buildFilterChip(
                      _getTransactionTypeDisplayName(type),
                      _selectedType == type,
                      () {
                        setState(() {
                          _selectedType = type;
                        });
                        Navigator.pop(context);
                        _loadTransactions();
                      },
                    )),
                  ],
                ),
                SizedBox(height: spacingAfterFilters),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isSelected, VoidCallback onTap) {
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onTap(),
      selectedColor: Colors.teal.withValues(alpha: 0.2),
      checkmarkColor: Colors.teal,
      backgroundColor: Colors.transparent, // Ensure unselected chips have a transparent background
      showCheckmark: true, // Always show checkmark for clarity
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text(
          'Transactions',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.help_outline, color: theme.appBarTheme.foregroundColor),
            onPressed: () => PageTutorials.startTransactionsTutorial(context, _scrollController),
            tooltip: 'Show Tutorial',
          ),
          TutorialHighlight(
            highlightKey: InteractiveTutorial.filterButtonKey,
            child: Stack(
              children: [
                IconButton(
                  icon: Icon(
                    Icons.filter_list,
                    color: theme.appBarTheme.foregroundColor, // Keep original theme color
                    size: 22,
                  ),
                  onPressed: _showFilterOptions,
                  padding: const EdgeInsets.all(8),
                  constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                ),
                // Add a small indicator dot when filter is active
                if (_selectedType != null)
                  Positioned(
                    right: 10,
                    top: 10,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.white, // Use teal for the indicator dot
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, size: 22),
            onPressed: _loadTransactions,
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Determine responsive layout parameters
          final isNarrowScreen = constraints.maxWidth < 600;
          final isVeryNarrowScreen = constraints.maxWidth < 400;
          final isExtremelyNarrowScreen = constraints.maxWidth < 320;
          final isUltraNarrowScreen = constraints.maxWidth < 280; // Added for ultra narrow screens

          // Responsive sizing following typography standards
          final searchHintFontSize = isUltraNarrowScreen ? 10.0 : isNarrowScreen ? 11.0 : 12.0; // Secondary Text range (10–12sp)
          final noDataTitleFontSize = isUltraNarrowScreen ? 14.0 : isNarrowScreen ? 15.0 : 16.0; // Subheading range (14–16sp)
          final noDataSubtitleFontSize = isUltraNarrowScreen ? 10.0 : isNarrowScreen ? 11.0 : 12.0; // Secondary Text range
          final dateHeaderFontSize = isUltraNarrowScreen ? 12.0 : isNarrowScreen ? 13.0 : 14.0; // Body Text range (12–14sp)
          final transactionCountFontSize = isUltraNarrowScreen ? 8.0 : isNarrowScreen ? 9.0 : 10.0; // Captions range (8–10sp)
          final noDataIconSize = isUltraNarrowScreen ? 48.0 : isNarrowScreen ? 52.0 : 56.0;
          final searchPadding = isUltraNarrowScreen ? 10.0 : isNarrowScreen ? 11.0 : 12.0;

          return Column(
            children: [
              // Search bar
              TutorialHighlight(
                highlightKey: InteractiveTutorial.searchBarKey,
                child: Container(
                  key: InteractiveTutorial.searchBarKey,
                  padding: EdgeInsets.symmetric(horizontal: searchPadding, vertical: 8),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: isVeryNarrowScreen ? 'Search...' : 'Search transactions...',
                      hintStyle: TextStyle(fontSize: searchHintFontSize),
                      prefixIcon: const Icon(Icons.search, size: 20),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: theme.cardColor,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    style: TextStyle(fontSize: searchHintFontSize),
                    onChanged: (value) {
                      setState(() => _searchQuery = value);
                      _loadTransactions();
                    },
                  ),
                ),
              ),

              // Time frame filter
              TutorialHighlight(
                highlightKey: InteractiveTutorial.timeFrameFilterKey,
                child: TimeFrameFilter(
                  key: InteractiveTutorial.timeFrameFilterKey,
                  selectedTimeFrame: _selectedTimeFrame,
                  onTimeFrameChanged: (timeFrame) {
                    setState(() {
                      _selectedTimeFrame = timeFrame;
                      _selectedDate = DateTime.now(); // Reset to current date
                    });
                    _loadTransactions();
                  },
                ),
              ),

              // Time frame navigator
              TimeFrameNavigator(
                timeFrame: _selectedTimeFrame,
                currentDate: _selectedDate,
                onDateChanged: (date) {
                  setState(() {
                    _selectedDate = date;
                  });
                  _loadTransactions();
                },
              ),

              // Small gap before transactions list
              const SizedBox(height: 8),

              // Transactions list
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _transactions.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.receipt_long,
                                  size: noDataIconSize,
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No transactions found',
                                  style: TextStyle(
                                    fontSize: noDataTitleFontSize,
                                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _searchQuery.isNotEmpty || _selectedType != null
                                      ? isVeryNarrowScreen
                                          ? 'Try adjusting filters'
                                          : 'Try adjusting your filters'
                                      : isVeryNarrowScreen
                                          ? 'Add your first transaction'
                                          : 'Start by adding your first transaction',
                                  style: TextStyle(
                                    fontSize: noDataSubtitleFontSize,
                                    color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: isVeryNarrowScreen ? 2 : 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          )
                        : TutorialHighlight(
                            highlightKey: InteractiveTutorial.transactionsListKey,
                            child: RefreshIndicator(
                              onRefresh: _loadTransactions,
                              child: ListView.builder(
                                controller: _scrollController,
                                padding: EdgeInsets.symmetric(horizontal: searchPadding),
                                itemCount: _transactionsByDate.keys.length,
                                itemBuilder: (context, index) {
                                  final dateKey = _transactionsByDate.keys.elementAt(index);
                                  final dateTransactions = _transactionsByDate[dateKey]!;
                                  final date = DateTime.parse(dateKey);

                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Date header
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                          horizontal: 16,
                                        ),
                                        margin: EdgeInsets.only(
                                          top: index == 0 ? 8 : 16,
                                          bottom: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          color: theme.colorScheme.primary.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: theme.colorScheme.primary.withValues(alpha: 0.2),
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                _formatDateHeader(date),
                                                style: TextStyle(
                                                  fontSize: dateHeaderFontSize,
                                                  fontWeight: FontWeight.bold,
                                                  color: theme.colorScheme.primary,
                                                ),
                                                maxLines: isVeryNarrowScreen ? 2 : 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 4,
                                              ),
                                              decoration: BoxDecoration(
                                                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: Text(
                                                isVeryNarrowScreen
                                                    ? '${dateTransactions.length}'
                                                    : '${dateTransactions.length} transaction${dateTransactions.length == 1 ? '' : 's'}',
                                                style: TextStyle(
                                                  fontSize: transactionCountFontSize,
                                                  fontWeight: FontWeight.w500,
                                                  color: theme.colorScheme.primary,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),

                                      // Transactions for this date with smooth animation
                                      ...dateTransactions.map<Widget>((transaction) {
                                        return AnimatedContainer(
                                          duration: const Duration(milliseconds: 200),
                                          curve: Curves.easeInOut,
                                          margin: const EdgeInsets.only(bottom: 8),
                                          child: SlideTransition(
                                            position: Tween<Offset>(
                                              begin: const Offset(0, 0),
                                              end: const Offset(0, 0),
                                            ).animate(CurvedAnimation(
                                              parent: _deleteAnimationController,
                                              curve: Curves.easeInOut,
                                            )),
                                            child: FadeTransition(
                                              opacity: Tween<double>(
                                                begin: 1.0,
                                                end: 1.0,
                                              ).animate(_deleteAnimationController),
                                              child: TransactionCard(
                                                transaction: transaction,
                                                onTap: () => _showTransactionDetails(transaction),
                                              ),
                                            ),
                                          ),
                                        );
                                      }),
                                    ],
                                  );
                                },
                              ),
                            ),
                          ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _formatDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final transactionDate = DateTime(date.year, date.month, date.day);

    if (transactionDate == today) {
      return 'Today, ${DateFormat('MMM dd').format(date)}';
    } else if (transactionDate == yesterday) {
      return 'Yesterday, ${DateFormat('MMM dd').format(date)}';
    } else if (now.year == date.year) {
      return DateFormat('EEEE, MMM dd').format(date);
    } else {
      return DateFormat('EEEE, MMM dd, yyyy').format(date);
    }
  }

  void _showTransactionDetails(Transaction transaction) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => LayoutBuilder(
        builder: (context, constraints) {
          // Determine responsive layout parameters
          final isNarrowScreen = constraints.maxWidth < 600;
          final isVeryNarrowScreen = constraints.maxWidth < 400;
          final screenHeight = MediaQuery.of(context).size.height;
          final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

          // Responsive sizing following typography standards
          final titleFontSize = isNarrowScreen ? 16.0 : 18.0; // Subheading range (16–20sp)
          final labelFontSize = isNarrowScreen ? 12.0 : 14.0; // Secondary Text range (12–14sp)
          final valueFontSize = isNarrowScreen ? 14.0 : 16.0; // Body Text range (14–16sp)
          final containerPadding = isNarrowScreen ? 12.0 : 16.0;

          // Calculate responsive modal height with better handling for small screens
          final isExtremelyNarrowScreen = constraints.maxWidth < 320;
          final maxHeight = isExtremelyNarrowScreen
              ? screenHeight * 0.75  // 75% for extremely narrow screens
              : isVeryNarrowScreen
                  ? screenHeight * 0.7  // 70% for very narrow screens
                  : isNarrowScreen
                      ? screenHeight * 0.65  // 65% for narrow screens
                      : screenHeight * 0.6;  // 60% for standard screens

          return Container(
            constraints: BoxConstraints(
              maxHeight: maxHeight,
              minHeight: isExtremelyNarrowScreen ? 250 : isVeryNarrowScreen ? 300 : 350,
            ),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Container(
                  width: 32,
                  height: 3,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // Header
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: containerPadding, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          isVeryNarrowScreen ? 'Details' : 'Transaction Details',
                          style: TextStyle(
                            fontSize: titleFontSize,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(
                              Icons.delete,
                              color: Colors.red,
                              size: isNarrowScreen ? 20 : 22,
                            ),
                            onPressed: () {
                              Navigator.pop(context);
                              _deleteTransaction(transaction);
                            },
                            padding: EdgeInsets.all(isNarrowScreen ? 6 : 8),
                            constraints: BoxConstraints(
                              minWidth: isNarrowScreen ? 36 : 40,
                              minHeight: isNarrowScreen ? 36 : 40
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.close,
                              size: isNarrowScreen ? 20 : 22
                            ),
                            onPressed: () => Navigator.pop(context),
                            padding: EdgeInsets.all(isNarrowScreen ? 6 : 8),
                            constraints: BoxConstraints(
                              minWidth: isNarrowScreen ? 36 : 40,
                              minHeight: isNarrowScreen ? 36 : 40
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const Divider(height: 1),

                // Transaction details - Scrollable content with better height handling
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(
                      horizontal: containerPadding,
                      vertical: isNarrowScreen ? 8 : 12
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildDetailRow('Amount', transaction.formattedAmount, labelFontSize, valueFontSize),
                        _buildDetailRow('Type', transaction.typeDisplayName, labelFontSize, valueFontSize),
                        _buildDetailRow('Category', transaction.category, labelFontSize, valueFontSize),
                        _buildDetailRow('Description', transaction.description, labelFontSize, valueFontSize),
                        _buildDetailRow('Date', transaction.formattedDate, labelFontSize, valueFontSize),
                        // Add extra padding to ensure last item is visible and account for keyboard
                        SizedBox(height: isExtremelyNarrowScreen ? 15 : isNarrowScreen ? 20 : 30 + bottomPadding),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, [double labelFontSize = 14.0, double valueFontSize = 16.0]) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Determine if we need to stack vertically for very narrow screens
        final isExtremelyNarrowScreen = constraints.maxWidth < 280;
        final isVeryNarrowScreen = constraints.maxWidth < 300;
        final containerPadding = isExtremelyNarrowScreen ? 10.0 : isVeryNarrowScreen ? 12.0 : 16.0;
        final labelWidth = isExtremelyNarrowScreen ? 70.0 : isVeryNarrowScreen ? 80.0 : 100.0;
        final spacing = isExtremelyNarrowScreen ? 6.0 : isVeryNarrowScreen ? 8.0 : 16.0;

        return Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(horizontal: containerPadding, vertical: 12),
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
              width: 0.5,
            ),
          ),
          child: isExtremelyNarrowScreen
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: labelFontSize,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: valueFontSize,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                )
              : isVeryNarrowScreen
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: labelFontSize,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          value,
                          style: TextStyle(
                            fontSize: valueFontSize,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: labelWidth,
                          child: Text(
                            label,
                            style: TextStyle(
                              fontSize: labelFontSize,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        SizedBox(width: spacing),
                        Expanded(
                          child: Text(
                            value,
                            style: TextStyle(
                              fontSize: valueFontSize,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
        );
      },
    );
  }

  void _deleteTransaction(Transaction transaction) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return LayoutBuilder(
          builder: (context, constraints) {
            // Determine responsive layout parameters
            final isNarrowScreen = constraints.maxWidth < 600;
            final isVeryNarrowScreen = constraints.maxWidth < 400;

            // Responsive sizing following typography standards
            final titleFontSize = isNarrowScreen ? 16.0 : 18.0; // Subheading range (16–20sp)
            final contentFontSize = isNarrowScreen ? 12.0 : 14.0; // Secondary Text range (12–14sp)
            final transactionNameFontSize = isNarrowScreen ? 14.0 : 16.0; // Body Text range (14–16sp)
            final transactionAmountFontSize = isNarrowScreen ? 16.0 : 18.0; // Subheading range

            return AlertDialog(
              title: Text(
                'Delete Transaction',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: titleFontSize,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isVeryNarrowScreen
                        ? 'Delete this transaction?'
                        : 'Are you sure you want to delete this transaction?',
                    style: TextStyle(fontSize: contentFontSize),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          transaction.description,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: transactionNameFontSize,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          transaction.formattedAmount,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: transactionAmountFontSize,
                            color: transaction.type == TransactionType.income
                              ? Colors.green
                              : Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.of(context).pop();
                    await _performDeleteOptimized(transaction);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Delete'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _performDeleteOptimized(Transaction transaction) async {
    // Store original state for rollback
    final originalTransactions = List<Transaction>.from(_transactions);
    final originalTransactionsByDate = Map<String, List<Transaction>>.from(_transactionsByDate);

    // Animate out and remove from UI immediately (optimistic update)
    await _deleteAnimationController.forward();

    setState(() {
      _transactions.removeWhere((t) => t.id == transaction.id);

      // Update grouped transactions
      final dateKey = DateFormat('yyyy-MM-dd').format(transaction.date);
      if (_transactionsByDate.containsKey(dateKey)) {
        _transactionsByDate[dateKey]!.removeWhere((t) => t.id == transaction.id);
        if (_transactionsByDate[dateKey]!.isEmpty) {
          _transactionsByDate.remove(dateKey);
        }
      }
    });

    // Reset animation for future use
    _deleteAnimationController.reset();

    // Show minimal loading feedback (non-blocking) with responsive sizing
    if (mounted) {
      final screenWidth = MediaQuery.of(context).size.width;
      final isNarrowScreen = screenWidth < 600;
      final feedbackFontSize = isNarrowScreen ? 12.0 : 14.0; // Secondary Text range

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Deleting...',
                style: TextStyle(fontSize: feedbackFontSize)
              ),
            ],
          ),
          duration: const Duration(milliseconds: 1500),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          backgroundColor: Colors.grey[700],
        ),
      );
    }

    try {
      // Perform actual deletion in background
      await TransactionService.deleteTransaction(transaction);

      // Handle emergency fund synchronization if this is an emergency fund transaction
      // This will also handle cache invalidation for related transactions
      await _handleEmergencyFundSync(transaction);

      // Invalidate cache for the month containing this transaction
      _cacheService.invalidateMonth(transaction.date);

      // Show quick success feedback with responsive sizing
      if (mounted) {
        final screenWidth = MediaQuery.of(context).size.width;
        final isNarrowScreen = screenWidth < 600;
        final successFontSize = isNarrowScreen ? 12.0 : 14.0; // Secondary Text range

        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Deleted',
                  style: TextStyle(fontSize: successFontSize)
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(milliseconds: 800),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } catch (e) {
      // Hide loading snackbar
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
      }

      // Rollback UI changes with animation
      setState(() {
        _transactions = originalTransactions;
        _transactionsByDate = originalTransactionsByDate;
      });

      // Show error with retry option and responsive sizing
      String errorMessage = 'Delete failed';
      if (e.toString().contains('timeout')) {
        errorMessage = 'Connection timeout';
      } else if (e.toString().contains('network') || e.toString().contains('connection')) {
        errorMessage = 'Network error';
      } else if (e.toString().contains('not authenticated')) {
        errorMessage = 'Authentication error';
      } else if (e.toString().contains('not found')) {
        errorMessage = 'Transaction not found';
      }

      if (mounted) {
        final screenWidth = MediaQuery.of(context).size.width;
        final isNarrowScreen = screenWidth < 600;
        final errorFontSize = isNarrowScreen ? 12.0 : 14.0; // Secondary Text range

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    errorMessage,
                    style: TextStyle(fontSize: errorFontSize),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () => _performDeleteOptimized(transaction),
            ),
          ),
        );
      }

      // Error logged internally
    }
  }

  /// Handle emergency fund synchronization when deleting emergency fund transactions
  Future<void> _handleEmergencyFundSync(Transaction transaction) async {
    // Check if this is an emergency fund transaction
    if (transaction.type == TransactionType.emergencyFund ||
        transaction.type == TransactionType.emergencyFundWithdrawal) {

      try {
        final user = await FirebaseService.getUser();
        if (user == null) {
          // Warning: User not found for emergency fund sync
          return;
        }

        final currentEmergencyFund = user.emergencyFundAmount ?? 0.0;
        double newEmergencyFund;

        if (transaction.type == TransactionType.emergencyFund) {
          // Deleting an emergency fund deposit - subtract from balance
          newEmergencyFund = currentEmergencyFund - transaction.amount;
        } else {
          // Deleting an emergency fund withdrawal - add back to balance
          newEmergencyFund = currentEmergencyFund + transaction.amount;
        }

        // Ensure the emergency fund doesn't go below zero
        final updatedEmergencyFund = newEmergencyFund < 0 ? 0.0 : newEmergencyFund;

        final updatedUser = user.copyWith(
          emergencyFundAmount: updatedEmergencyFund,
        );

        await FirebaseService.saveUser(updatedUser);
        // Emergency fund synced after deletion: ₱${updatedEmergencyFund.toStringAsFixed(2)}

        // Notify listeners about emergency fund update
        _userNotifier.notifyEmergencyFundUpdated();

      } catch (e) {
        // Error syncing emergency fund on deletion: $e
        // Non-blocking error - transaction deletion should still succeed
      }
    }
    
    // Special handling for emergency fund withdrawal deletions
    // When deleting an emergency fund withdrawal, we also need to delete the corresponding income transaction
    if (transaction.type == TransactionType.emergencyFundWithdrawal) {
      try {
        // Find and delete the corresponding income transaction
        // The income transaction would have been created with the same date and amount
        final allTransactions = await TransactionService.getAllTransactions();
        final correspondingIncomeTransaction = allTransactions.firstWhere(
          (t) => t.type == TransactionType.income &&
                 t.amount == transaction.amount &&
                 t.date.isAtSameMomentAs(transaction.date) &&
                 t.category == 'Emergency Fund Withdrawal',
          orElse: () => transaction, // Fallback to avoid errors
        );
        
        // Delete the corresponding income transaction if found and it's not the same transaction
        if (correspondingIncomeTransaction.id != transaction.id) {
          await TransactionService.deleteTransaction(correspondingIncomeTransaction);
          
          // Invalidate cache for the month containing the corresponding income transaction
          _cacheService.invalidateMonth(correspondingIncomeTransaction.date);
        }
      } catch (e) {
        // Error deleting corresponding income transaction: $e
        // Continue with the main transaction deletion
      }
    }
    
    // Special handling for income transactions related to emergency fund withdrawals
    // When deleting an income transaction that was created for an emergency fund withdrawal,
    // we also need to delete the corresponding emergencyFundWithdrawal transaction
    if (transaction.type == TransactionType.income && transaction.category == 'Emergency Fund Withdrawal') {
      try {
        // Find and delete the corresponding emergency fund withdrawal transaction
        // The emergency fund withdrawal transaction would have been created with the same date and amount
        final allTransactions = await TransactionService.getAllTransactions();
        final correspondingWithdrawalTransaction = allTransactions.firstWhere(
          (t) => t.type == TransactionType.emergencyFundWithdrawal &&
                 t.amount == transaction.amount &&
                 t.date.isAtSameMomentAs(transaction.date),
          orElse: () => transaction, // Fallback to avoid errors
        );
        
        // Delete the corresponding emergency fund withdrawal transaction if found and it's not the same transaction
        if (correspondingWithdrawalTransaction.id != transaction.id) {
          await TransactionService.deleteTransaction(correspondingWithdrawalTransaction);
          
          // Invalidate cache for the month containing the corresponding withdrawal transaction
          _cacheService.invalidateMonth(correspondingWithdrawalTransaction.date);
        }
      } catch (e) {
        // Error deleting corresponding emergency fund withdrawal transaction: $e
        // Continue with the main transaction deletion
      }
    }
    
    // Special handling for debt deletions
    // When deleting a debt transaction, we also need to delete the corresponding income transaction
    if (transaction.type == TransactionType.debt) {
      try {
        // Find and delete the corresponding income transaction
        // The income transaction would have been created with the same date and amount
        final allTransactions = await TransactionService.getAllTransactions();
        final correspondingIncomeTransaction = allTransactions.firstWhere(
          (t) => t.type == TransactionType.income &&
                 t.amount == transaction.amount &&
                 t.date.isAtSameMomentAs(transaction.date) &&
                 t.category == 'Debt Income',
          orElse: () => transaction, // Fallback to avoid errors
        );
        
        // Delete the corresponding income transaction if found and it's not the same transaction
        if (correspondingIncomeTransaction.id != transaction.id) {
          await TransactionService.deleteTransaction(correspondingIncomeTransaction);
          
          // Invalidate cache for the month containing the corresponding income transaction
          _cacheService.invalidateMonth(correspondingIncomeTransaction.date);
        }
      } catch (e) {
        // Error deleting corresponding income transaction: $e
        // Continue with the main transaction deletion
      }
    }
    
    // Special handling for income transactions related to debt
    // When deleting an income transaction that was created for a debt transaction,
    // we also need to delete the corresponding debt transaction
    if (transaction.type == TransactionType.income && transaction.category == 'Debt Income') {
      try {
        // Find and delete the corresponding debt transaction
        // The debt transaction would have been created with the same date and amount
        final allTransactions = await TransactionService.getAllTransactions();
        final correspondingDebtTransaction = allTransactions.firstWhere(
          (t) => t.type == TransactionType.debt &&
                 t.amount == transaction.amount &&
                 t.date.isAtSameMomentAs(transaction.date),
          orElse: () => transaction, // Fallback to avoid errors
        );
        
        // Delete the corresponding debt transaction if found and it's not the same transaction
        if (correspondingDebtTransaction.id != transaction.id) {
          await TransactionService.deleteTransaction(correspondingDebtTransaction);
          
          // Invalidate cache for the month containing the corresponding debt transaction
          _cacheService.invalidateMonth(correspondingDebtTransaction.date);
        }
      } catch (e) {
        // Error deleting corresponding debt transaction: $e
        // Continue with the main transaction deletion
      }
    }
    
    // For expense transactions, update the max monthly expense
    // This ensures that when large expense transactions are deleted, the max is properly recalculated
    if (transaction.type == TransactionType.expense || transaction.type == TransactionType.recurringExpense) {
      // Update max monthly expense in the background
      _updateMaxMonthlyExpense(transaction.date);
    }
  }
  
  /// Update max monthly expense by recalculating from historical data
  /// This ensures that when large transactions are added or deleted, the max is properly recalculated
  Future<void> _updateMaxMonthlyExpense(DateTime transactionDate) async {
    try {
      // Get current user
      final user = await FirebaseService.getUser();
      if (user == null) return;

      // Recalculate the true maximum from historical data
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

      // Always update the user's maxMonthlyExpense with the recalculated value
      final updatedUser = user.copyWith(maxMonthlyExpense: maxExpenses);
      await FirebaseService.saveUser(updatedUser);
    } catch (e) {
      // Silent error handling
    }
  }

  String _getTransactionTypeDisplayName(TransactionType type) {
    switch (type) {
      case TransactionType.income:
        return 'Income';
      case TransactionType.expense:
        return 'Expense';
      case TransactionType.savings:
        return 'Savings';
      case TransactionType.savingsWithdrawal:
        return 'Savings Withdrawal';
      case TransactionType.debt:
        return 'Debt';
      case TransactionType.debtPayment:
        return 'Debt Payment';
      case TransactionType.recurringExpense:
        return 'Recurring Expense';
      case TransactionType.emergencyFund:
        return 'Emergency Fund (S)';
      case TransactionType.emergencyFundWithdrawal:
        return 'Emergency Fund (W)';
    }
  }
}