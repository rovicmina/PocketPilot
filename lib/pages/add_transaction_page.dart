import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/transaction.dart';
import '../models/budget.dart';
import '../models/user.dart' as app_user;
import '../services/transaction_recording_service.dart';
import '../services/transaction_notifier.dart';
import '../services/firebase_service.dart';
import '../utils/form_state_tracker.dart';
import '../widgets/unsaved_changes_dialog.dart';
import '../widgets/page_tutorials.dart';
import '../widgets/custom_tutorial.dart';

class AddTransactionPage extends StatefulWidget {
  final Transaction? transaction; // Optional transaction for editing

  const AddTransactionPage({super.key, this.transaction});

  @override
  State<AddTransactionPage> createState() => _AddTransactionPageState();
}

class _AddTransactionPageState extends State<AddTransactionPage> with FormStateTracker {
  final _formKey = GlobalKey<FormState>();
  late final TrackedTextEditingController _amountController;
  late final TrackedTextEditingController _decimalController;
  late final TrackedTextEditingController _descriptionController;

  TransactionType _selectedType = TransactionType.expense;
  String _selectedCategory = BudgetCategory.defaultCategories.first;
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;
  bool _isEditMode = false;
  app_user.User? _currentUser;

  // Transaction notifier for real-time updates
  final TransactionNotifier _transactionNotifier = TransactionNotifier();

  // Scroll controller for tutorial scrolling
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();

    // Load current user data
    _loadCurrentUser();

    // Check if we're editing an existing transaction
    _isEditMode = widget.transaction != null;

    if (_isEditMode) {
      // Pre-populate fields with existing transaction data
      final transaction = widget.transaction!;
      _selectedType = transaction.type;
      _selectedCategory = transaction.category;
      _selectedDate = transaction.date;
    }

    _amountController = createTrackedController('amount', this);
    _decimalController = createTrackedController('decimal', this);
    _descriptionController = createTrackedController('description', this);

    // Set initial values if editing
    if (_isEditMode) {
      final amountString = widget.transaction!.amount.toStringAsFixed(2);
      final parts = amountString.split('.');
      _amountController.text = parts[0];
      _decimalController.text = parts.length > 1 ? parts[1] : '00';
      _descriptionController.text = widget.transaction!.description;
    }

    // Initialize form tracking with default values
    initializeFormTracking({
      'amount': _amountController.text,
      'decimal': _decimalController.text,
      'description': _descriptionController.text,
      'selectedType': _selectedType,
      'selectedCategory': _selectedCategory,
      'selectedDate': _selectedDate,
    });

