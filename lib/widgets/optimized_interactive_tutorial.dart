import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'custom_tutorial.dart';
import 'page_tutorials.dart';
import 'tutorial_celebration.dart';
import 'tutorial_cleanup.dart';

/// Optimized version of InteractiveTutorial with better state management and reduced rebuilds
class OptimizedInteractiveTutorial {
  static final GlobalKey dashboardKey = GlobalKey();
  static final GlobalKey incomeCardKey = GlobalKey();
  static final GlobalKey expensesCardKey = GlobalKey();
  static final GlobalKey savingsCardKey = GlobalKey();
  static final GlobalKey chartKey = GlobalKey();
  static final GlobalKey savingsProgressKey = GlobalKey();
  static final GlobalKey budgetingTipsKey = GlobalKey();
  static final GlobalKey helpButtonKey = GlobalKey();
  static final GlobalKey notificationsKey = GlobalKey();
  static final GlobalKey navigationKey = GlobalKey();
  static final GlobalKey addTransactionKey = GlobalKey();
  static final GlobalKey calendarKey = GlobalKey();
  static final GlobalKey transactionsKey = GlobalKey();
  static final GlobalKey budgetKey = GlobalKey();
  static final GlobalKey profileKey = GlobalKey();
  static final GlobalKey selectedDayDetailsKey = GlobalKey();
  static final GlobalKey addReminderKey = GlobalKey();
  static final GlobalKey transactionTypeKey = GlobalKey();
  static final GlobalKey amountFieldKey = GlobalKey();
  static final GlobalKey categoryFieldKey = GlobalKey();
  static final GlobalKey descriptionFieldKey = GlobalKey();
  static final GlobalKey dateFieldKey = GlobalKey();
  static final GlobalKey saveButtonKey = GlobalKey();
  static final GlobalKey searchBarKey = GlobalKey();
  static final GlobalKey timeFrameFilterKey = GlobalKey();
  static final GlobalKey filterButtonKey = GlobalKey();
  static final GlobalKey transactionsListKey = GlobalKey();
  static final GlobalKey budgetOverviewKey = GlobalKey();
  static final GlobalKey dailyAllocationsKey = GlobalKey();
  static final GlobalKey monthlyAllocationsKey = GlobalKey();
  static final GlobalKey budgetSummaryKey = GlobalKey();
  static final GlobalKey emergencyFundKey = GlobalKey();
  static final GlobalKey appBarKey = GlobalKey(); // New key for highlighting all app bar buttons

  // Track which element is currently highlighted using a more efficient approach
  static GlobalKey? _currentHighlightedKey;
  static final Set<VoidCallback> _listeners = <VoidCallback>{};

  /// Get the currently highlighted key
  static GlobalKey? get currentHighlightedKey => _currentHighlightedKey;

  /// Add a listener for highlight changes
  static void addHighlightListener(VoidCallback listener) {
    _listeners.add(listener);
  }

  /// Remove a listener for highlight changes
  static void removeHighlightListener(VoidCallback listener) {
    _listeners.remove(listener);
  }

  /// Notify all listeners of highlight changes
  static void _notifyListeners() {
    // Create a copy of the listeners set to avoid concurrent modification
    final listeners = Set<VoidCallback>.from(_listeners);
    for (final listener in listeners) {
      try {
        listener();
      } catch (e) {
        // Ignore errors in individual listeners
      }
    }
  }

  /// Set the currently highlighted key
  static void setHighlightedKey(GlobalKey? key) {
    if (_currentHighlightedKey != key) {
      _currentHighlightedKey = key;
      _notifyListeners();
    }
  }

  /// Reset the highlighted key to prevent issues with disposed widgets
  static void resetHighlightedKey() {
    setHighlightedKey(null);
  }

  static bool _isRunning = false;
  static bool get isRunning => _isRunning;

