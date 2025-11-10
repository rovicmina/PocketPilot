import 'package:flutter/material.dart';
import '../models/transaction.dart';
import '../models/budget.dart';

class TransactionCard extends StatelessWidget {
  final Transaction transaction;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const TransactionCard({
    super.key,
    required this.transaction,
    this.onTap,
    this.onDelete,
  });

  Color get _typeColor {
    switch (transaction.type) {
      case TransactionType.income:
        return Colors.green;
      case TransactionType.expense:
        return Colors.red;
      case TransactionType.savings:
        return Colors.blue;
      case TransactionType.savingsWithdrawal:
        return Colors.orange;
      case TransactionType.debt:
        return Colors.purple;
      case TransactionType.debtPayment:
        return Colors.deepPurple;
      case TransactionType.recurringExpense:
        return Colors.amber;
      case TransactionType.emergencyFund:
        return Colors.pink;
      case TransactionType.emergencyFundWithdrawal:
        return Colors.green;
    }
  }


  String get _typeSign {
    switch (transaction.type) {
      case TransactionType.income:
      case TransactionType.debt:
      case TransactionType.emergencyFundWithdrawal: // Money coming back from emergency fund
        return '+';
      case TransactionType.expense:
      case TransactionType.savings:
      case TransactionType.savingsWithdrawal:
      case TransactionType.debtPayment:
      case TransactionType.recurringExpense:
      case TransactionType.emergencyFund: // Money going to emergency fund
        return '-';
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Determine responsive layout parameters
        final isNarrowScreen = constraints.maxWidth < 350; // Transaction cards are smaller, adjust threshold
        final isVeryNarrowScreen = constraints.maxWidth < 300;
        final isExtremelyNarrowScreen = constraints.maxWidth < 250;
        
        // Responsive sizing following typography standards
        final descriptionFontSize = isExtremelyNarrowScreen ? 12.0 : isVeryNarrowScreen ? 13.0 : isNarrowScreen ? 14.0 : 16.0; // Body Text range (12–16sp)
        final categoryFontSize = isExtremelyNarrowScreen ? 10.0 : isVeryNarrowScreen ? 11.0 : isNarrowScreen ? 12.0 : 14.0; // Secondary Text range (10–14sp)
        final typeLabelFontSize = isExtremelyNarrowScreen ? 7.0 : isVeryNarrowScreen ? 8.0 : isNarrowScreen ? 9.0 : 11.0; // Smaller font size for type label
        final dateFontSize = isExtremelyNarrowScreen ? 8.0 : isVeryNarrowScreen ? 9.0 : isNarrowScreen ? 10.0 : 12.0; // Captions range
        final amountFontSize = isExtremelyNarrowScreen ? 12.0 : isVeryNarrowScreen ? 13.0 : isNarrowScreen ? 14.0 : 16.0; // Body Text range
        final iconSize = isExtremelyNarrowScreen ? 16.0 : isVeryNarrowScreen ? 18.0 : isNarrowScreen ? 20.0 : 24.0;
        final containerPadding = isExtremelyNarrowScreen ? 8.0 : isVeryNarrowScreen ? 10.0 : isNarrowScreen ? 12.0 : 16.0;
        final iconPadding = isExtremelyNarrowScreen ? 6.0 : isVeryNarrowScreen ? 8.0 : isNarrowScreen ? 10.0 : 12.0;
        final elementSpacing = isExtremelyNarrowScreen ? 8.0 : isVeryNarrowScreen ? 10.0 : isNarrowScreen ? 12.0 : 16.0;
        final itemSpacing = isExtremelyNarrowScreen ? 0.5 : isVeryNarrowScreen ? 1.0 : isNarrowScreen ? 2.0 : 4.0;
        final deleteIconSize = isExtremelyNarrowScreen ? 10.0 : isVeryNarrowScreen ? 12.0 : isNarrowScreen ? 14.0 : 16.0;
        final borderRadius = isExtremelyNarrowScreen ? 8.0 : isVeryNarrowScreen ? 10.0 : isNarrowScreen ? 11.0 : 12.0;
        
        return Card(
          elevation: 2,
          margin: const EdgeInsets.symmetric(vertical: 4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(borderRadius),
            child: Padding(
              padding: EdgeInsets.all(containerPadding),
              child: Row(
                children: [
                  // Category Icon
                  Container(
                    padding: EdgeInsets.all(iconPadding),
                    decoration: BoxDecoration(
                      color: _typeColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(borderRadius),
                    ),
                    child: Text(
                      BudgetCategory.getCategoryIcon(transaction.category),
                      style: TextStyle(fontSize: iconSize),
                    ),
                  ),
                  SizedBox(width: elementSpacing),
                  
                  // Transaction Details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          transaction.description.isEmpty 
                              ? transaction.typeDisplayName 
                              : _formatTransactionDescription(transaction.description),
                          style: TextStyle(
                            fontSize: descriptionFontSize,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                          maxLines: isExtremelyNarrowScreen ? 1 : isVeryNarrowScreen ? 1 : 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: itemSpacing),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                _formatCategoryName(transaction.category),
                                style: TextStyle(
                                  fontSize: categoryFontSize,
                                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: isExtremelyNarrowScreen ? 1 : 2,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: isVeryNarrowScreen ? 6.0 : 8.0,
                                vertical: isVeryNarrowScreen ? 1.0 : 2.0,
                              ),
                              decoration: BoxDecoration(
                                color: _typeColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(isVeryNarrowScreen ? 10.0 : 12.0),
                              ),
                              child: Text(
                                transaction.typeDisplayName,
                                style: TextStyle(
                                  fontSize: typeLabelFontSize,
                                  color: _typeColor,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: itemSpacing),
                        Text(
                          transaction.formattedDate,
                          style: TextStyle(
                            fontSize: dateFontSize,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Amount and Actions
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '$_typeSign${transaction.formattedAmount}',
                        style: TextStyle(
                          fontSize: amountFontSize,
                          fontWeight: FontWeight.bold,
                          color: _typeColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (onDelete != null) ...[
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: onDelete,
                          child: Container(
                            padding: EdgeInsets.all(isExtremelyNarrowScreen ? 2.0 : isVeryNarrowScreen ? 3.0 : 4.0),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(isExtremelyNarrowScreen ? 3.0 : isVeryNarrowScreen ? 4.0 : 6.0),
                            ),
                            child: Icon(
                              Icons.delete_outline,
                              size: deleteIconSize,
                              color: Colors.red,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Remove "Transaction" prefix from transaction descriptions and format professionally
  String _formatTransactionDescription(String description) {
    // Remove "Transaction" prefix if present
    if (description.toLowerCase().startsWith('transaction - ')) {
      description = description.substring(14); // Remove "Transaction - " prefix
    }
    
    // Handle specific formatting cases
    if (description.toLowerCase() == 'emergencyfund') {
      return 'Emergency Fund';
    }
    
    if (description.toLowerCase() == 'emergencyfundwithdrawal') {
      return 'Emergency Fund (Withdraw)';
    }
    
    // Format description to be more professional
    return _formatProperCase(description);
  }
  
  /// Format category names to be more professional with proper capitalization
  String _formatCategoryName(String category) {
    // Professional formatting for common categories
    switch (category.toLowerCase()) {
      case 'food':
        return 'Food';
      case 'housing':
      case 'housing & utilities':
      case 'housing and utilities':
        return 'Housing & Utilities';
      case 'transportation':
        return 'Transportation';
      case 'healthcare':
        return 'Healthcare';
      case 'entertainment':
        return 'Entertainment';
      case 'shopping':
        return 'Shopping';
      case 'personal care':
      case 'personalcare':
        return 'Personal Care';
      case 'education':
        return 'Education';
      case 'gifts':
        return 'Gifts';
      case 'debt':
        return 'Debt';
      case 'savings':
        return 'Savings';
      case 'savings (ef)':
      case 'savings (ef':
        return 'Savings (EF)';
      case 'emergency fund':
      case 'emergencyfund':
        return 'Emergency Fund';
      case 'withdrawal (ef)':
        return 'Withdrawal (EF)';
      case 'income':
        return 'Income';
      default:
        // Apply proper capitalization
        return _formatProperCase(category);
    }
  }
  
  /// Format text with proper capitalization (Title Case)
  String _formatProperCase(String text) {
    if (text.isEmpty) return text;
    
    // Handle special cases that should remain in uppercase
    const specialAbbreviations = ['EF', 'ID', 'USA', 'UK'];
    
    // Split by spaces and format each word
    final words = text.split(' ');
    final formattedWords = <String>[];
    
    for (final word in words) {
      if (word.isEmpty) {
        formattedWords.add(word);
        continue;
      }
      
      // Check if word is a special abbreviation
      bool isSpecialAbbr = false;
      for (final abbr in specialAbbreviations) {
        if (word.toLowerCase() == abbr.toLowerCase()) {
          formattedWords.add(abbr);
          isSpecialAbbr = true;
          break;
        }
      }
      
      if (isSpecialAbbr) continue;
      
      // Handle hyphenated words
      if (word.contains('-')) {
        final hyphenatedParts = word.split('-');
        final formattedParts = hyphenatedParts.map((part) {
          if (part.isEmpty) return part;
          return part[0].toUpperCase() + part.substring(1).toLowerCase();
        }).join('-');
        formattedWords.add(formattedParts);
        continue;
      }
      
      // Standard capitalization
      formattedWords.add(word[0].toUpperCase() + word.substring(1).toLowerCase());
    }
    
    return formattedWords.join(' ');
  }
}