import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/firebase_service.dart';
import '../services/theme_service.dart';
import '../services/transaction_notifier.dart';
import '../widgets/custom_tutorial.dart';
import '../widgets/tutorial_hotfix.dart';
import 'dashboard_page.dart';
import 'calendar_page.dart';
import 'add_transaction_page.dart';
import 'transactions_page.dart';
import 'budget_page.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key}); // Removed showUserGuide parameter

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;
  int _selectedNavIndex = 0; // Track which navigation button is selected
  
  // Transaction notifier for coordinating updates
  final TransactionNotifier _transactionNotifier = TransactionNotifier();

  @override
  void initState() {
    super.initState();
    // Initialize the selected nav index to match the current page
    _selectedNavIndex = _getNavIndex(_currentIndex);

    // Show interactive tutorial after the widget is built for new users
    // Removed automatic tutorial showing - tutorials will only show when clicked
  }

  final List<Widget> _pages = [
    const DashboardPage(),
    const CalendarPage(),
    const TransactionsPage(),
    const BudgetPage(),
  ];

  // Map navigation button indices to page indices
  int _getPageIndex(int navIndex) {
    switch (navIndex) {
      case 0: return 0; // Dashboard
      case 1: return 1; // Calendar
      case 3: return 2; // Transactions
      case 4: return 3; // Budget
      default: return 0;
    }
  }

  // Get navigation index from page index
  int _getNavIndex(int pageIndex) {
    switch (pageIndex) {
      case 0: return 0; // Dashboard
      case 1: return 1; // Calendar
      case 2: return 3; // Transactions
      case 3: return 4; // Budget
      default: return 0;
    }
  }

  void _onTabTapped(int index) {
    if (index == 2) {
      // Add button - show add transaction modal
      _showAddTransactionModal();
    } else {
      final pageIndex = _getPageIndex(index);
      setState(() {
        _currentIndex = pageIndex;
        _selectedNavIndex = index;
      });
    }
  }

  void _showAddTransactionModal() {
    final theme = Theme.of(context);
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.9,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: const AddTransactionPage(),
      ),
    ).then((result) {
      // When modal is closed, refresh dashboard if we're on it
      if (_currentIndex == 0) {
        _transactionNotifier.notifyTransactionsRefresh();
      }
    });
  }

  /// Show exit confirmation dialog when back button is pressed on dashboard
  void _showExitConfirmation() async {
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Exit PocketPilot'),
        content: const Text('Are you sure you want to exit the app?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              'Exit',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );

    if (shouldExit == true) {
      SystemNavigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeService = ThemeService();
    
    return AnimatedBuilder(
      animation: themeService,
      builder: (context, child) {
        return Theme(
          data: themeService.isDarkMode ? themeService.darkTheme : themeService.lightTheme,
          child: _buildMainNavigation(),
        );
      },
    );
  }

  Widget _buildMainNavigation() {
    final theme = Theme.of(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (didPop) return;
        
        // Handle back button based on current page
        if (_currentIndex == 0) {
          // On dashboard, show exit confirmation
          _showExitConfirmation();
        } else {
          // On other pages, navigate to dashboard
          setState(() {
            _currentIndex = 0;
            _selectedNavIndex = 0;
          });
        }
      },
      child: TutorialHotfixWrapper( // Wrap the entire navigation with the hotfix
        child: Scaffold(
          body: IndexedStack(
            index: _currentIndex,
            children: _pages,
          ),
          bottomNavigationBar: Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: theme.shadowColor,
                  spreadRadius: 1,
                  blurRadius: 5,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // Check if screen is narrow (less than 400px)
                  final isNarrowScreen = constraints.maxWidth < 400;
                  final isVeryNarrowScreen = constraints.maxWidth < 350;
                  final isExtremelyNarrowScreen = constraints.maxWidth < 300;
                  final isUltraNarrowScreen = constraints.maxWidth < 250; // Added for ultra narrow screens
                  final itemWidth = constraints.maxWidth / 5;
                  
                  // Use a flexible approach that adapts to content
                  return Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isUltraNarrowScreen ? 1 : isNarrowScreen ? 2 : 3,
                      vertical: isUltraNarrowScreen ? 1 : isVeryNarrowScreen ? 2 : 3,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildNavItem(Icons.dashboard, isUltraNarrowScreen ? 'H' : isExtremelyNarrowScreen ? 'Home' : 'Dashboard', 0, itemWidth, isNarrowScreen, isVeryNarrowScreen, key: InteractiveTutorial.navigationKey),
                        _buildNavItem(Icons.calendar_month, isUltraNarrowScreen ? 'C' : isExtremelyNarrowScreen ? 'Cal' : 'Calendar', 1, itemWidth, isNarrowScreen, isVeryNarrowScreen, key: InteractiveTutorial.calendarKey),
                        Container(
                          key: InteractiveTutorial.addTransactionKey,
                          child: _buildAddButton(isNarrowScreen, isVeryNarrowScreen),
                        ),
                        _buildNavItem(Icons.receipt_long, isUltraNarrowScreen ? 'T' : isExtremelyNarrowScreen ? 'Txn' : 'Transactions', 3, itemWidth, isNarrowScreen, isVeryNarrowScreen, key: InteractiveTutorial.transactionsKey), // Changed 'Trans' to 'Txn'
                        _buildNavItem(Icons.account_balance_wallet, isUltraNarrowScreen ? 'B' : isExtremelyNarrowScreen ? 'Bud' : 'Budget', 4, itemWidth, isNarrowScreen, isVeryNarrowScreen, key: InteractiveTutorial.budgetKey),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
    
  }

  Widget _buildNavItem(IconData icon, String label, int index, double itemWidth, bool isNarrowScreen, bool isVeryNarrowScreen, {GlobalKey? key}) {
    final isSelected = _selectedNavIndex == index;
    final theme = Theme.of(context);
    final isExtremelyNarrowScreen = itemWidth < 60;
    final isUltraNarrowScreen = itemWidth < 50; // Added for ultra narrow screens
    
    // Adjust sizes based on screen width
    final iconSize = isUltraNarrowScreen ? 16.0 : isExtremelyNarrowScreen ? 18.0 : isVeryNarrowScreen ? 20.0 : isNarrowScreen ? 22.0 : 24.0; // Reduced from 18-26 to 16-24
    final fontSize = isUltraNarrowScreen ? 6.0 : isExtremelyNarrowScreen ? 8.0 : isVeryNarrowScreen ? 10.0 : isNarrowScreen ? 12.0 : 14.0; // Reduced from 8-16 to 6-14
    final horizontalPadding = isUltraNarrowScreen ? 0.8 : isExtremelyNarrowScreen ? 1.2 : isVeryNarrowScreen ? 1.8 : isNarrowScreen ? 2.5 : 3.5; // Reduced from 1-4 to 0.8-3.5
    final verticalPadding = isUltraNarrowScreen ? 3.0 : isExtremelyNarrowScreen ? 4.0 : isVeryNarrowScreen ? 5.0 : isNarrowScreen ? 7.0 : 9.0; // Reduced from 4-10 to 3-9

    return Container(
      key: key,
      child: _HoverableNavItem(
        onTap: () => _onTabTapped(index),
        isSelected: isSelected,
        child: Container(
        width: itemWidth,
        padding: EdgeInsets.symmetric(
          vertical: verticalPadding, 
          horizontal: horizontalPadding,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon with smooth color transition and scale animation
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOutCubic,
              transform: Matrix4.identity()..scale(isSelected ? 1.1 : 1.0),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                padding: EdgeInsets.all(isSelected ? (isExtremelyNarrowScreen ? 3.0 : isVeryNarrowScreen ? 4.0 : isNarrowScreen ? 6.0 : 8.0) : (isExtremelyNarrowScreen ? 1.0 : isVeryNarrowScreen ? 2.0 : isNarrowScreen ? 3.0 : 4.0)),
                decoration: BoxDecoration(
                  color: isSelected 
                    ? theme.colorScheme.primary.withValues(alpha: 0.1)
                    : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: isSelected 
                    ? theme.colorScheme.primary 
                    : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  size: iconSize,
                ),
              ),
            ),
            SizedBox(height: isExtremelyNarrowScreen ? 0.5 : isVeryNarrowScreen ? 1 : isNarrowScreen ? 2 : 4),
            // Label with smooth color and weight transition
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOutCubic,
              style: TextStyle(
                color: isSelected 
                  ? theme.colorScheme.primary 
                  : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                fontSize: fontSize,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400, // Reduced from w700 to w600
              ),
              child: Text(
                label,
                textAlign: TextAlign.center,
                overflow: TextOverflow.visible, // Changed from ellipsis to visible
                maxLines: 1,
              ),
            ),
          ],
        ),
      ),
    ));
  }

  Widget _buildAddButton(bool isNarrowScreen, bool isVeryNarrowScreen) {
    return _HoverableAddButton(
      onTap: () => _showAddTransactionModal(),
      isNarrowScreen: isNarrowScreen,
      isVeryNarrowScreen: isVeryNarrowScreen,
    );
  }
}

