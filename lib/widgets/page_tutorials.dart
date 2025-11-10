import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'custom_tutorial.dart';
import 'tutorial_celebration.dart';
import 'tutorial_cleanup.dart';

/// Cache for tutorial steps to improve performance
class TutorialCache {
  static final Map<String, List<TutorialStep>> _cache = {};
  
  static List<TutorialStep>? getTutorialSteps(String tutorialId) {
    return _cache[tutorialId];
  }
  
  static void cacheTutorialSteps(String tutorialId, List<TutorialStep> steps) {
    _cache[tutorialId] = steps;
  }
  
  static void clearCache() {
    _cache.clear();
  }
  
  static void clearTutorialCache(String tutorialId) {
    _cache.remove(tutorialId);
  }
}

class PageTutorials {
  static bool _isRunning = false;
  static VoidCallback? onCalendarTutorialSelectToday;
  
  static bool get isRunning {
    debugPrint('PageTutorials.isRunning getter called, returning: $_isRunning');
    return _isRunning;
  }

  static set isRunning(bool value) {
    debugPrint('PageTutorials.isRunning changed from $_isRunning to $value');
    _isRunning = value;
  }

  // Tutorial completion status keys
  static const String CALENDAR_TUTORIAL_KEY = 'calendar_tutorial_completed';
  static const String ADD_TRANSACTION_TUTORIAL_KEY = 'add_transaction_tutorial_completed';
  static const String TRANSACTIONS_TUTORIAL_KEY = 'transactions_tutorial_completed';
  static const String BUDGET_TUTORIAL_KEY = 'budget_tutorial_completed';
  static const String DASHBOARD_TUTORIAL_KEY = 'dashboard_tutorial_completed';
  
  // First visit tracking keys
  static const String CALENDAR_FIRST_VISIT_KEY = 'calendar_first_visit';
  static const String ADD_TRANSACTION_FIRST_VISIT_KEY = 'add_transaction_first_visit';
  static const String TRANSACTIONS_FIRST_VISIT_KEY = 'transactions_first_visit';
  static const String BUDGET_FIRST_VISIT_KEY = 'budget_first_visit';
  static const String DASHBOARD_FIRST_VISIT_KEY = 'dashboard_first_visit';
  
  // Tutorial progress tracking keys
  static const String CALENDAR_TUTORIAL_PROGRESS_KEY = 'calendar_tutorial_progress';
  static const String ADD_TRANSACTION_TUTORIAL_PROGRESS_KEY = 'add_transaction_tutorial_progress';
  static const String TRANSACTIONS_TUTORIAL_PROGRESS_KEY = 'transactions_tutorial_progress';
  static const String BUDGET_TUTORIAL_PROGRESS_KEY = 'budget_tutorial_progress';
  static const String DASHBOARD_TUTORIAL_PROGRESS_KEY = 'dashboard_tutorial_progress';

  // Tutorial IDs for caching
  static const String CALENDAR_TUTORIAL_ID = 'calendar_tutorial';
  static const String ADD_TRANSACTION_TUTORIAL_ID = 'add_transaction_tutorial';
  static const String TRANSACTIONS_TUTORIAL_ID = 'transactions_tutorial';
  static const String BUDGET_TUTORIAL_ID = 'budget_tutorial';
  static const String DASHBOARD_TUTORIAL_ID = 'dashboard_tutorial';

  // GlobalKeys for different pages (kept for compatibility)
  static final GlobalKey calendarKey = GlobalKey();
  static final GlobalKey calendarOverviewKey = GlobalKey(); // New key for calendar overview step
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
  
  // GlobalKeys for budget page with no data tutorial
  static final GlobalKey budgetNoDataKey = GlobalKey();
  static final GlobalKey budgetNoDataInfoKey = GlobalKey();
  static final GlobalKey budgetNoDataAddTransactionKey = GlobalKey();