    // Removed automatic tutorial start - users can click the help button to start tutorial
  }
  
  // Removed automatic tutorial start - users can click the help button to start tutorial

  Future<void> _loadCurrentUser() async {
    try {
      final user = await FirebaseService.getUser();
      if (mounted) {
        setState(() {
          _currentUser = user;
        });
      }
    } catch (e) {
      // Error loading current user - silently handle
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _decimalController.dispose();
    _descriptionController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Widget _buildTransactionTypeCard(TransactionType type) {
    final isSelected = _selectedType == type;
    final typeInfo = _getTransactionTypeInfo(type);
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        // Responsive sizing for transaction type cards
        final cardWidth = constraints.maxWidth;
        final isCompactCard = cardWidth < 120;
        final iconSize = isCompactCard ? 20.0 : 24.0;
        final fontSize = isCompactCard ? 10.0 : 11.0;
        final descriptionFontSize = isCompactCard ? 8.0 : 9.0;
        final verticalPadding = isCompactCard ? 8.0 : 12.0;
        final horizontalPadding = isCompactCard ? 2.0 : 4.0;

        return Card(
          elevation: isSelected ? 4 : 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: isSelected ? theme.colorScheme.primary : theme.dividerColor,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: InkWell(
            onTap: () {
              setState(() => _selectedType = type);
              updateFormField('selectedType', type);
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: EdgeInsets.symmetric(vertical: verticalPadding, horizontal: horizontalPadding),
              decoration: BoxDecoration(
                color: isSelected ? theme.colorScheme.primary.withValues(alpha: 0.1) : theme.cardTheme.color,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    typeInfo.icon,
                    color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    size: iconSize,
                  ),
                  SizedBox(height: isCompactCard ? 2 : 4),
                  Text(
                    typeInfo.label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                      fontSize: fontSize,
                    ),
                    maxLines: isCompactCard ? 2 : 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: isCompactCard ? 1 : 2),
                  Text(
                    typeInfo.description,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      fontSize: descriptionFontSize,
                    ),
                    maxLines: isCompactCard ? 2 : 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  TransactionTypeInfo _getTransactionTypeInfo(TransactionType type) {
    switch (type) {
      case TransactionType.expense:
        return const TransactionTypeInfo(
          icon: Icons.shopping_cart,
          label: 'EXPENSE',
          description: 'Money spent',
        );
      case TransactionType.income:
        return const TransactionTypeInfo(
          icon: Icons.account_balance_wallet,
          label: 'INCOME',
          description: 'Money received',
        );
      case TransactionType.savings:
        return const TransactionTypeInfo(
          icon: Icons.savings,
          label: 'SAVINGS',
          description: 'Money saved',
        );
      case TransactionType.savingsWithdrawal:
        return const TransactionTypeInfo(
          icon: Icons.account_balance,
          label: 'WITHDRAW',
          description: 'From savings',
        );
      case TransactionType.debt:
        return const TransactionTypeInfo(
          icon: Icons.credit_card,
          label: 'DEBT',
          description: 'Money borrowed',
        );
      case TransactionType.debtPayment:
        return const TransactionTypeInfo(
          icon: Icons.payments,
          label: 'DEBT PAYMENT',
          description: 'Pay borrowed money',
        );
      case TransactionType.recurringExpense:
        return const TransactionTypeInfo(
          icon: Icons.repeat,
          label: 'RECURRING',
          description: 'Regular expense',
        );
      case TransactionType.emergencyFund:
        return const TransactionTypeInfo(
          icon: Icons.emergency,
          label: 'EMERGENCY FUND',
          description: 'Add to emergency',
        );
      case TransactionType.emergencyFundWithdrawal:
        return const TransactionTypeInfo(
          icon: Icons.warning,
          label: 'WITHDRAW',
          description: 'From emergency fund',
        );
    }
  }

  Future<void> _selectDate() async {
    // For emergency fund withdrawals, restrict to present and past dates only
    final DateTime lastDate = _selectedType == TransactionType.emergencyFundWithdrawal
        ? DateTime.now()
        : DateTime.now().add(const Duration(days: 365));

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: lastDate,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.teal,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      updateFormField('selectedDate', picked);
    }
  }

  Future<void> _saveTransaction() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Combine integer and decimal parts
    final integerPart = _amountController.text.isEmpty ? '0' : _amountController.text;
    final decimalPart = _decimalController.text.padRight(2, '0').substring(0, 2);
    final amountString = '$integerPart.$decimalPart';
    final amount = double.parse(amountString);

    // Validate amount
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid amount'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Check for suspicious decimal-only inputs (integer part is 0 but decimal part has value)
    final hasIntegerValue = integerPart != '0' && integerPart.isNotEmpty;
    final hasDecimalValue = decimalPart != '00' && decimalPart.isNotEmpty;

    if (!hasIntegerValue && hasDecimalValue) {
      final shouldProceed = await showDialog<bool>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Confirm Amount'),
            content: Text(
              'You entered ₱$amountString. This appears to be a very small amount (less than ₱1.00). Are you sure this is correct?',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Yes, Continue'),
              ),
            ],
          );
        },
      );

      if (shouldProceed != true) {
        return; // User cancelled
      }
    }

    // For emergency fund withdrawal, check if amount exceeds available balance
    if (_selectedType == TransactionType.emergencyFundWithdrawal) {
      final availableBalance = _currentUser?.emergencyFundAmount ?? 0.0;
      if (amount > availableBalance) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Amount exceeds available emergency fund balance (₱${availableBalance.toStringAsFixed(2)})'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
    }

    // Check for large amounts (>= 2x monthly net) for income and expense transactions
    if ((_selectedType == TransactionType.income || _selectedType == TransactionType.expense) &&
        _currentUser?.monthlyNet != null &&
        amount >= (_currentUser!.monthlyNet! * 2)) {

      if (mounted) {
        final shouldProceed = await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Large Amount Confirmation'),
              content: Text(
                'The amount ₱${amount.toStringAsFixed(2)} is quite large compared to your monthly net income of ₱${_currentUser!.monthlyNet!.toStringAsFixed(2)}. Are you sure this is correct?',
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Yes, Continue'),
                ),
              ],
            );
          },
        );

        if (shouldProceed != true) {
          return; // User cancelled
        }
      }
    }

    setSubmitting(true);
    setState(() {
      _isLoading = true;
    });

    try {

      // For non-expense types, use a default category or the transaction type name
      String category = _selectedCategory;
      if (_selectedType != TransactionType.expense) {
        category = _selectedType.toString().split('.').last;
      }

      // Provide default description if empty
      String description = _descriptionController.text.trim();
      if (description.isEmpty) {
        description = 'Transaction - $category';
      }

      if (_isEditMode) {
        // Update existing transaction
        final updatedTransaction = Transaction(
          id: widget.transaction!.id,
          amount: amount,
          type: _selectedType,
          category: category,
          description: description,
          date: _selectedDate,
        );

        await FirebaseService.updateTransaction(updatedTransaction);

        if (mounted) {
          // Notify all listeners that a transaction was updated
          _transactionNotifier.notifyTransactionAdded();

          Navigator.of(context).pop(true); // Return true to indicate success
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Transaction updated successfully!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        // Optimistic UI update - notify before saving
        _transactionNotifier.notifyTransactionAdded();

        // Close the modal immediately for better UX
        if (mounted) {
          Navigator.of(context).pop(true);
        }

        // Show success message immediately
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Transaction added successfully!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }

        // Save in background with proper emergency fund handling
        bool success = false;
        if (_selectedType == TransactionType.emergencyFund) {
          success = await TransactionRecordingService.recordEmergencyFundDeposit(
            amount: amount,
            description: description,
            date: _selectedDate,
          );
        } else if (_selectedType == TransactionType.emergencyFundWithdrawal) {
          success = await TransactionRecordingService.recordEmergencyFundWithdrawal(
            amount: amount,
            description: description,
            date: _selectedDate,
          );
        } else if (_selectedType == TransactionType.debt) {
          // Handle debt income specially to also record as income
          success = await TransactionRecordingService.recordDebtIncome(
            amount: amount,
            description: description,
            category: category,
            date: _selectedDate,
          );
        } else {
          success = await TransactionRecordingService.recordManualTransaction(
            amount: amount,
            type: _selectedType,
            category: category,
            description: description,
            date: _selectedDate,
          );
        }

        // If save failed, notify user but don't revert UI (TransactionNotifier handles consistency)
        if (!success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Transaction saved to queue - will sync when connection improves'),
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
            content: Text('Error ${_isEditMode ? 'updating' : 'adding'} transaction: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return FormPageWrapper(
      hasUnsavedChanges: hasUnsavedChanges,
      warningTitle: 'Discard Transaction?',
      warningMessage: 'You have entered transaction information. Are you sure you want to go back without saving?',
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          title: LayoutBuilder(
            builder: (context, constraints) {
              final isNarrowScreen = MediaQuery.of(context).size.width < 600;
              final titleFontSize = isNarrowScreen ? 20.0 : 22.0; // Section Heading range (20–24sp)

              return Text(
                _isEditMode ? 'Edit Transaction' : 'Add Transaction',
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
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
              icon: Icon(Icons.help_outline, color: theme.appBarTheme.foregroundColor),
              onPressed: () => PageTutorials.startAddTransactionTutorial(context, _scrollController),
              tooltip: 'Show Tutorial',
            ),
            LayoutBuilder(
              builder: (context, constraints) {
                final isNarrowScreen = MediaQuery.of(context).size.width < 600;
                final actionTextFontSize = isNarrowScreen ? 14.0 : 16.0; // Body Text range

                return TextButton(
                  onPressed: _isLoading ? null : _saveTransaction,
                  child: _isLoading
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(theme.appBarTheme.foregroundColor!),
                          ),
                        )
                      : Text(
                          _isEditMode ? 'Save' : 'Save',
                          style: TextStyle(
                            color: theme.appBarTheme.foregroundColor,
                            fontSize: actionTextFontSize,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                );
              },
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
            final horizontalPadding = isUltraNarrowScreen ? 12.0 : isNarrowScreen ? 14.0 : 16.0;
            final gridCrossAxisCount = isUltraNarrowScreen ? 1 : isVeryNarrowScreen ? 2 : 3;
            final gridChildAspectRatio = isUltraNarrowScreen ? 1.4 : isVeryNarrowScreen ? 1.2 : 1.0;

            // Typography standards
            final sectionHeaderFontSize = isUltraNarrowScreen ? 12.0 : isNarrowScreen ? 13.0 : 14.0; // Body Text range (12–14sp)
            final inputLabelFontSize = isUltraNarrowScreen ? 12.0 : isNarrowScreen ? 13.0 : 14.0; // Body Text range
            final spacingBetweenSections = isUltraNarrowScreen ? 12.0 : isNarrowScreen ? 14.0 : 16.0;
            final sectionSpacing = isUltraNarrowScreen ? 6.0 : isNarrowScreen ? 7.0 : 8.0;

            return Form(
              key: _formKey,
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: EdgeInsets.all(horizontalPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Transaction Type Selection
                    Text(
                      'Transaction Type',
                      style: TextStyle(
                        fontSize: sectionHeaderFontSize,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: sectionSpacing),
                    TutorialHighlight(
                      highlightKey: InteractiveTutorial.transactionTypeKey,
                      child: GridView.count(
                        crossAxisCount: gridCrossAxisCount,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                        childAspectRatio: gridChildAspectRatio,
                        children: [
                          TransactionType.expense,
                          TransactionType.income,
                          TransactionType.savings,
                          TransactionType.emergencyFund,
                          TransactionType.emergencyFundWithdrawal,
                          TransactionType.debt,
                        ].map((type) => _buildTransactionTypeCard(type)).toList(),
                      ),
                    ),
                    SizedBox(height: spacingBetweenSections),

                    // Amount Input
                    Text(
                      'Amount',
                      style: TextStyle(
                        fontSize: inputLabelFontSize,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: sectionSpacing),
                    TutorialHighlight(
                      highlightKey: InteractiveTutorial.amountFieldKey,
                      child: Row(
                        children: [
                          // Currency symbol
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: isNarrowScreen ? 12 : 16,
                              vertical: isNarrowScreen ? 14 : 16,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withValues(alpha: 0.1),
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(12),
                                bottomLeft: Radius.circular(12),
                              ),
                              border: Border.all(color: theme.dividerColor),
                            ),
                            child: Text(
                              '₱',
                              style: TextStyle(
                                fontSize: isNarrowScreen ? 16.0 : 18.0,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ),
                          // Integer part input
                          Expanded(
                            flex: 3,
                            child: TextFormField(
                              controller: _amountController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(7), // 7-digit limit
                              ],
                              decoration: InputDecoration(
                                hintText: '0',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.zero,
                                  borderSide: BorderSide(color: theme.dividerColor),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.zero,
                                  borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.zero,
                                  borderSide: BorderSide(color: theme.dividerColor),
                                ),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: isNarrowScreen ? 12 : 16,
                                  vertical: isNarrowScreen ? 14 : 16,
                                ),
                              ),
                              style: TextStyle(
                                fontSize: isNarrowScreen ? 16.0 : 18.0,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          // Decimal separator
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: isNarrowScreen ? 14 : 16,
                            ),
                            decoration: BoxDecoration(
                              border: Border.symmetric(
                                vertical: BorderSide(color: theme.dividerColor),
                              ),
                            ),
                            child: Text(
                              '.',
                              style: TextStyle(
                                fontSize: isNarrowScreen ? 16.0 : 18.0,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                          ),
                          // Decimal part input
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: _decimalController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(2), // Max 2 decimal places
                              ],
                              decoration: InputDecoration(
                                hintText: '00',
                                border: OutlineInputBorder(
                                  borderRadius: const BorderRadius.only(
                                    topRight: Radius.circular(12),
                                    bottomRight: Radius.circular(12),
                                  ),
                                  borderSide: BorderSide(color: theme.dividerColor),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: const BorderRadius.only(
                                    topRight: Radius.circular(12),
                                    bottomRight: Radius.circular(12),
                                  ),
                                  borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: const BorderRadius.only(
                                    topRight: Radius.circular(12),
                                    bottomRight: Radius.circular(12),
                                  ),
                                  borderSide: BorderSide(color: theme.dividerColor),
                                ),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: isNarrowScreen ? 12 : 16,
                                  vertical: isNarrowScreen ? 14 : 16,
                                ),
                              ),
                              style: TextStyle(
                                fontSize: isNarrowScreen ? 16.0 : 18.0,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Amount validation message
                    Builder(
                      builder: (context) {
                        final integerPart = _amountController.text.isEmpty ? '0' : _amountController.text;
                        final decimalPart = _decimalController.text.padRight(2, '0').substring(0, 2);
                        final amountString = '$integerPart.$decimalPart';
                        final amount = double.tryParse(amountString) ?? 0.0;

                        // Check for suspicious decimal-only inputs
                        final hasIntegerValue = integerPart != '0' && integerPart.isNotEmpty;
                        final hasDecimalValue = decimalPart != '00' && decimalPart.isNotEmpty;

                        if (!hasIntegerValue && hasDecimalValue) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              '⚠️ This amount is less than ₱1.00. Please confirm this is correct when saving.',
                              style: TextStyle(
                                color: Colors.orange[700],
                                fontSize: isNarrowScreen ? 12.0 : 14.0,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          );
                        }

                        if (amount <= 0) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              'Please enter an amount',
                              style: TextStyle(
                                color: theme.colorScheme.error,
                                fontSize: isNarrowScreen ? 12.0 : 14.0,
                              ),
                            ),
                          );
                        }

                        // For emergency fund withdrawal, check if amount exceeds available balance
                        if (_selectedType == TransactionType.emergencyFundWithdrawal) {
                          final availableBalance = _currentUser?.emergencyFundAmount ?? 0.0;
                          if (amount > availableBalance) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                'Amount exceeds available emergency fund balance (₱${availableBalance.toStringAsFixed(2)})',
                                style: TextStyle(
                                  color: theme.colorScheme.error,
                                  fontSize: isNarrowScreen ? 12.0 : 14.0,
                                ),
                              ),
                            );
                          }
                        }

                        return const SizedBox.shrink();
                      },
                    ),
                    SizedBox(height: spacingBetweenSections),

                    // Category Selection (only show for expense type)
                    if (_selectedType == TransactionType.expense) ...[
                      Text(
                        'Category',
                        style: TextStyle(
                          fontSize: inputLabelFontSize,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: sectionSpacing),
                      TutorialHighlight(
                        highlightKey: InteractiveTutorial.categoryFieldKey,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          decoration: BoxDecoration(
                            border: Border.all(color: theme.dividerColor),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedCategory,
                              isExpanded: true,
                              icon: Icon(Icons.arrow_drop_down, color: theme.colorScheme.primary),
                              onChanged: (String? newValue) {
                                if (newValue != null) {
                                  setState(() {
                                    _selectedCategory = newValue;
                                  });
                                  updateFormField('selectedCategory', newValue);
                                }
                              },
                              items: BudgetCategory.defaultCategories
                                  .where((category) => category != 'Savings')
                                  .map((String category) {
                                return DropdownMenuItem<String>(
                                  value: category,
                                  child: Row(
                                    children: [
                                      Text(
                                        BudgetCategory.getCategoryIcon(category),
                                        style: TextStyle(fontSize: isNarrowScreen ? 18.0 : 20.0),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          category,
                                          style: TextStyle(
                                            fontSize: isNarrowScreen ? 14.0 : 16.0, // Body Text range
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ),
                    ],
                    SizedBox(height: spacingBetweenSections),

                    // Description Input
                    Text(
                      'Description (Optional)',
                      style: TextStyle(
                        fontSize: inputLabelFontSize,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: sectionSpacing),
                    TutorialHighlight(
                      highlightKey: InteractiveTutorial.descriptionFieldKey,
                      child: TextFormField(
                        controller: _descriptionController,
                        decoration: InputDecoration(
                          hintText: 'Enter description...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
                          ),
                        ),
                        style: TextStyle(
                          fontSize: isNarrowScreen ? 14.0 : 16.0, // Body Text range
                        ),
                        maxLines: 3,
                        // Remove validator to make it optional
                      ),
                    ),
                    SizedBox(height: spacingBetweenSections),

                    // Date Selection
                    Text(
                      'Date',
                      style: TextStyle(
                        fontSize: inputLabelFontSize,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: sectionSpacing),
                    TutorialHighlight(
                      highlightKey: InteractiveTutorial.dateFieldKey,
                      child: InkWell(
                        onTap: _selectDate,
                        child: Container(
                        padding: EdgeInsets.all(isNarrowScreen ? 12 : 16),
                        decoration: BoxDecoration(
                          border: Border.all(color: theme.dividerColor),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.calendar_today, color: theme.colorScheme.primary),
                            SizedBox(width: isNarrowScreen ? 8 : 12),
                            Expanded(
                              child: Text(
                                DateFormat('MMM dd, yyyy').format(_selectedDate),
                                style: TextStyle(
                                  fontSize: isNarrowScreen ? 14.0 : 16.0, // Body Text range
                                  color: theme.colorScheme.onSurface
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                            Icon(
                              Icons.arrow_forward_ios,
                              size: isNarrowScreen ? 14 : 16,
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.6)
                            ),
                          ],
                        ),
                      ),
                      ),
                    ),
                    SizedBox(
                      height: spacingBetweenSections + 8.0,
                    ),

                    // Save Button
                    TutorialHighlight(
                      highlightKey: InteractiveTutorial.saveButtonKey,
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                        onPressed: _isLoading ? null : _saveTransaction,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: theme.colorScheme.onPrimary,
                          padding: EdgeInsets.symmetric(vertical: isNarrowScreen ? 14 : 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isLoading
                            ? SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.onPrimary),
                                ),
                              )
                            : Text(
                                _isEditMode ? 'Update Transaction' : 'Add Transaction',
                                style: TextStyle(
                                  fontSize: isNarrowScreen ? 16.0 : 18.0, // Subheading range for important buttons
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                      ),
                    ),

                    // Add bottom padding to prevent overflow
                    SizedBox(height: isNarrowScreen ? 20.0 : 24.0),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}


class TransactionTypeInfo {
  final IconData icon;
  final String label;
  final String description;

  const TransactionTypeInfo({
    required this.icon,
    required this.label,
    required this.description,
  });
}