  /// Start tutorial with optimized state management
  static void startTutorial(BuildContext context, {ScrollController? scrollController}) {
    if (_isRunning) return;

    _isRunning = true;

    try {
      // Clean up any existing tutorial resources first
      TutorialCleanup.cleanupTutorialResources();
      
      // Add a small delay to ensure context is fully ready
      Future.delayed(const Duration(milliseconds: 100), () {
        if (!context.mounted) {
          _isRunning = false;
          return;
        }
        
        try {
          // Try to get cached steps first
          List<TutorialStep>? steps = TutorialCache.getTutorialSteps(PageTutorials.DASHBOARD_TUTORIAL_ID);
          if (steps == null) {
            steps = _createTutorialSteps();
            // Cache the steps
            TutorialCache.cacheTutorialSteps(PageTutorials.DASHBOARD_TUTORIAL_ID, steps);
          }
          
          // Set initial highlighted key with defensive coding
          if (steps.isNotEmpty) {
            // Add a small delay to ensure context is available
            WidgetsBinding.instance.addPostFrameCallback((_) {
              try {
                if (context.mounted) {
                  // Add additional check to ensure the target key's widget is still mounted
                  final targetKey = steps!.first.targetKey;
                  if (targetKey.currentContext?.mounted ?? false) {
                    setHighlightedKey(targetKey);
                  } else {
                    // If the target widget is not mounted, don't set the highlighted key
                  }
                }
              } catch (e) {
                // Ignore errors when setting initial highlighted key
              }
            });
          }

          Navigator.of(context).push(
            PageRouteBuilder(
              opaque: false,
              pageBuilder: (context, _, __) {
                // Double-check context is still valid
                if (!context.mounted) {
                  _isRunning = false;
                  return const SizedBox.shrink();
                }
                return TutorialOverlay(
                  steps: steps ?? [],
                  scrollController: scrollController,
                  onComplete: () {
                    _isRunning = false;
                    try {
                      resetHighlightedKey();
                      // Mark page as visited after tutorial completion
                      PageTutorials.markPageAsVisited(PageTutorials.DASHBOARD_FIRST_VISIT_KEY);
                    } catch (e) {
                      // Ignore errors when resetting highlighted key
                    }
                    // Clear progress when tutorial is completed
                    _clearTutorialProgress();
                    // Only call Navigator.pop if the context is still valid
                    try {
                      if (context.mounted && Navigator.canPop(context)) {
                        Navigator.of(context).pop();
                      }
                    } catch (e) {
                      // Ignore navigation errors
                    }
                  },
                );
              },
            ),
          );
        } catch (e) {
          _isRunning = false;
        }
      });
    } catch (e) {
      _isRunning = false;
    }
  }

  static Future<void> startTutorialWithProgress(BuildContext context, {ScrollController? scrollController}) async {
    if (_isRunning) return;

    _isRunning = true;

    try {
      // Clean up any existing tutorial resources first
      TutorialCleanup.cleanupTutorialResources();
      
      // Add a small delay to ensure context is fully ready
      await Future.delayed(const Duration(milliseconds: 100));
      if (!context.mounted) {
        _isRunning = false;
        return;
      }
      
      try {
        // Try to get cached steps first
        List<TutorialStep>? steps = TutorialCache.getTutorialSteps(PageTutorials.DASHBOARD_TUTORIAL_ID);
        if (steps == null) {
          steps = _createTutorialSteps();
          // Cache the steps
          TutorialCache.cacheTutorialSteps(PageTutorials.DASHBOARD_TUTORIAL_ID, steps);
        }
        
        // Get saved progress
        int startStep = 0;
        try {
          final prefs = await SharedPreferences.getInstance();
          startStep = prefs.getInt(PageTutorials.DASHBOARD_TUTORIAL_PROGRESS_KEY) ?? 0;
          // Make sure startStep is within bounds
          if (startStep >= steps.length) {
            startStep = 0;
          }
        } catch (e) {
          startStep = 0;
        }
        
        // Set initial highlighted key based on start step with defensive coding
        if (steps.isNotEmpty && startStep < steps.length) {
          // Add a small delay to ensure context is available
          WidgetsBinding.instance.addPostFrameCallback((_) {
            try {
              if (context.mounted) {
                // Add additional check to ensure the target key's widget is still mounted
                final targetKey = steps![startStep].targetKey;
                if (targetKey.currentContext?.mounted ?? false) {
                  setHighlightedKey(targetKey);
                } else {
                  // If the target widget is not mounted, don't set the highlighted key
                }
              }
            } catch (e) {
              // Ignore errors when setting initial highlighted key
            }
          });
        }

        Navigator.of(context).push(
          PageRouteBuilder(
            opaque: false,
            pageBuilder: (context, _, __) {
              // Double-check context is still valid
              if (!context.mounted) {
                _isRunning = false;
                return const SizedBox.shrink();
              }
              return TutorialOverlay(
                steps: steps ?? [],
                scrollController: scrollController,
                onComplete: () {
                  _isRunning = false;
                  try {
                    resetHighlightedKey();
                  } catch (e) {
                    // Ignore errors when resetting highlighted key
                  }
                  // Clear progress when tutorial is completed
                  _clearTutorialProgress();
                  // Only call Navigator.pop if the context is still valid
                  try {
                    if (context.mounted && Navigator.canPop(context)) {
                      Navigator.of(context).pop();
                    }
                  } catch (e) {
                    // Ignore navigation errors
                  }
                },
                startStep: startStep,
              );
            },
          ),
        );
      } catch (e) {
        _isRunning = false;
      }
    } catch (e) {
      _isRunning = false;
    }
  }