  /// Start calendar page tutorial
  static Future<void> startCalendarTutorial(BuildContext context, ScrollController? scrollController) async {
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
        List<TutorialStep>? steps = TutorialCache.getTutorialSteps(CALENDAR_TUTORIAL_ID);
        if (steps == null) {
          steps = _createCalendarTutorialSteps();
          // Cache the steps
          TutorialCache.cacheTutorialSteps(CALENDAR_TUTORIAL_ID, steps);
        }
        
        // Set initial highlighted key to the first step's target key
        if (steps.isNotEmpty) {
          // Add a small delay to ensure context is available
          WidgetsBinding.instance.addPostFrameCallback((_) {
            try {
              if (context.mounted) {
                InteractiveTutorial.highlightedKeyNotifier.value = steps!.first.targetKey;
              }
            } catch (e) {
              debugPrint("Error setting initial highlighted key: $e");
            }
          });
        }

        await Navigator.of(context).push(
          PageRouteBuilder(
            opaque: false,
            pageBuilder: (context, _, __) {
              // Double-check context is still valid
              if (!context.mounted) {
                _isRunning = false;
                return const SizedBox.shrink();
              }
              return TutorialOverlay(
                steps: steps!,
                scrollController: scrollController,
                onComplete: () {
                  _isRunning = false;
                  try {
                    InteractiveTutorial.resetHighlightedKeyNotifier();
                    // Mark page as visited after tutorial completion
                    markPageAsVisited(CALENDAR_FIRST_VISIT_KEY);
                  } catch (e) {
                    debugPrint("Error resetting highlighted key notifier: $e");
                  }
                  _clearTutorialProgress(CALENDAR_TUTORIAL_PROGRESS_KEY);
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
        debugPrint("Error starting calendar tutorial: $e");
      }
    } catch (e) {
      _isRunning = false;
      debugPrint("Error starting calendar tutorial: $e");
    }
  }

  /// Start add transaction page tutorial
  static void startAddTransactionTutorial(BuildContext context, ScrollController? scrollController) {
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
          List<TutorialStep>? steps = TutorialCache.getTutorialSteps(ADD_TRANSACTION_TUTORIAL_ID);
          if (steps == null) {
            steps = _createAddTransactionTutorialSteps();
            // Cache the steps
            TutorialCache.cacheTutorialSteps(ADD_TRANSACTION_TUTORIAL_ID, steps);
          }
          
          // Set initial highlighted key
          if (steps.isNotEmpty) {
            // Add a small delay to ensure context is available
            WidgetsBinding.instance.addPostFrameCallback((_) {
              try {
                if (context.mounted) {
                  InteractiveTutorial.highlightedKeyNotifier.value = steps!.first.targetKey;
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
                  steps: steps!,
                  scrollController: scrollController,
                  onComplete: () {
                    _isRunning = false;
                    try {
                      InteractiveTutorial.resetHighlightedKeyNotifier();
                      // Mark page as visited after tutorial completion
                      markPageAsVisited(ADD_TRANSACTION_FIRST_VISIT_KEY);
                    } catch (e) {
                      debugPrint("Error resetting highlighted key notifier: $e");
                    }
                    _clearTutorialProgress(ADD_TRANSACTION_TUTORIAL_PROGRESS_KEY);
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
          debugPrint("Error starting add transaction tutorial: $e");
        }
      });
    } catch (e) {
      _isRunning = false;
      debugPrint("Error starting add transaction tutorial: $e");
    }
  }

  /// Start transactions page tutorial
  static void startTransactionsTutorial(BuildContext context, ScrollController? scrollController) {
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
          List<TutorialStep>? steps = TutorialCache.getTutorialSteps(TRANSACTIONS_TUTORIAL_ID);
          if (steps == null) {
            steps = _createTransactionsTutorialSteps();
            // Cache the steps
            TutorialCache.cacheTutorialSteps(TRANSACTIONS_TUTORIAL_ID, steps);
          }
          
          // Set initial highlighted key
          if (steps.isNotEmpty) {
            // Add a small delay to ensure context is available
            WidgetsBinding.instance.addPostFrameCallback((_) {
              try {
                if (context.mounted) {
                  InteractiveTutorial.highlightedKeyNotifier.value = steps!.first.targetKey;
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
                  steps: steps!,
                  scrollController: scrollController,
                  onComplete: () {
                    _isRunning = false;
                    try {
                      InteractiveTutorial.resetHighlightedKeyNotifier();
                      // Mark page as visited after tutorial completion
                      markPageAsVisited(TRANSACTIONS_FIRST_VISIT_KEY);
                    } catch (e) {
                      debugPrint("Error resetting highlighted key notifier: $e");
                    }
                    _clearTutorialProgress(TRANSACTIONS_TUTORIAL_PROGRESS_KEY);
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
          debugPrint("Error starting transactions tutorial: $e");
        }
      });
    } catch (e) {
      _isRunning = false;
      debugPrint("Error starting transactions tutorial: $e");
    }
  }

  /// Start budget page tutorial
  static void startBudgetTutorial(BuildContext context, ScrollController? scrollController) {
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
          List<TutorialStep>? steps = TutorialCache.getTutorialSteps(BUDGET_TUTORIAL_ID);
          if (steps == null) {
            steps = _createBudgetTutorialSteps();
            // Cache the steps
            TutorialCache.cacheTutorialSteps(BUDGET_TUTORIAL_ID, steps);
          }
          
          // Set initial highlighted key
          if (steps.isNotEmpty) {
            // Add a small delay to ensure context is available
            WidgetsBinding.instance.addPostFrameCallback((_) {
              try {
                if (context.mounted) {
                  InteractiveTutorial.highlightedKeyNotifier.value = steps!.first.targetKey;
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
                  steps: steps!,
                  scrollController: scrollController,
                  onComplete: () {
                    _isRunning = false;
                    try {
                      InteractiveTutorial.resetHighlightedKeyNotifier();
                      // Mark page as visited after tutorial completion
                      markPageAsVisited(BUDGET_FIRST_VISIT_KEY);
                    } catch (e) {
                      debugPrint("Error resetting highlighted key notifier: $e");
                    }
                    _clearTutorialProgress(BUDGET_TUTORIAL_PROGRESS_KEY);
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
          debugPrint("Error starting budget tutorial: $e");
        }
      });
    } catch (e) {
      _isRunning = false;
      debugPrint("Error starting budget tutorial: $e");
    }
  }

  /// Start budget page no data tutorial
  static void startBudgetNoDataTutorial(BuildContext context) {
    if (_isRunning) return;

    _isRunning = true;

    try {
      final steps = _createBudgetNoDataTutorialSteps();
      // Set initial highlighted key with defensive coding
      if (steps.isNotEmpty) {
        // Add a small delay to ensure context is available
        WidgetsBinding.instance.addPostFrameCallback((_) {
          try {
            if (context.mounted) {
              InteractiveTutorial.highlightedKeyNotifier.value = steps.first.targetKey;
            }
          } catch (e) {
            debugPrint("Error setting initial highlighted key: $e");
          }
        });
      }

      Navigator.of(context).push(
        PageRouteBuilder(
          opaque: false,
          pageBuilder: (context, _, __) => TutorialOverlay(
            steps: steps,
            onComplete: () {
              _isRunning = false;
              try {
                InteractiveTutorial.resetHighlightedKeyNotifier();
              } catch (e) {
                debugPrint("Error resetting highlighted key notifier: $e");
              }
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
          ),
        ),
      );
    } catch (e) {
      _isRunning = false;
      debugPrint("Error starting budget no data tutorial: $e");
    }
  }

  /// Stop current tutorial
  static void stopTutorial() {
    _isRunning = false;
    try {
      InteractiveTutorial.resetHighlightedKeyNotifier();
    } catch (e) {
      debugPrint("Error resetting highlighted key notifier in stopTutorial: $e");
    }
  }

  /// Get tutorial progress
  static Future<int> _getTutorialProgress(String progressKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(progressKey) ?? 0;
    } catch (e) {
      debugPrint("Error getting tutorial progress: $e");
      return 0;
    }
  }

  /// Clear tutorial progress (when tutorial is completed or reset)
  static Future<void> _clearTutorialProgress(String progressKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(progressKey);
    } catch (e) {
      debugPrint("Error clearing tutorial progress: $e");
    }
  }

  /// Start calendar page tutorial with progress tracking
  static Future<void> startCalendarTutorialWithProgress(BuildContext context, ScrollController? scrollController, int startStep) async {
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
        List<TutorialStep>? steps = TutorialCache.getTutorialSteps(CALENDAR_TUTORIAL_ID);
        if (steps == null) {
          steps = _createCalendarTutorialSteps();
          // Cache the steps
          TutorialCache.cacheTutorialSteps(CALENDAR_TUTORIAL_ID, steps);
        }
        
        // Set initial highlighted key for calendar tutorial
        if (steps.isNotEmpty && startStep < steps.length) {
          // Add a small delay to ensure context is available
          WidgetsBinding.instance.addPostFrameCallback((_) {
            try {
              if (context.mounted) {
                InteractiveTutorial.highlightedKeyNotifier.value = steps![startStep].targetKey;
              }
            } catch (e) {
              debugPrint("Error setting initial highlighted key: $e");
            }
          });
        }

        await Navigator.of(context).push(
          PageRouteBuilder(
            opaque: false,
            pageBuilder: (context, _, __) {
              // Double-check context is still valid
              if (!context.mounted) {
                _isRunning = false;
                return const SizedBox.shrink();
              }
              return TutorialOverlay(
                steps: steps!,
                scrollController: scrollController,
                onComplete: () {
                  _isRunning = false;
                  try {
                    InteractiveTutorial.resetHighlightedKeyNotifier();
                  } catch (e) {
                    debugPrint("Error resetting highlighted key notifier: $e");
                  }
                  _clearTutorialProgress(CALENDAR_TUTORIAL_PROGRESS_KEY);
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
        debugPrint("Error starting calendar tutorial with progress: $e");
      }
    } catch (e) {
      _isRunning = false;
      debugPrint("Error starting calendar tutorial with progress: $e");
    }
  }

  /// Start add transaction page tutorial with progress tracking
  static void startAddTransactionTutorialWithProgress(BuildContext context, ScrollController? scrollController, int startStep) {
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
          List<TutorialStep>? steps = TutorialCache.getTutorialSteps(ADD_TRANSACTION_TUTORIAL_ID);
          if (steps == null) {
            steps = _createAddTransactionTutorialSteps();
            // Cache the steps
            TutorialCache.cacheTutorialSteps(ADD_TRANSACTION_TUTORIAL_ID, steps);
          }
          
          // Set initial highlighted key
          if (steps.isNotEmpty && startStep < steps.length) {
            // Add a small delay to ensure context is available
            WidgetsBinding.instance.addPostFrameCallback((_) {
              try {
                if (context.mounted) {
                  InteractiveTutorial.highlightedKeyNotifier.value = steps![startStep].targetKey;
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
                  steps: steps!,
                  scrollController: scrollController,
                  onComplete: () {
                    _isRunning = false;
                    try {
                      InteractiveTutorial.resetHighlightedKeyNotifier();
                    } catch (e) {
                      debugPrint("Error resetting highlighted key notifier: $e");
                    }
                    _clearTutorialProgress(ADD_TRANSACTION_TUTORIAL_PROGRESS_KEY);
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
          debugPrint("Error starting add transaction tutorial with progress: $e");
        }
      });
    } catch (e) {
      _isRunning = false;
      debugPrint("Error starting add transaction tutorial with progress: $e");
    }
  }

  /// Start transactions page tutorial with progress tracking
  static void startTransactionsTutorialWithProgress(BuildContext context, ScrollController? scrollController, int startStep) {
    if (_isRunning) return;

    _isRunning = true;

    try {
      // Try to get cached steps first
      List<TutorialStep>? steps = TutorialCache.getTutorialSteps(TRANSACTIONS_TUTORIAL_ID);
      if (steps == null) {
        steps = _createTransactionsTutorialSteps();
        // Cache the steps
        TutorialCache.cacheTutorialSteps(TRANSACTIONS_TUTORIAL_ID, steps);
      }
      
      // Set initial highlighted key
      if (steps.isNotEmpty && startStep < steps.length) {
        // Add a small delay to ensure context is available
        WidgetsBinding.instance.addPostFrameCallback((_) {
          try {
            if (context.mounted) {
              InteractiveTutorial.highlightedKeyNotifier.value = steps![startStep].targetKey;
            }
          } catch (e) {
            debugPrint("Error setting initial highlighted key: $e");
          }
        });
      }

      Navigator.of(context).push(
        PageRouteBuilder(
          opaque: false,
          pageBuilder: (context, _, __) => TutorialOverlay(
            steps: steps!,
            scrollController: scrollController,
            onComplete: () {
              _isRunning = false;
              try {
                InteractiveTutorial.resetHighlightedKeyNotifier();
              } catch (e) {
                debugPrint("Error resetting highlighted key notifier: $e");
              }
              _clearTutorialProgress(TRANSACTIONS_TUTORIAL_PROGRESS_KEY);
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
          ),
        ),
      );
    } catch (e) {
      _isRunning = false;
      debugPrint("Error starting transactions tutorial with progress: $e");
    }
  }

  /// Start budget page tutorial with progress tracking
  static void startBudgetTutorialWithProgress(BuildContext context, ScrollController? scrollController, int startStep) {
    if (_isRunning) return;

    _isRunning = true;

    try {
      // Try to get cached steps first
      List<TutorialStep>? steps = TutorialCache.getTutorialSteps(BUDGET_TUTORIAL_ID);
      if (steps == null) {
        steps = _createBudgetTutorialSteps();
        // Cache the steps
        TutorialCache.cacheTutorialSteps(BUDGET_TUTORIAL_ID, steps);
      }
      
      // Set initial highlighted key
      if (steps.isNotEmpty && startStep < steps.length) {
        // Add a small delay to ensure context is available
        WidgetsBinding.instance.addPostFrameCallback((_) {
          try {
            if (context.mounted) {
              InteractiveTutorial.highlightedKeyNotifier.value = steps![startStep].targetKey;
            }
          } catch (e) {
            debugPrint("Error setting initial highlighted key: $e");
          }
        });
      }

      Navigator.of(context).push(
        PageRouteBuilder(
          opaque: false,
          pageBuilder: (context, _, __) => TutorialOverlay(
            steps: steps!,
            scrollController: scrollController,
            onComplete: () {
              _isRunning = false;
              try {
                InteractiveTutorial.resetHighlightedKeyNotifier();
              } catch (e) {
                debugPrint("Error resetting highlighted key notifier: $e");
              }
              _clearTutorialProgress(BUDGET_TUTORIAL_PROGRESS_KEY);
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
          ),
        ),
      );
    } catch (e) {
      _isRunning = false;
      debugPrint("Error starting budget tutorial with progress: $e");
    }
  }

  /// Start budget page no data tutorial with progress tracking
  static void startBudgetNoDataTutorialWithProgress(BuildContext context, int startStep) {
    if (_isRunning) return;

    _isRunning = true;

    try {
      final steps = _createBudgetNoDataTutorialSteps();
      // Set initial highlighted key
      if (steps.isNotEmpty && startStep < steps.length) {
        // Add a small delay to ensure context is available
        WidgetsBinding.instance.addPostFrameCallback((_) {
          try {
            if (context.mounted) {
              InteractiveTutorial.highlightedKeyNotifier.value = steps[startStep].targetKey;
            }
          } catch (e) {
            debugPrint("Error setting initial highlighted key: $e");
          }
        });
      }

      Navigator.of(context).push(
        PageRouteBuilder(
          opaque: false,
          pageBuilder: (context, _, __) => TutorialOverlay(
            steps: steps,
            onComplete: () {
              _isRunning = false;
              try {
                InteractiveTutorial.resetHighlightedKeyNotifier();
                // Mark page as visited after tutorial completion
                markPageAsVisited(BUDGET_FIRST_VISIT_KEY);
              } catch (e) {
                debugPrint("Error resetting highlighted key notifier: $e");
              }
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
          ),
        ),
      );
    } catch (e) {
      _isRunning = false;
      debugPrint("Error starting budget no data tutorial with progress: $e");
    }
  }

  /// Resume calendar tutorial from last progress
  static Future<void> resumeCalendarTutorial(BuildContext context, ScrollController? scrollController) async {
    final progress = await _getTutorialProgress(CALENDAR_TUTORIAL_PROGRESS_KEY);
    startCalendarTutorialWithProgress(context, scrollController, progress);
  }

  /// Resume add transaction tutorial from last progress
  static void resumeAddTransactionTutorial(BuildContext context, ScrollController? scrollController) {
    final progress = _getTutorialProgress(ADD_TRANSACTION_TUTORIAL_PROGRESS_KEY);
    progress.then((value) => startAddTransactionTutorialWithProgress(context, scrollController, value));
  }

  /// Resume transactions tutorial from last progress
  static void resumeTransactionsTutorial(BuildContext context, ScrollController? scrollController) {
    final progress = _getTutorialProgress(TRANSACTIONS_TUTORIAL_PROGRESS_KEY);
    progress.then((value) => startTransactionsTutorialWithProgress(context, scrollController, value));
  }

  /// Resume budget tutorial from last progress
  static void resumeBudgetTutorial(BuildContext context, ScrollController? scrollController) {
    final progress = _getTutorialProgress(BUDGET_TUTORIAL_PROGRESS_KEY);
    progress.then((value) => startBudgetTutorialWithProgress(context, scrollController, value));
  }

  /// Check if this is the user's first visit to a page
  static Future<bool> _isFirstVisit(String visitKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hasVisited = prefs.getBool(visitKey) ?? false;
      // Return true if user has NOT visited this page before
      return !hasVisited;
    } catch (e) {
      debugPrint("Error checking first visit: $e");
      return false;
    }
  }

  /// Mark a page as visited (call this after showing the tutorial)
  static Future<void> markPageAsVisited(String visitKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(visitKey, true);
    } catch (e) {
      debugPrint("Error marking page as visited: $e");
    }
  }

  /// Check if calendar page is being visited for the first time
  static Future<bool> isCalendarFirstVisit() async {
    return await _isFirstVisit(CALENDAR_FIRST_VISIT_KEY);
  }

  /// Check if add transaction page is being visited for the first time
  static Future<bool> isAddTransactionFirstVisit() async {
    return await _isFirstVisit(ADD_TRANSACTION_FIRST_VISIT_KEY);
  }

  /// Check if transactions page is being visited for the first time
  static Future<bool> isTransactionsFirstVisit() async {
    return await _isFirstVisit(TRANSACTIONS_FIRST_VISIT_KEY);
  }

  /// Check if budget page is being visited for the first time
  static Future<bool> isBudgetFirstVisit() async {
    return await _isFirstVisit(BUDGET_FIRST_VISIT_KEY);
  }

  /// Check if dashboard page is being visited for the first time
  static Future<bool> isDashboardFirstVisit() async {
    return await _isFirstVisit(DASHBOARD_FIRST_VISIT_KEY);
  }

  static List<TutorialStep> _createCalendarTutorialSteps() {
    return [
      TutorialStep(
        title: "Calendar Overview",
        description: "This is your Calendar - your financial timeline. Here you can see all your transactions organized by date, with color-coded days showing your spending patterns.",
        targetKey: calendarOverviewKey,
      ),
      TutorialStep(
        title: "Daily Transactions",
        description: "Tap any day to see detailed transactions for that date. Days are color-coded based on your transaction - green for recorded income, red for spending, blue for savings, orange for debt and dark blue for emergency fund input.",
        targetKey: calendarKey,
      ),
      TutorialStep(
        title: "Transaction Details",
        description: "When you select a day, this section shows all transactions and reminders for that date. Switch between Transactions and Reminders tabs to see different information.",
        targetKey: selectedDayDetailsKey,
      ),
      TutorialStep(
        title: "Add Reminders",
        description: "Use this button (bell logo) on the bottom right of the page to add reminders for bills, savings goals, or any important financial dates. Reminders help you stay on top of your financial commitments.",
        targetKey: addReminderKey,
      ),
    ];
  }

  static List<TutorialStep> _createAddTransactionTutorialSteps() {
    return [
      TutorialStep(
        title: "Choose Transaction Type",
        description: "First, select what type of transaction you want to add. Choose from Expense, Income, Savings, Emergency Fund, Debt, and more. Each type serves a different financial purpose.",
        targetKey: InteractiveTutorial.transactionTypeKey,
      ),
      TutorialStep(
        title: "Enter Amount",
        description: "Enter the monetary amount for this transaction. Use numbers only - the app will format it properly. For emergency fund withdrawals, you'll see your available balance.",
        targetKey: InteractiveTutorial.amountFieldKey,
      ),
      TutorialStep(
        title: "Select Category",
        description: "If you chose Expense, pick a specific category like Food, Transportation, or Entertainment. This helps you track where your money goes.",
        targetKey: InteractiveTutorial.categoryFieldKey,
      ),
      TutorialStep(
        title: "Add Description",
        description: "Add a note to remember what this transaction was for. This is optional but helps you keep track of your spending details.",
        targetKey: InteractiveTutorial.descriptionFieldKey,
      ),
      TutorialStep(
        title: "Pick Date",
        description: "Select when this transaction occurred. You can choose any date, even in the past, to accurately track your financial history.",
        targetKey: InteractiveTutorial.dateFieldKey,
      ),
      TutorialStep(
        title: "Save Transaction",
        description: "Review your information and tap Save to add this transaction to your financial records. It will appear in your Calendar and update your Dashboard.",
        targetKey: InteractiveTutorial.saveButtonKey,
      ),
    ];
  }

  static List<TutorialStep> _createTransactionsTutorialSteps() {
    return [
      TutorialStep(
        title: "Search Transactions",
        description: "Use this search bar to find specific transactions by description or category. Type any keyword to filter your transaction history.",
        targetKey: InteractiveTutorial.searchBarKey,
      ),
      TutorialStep(
        title: "Filter by Time Frame",
        description: "Choose different time periods to view your transactions - daily, weekly, monthly, or custom date ranges to focus on specific periods.",
        targetKey: InteractiveTutorial.timeFrameFilterKey,
      ),
      TutorialStep(
        title: "Filter by Type",
        description: "Tap this filter button to narrow down transactions by type (Income, Expense, Savings, etc.). The button shows an active color when filters are applied.",
        targetKey: InteractiveTutorial.filterButtonKey,
      ),
      TutorialStep(
        title: "Transaction List",
        description: "Your transactions are grouped by date. Each card shows the transaction details. Tap any transaction to view full details or delete it.",
        targetKey: InteractiveTutorial.transactionsListKey,
      ),
      TutorialStep(
        title: "View Details & Delete",
        description: "Tap any transaction card to see full details in a popup. From there, you can delete transactions you no longer need. Be careful - deletions cannot be undone.",
        targetKey: InteractiveTutorial.transactionsListKey,
      ),
    ];
  }

  static List<TutorialStep> _createBudgetTutorialSteps() {
    return [
      TutorialStep(
        title: "Budget Overview",
        description: "This shows your personalized budget for the current month. The budget is generated based on your spending patterns from previous months.",
        targetKey: budgetOverviewKey,
      ),
      TutorialStep(
        title: "Data Source Month",
        description: "Your budget is calculated from your spending data in the previous month. This ensures your budget reflects your actual spending habits.",
        targetKey: budgetOverviewKey,
      ),
      TutorialStep(
        title: "Daily Budget Allowance",
        description: "These are flexible daily spending categories like Food and Transportation. The amounts are based on your historical spending patterns.",
        targetKey: dailyAllocationsKey,
      ),
      TutorialStep(
        title: "Fixed Monthly Expenses",
        description: "These are recurring monthly costs like rent, utilities, and subscriptions. The amounts are carried forward from your previous month's spending.",
        targetKey: monthlyAllocationsKey,
      ),
      TutorialStep(
        title: "Budget Allocation Summary",
        description: "This summary shows your total monthly net income, total budget allocated, and any remaining budget. It helps you understand your overall financial picture.",
        targetKey: budgetSummaryKey,
      ),
      TutorialStep(
        title: "Emergency Fund Progress",
        description: "Track your emergency fund savings here. The goal is typically 3 months of your highest monthly expenses as a safety net.",
        targetKey: emergencyFundKey,
      ),
    ];
  }

  static List<TutorialStep> _createBudgetNoDataTutorialSteps() {
    return [
      TutorialStep(
        title: "No Budget Data Available",
        description: "To generate a personalized budget, we need spending data from your previous month. This helps us understand your spending patterns.",
        targetKey: budgetNoDataKey,
      ),
      TutorialStep(
        title: "How to Add Transactions",
        description: "Go to the Calendar or Transactions page and add your spending from last month. The more data you enter, the better your budget will be.",
        targetKey: budgetNoDataAddTransactionKey,
      ),
      TutorialStep(
        title: "Getting Started",
        description: "Start by adding a few transactions from last month. Even partial data will help generate a basic budget for this month.",
        targetKey: budgetNoDataInfoKey,
      ),
    ];
  }

  // Remove _showFeedbackDialog and _submitFeedback methods
}