class _HoverableNavItem extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final bool isSelected;

  const _HoverableNavItem({
    required this.child,
    required this.onTap,
    required this.isSelected,
  });

  @override
  State<_HoverableNavItem> createState() => _HoverableNavItemState();
}

class _HoverableNavItemState extends State<_HoverableNavItem>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) {
        if (!widget.isSelected) {
          setState(() {
            _isHovered = true;
          });
          _animationController.forward();
        }
      },
      onExit: (_) {
        setState(() {
          _isHovered = false;
        });
        _animationController.reverse();
      },
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: widget.isSelected ? 1.0 : _scaleAnimation.value,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: widget.onTap,
                borderRadius: BorderRadius.circular(16),
                splashColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                highlightColor: theme.colorScheme.primary.withValues(alpha: 0.05),
                hoverColor: theme.colorScheme.primary.withValues(alpha: 0.08),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOutCubic,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: _isHovered && !widget.isSelected
                        ? theme.colorScheme.primary.withValues(alpha: 0.05)
                        : Colors.transparent,
                  ),
                  child: widget.child,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _HoverableAddButton extends StatefulWidget {
  final VoidCallback onTap;
  final bool isNarrowScreen;
  final bool isVeryNarrowScreen;

  const _HoverableAddButton({
    required this.onTap,
    required this.isNarrowScreen,
    required this.isVeryNarrowScreen,
  });

  @override
  State<_HoverableAddButton> createState() => _HoverableAddButtonState();
}

