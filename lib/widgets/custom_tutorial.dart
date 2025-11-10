import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'page_tutorials.dart';
import 'tutorial_celebration.dart';
import 'tutorial_cleanup.dart';

/// Represents a single tutorial step
class TutorialStep {
  final String title;
  final String description;
  final GlobalKey targetKey;

  const TutorialStep({
    required this.title,
    required this.description,
    required this.targetKey,
  });
}

/// Custom tutorial overlay that avoids scrolling issues
class TutorialOverlay extends StatefulWidget {
  final List<TutorialStep> steps;
  final VoidCallback onComplete;
  final ScrollController? scrollController;
  final int startStep;

  const TutorialOverlay({
    super.key,
    required this.steps,
    required this.onComplete,
    this.scrollController,
    this.startStep = 0,
  });

  @override
  State<TutorialOverlay> createState() => _TutorialOverlayState();
}

class _TutorialOverlayState extends State<TutorialOverlay>
    with TickerProviderStateMixin {
  late int _currentStep;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    _isDisposed = false;
    _currentStep = widget.startStep;
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
    
    // Add slide animation controller for card transitions
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0), // Start from the right
      end: Offset.zero, // End at the center
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOut,
    ));
    
    // Add a small delay before starting animations to ensure the widget is fully initialized
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_isDisposed) {
        _fadeController.forward();
        _slideController.forward();
      }
    });

    // Don't scroll for budget tutorial - just highlight
    // Set initial highlighted key if starting from a specific step
    if (widget.steps.isNotEmpty && _currentStep < widget.steps.length) {
      // Add a small delay to ensure the widget is fully initialized before setting the highlighted key
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_isDisposed) {
          InteractiveTutorial._currentHighlightedKeyNotifier.value = widget.steps[_currentStep].targetKey;
        }
      });
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    // Reset the highlighted key when disposing with defensive coding
    try {
      InteractiveTutorial.resetHighlightedKeyNotifier();
    } catch (e) {
      // Ignore errors when resetting the highlighted key
      debugPrint("Error resetting highlighted key notifier in dispose: $e");
    }
    
    // Dispose of animation controllers with defensive coding
    try {
      _fadeController.dispose();
    } catch (e) {
      debugPrint("Error disposing fade controller: $e");
    }
    
    try {
      _slideController.dispose();
    } catch (e) {
      debugPrint("Error disposing slide controller: $e");
    }
    
    // Add a small delay before calling super.dispose to ensure all cleanup is complete
    Future.microtask(() {
      // Perform additional cleanup
      try {
        TutorialCleanup.aggressiveCleanup();
      } catch (e) {
        debugPrint("Error in microtask cleanup: $e");
      }
    });
    
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!mounted || _isDisposed) return const SizedBox.shrink();
    
    // Add additional safety check for steps
    if (widget.steps.isEmpty || _currentStep >= widget.steps.length) {
      // If we have invalid steps, complete the tutorial
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_isDisposed) {
          _completeTutorial();
        }
      });
      return const SizedBox.shrink();
    }
    
    // Additional check to ensure the current step's target key widget is still mounted
    final currentStepKey = widget.steps[_currentStep].targetKey;
    if (currentStepKey.currentContext != null && !currentStepKey.currentContext!.mounted) {
      debugPrint("Current step target widget not mounted, completing tutorial");
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_isDisposed) {
          _completeTutorial();
        }
      });
      return const SizedBox.shrink();
    }
    
    final step = widget.steps[_currentStep];
    final isFirst = _currentStep == 0;
    final isLast = _currentStep == widget.steps.length - 1;
    
    // Create the tutorial card
    final tutorialCard = TutorialCard(
      step: step,
      onNext: _nextStep,
      onPrevious: _previousStep,
      onSkip: _skipTutorial,
      isFirst: isFirst,
      isLast: isLast,
      currentStep: _currentStep,
      totalSteps: widget.steps.length,
    );
    
    final screenSize = MediaQuery.of(context).size;
    
    // Determine positioning based on target key
    // According to requirements:
    // 1. All tutorial cards in the transactions page should display at the bottom
    // 2. All tutorial cards should display at the top except for the "choose transaction type" tutorial card in add transaction page
    // 3. In the budget page, tutorial card steps 1, 2, 3, 4 should display from the bottom of the screen
    // 4. In the dashboard page, tutorial card step 1 should display from the bottom of the screen
    bool positionAtTop;
    
    // Check if this is a transactions page tutorial step
    final isTransactionsTutorial = step.targetKey == InteractiveTutorial.searchBarKey ||
                                  step.targetKey == InteractiveTutorial.timeFrameFilterKey ||
                                  step.targetKey == InteractiveTutorial.filterButtonKey ||
                                  step.targetKey == InteractiveTutorial.transactionsListKey;
    
    // Check if this is one of the first 4 steps of the budget tutorial
    final isBudgetTutorialFirstFourSteps = 
        (step.targetKey == PageTutorials.budgetOverviewKey && _currentStep < 4) ||
        (step.targetKey == PageTutorials.dailyAllocationsKey && _currentStep < 4) ||
        (step.targetKey == PageTutorials.monthlyAllocationsKey && _currentStep < 4);
    
    // Check if this is one of the first 3 steps of the calendar tutorial
    final isCalendarTutorialFirstThreeSteps = 
        (step.targetKey == PageTutorials.calendarOverviewKey && _currentStep < 3) ||
        (step.targetKey == PageTutorials.calendarKey && _currentStep < 3) ||
        (step.targetKey == PageTutorials.selectedDayDetailsKey && _currentStep < 3);
    
    // Check if this is the first step of the dashboard tutorial
    final isFirstStepOfDashboardTutorial = 
        step.targetKey == InteractiveTutorial.dashboardKey && _currentStep == 0;
    
    if (isTransactionsTutorial) {
      // Position all transactions page tutorial cards at the bottom
      positionAtTop = false;
    } else if (isBudgetTutorialFirstFourSteps) {
      // Position first 4 steps of budget tutorial at the bottom
      positionAtTop = false;
    } else if (isCalendarTutorialFirstThreeSteps) {
      // Position first 3 steps of calendar tutorial at the bottom
      positionAtTop = false;
    } else if (isFirstStepOfDashboardTutorial) {
      // Position first step of dashboard tutorial at the bottom
      positionAtTop = false;
    } else if (step.targetKey == InteractiveTutorial.transactionTypeKey) {
      // Position transaction type selection at the bottom to avoid obstructing the options
      positionAtTop = false;
    } else if (step.targetKey == InteractiveTutorial.appBarKey) {
      // Position at the bottom for app bar navigation buttons
      positionAtTop = false;
    } else if (step.targetKey == InteractiveTutorial.savingsProgressKey || 
        step.targetKey == InteractiveTutorial.chartKey ||
        step.targetKey == PageTutorials.addReminderKey) {
      // Position at the top for savings progress, financial overview, 
      // and add reminder
      positionAtTop = true;
    } else if (step.targetKey == InteractiveTutorial.incomeCardKey || 
               step.targetKey == InteractiveTutorial.expensesCardKey || 
               step.targetKey == InteractiveTutorial.savingsCardKey ||
               step.targetKey == InteractiveTutorial.budgetingTipsKey ||
               step.targetKey == PageTutorials.selectedDayDetailsKey) {
      // Position at the bottom for income, expenses, savings, budgeting tips,
      // and transaction details
      positionAtTop = false;
    } else {
      // Default positioning at the top (changed from bottom to top as per requirements)
      positionAtTop = true;
    }
    
    return Focus(
      autofocus: true,
      child: KeyboardListener(
        focusNode: FocusNode(),
        onKeyEvent: (event) {
          if (!mounted || _isDisposed) return;
          if (event is KeyDownEvent || event is KeyUpEvent) {
            // Handle keyboard shortcuts
            if (event.logicalKey == LogicalKeyboardKey.arrowRight || 
                event.logicalKey == LogicalKeyboardKey.space) {
              _nextStep();
            } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
              _previousStep();
            } else if (event.logicalKey == LogicalKeyboardKey.escape) {
              _skipTutorial();
            }
          }
        },
        child: KeyboardListener(
          focusNode: FocusNode(),
          onKeyEvent: (event) {
            if (!mounted || _isDisposed) return;
            // Handle keyboard shortcuts for older Flutter versions
            if (event is KeyDownEvent || event is KeyUpEvent) {
              if (event.logicalKey == LogicalKeyboardKey.arrowRight || 
                  event.logicalKey == LogicalKeyboardKey.space) {
                _nextStep();
              } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                _previousStep();
              } else if (event.logicalKey == LogicalKeyboardKey.escape) {
                _skipTutorial();
              }
            }
          },
          child: Material(
            color: Colors.black.withValues(alpha: 0.2), // Reduced from 0.3 to 0.2 for less dimming
            child: Stack(
              children: [
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: SafeArea(
                    child: Container(), // Empty container to fill the safe area
                  ),
                ),
                // Position the tutorial card with slide animation
                Positioned(
                  top: positionAtTop ? (screenSize.width > 600 ? 80.0 : 70.0) : null,
                  bottom: positionAtTop ? null : (screenSize.width > 600 ? 30.0 : 20.0),
                  left: screenSize.width > 800 ? (screenSize.width - 600) / 2 : screenSize.width * 0.025,
                  right: screenSize.width > 800 ? (screenSize.width - 600) / 2 : screenSize.width * 0.025,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: tutorialCard,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _nextStep() {
    // Save current progress before moving to next step
    _saveCurrentProgress();
    
    if (_currentStep < widget.steps.length - 1) {
      // Update slide animation direction
      _slideAnimation = Tween<Offset>(
        begin: const Offset(1.0, 0.0), // Start from the right
        end: Offset.zero, // End at the center
      ).animate(CurvedAnimation(
        parent: _slideController,
        curve: Curves.easeOut,
      ));
      
      // Reverse the animations before changing steps
      _fadeController.reverse().then((_) {
        if (!mounted) return;
        _slideController.reverse().then((_) {
          if (!mounted) return;
          // Check if next step needs special scrolling
          final nextStepIndex = _currentStep + 1;
          final nextStepKey = widget.steps[nextStepIndex].targetKey;

          if (nextStepKey == InteractiveTutorial.budgetingTipsKey) {
            // Scroll to center budgeting tips area
            _scrollToBudgetingTipsArea();
            // Add extra delay for scrolling to complete
            Future.delayed(const Duration(milliseconds: 600), () {
              if (!mounted) return;
              setState(() {
                _currentStep = nextStepIndex;
                // Add additional check to ensure the target key's widget is still mounted
                final targetKey = widget.steps[_currentStep].targetKey;
                if (targetKey.currentContext?.mounted ?? false) {
                  InteractiveTutorial._currentHighlightedKeyNotifier.value = targetKey;
                } else {
                  debugPrint("Target widget not mounted during next step, skipping highlighted key update");
                }
              });
              // Delay to ensure context is available
              Future.delayed(const Duration(milliseconds: 100), () {
                if (!mounted) return;
                _fadeController.forward();
                _slideController.forward();
              });
            });
          } else if (nextStepKey == InteractiveTutorial.savingsProgressKey) {
            // Scroll to savings progress area
            _scrollToSavingsProgressArea();
            // Add extra delay for scrolling to complete
            Future.delayed(const Duration(milliseconds: 600), () {
              if (!mounted) return;
              setState(() {
                _currentStep = nextStepIndex;
                InteractiveTutorial._currentHighlightedKeyNotifier.value = widget.steps[_currentStep].targetKey;
              });
              // Delay to ensure context is available
              Future.delayed(const Duration(milliseconds: 100), () {
                if (!mounted) return;
                _fadeController.forward();
                _slideController.forward();
              });
            });
          } else if (nextStepKey == InteractiveTutorial.chartKey) {
            // Scroll to chart area
            _scrollToChartArea();
            // Add extra delay for scrolling to complete
            Future.delayed(const Duration(milliseconds: 600), () {
              if (!mounted) return;
              setState(() {
                _currentStep = nextStepIndex;
                InteractiveTutorial._currentHighlightedKeyNotifier.value = widget.steps[_currentStep].targetKey;
              });
              // Delay to ensure context is available
              Future.delayed(const Duration(milliseconds: 100), () {
                if (!mounted) return;
                _fadeController.forward();
                _slideController.forward();
              });
            });
          } else if (nextStepKey == InteractiveTutorial.amountFieldKey) {
            // Scroll to amount field area in add transaction page
            _scrollToAmountFieldArea();
            // Add extra delay for scrolling to complete
            Future.delayed(const Duration(milliseconds: 600), () {
              if (!mounted) return;
              setState(() {
                _currentStep = nextStepIndex;
                InteractiveTutorial._currentHighlightedKeyNotifier.value = widget.steps[_currentStep].targetKey;
              });
              // Delay to ensure context is available
              Future.delayed(const Duration(milliseconds: 100), () {
                if (!mounted) return;
                _fadeController.forward();
                _slideController.forward();
              });
            });
          } else if (nextStepKey == InteractiveTutorial.categoryFieldKey) {
            // Scroll to category field area in add transaction page
            _scrollToCategoryFieldArea();
            // Add extra delay for scrolling to complete
            Future.delayed(const Duration(milliseconds: 600), () {
              if (!mounted) return;
              setState(() {
                _currentStep = nextStepIndex;
                InteractiveTutorial._currentHighlightedKeyNotifier.value = widget.steps[_currentStep].targetKey;
              });
              // Delay to ensure context is available
              Future.delayed(const Duration(milliseconds: 100), () {
                if (!mounted) return;
                _fadeController.forward();
                _slideController.forward();
              });
            });
          } else if (nextStepKey == InteractiveTutorial.descriptionFieldKey) {
            // Scroll to description field area in add transaction page
            _scrollToDescriptionFieldArea();
            // Add extra delay for scrolling to complete
            Future.delayed(const Duration(milliseconds: 600), () {
              if (!mounted) return;
              setState(() {
                _currentStep = nextStepIndex;
                InteractiveTutorial._currentHighlightedKeyNotifier.value = widget.steps[_currentStep].targetKey;
              });
              // Delay to ensure context is available
              Future.delayed(const Duration(milliseconds: 100), () {
                if (!mounted) return;
                _fadeController.forward();
                _slideController.forward();
              });
            });
          } else if (nextStepKey == InteractiveTutorial.dateFieldKey) {
            // Scroll to date field area in add transaction page
            _scrollToDateFieldArea();
            // Add extra delay for scrolling to complete
            Future.delayed(const Duration(milliseconds: 600), () {
              if (!mounted) return;
              setState(() {
                _currentStep = nextStepIndex;
                InteractiveTutorial._currentHighlightedKeyNotifier.value = widget.steps[_currentStep].targetKey;
              });
              // Delay to ensure context is available
              Future.delayed(const Duration(milliseconds: 100), () {
                if (!mounted) return;
                _fadeController.forward();
                _slideController.forward();
              });
            });
          } else if (nextStepKey == InteractiveTutorial.saveButtonKey) {
            // Scroll to save button area in add transaction page
            _scrollToSaveButtonArea();
            // Add extra delay for scrolling to complete
            Future.delayed(const Duration(milliseconds: 600), () {
              if (!mounted) return;
              setState(() {
                _currentStep = nextStepIndex;
                InteractiveTutorial._currentHighlightedKeyNotifier.value = widget.steps[_currentStep].targetKey;
              });
              // Delay to ensure context is available
              Future.delayed(const Duration(milliseconds: 100), () {
                if (!mounted) return;
                _fadeController.forward();
                _slideController.forward();
              });
            });
          } else if (nextStepKey == PageTutorials.budgetOverviewKey) {
            // Don't scroll for budget tutorial, just update state
            // Add extra delay for scrolling to complete
            Future.delayed(const Duration(milliseconds: 600), () {
              if (!mounted) return;
              setState(() {
                _currentStep = nextStepIndex;
                InteractiveTutorial._currentHighlightedKeyNotifier.value = widget.steps[_currentStep].targetKey;
              });
              // Delay to ensure context is available
              Future.delayed(const Duration(milliseconds: 100), () {
                if (!mounted) return;
                _fadeController.forward();
                _slideController.forward();
              });
            });
          } else if (nextStepKey == PageTutorials.dailyAllocationsKey) {
            // Scroll to daily allocations area to make it visible
            _scrollToDailyAllocationsArea();
            if (!mounted) return;
            setState(() {
              _currentStep = nextStepIndex;
              InteractiveTutorial._currentHighlightedKeyNotifier.value = widget.steps[_currentStep].targetKey;
            });
            // Delay to ensure context is available
            Future.delayed(const Duration(milliseconds: 100), () {
              if (!mounted) return;
              _fadeController.forward();
              _slideController.forward();
            });
          } else if (nextStepKey == PageTutorials.monthlyAllocationsKey) {
            // Scroll to monthly allocations area to make it visible
            _scrollToMonthlyAllocationsArea();
            // Add extra delay for scrolling to complete
            Future.delayed(const Duration(milliseconds: 600), () {
              if (!mounted) return;
              setState(() {
                _currentStep = nextStepIndex;
                InteractiveTutorial._currentHighlightedKeyNotifier.value = widget.steps[_currentStep].targetKey;
              });
              // Delay to ensure context is available
              Future.delayed(const Duration(milliseconds: 100), () {
                if (!mounted) return;
                _fadeController.forward();
                _slideController.forward();
              });
            });
          } else if (nextStepKey == PageTutorials.budgetSummaryKey) {
            // Scroll to budget summary area to make it visible
            _scrollToBudgetSummaryArea();
            // Add extra delay for scrolling to complete
            Future.delayed(const Duration(milliseconds: 600), () {
              if (!mounted) return;
              setState(() {
                _currentStep = nextStepIndex;
                InteractiveTutorial._currentHighlightedKeyNotifier.value = widget.steps[_currentStep].targetKey;
              });
              // Delay to ensure context is available
              Future.delayed(const Duration(milliseconds: 100), () {
                if (!mounted) return;
                _fadeController.forward();
                _slideController.forward();
              });
            });
          } else if (nextStepKey == PageTutorials.emergencyFundKey) {
            // Scroll to emergency fund area to make it visible
            _scrollToEmergencyFundArea();
            // Add extra delay for scrolling to complete
            Future.delayed(const Duration(milliseconds: 600), () {
              if (!mounted) return;
              setState(() {
                _currentStep = nextStepIndex;
                InteractiveTutorial._currentHighlightedKeyNotifier.value = widget.steps[_currentStep].targetKey;
              });
              // Delay to ensure context is available
              Future.delayed(const Duration(milliseconds: 100), () {
                if (!mounted) return;
                _fadeController.forward();
                _slideController.forward();
              });
            });
          } else if (nextStepKey == PageTutorials.selectedDayDetailsKey) {
            // For calendar tutorial, we need to ensure a day is selected
            // Call the callback to select today
            PageTutorials.onCalendarTutorialSelectToday?.call();
            
            // Add delay to ensure day is selected before scrolling
            Future.delayed(const Duration(milliseconds: 300), () {
              if (!mounted) return;
              // Scroll to selected day details area
              _scrollToSelectedDayDetailsArea();
              // Add extra delay for scrolling to complete
              Future.delayed(const Duration(milliseconds: 600), () {
                if (!mounted) return;
                setState(() {
                  _currentStep = nextStepIndex;
                  InteractiveTutorial._currentHighlightedKeyNotifier.value = widget.steps[_currentStep].targetKey;
                  debugPrint('Highlighting selectedDayDetailsKey');
                });
                // Delay to ensure context is available
                Future.delayed(const Duration(milliseconds: 100), () {
                  if (!mounted) return;
                  _fadeController.forward();
                  _slideController.forward();
                });
              });
            });
          } else if (nextStepKey == PageTutorials.addReminderKey) {
            // Scroll to add reminder area
            _scrollToAddReminderArea();
            // Add extra delay for scrolling to complete
            Future.delayed(const Duration(milliseconds: 600), () {
              if (!mounted) return;
              setState(() {
                _currentStep = nextStepIndex;
                InteractiveTutorial._currentHighlightedKeyNotifier.value = widget.steps[_currentStep].targetKey;
                debugPrint('Highlighting addReminderKey');
              });
              // Delay to ensure context is available
              Future.delayed(const Duration(milliseconds: 100), () {
                if (!mounted) return;
                _fadeController.forward();
                _slideController.forward();
              });
            });
          } else {
            // For regular steps (not special scrolling ones), use the general scrolling logic
            // For calendar tutorial, we need to ensure a day is selected when going to transaction details
            if (widget.steps[_currentStep + 1].targetKey == PageTutorials.selectedDayDetailsKey) {
              PageTutorials.onCalendarTutorialSelectToday?.call();
              
              // Add delay to ensure day is selected before scrolling
              Future.delayed(const Duration(milliseconds: 300), () {
                if (!mounted) return;
                setState(() {
                  _currentStep++;
                  InteractiveTutorial._currentHighlightedKeyNotifier.value = widget.steps[_currentStep].targetKey;
                  debugPrint('Highlighting next step key: ${widget.steps[_currentStep].targetKey}');
                });
              });
            } else {
              if (!mounted) return;
              setState(() {
                _currentStep++;
                InteractiveTutorial._currentHighlightedKeyNotifier.value = widget.steps[_currentStep].targetKey;
                debugPrint('Highlighting next step key: ${widget.steps[_currentStep].targetKey}');
              });
            }
            // Scroll to make current step visible (but not for calendar tutorials)
            final currentStepKey = widget.steps[_currentStep].targetKey;
            final isCalendarTutorial = currentStepKey == InteractiveTutorial.calendarKey ||
                                      currentStepKey == InteractiveTutorial.selectedDayDetailsKey ||
                                      currentStepKey == InteractiveTutorial.addReminderKey;
            if (!isCalendarTutorial) {
              _scrollToCurrentStep();
            }
            // Delay to ensure context is available
            Future.delayed(const Duration(milliseconds: 100), () {
              if (!mounted) return;
              _fadeController.forward();
              _slideController.forward();
            });
          }
        });
      });
    } else {
      _completeTutorial();
    }
  }

  void _previousStep() {
    // Save current progress before moving to previous step
    _saveCurrentProgress();
    
    if (_currentStep > 0) {
      // Update slide animation direction
      _slideAnimation = Tween<Offset>(
        begin: const Offset(-1.0, 0.0), // Start from the left
        end: Offset.zero, // End at the center
      ).animate(CurvedAnimation(
        parent: _slideController,
        curve: Curves.easeOut,
      ));
      
      // Reverse the animations before changing steps
      _fadeController.reverse().then((_) {
        if (!mounted) return;
        _slideController.reverse().then((_) {
          if (!mounted) return;
          // For calendar tutorial, we need to ensure a day is selected when going back to transaction details
          if (widget.steps[_currentStep - 1].targetKey == PageTutorials.selectedDayDetailsKey) {
            PageTutorials.onCalendarTutorialSelectToday?.call();
            
            // Add delay to ensure day is selected before scrolling
            Future.delayed(const Duration(milliseconds: 300), () {
              if (!mounted) return;
              setState(() {
                _currentStep--;
                InteractiveTutorial._currentHighlightedKeyNotifier.value = widget.steps[_currentStep].targetKey;
                debugPrint('Highlighting previous step key: ${widget.steps[_currentStep].targetKey}');
              });
            });
          } else {
            if (!mounted) return;
            setState(() {
              _currentStep--;
              InteractiveTutorial._currentHighlightedKeyNotifier.value = widget.steps[_currentStep].targetKey;
              debugPrint('Highlighting previous step key: ${widget.steps[_currentStep].targetKey}');
            });
          }
          // Scroll to make current step visible
          _scrollToCurrentStep();
          // Delay to ensure context is available
          Future.delayed(const Duration(milliseconds: 100), () {
            if (!mounted) return;
            _fadeController.forward();
            _slideController.forward();
          });
        });
      });
    }
  }

  void _skipTutorial() {
    _completeTutorial();
  }

  void _completeTutorial() {
    // Reset the highlighted key before doing any async operations
    try {
      InteractiveTutorial._currentHighlightedKeyNotifier.value = null;
    } catch (e) {
      debugPrint("Error resetting highlighted key: $e");
    }
    
    _markTutorialCompleted();
    // Clear progress when tutorial is completed
    _clearTutorialProgress();
    // Scroll to top before completing tutorial
    if (widget.scrollController != null && widget.scrollController!.hasClients) {
      if (!mounted) return;
      widget.scrollController!.animateTo(
        0.0,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOut,
      ).catchError((error) {
        // Ignore scroll errors
        debugPrint("Error scrolling to top: $error");
      });
    }
    
    // Call onComplete directly without feedback
    if (!mounted) return;
    try {
      widget.onComplete();
    } catch (e) {
      // Ignore errors when calling onComplete
      debugPrint("Error calling onComplete: $e");
    }
  }

  Future<void> _saveCurrentProgress() async {
    // Save current step progress
    // We'll implement this based on which tutorial is running
    // For now, we'll just print the current step
    debugPrint("Saving progress for step: $_currentStep");
    
    // Determine which tutorial we're in based on the first step's target key
    if (widget.steps.isNotEmpty) {
      final firstStepKey = widget.steps[0].targetKey;
      
      String? progressKey;
      if (firstStepKey == InteractiveTutorial.dashboardKey) {
        progressKey = PageTutorials.DASHBOARD_TUTORIAL_PROGRESS_KEY;
      } else if (firstStepKey == PageTutorials.calendarKey) {
        progressKey = PageTutorials.CALENDAR_TUTORIAL_PROGRESS_KEY;
      } else if (firstStepKey == InteractiveTutorial.transactionTypeKey) {
        progressKey = PageTutorials.ADD_TRANSACTION_TUTORIAL_PROGRESS_KEY;
      } else if (firstStepKey == InteractiveTutorial.searchBarKey) {
        progressKey = PageTutorials.TRANSACTIONS_TUTORIAL_PROGRESS_KEY;
      } else if (firstStepKey == PageTutorials.budgetOverviewKey) {
        progressKey = PageTutorials.BUDGET_TUTORIAL_PROGRESS_KEY;
      }
      
      if (progressKey != null) {
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setInt(progressKey, _currentStep);
          debugPrint("Saved progress $_currentStep for $progressKey");
        } catch (e) {
          debugPrint("Error saving tutorial progress: $e");
        }
      }
    }
  }

  Future<void> _clearTutorialProgress() async {
    // Clear progress when tutorial is completed
    if (widget.steps.isNotEmpty) {
      final firstStepKey = widget.steps[0].targetKey;
      
      String? progressKey;
      if (firstStepKey == InteractiveTutorial.dashboardKey) {
        progressKey = PageTutorials.DASHBOARD_TUTORIAL_PROGRESS_KEY;
      } else if (firstStepKey == PageTutorials.calendarKey) {
        progressKey = PageTutorials.CALENDAR_TUTORIAL_PROGRESS_KEY;
      } else if (firstStepKey == InteractiveTutorial.transactionTypeKey) {
        progressKey = PageTutorials.ADD_TRANSACTION_TUTORIAL_PROGRESS_KEY;
      } else if (firstStepKey == InteractiveTutorial.searchBarKey) {
        progressKey = PageTutorials.TRANSACTIONS_TUTORIAL_PROGRESS_KEY;
      } else if (firstStepKey == PageTutorials.budgetOverviewKey) {
        progressKey = PageTutorials.BUDGET_TUTORIAL_PROGRESS_KEY;
      }
      
      if (progressKey != null) {
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove(progressKey);
          debugPrint("Cleared progress for $progressKey");
        } catch (e) {
          debugPrint("Error clearing tutorial progress: $e");
        }
      }
    }
  }

  Future<void> _scrollToCurrentStep() async {
    if (!mounted) return;
    final step = widget.steps[_currentStep];

    // Skip scrolling for budgeting tips (handled separately)
    if (step.targetKey == InteractiveTutorial.budgetingTipsKey) {
      return;
    }

    // Allow scrolling for calendar tutorial steps except for the calendar overview
    final isCalendarTutorial = step.targetKey == InteractiveTutorial.calendarKey ||
                              step.targetKey == InteractiveTutorial.selectedDayDetailsKey ||
                              step.targetKey == InteractiveTutorial.addReminderKey;
    if (isCalendarTutorial && step.targetKey != InteractiveTutorial.calendarKey) {
      // For calendar tutorials, scroll to the element
      if (widget.scrollController != null && step.targetKey.currentContext != null) {
        // Temporarily enable scrolling during tutorial
        PageTutorials.isRunning = false;
        
        // For transaction details, scroll to the bottom
        if (step.targetKey == InteractiveTutorial.selectedDayDetailsKey) {
          final targetPosition = widget.scrollController!.position.maxScrollExtent;
          if (!mounted) return;
          await widget.scrollController!.animateTo(
            targetPosition,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
          );
        } else {
          if (!mounted) return;
          final RenderBox renderBox = step.targetKey.currentContext!.findRenderObject() as RenderBox;
          final position = renderBox.localToGlobal(Offset.zero);
          final screenHeight = MediaQuery.of(context).size.height;
          final targetHeight = renderBox.size.height;

          // Position based on step type
          final desiredScreenPosition = _getDesiredPosition(step);

          final targetCenter = position.dy + targetHeight / 2;
          final scrollOffset = widget.scrollController!.offset + (targetCenter - desiredScreenPosition);

          if ((targetCenter - desiredScreenPosition).abs() > screenHeight * 0.1) {
            if (!mounted) return;
            await widget.scrollController!.animateTo(
              scrollOffset.clamp(0.0, widget.scrollController!.position.maxScrollExtent),
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeInOut,
            );
          }
        }
        
        // Re-enable tutorial scrolling prevention
        PageTutorials.isRunning = true;
      }
      return;
    }

    // Skip scrolling for other calendar tutorial steps
    if (isCalendarTutorial) {
      return;
    }

    if (widget.scrollController != null && step.targetKey.currentContext != null) {
      if (!mounted) return;
      final RenderBox renderBox = step.targetKey.currentContext!.findRenderObject() as RenderBox;
      final position = renderBox.localToGlobal(Offset.zero);
      final screenHeight = MediaQuery.of(context).size.height;
      final targetHeight = renderBox.size.height;

      // Position based on step type
      final desiredScreenPosition = _getDesiredPosition(step);

      final targetCenter = position.dy + targetHeight / 2;
      final scrollOffset = widget.scrollController!.offset + (targetCenter - desiredScreenPosition);

      if ((targetCenter - desiredScreenPosition).abs() > screenHeight * 0.1) {
        if (!mounted) return;
        await widget.scrollController!.animateTo(
          scrollOffset.clamp(0.0, widget.scrollController!.position.maxScrollExtent),
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    }
  }


  Future<void> _scrollToBudgetingTipsArea() async {
    if (widget.scrollController != null) {
      // Scroll to a position that centers the budgeting tips area
      // Based on the dashboard layout, budgeting tips are around the middle of the scrollable content
      // Estimate position - budgeting tips are typically in the middle third of the page
      // Adjusted to scroll less so the title remains visible
      final targetScrollPosition = widget.scrollController!.position.maxScrollExtent * 0.3;
      
      if (!mounted) return;

      await widget.scrollController!.animateTo(
        targetScrollPosition.clamp(0.0, widget.scrollController!.position.maxScrollExtent),
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _scrollToSavingsProgressArea() async {
    if (widget.scrollController != null) {
      // Scroll to a position that shows the savings progress area
      // Based on the dashboard layout, savings progress is below budgeting tips
      // Scroll a bit further down to ensure the card is fully visible
      final targetScrollPosition = widget.scrollController!.position.maxScrollExtent * 0.8;
      
      if (!mounted) return;

      await widget.scrollController!.animateTo(
        targetScrollPosition.clamp(0.0, widget.scrollController!.position.maxScrollExtent),
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _scrollToChartArea() async {
    if (widget.scrollController != null) {
      // Scroll to a position that shows the financial overview chart area
      // Based on the dashboard layout, chart is near the bottom of the scrollable content
      final targetScrollPosition = widget.scrollController!.position.maxScrollExtent * 1;
      
      if (!mounted) return;

      await widget.scrollController!.animateTo(
        targetScrollPosition.clamp(0.0, widget.scrollController!.position.maxScrollExtent),
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }


  Future<void> _scrollToAmountFieldArea() async {
    if (widget.scrollController != null) {
      // Scroll to amount field area in add transaction page
      final targetScrollPosition = widget.scrollController!.position.maxScrollExtent * 0.1;
      
      if (!mounted) return;

      await widget.scrollController!.animateTo(
        targetScrollPosition.clamp(0.0, widget.scrollController!.position.maxScrollExtent),
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _scrollToCategoryFieldArea() async {
    if (widget.scrollController != null) {
      // Scroll to category field area in add transaction page
      final targetScrollPosition = widget.scrollController!.position.maxScrollExtent * 0.3;
      
      if (!mounted) return;

      await widget.scrollController!.animateTo(
        targetScrollPosition.clamp(0.0, widget.scrollController!.position.maxScrollExtent),
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _scrollToDescriptionFieldArea() async {
    if (widget.scrollController != null) {
      // Scroll to description field area in add transaction page
      final targetScrollPosition = widget.scrollController!.position.maxScrollExtent * 0.6;
      
      if (!mounted) return;

      await widget.scrollController!.animateTo(
        targetScrollPosition.clamp(0.0, widget.scrollController!.position.maxScrollExtent),
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _scrollToDateFieldArea() async {
    if (widget.scrollController != null) {
      // Scroll to date field area in add transaction page
      final targetScrollPosition = widget.scrollController!.position.maxScrollExtent * 0.8;
      
      if (!mounted) return;

      await widget.scrollController!.animateTo(
        targetScrollPosition.clamp(0.0, widget.scrollController!.position.maxScrollExtent),
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _scrollToSaveButtonArea() async {
    if (widget.scrollController != null) {
      // Scroll to save button area in add transaction page
      final targetScrollPosition = widget.scrollController!.position.maxScrollExtent;
      
      if (!mounted) return;

      await widget.scrollController!.animateTo(
        targetScrollPosition,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }


  Future<void> _scrollToDailyAllocationsArea() async {
    if (widget.scrollController != null && widget.scrollController!.hasClients) {
      // Scroll to 25% of the max scroll extent to ensure daily allocations are visible
      final targetPosition = widget.scrollController!.position.maxScrollExtent * 0.25;
      if (!mounted) return;
      await widget.scrollController!.animateTo(
        targetPosition.clamp(0.0, widget.scrollController!.position.maxScrollExtent),
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _scrollToMonthlyAllocationsArea() async {
    if (widget.scrollController != null && widget.scrollController!.hasClients) {
      // Scroll to 70% of the max scroll extent to ensure monthly allocations are visible
      final targetPosition = widget.scrollController!.position.maxScrollExtent * 0.7;
      if (!mounted) return;
      await widget.scrollController!.animateTo(
        targetPosition.clamp(0.0, widget.scrollController!.position.maxScrollExtent),
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _scrollToBudgetSummaryArea() async {
    if (widget.scrollController != null && widget.scrollController!.hasClients) {
      // Scroll to 75% of the max scroll extent to ensure budget summary is visible
      final targetPosition = widget.scrollController!.position.maxScrollExtent * 0.85;
      if (!mounted) return;
      await widget.scrollController!.animateTo(
        targetPosition.clamp(0.0, widget.scrollController!.position.maxScrollExtent),
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _scrollToEmergencyFundArea() async {
    if (widget.scrollController != null && widget.scrollController!.hasClients) {
      // Scroll to 100% of the max scroll extent to show the bottom of the page
      final targetPosition = widget.scrollController!.position.maxScrollExtent;
      if (!mounted) return;
      await widget.scrollController!.animateTo(
        targetPosition,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOut,
      );
    }
  }

  /// Scroll to the selected day details area in the calendar page
  Future<void> _scrollToSelectedDayDetailsArea() async {
    if (widget.scrollController != null && widget.scrollController!.hasClients) {
      // Temporarily enable scrolling during tutorial
      PageTutorials.isRunning = false;
      
      // Scroll to the bottom to show the selected day details
      final targetPosition = widget.scrollController!.position.maxScrollExtent;
      if (!mounted) return;
      await widget.scrollController!.animateTo(
        targetPosition,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOut,
      );
      
      // Re-enable tutorial scrolling prevention
      PageTutorials.isRunning = true;
    }
  }

  /// Scroll to the add reminder button area in the calendar page
  Future<void> _scrollToAddReminderArea() async {
    if (widget.scrollController != null && widget.scrollController!.hasClients) {
      // Temporarily enable scrolling during tutorial
      PageTutorials.isRunning = false;
      
      // Scroll to the bottom to show the add reminder button
      final targetPosition = widget.scrollController!.position.maxScrollExtent;
      if (!mounted) return;
      await widget.scrollController!.animateTo(
        targetPosition,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOut,
      );
      
      // Re-enable tutorial scrolling prevention
      PageTutorials.isRunning = true;
    }
  }

  double _getDesiredPosition(TutorialStep step) {
    if (!mounted) return 0.0;
    final screenHeight = MediaQuery.of(context).size.height;

    // Different positioning for different step types
    if (step.targetKey == InteractiveTutorial.budgetingTipsKey) {
      return screenHeight * 0.25; // Position higher on screen so title is visible
    } else if (step.targetKey == InteractiveTutorial.savingsProgressKey) {
      return screenHeight * 0.8; // Scroll further down to show context below (increased from 0.7 to 0.8)
    } else if (step.targetKey == InteractiveTutorial.chartKey) {
      return screenHeight * 0.67; // Lower third
    } else if (step.targetKey == PageTutorials.selectedDayDetailsKey) {
      return screenHeight * 0.85; // Position near bottom for transaction details
    } else {
      return screenHeight * 0.35; // Default
    }
  }

  Future<void> _markTutorialCompleted() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('dashboard_tutorial_completed', true);
      debugPrint("Dashboard tutorial completed");
    } catch (e) {
      debugPrint("Error marking tutorial completed: $e");
    }
  }
}
/// Widget that adds tutorial highlighting when active
class TutorialHighlight extends StatefulWidget {
  final Widget child;
  final GlobalKey highlightKey;
  final List<GlobalKey>? additionalHighlightKeys; // New parameter for additional keys to highlight

  const TutorialHighlight({
    super.key,
    required this.child,
    required this.highlightKey,
    this.additionalHighlightKeys, // Accept additional keys
  });

  @override
  State<TutorialHighlight> createState() => _TutorialHighlightState();
}

class _TutorialHighlightState extends State<TutorialHighlight>
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
    
    // Listen to changes in the highlighted key with defensive coding
    try {
      InteractiveTutorial.highlightedKeyNotifier.addListener(_onHighlightChanged);
    } catch (e) {
      debugPrint("Error adding highlight listener: $e");
    }
    
    // Initialize highlight state
    _updateHighlightState();
  }

  @override
  void dispose() {
    _isDisposed = true;
    // Remove listener to prevent updates after disposal with defensive coding
    try {
      InteractiveTutorial.highlightedKeyNotifier.removeListener(_onHighlightChanged);
    } catch (e) {
      debugPrint("Error removing highlight listener: $e");
    }
    
    try {
      _pulseController.dispose();
    } catch (e) {
      debugPrint("Error disposing pulse controller: $e");
    }
    
    super.dispose();
  }
  
  void _onHighlightChanged() {
    if (_isDisposed) return;
    _updateHighlightState();
  }
  
  void _updateHighlightState() {
    if (_isDisposed || !mounted) return;
    
    try {
      // Check if current key or any additional keys are highlighted
      final currentHighlightedKey = InteractiveTutorial.highlightedKeyNotifier.value;
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
    } catch (e) {
      debugPrint("Error updating highlight state: $e");
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

/// Special highlight widget for the AppBar that can highlight multiple navigation buttons
class AppBarTutorialHighlight extends StatefulWidget {
  final Widget child;
  final List<GlobalKey> highlightKeys;

  const AppBarTutorialHighlight({
    super.key,
    required this.child,
    required this.highlightKeys,
  });

  @override
  State<AppBarTutorialHighlight> createState() => _AppBarTutorialHighlightState();
}

class _AppBarTutorialHighlightState extends State<AppBarTutorialHighlight>
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
    
    // Listen to changes in the highlighted key with defensive coding
    try {
      InteractiveTutorial.highlightedKeyNotifier.addListener(_onHighlightChanged);
    } catch (e) {
      debugPrint("Error adding highlight listener: $e");
    }
    
    // Initialize highlight state
    _updateHighlightState();
  }

  @override
  void dispose() {
    _isDisposed = true;
    // Remove listener to prevent updates after disposal with defensive coding
    try {
      InteractiveTutorial.highlightedKeyNotifier.removeListener(_onHighlightChanged);
    } catch (e) {
      debugPrint("Error removing highlight listener: $e");
    }
    
    try {
      _pulseController.dispose();
    } catch (e) {
      debugPrint("Error disposing pulse controller: $e");
    }
    
    super.dispose();
  }
  
  void _onHighlightChanged() {
    if (_isDisposed) return;
    _updateHighlightState();
  }
  
  void _updateHighlightState() {
    if (_isDisposed || !mounted) return;
    
    try {
      // Check if any of the highlight keys are currently active
      final currentHighlightedKey = InteractiveTutorial.highlightedKeyNotifier.value;
      final isHighlighted = widget.highlightKeys.contains(currentHighlightedKey);
      
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
    } catch (e) {
      debugPrint("Error updating highlight state: $e");
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

/// Information card for tutorial steps
class TutorialCard extends StatefulWidget {
  final TutorialStep step;
  final VoidCallback onNext;
  final VoidCallback onPrevious;
  final VoidCallback onSkip;
  final bool isFirst;
  final bool isLast;
  final int currentStep;
  final int totalSteps;

  const TutorialCard({
    super.key,
    required this.step,
    required this.onNext,
    required this.onPrevious,
    required this.onSkip,
    required this.isFirst,
    required this.isLast,
    this.currentStep = 0,
    this.totalSteps = 1,
  });

  @override
  State<TutorialCard> createState() => _TutorialCardState();
}

class _TutorialCardState extends State<TutorialCard>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutBack,
      ),
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _isDisposed = true;
    try {
      _controller.dispose();
    } catch (e) {
      debugPrint("Error disposing tutorial card controller: $e");
    }
    
    // Add a small delay before calling super.dispose to ensure all cleanup is complete
    Future.microtask(() {
      // This is just to ensure the dispose process is complete
    });
    
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isDisposed || !mounted) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final screenSize = MediaQuery.of(context).size;
    
    // Adjust padding and font sizes based on screen size
    final double cardPadding = screenSize.width > 600 ? 24.0 : 16.0;
    final double titleFontSize = screenSize.width > 600 ? 24.0 : 20.0;
    final double descriptionFontSize = screenSize.width > 600 ? 18.0 : 16.0;
    final double buttonFontSize = screenSize.width > 600 ? 18.0 : 16.0;
    
    // Adjust card width based on screen size, with a maximum width
    final double cardWidth = screenSize.width > 800 
        ? 600.0 
        : screenSize.width > 600 
            ? screenSize.width * 0.8 
            : screenSize.width * 0.95;
    
    // Adjust colors for better visibility against dimmed background
    final cardBackgroundColor = isDarkMode 
        ? const Color(0xFF3A3A3A) // Lighter dark background for better contrast
        : const Color(0xFFF0F0F0); // Lighter background for better visibility
    
    return Center(
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: FadeTransition(
          opacity: _opacityAnimation,
          child: Container(
            width: cardWidth,
            padding: EdgeInsets.all(cardPadding),
            decoration: BoxDecoration(
              color: cardBackgroundColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: isDarkMode 
                      ? Colors.black.withValues(alpha: 0.7) // Darker shadow for better contrast
                      : Colors.black.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        widget.step.title,
                        style: TextStyle(
                          fontSize: titleFontSize,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.white : Colors.black,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: widget.onSkip,
                      iconSize: titleFontSize,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  widget.step.description,
                  style: TextStyle(
                    fontSize: descriptionFontSize,
                    color: isDarkMode ? Colors.white : Colors.black87, // Darker text for better readability
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),
                // Progress indicator
                if (widget.totalSteps > 1) ...[
                  LinearProgressIndicator(
                    value: widget.totalSteps > 0 ? (widget.currentStep + 1) / widget.totalSteps : 0,
                    backgroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                    color: theme.colorScheme.primary,
                    minHeight: 6,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Step ${widget.currentStep + 1} of ${widget.totalSteps}',
                    style: TextStyle(
                      fontSize: descriptionFontSize - 4,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (!widget.isFirst)
                      TextButton(
                        onPressed: widget.onPrevious,
                        style: TextButton.styleFrom(
                          foregroundColor: isDarkMode 
                              ? Colors.white70 
                              : Colors.black87,
                        ),
                        child: Text(
                          "Previous",
                          style: TextStyle(
                            fontSize: buttonFontSize,
                            fontWeight: FontWeight.w600, // Slightly bolder for better visibility
                          ),
                        ),
                      )
                    else
                      const SizedBox.shrink(),
                    TextButton(
                      onPressed: widget.onSkip,
                      style: TextButton.styleFrom(
                        foregroundColor: isDarkMode 
                            ? Colors.white70 
                            : Colors.black87,
                      ),
                      child: Text(
                        "Skip",
                        style: TextStyle(
                          fontSize: buttonFontSize,
                          fontWeight: FontWeight.w600, // Slightly bolder for better visibility
                        ),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: widget.onNext,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: theme.colorScheme.onPrimary,
                        padding: EdgeInsets.symmetric(
                          horizontal: screenSize.width > 600 ? 24 : 20, 
                          vertical: screenSize.width > 600 ? 12 : 10
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        widget.isLast ? "Finish" : "Next",
                        style: TextStyle(
                          fontSize: buttonFontSize,
                          fontWeight: FontWeight.w600, // Slightly bolder for better visibility
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Custom tutorial controller to replace the old system
class InteractiveTutorial {
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

  // Track which element is currently highlighted
  static final ValueNotifier<GlobalKey?> _currentHighlightedKeyNotifier = ValueNotifier(null);

  static GlobalKey? get currentHighlightedKey => _currentHighlightedKeyNotifier.value;

  static ValueNotifier<GlobalKey?> get highlightedKeyNotifier => _currentHighlightedKeyNotifier;

  static bool _isRunning = false;

  static bool get isRunning => _isRunning;

  /// Reset the highlighted key notifier to prevent issues with disposed widgets
  static void resetHighlightedKeyNotifier() {
    try {
      // Only reset if there's a current value to avoid unnecessary notifications
      if (_currentHighlightedKeyNotifier.value != null) {
        // Add a small delay to ensure any pending operations are completed
        Future.microtask(() {
          try {
            _currentHighlightedKeyNotifier.value = null;
          } catch (e) {
            // Ignore errors when resetting the highlighted key
            debugPrint("Error resetting highlighted key notifier in microtask: $e");
          }
        });
      }
    } catch (e) {
      // Ignore errors when resetting the highlighted key
      debugPrint("Error resetting highlighted key notifier: $e");
    }
  }

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
                    _currentHighlightedKeyNotifier.value = targetKey;
                  } else {
                    // If the target widget is not mounted, don't set the highlighted key
                    debugPrint("Target widget not mounted, skipping highlighted key setting");
                  }
                }
              } catch (e) {
                debugPrint("Error setting initial highlighted key: $e");
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
                      resetHighlightedKeyNotifier();
                      // Mark page as visited after tutorial completion
                      PageTutorials.markPageAsVisited(PageTutorials.DASHBOARD_FIRST_VISIT_KEY);
                    } catch (e) {
                      debugPrint("Error resetting highlighted key notifier: $e");
                    }
                    // Clear progress when tutorial is completed
                    _clearTutorialProgress();
                    // Removed celebration dialog
                    // Only call Navigator.pop if the context is still valid
                    try {
                      if (context.mounted && Navigator.canPop(context)) {
                        Navigator.of(context).pop();
                      }
                    } catch (e) {
                      // Ignore navigation errors
                      debugPrint("Error popping navigator: $e");
                    }
                  },
                );
              },
            ),
          );
        } catch (e) {
          _isRunning = false;
          debugPrint("Error starting tutorial: $e");
        }
      });
    } catch (e) {
      _isRunning = false;
      debugPrint("Error starting tutorial: $e");
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
          debugPrint("Error getting tutorial progress: $e");
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
                  _currentHighlightedKeyNotifier.value = targetKey;
                } else {
                  // If the target widget is not mounted, don't set the highlighted key
                  debugPrint("Target widget not mounted, skipping highlighted key setting");
                }
              }
            } catch (e) {
              debugPrint("Error setting initial highlighted key: $e");
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
                    resetHighlightedKeyNotifier();
                  } catch (e) {
                    debugPrint("Error resetting highlighted key notifier: $e");
                  }
                  // Clear progress when tutorial is completed
                  _clearTutorialProgress();
                  // Removed celebration dialog
                  // Only call Navigator.pop if the context is still valid
                  try {
                    if (context.mounted && Navigator.canPop(context)) {
                      Navigator.of(context).pop();
                    }
                  } catch (e) {
                    // Ignore navigation errors
                    debugPrint("Error popping navigator: $e");
                  }
                },
                startStep: startStep,
              );
            },
          ),
        );
      } catch (e) {
        _isRunning = false;
        debugPrint("Error starting tutorial with progress: $e");
      }
    } catch (e) {
      _isRunning = false;
      debugPrint("Error starting tutorial with progress: $e");
    }
  }

  static void stopTutorial() {
    _isRunning = false;
    try {
      resetHighlightedKeyNotifier();
    } catch (e) {
      debugPrint("Error resetting highlighted key notifier: $e");
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
      debugPrint("Cleared dashboard tutorial progress");
    } catch (e) {
      debugPrint("Error clearing tutorial progress: $e");
    }
  }
}