  static void stopTutorial() {
    _isRunning = false;
    try {
      resetHighlightedKey();
    } catch (e) {
      // Ignore errors when resetting highlighted key
    }
  }

  static List<TutorialStep> _createTutorialSteps() {
    return [
      TutorialStep(
        title: "Welcome to PocketPilot!",
        description: "This is your Dashboard - your financial home screen. Here you'll see an overview of your finances.",
        targetKey: dashboardKey,
      ),
      TutorialStep(
        title: "Income Overview",
        description: "This card shows your total income for the selected time period. Track your earnings here.",
        targetKey: incomeCardKey,
      ),
      TutorialStep(
        title: "Expense Tracking",
        description: "Monitor your spending with this card. It shows your total expenses for the period.",
        targetKey: expensesCardKey,
      ),
      TutorialStep(
        title: "Savings Progress",
        description: "See how much you're saving. This includes any savings transactions you've recorded.",
        targetKey: savingsCardKey,
      ),
      TutorialStep(
        title: "Budgeting Tips",
        description: "Get personalized financial advice based on your spending patterns and budget strategy. These tips help you make better financial decisions.",
        targetKey: budgetingTipsKey,
      ),
      TutorialStep(
        title: "Savings Progress",
        description: "Track your progress towards your savings goals. This shows how much you've saved compared to your target.",
        targetKey: savingsProgressKey,
      ),
      TutorialStep(
        title: "Financial Overview Chart",
        description: "This chart visualizes your income, expenses, and savings in an easy-to-understand format.",
        targetKey: chartKey,
      ),
      TutorialStep(
        title: "App Navigation Buttons",
        description: "Get familiar with the key buttons in the app bar:\n\n• Profile picture button (top left) - Access your profile settings and personal information\n• Question mark button (top right) - Access help, tutorials, and support anytime\n• Bell button (next to question mark) - Manage notifications and reminders for your finances",
        targetKey: appBarKey,
      ),
    ];
  }

  static Future<void> _clearTutorialProgress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(PageTutorials.DASHBOARD_TUTORIAL_PROGRESS_KEY);
    } catch (e) {
      // Ignore errors when clearing tutorial progress
    }
  }
}

/// Optimized highlight widget that reduces unnecessary rebuilds
class OptimizedTutorialHighlight extends StatefulWidget {
  final Widget child;
  final GlobalKey highlightKey;
  final List<GlobalKey>? additionalHighlightKeys;

  const OptimizedTutorialHighlight({
    super.key,
    required this.child,
    required this.highlightKey,
    this.additionalHighlightKeys,
  });

  @override
  State<OptimizedTutorialHighlight> createState() => _OptimizedTutorialHighlightState();
}

class _OptimizedTutorialHighlightState extends State<OptimizedTutorialHighlight>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  bool _isHighlighted = false;
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 0.3, end: 0.8).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    
    // Listen to changes in the highlighted key
    OptimizedInteractiveTutorial.addHighlightListener(_onHighlightChanged);
    
    // Initialize highlight state
    _updateHighlightState();
  }

  @override
  void dispose() {
    _isDisposed = true;
    // Remove listener to prevent updates after disposal
    OptimizedInteractiveTutorial.removeHighlightListener(_onHighlightChanged);
    
    _pulseController.dispose();
    super.dispose();
  }
  
  void _onHighlightChanged() {
    if (_isDisposed) return;
    _updateHighlightState();
  }
  
  void _updateHighlightState() {
    if (_isDisposed || !mounted) return;
    
    // Check if current key or any additional keys are highlighted
    final currentHighlightedKey = OptimizedInteractiveTutorial.currentHighlightedKey;
    final isHighlighted = currentHighlightedKey == widget.highlightKey ||
        (widget.additionalHighlightKeys?.contains(currentHighlightedKey) ?? false);
    
    // Only update state if the highlight status has changed
    if (_isHighlighted != isHighlighted) {
      setState(() {
        _isHighlighted = isHighlighted;
      });
      
      // Control the pulse animation based on highlight status
      if (isHighlighted) {
        _pulseController.repeat(reverse: true);
      } else {
        _pulseController.stop();
        _pulseController.value = 0.0;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          decoration: _isHighlighted
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.blue.withValues(alpha: _pulseAnimation.value),
                    width: 3,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withValues(alpha: _pulseAnimation.value * 0.5),
                      blurRadius: 15,
                      spreadRadius: 3,
                    ),
                  ],
                )
              : null,
          child: widget.child,
        );
      },
    );
  }
}