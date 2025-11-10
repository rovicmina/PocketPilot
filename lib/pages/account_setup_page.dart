import 'package:flutter/material.dart';
import '../services/firebase_service.dart';
import '../models/budget.dart';
import '../utils/form_state_tracker.dart';
import '../widgets/unsaved_changes_dialog.dart';
import '../widgets/tutorial_cleanup.dart';
import 'main_navigation.dart';

class AccountSetupPage extends StatefulWidget {
  const AccountSetupPage({super.key});

  @override
  State<AccountSetupPage> createState() => _AccountSetupPageState();
}

class _AccountSetupPageState extends State<AccountSetupPage> with FormStateTracker {
  final _formKey = GlobalKey<FormState>();
  late final TrackedTextEditingController _budgetController;

  final Map<String, TrackedTextEditingController> _categoryControllers = {};
  final Map<String, double> _categoryBudgets = {};

  @override
  void initState() {
    super.initState();

    // Initialize main budget controller
    _budgetController = createTrackedController('budget', this);

    // Initialize category controllers
    for (String category in BudgetCategory.defaultCategories) {
      _categoryControllers[category] = createTrackedController('category_$category', this);
      _categoryBudgets[category] = 0.0;
    }

    // Initialize form tracking
    Map<String, dynamic> initialValues = {
      'budget': '',
      'categoryBudgets': Map<String, double>.from(_categoryBudgets),
    };
    for (String category in BudgetCategory.defaultCategories) {
      initialValues['category_$category'] = '';
    }
    initializeFormTracking(initialValues);
  }

  String? _validateBudget(String? value) {
    if (value == null || value.isEmpty) {
      return 'Initial budget is required';
    }
    final budget = double.tryParse(value);
    if (budget == null || budget < 0) {
      return 'Please enter a valid budget amount';
    }
    return null;
  }

  String? _validateCategoryBudget(String? value) {
    if (value == null || value.isEmpty) {
      return null; // Category budgets are optional
    }
    final budget = double.tryParse(value);
    if (budget == null || budget < 0) {
      return 'Invalid amount';
    }
    return null;
  }

  void _updateCategoryBudget(String category, String value) {
    final budget = double.tryParse(value);
    if (budget != null) {
      setState(() {
        _categoryBudgets[category] = budget;
      });
      updateFormField('categoryBudgets', Map<String, double>.from(_categoryBudgets));
    }
  }

  double get _totalCategoryBudgets {
    return _categoryBudgets.values.fold(0.0, (sum, amount) => sum + amount);
  }

  @override
  Widget build(BuildContext context) {
    return FormPageWrapper(
      hasUnsavedChanges: hasUnsavedChanges,
      warningTitle: 'Discard Account Setup?',
      warningMessage: 'You have entered budget information. Are you sure you want to go back without completing the setup?',
      child: Scaffold(
      appBar: AppBar(
        title: LayoutBuilder(
          builder: (context, constraints) {
            final isNarrowScreen = MediaQuery.of(context).size.width < 600;
            final titleFontSize = isNarrowScreen ? 20.0 : 22.0; // Section Heading range (20–24sp)
            
            return Text(
              'Account Setup',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: titleFontSize,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            );
          },
        ),
        backgroundColor: Colors.teal,
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.account_balance_wallet,
                size: 80,
                color: Colors.teal,
              ),
              const SizedBox(height: 16),
              const Text(
                'Set up your budget',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 32),

              // Initial budget field
              TextFormField(
                controller: _budgetController,
                decoration: const InputDecoration(
                  labelText: 'Initial Budget (PHP)',
                  prefixIcon: Icon(Icons.account_balance),
                  border: OutlineInputBorder(),
                  helperText: 'This is your starting budget amount',
                ),
                keyboardType: TextInputType.number,
                validator: _validateBudget,
              ),
              const SizedBox(height: 24),

              const Text(
                'Category Budgets (Optional)',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Set spending limits for each category. You can modify these later.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 16),

              // Category budget fields
              ...(BudgetCategory.defaultCategories.map((category) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: TextFormField(
                    controller: _categoryControllers[category],
                    decoration: InputDecoration(
                      labelText: '${BudgetCategory.getCategoryIcon(category)} $category',
                      prefixIcon: const Icon(Icons.category),
                      border: const OutlineInputBorder(),
                      suffixText: 'PHP',
                    ),
                    keyboardType: TextInputType.number,
                    validator: _validateCategoryBudget,
                    onChanged: (value) => _updateCategoryBudget(category, value),
                  ),
                );
              }).toList()),

              const SizedBox(height: 16),

              // Total category budgets display
              if (_totalCategoryBudgets > 0)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.teal.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.teal.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total Category Budgets:',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        '₱${_totalCategoryBudgets.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.teal,
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 32),

              ElevatedButton(
                onPressed: () async {
                  if (_formKey.currentState!.validate()) {
                    setSubmitting(true);
                    final scaffoldMessenger = ScaffoldMessenger.of(context);
                    final navigator = Navigator.of(context);
                    final initialBudget = double.parse(_budgetController.text);

                    // Filter out empty category budgets
                    final filteredCategoryBudgets = <String, double>{};
                    for (final entry in _categoryBudgets.entries) {
                      if (entry.value > 0) {
                        filteredCategoryBudgets[entry.key] = entry.value;
                      }
                    }

                    // Create budget object
                    final budget = Budget(
                      id: 'budget_${DateTime.now().millisecondsSinceEpoch}',
                      monthlyBudget: initialBudget,
                      categoryBudgets: filteredCategoryBudgets,
                      month: DateTime.now(),
                    );

                    // Save budget
                    await FirebaseService.saveBudget(budget);

                    if (mounted) {
                      // Show success message
                      scaffoldMessenger.showSnackBar(
                        const SnackBar(
                          content: Text('Account setup completed successfully!'),
                          backgroundColor: Colors.green,
                        ),
                      );

                      // Show tutorial information dialog before navigating to main app
                      await showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (BuildContext context) {
                          return AlertDialog(
                            title: const Text('Welcome to PocketPilot!'),
                            content: const Text(
                              'For tutorials on each page, click the help button (❓) in the top right corner.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () {
                                  Navigator.of(context).pop();
                                  // Clean up tutorial resources and navigate to main app
                                  TutorialCleanup.forceCleanup();
                                  Navigator.of(context).pushReplacement(
                                    MaterialPageRoute(builder: (context) => const MainNavigation()),
                                  );
                                },
                                child: const Text('Got it'),
                              ),
                            ],
                          );
                        },
                      );
                    }
                  }
                },
                child: const Padding(
                  padding: EdgeInsets.all(12.0),
                  child: Text(
                    'Complete Setup',
                    style: TextStyle(fontSize: 18),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              TextButton(
                onPressed: () async {
                  // Show tutorial information dialog before navigating to main app
                  await showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (BuildContext context) {
                      return AlertDialog(
                        title: const Text('Welcome to PocketPilot!'),
                        content: const Text(
                          'For tutorials on each page, click the help button (❓) in the top right corner.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                              // Navigate to main app after user acknowledges the message
                              Navigator.of(context).pushReplacement(
                                MaterialPageRoute(builder: (context) => const MainNavigation()),
                              );
                            },
                            child: const Text('Got it'),
                          ),
                        ],
                      );
                    },
                  );
                },
                child: const Text(
                  'Skip for now',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
    );
  }

  @override
  void dispose() {
    _budgetController.dispose();
    for (final controller in _categoryControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }
}