class _HoverableAddButtonState extends State<_HoverableAddButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _elevationAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.08,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOutCubic,
    ));
    _elevationAnimation = Tween<double>(
      begin: 8.0,
      end: 16.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOutCubic,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isExtremelyNarrow = widget.isVeryNarrowScreen && MediaQuery.of(context).size.width < 320;
    final isUltraNarrow = widget.isVeryNarrowScreen && MediaQuery.of(context).size.width < 280; // Added for ultra narrow screens
    final isVerySmall = widget.isVeryNarrowScreen;
    final size = isUltraNarrow ? 36.0 : isExtremelyNarrow ? 40.0 : isVerySmall ? 44.0 : widget.isNarrowScreen ? 50.0 : 56.0;
    final iconSize = isUltraNarrow ? 18.0 : isExtremelyNarrow ? 20.0 : isVerySmall ? 22.0 : widget.isNarrowScreen ? 24.0 : 28.0;
    
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) {
        _animationController.forward();
      },
      onExit: (_) {
        _animationController.reverse();
      },
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: widget.onTap,
                borderRadius: BorderRadius.circular(32),
                splashColor: Colors.white.withValues(alpha: 0.2),
                highlightColor: Colors.white.withValues(alpha: 0.1),
                child: Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.teal,
                        Colors.teal.shade600,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.teal.withValues(alpha: 0.4),
                        spreadRadius: 2,
                        blurRadius: _elevationAnimation.value,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.add,
                    color: Colors.white,
                    size: iconSize,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}