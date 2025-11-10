import 'package:flutter/material.dart';
import '../models/transaction.dart';

/// Utility class for managing category colors and visual indicators
class CategoryColors {
  
  /// Get color for a specific category
  static Color getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'housing & utilities':
      case 'housing':
      case 'utilities':
        return const Color(0xFF8B4513); // Brown
      
      case 'food & groceries':
      case 'food':
        return const Color(0xFFFF6347); // Tomato Red
      
      case 'groceries':
        return const Color(0xFF32CD32); // Lime Green
      
      case 'transportation':
      case 'transport':
        return const Color(0xFF4169E1); // Royal Blue
      
      case 'debt/loans':
      case 'debt':
      case 'loans':
      case 'credit':
        return const Color(0xFFDC143C); // Crimson
      
      case 'health & personal care':
      case 'health':
      case 'healthcare':
      case 'personal care':
        return const Color(0xFF20B2AA); // Light Sea Green
      
      case 'entertainment & lifestyle':
      case 'entertainment':
      case 'lifestyle':
        return const Color(0xFFFF69B4); // Hot Pink
      
      case 'education':
        return const Color(0xFF8A2BE2); // Blue Violet
      case 'childcare':
        return const Color(0xFFFF69B4); // Hot Pink
      
      case 'tithes & donations':
      case 'tithes':
      case 'donations':
        return const Color(0xFFFFD700); // Gold
      
      case 'savings':
        return const Color(0xFF228B22); // Forest Green
      
      case 'others':
      case 'other':
      case 'miscellaneous':
        return const Color(0xFF708090); // Slate Gray
      
      default:
        return const Color(0xFF708090); // Default to Slate Gray
    }
  }
  
  /// Get color for transaction type (main calendar color scheme)
  static Color getTransactionTypeColor(TransactionType type) {
    switch (type) {
      case TransactionType.income:
      case TransactionType.savingsWithdrawal: // Withdraw from savings = income (green)
      case TransactionType.emergencyFundWithdrawal: // Emergency fund withdrawal = income (green)
        return const Color(0xFF4CAF50); // Green
      case TransactionType.expense:
      case TransactionType.recurringExpense: // Any expense = red
        return const Color(0xFFF44336); // Red
      case TransactionType.savings:
      case TransactionType.emergencyFund: // Emergency fund uses same shade as savings
        return const Color(0xFF2196F3); // Blue
      case TransactionType.debt:
      case TransactionType.debtPayment:
        return const Color(0xFFFF9800); // Orange
    }
  }
  
  /// Get a lighter version of the category color for backgrounds
  static Color getCategoryColorLight(String category) {
    return getCategoryColor(category).withValues(alpha: 0.2);
  }
  
  /// Get a darker version of the category color for borders
  static Color getCategoryColorDark(String category) {
    return getCategoryColor(category).withValues(alpha: 0.8);
  }
  
  /// Get icon for category
  static IconData getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'housing & utilities':
      case 'housing':
      case 'utilities':
        return Icons.home;
      
      case 'food & groceries':
      case 'food':
        return Icons.restaurant;
      
      case 'groceries':
        return Icons.shopping_cart;
      
      case 'transportation':
      case 'transport':
        return Icons.directions_car;
      
      case 'debt/loans':
      case 'debt':
      case 'loans':
      case 'credit':
        return Icons.credit_card;
      
      case 'health & personal care':
      case 'health':
      case 'healthcare':
      case 'personal care':
        return Icons.local_hospital;
      
      case 'entertainment & lifestyle':
      case 'entertainment':
      case 'lifestyle':
        return Icons.movie;
      
      case 'education':
        return Icons.school;
      case 'childcare':
        return Icons.child_care;
      
      case 'tithes & donations':
      case 'tithes':
      case 'donations':
        return Icons.volunteer_activism;
      
      case 'savings':
        return Icons.savings;
      
      case 'others':
      case 'other':
      case 'miscellaneous':
        return Icons.category;
      
      default:
        return Icons.category;
    }
  }
  
  /// Get all available category colors as a map
  static Map<String, Color> getAllCategoryColors() {
    return {
      'Housing & Utilities': getCategoryColor('housing & utilities'),
      'Food': getCategoryColor('food'),
      'Groceries': getCategoryColor('groceries'),
      'Transportation': getCategoryColor('transportation'),
      'Debt/Loans': getCategoryColor('debt/loans'),
      'Health & Personal Care': getCategoryColor('health & personal care'),
      'Entertainment & Lifestyle': getCategoryColor('entertainment & lifestyle'),
      'Education': getCategoryColor('education'),
      'Childcare': getCategoryColor('childcare'),
      'Tithes & Donations': getCategoryColor('tithes & donations'),
      'Savings': getCategoryColor('savings'),
      'Others': getCategoryColor('others'),
    };
  }
  
  /// Create a gradient for multiple categories
  static LinearGradient createCategoryGradient(List<String> categories) {
    if (categories.isEmpty) {
      return const LinearGradient(colors: [Colors.transparent]);
    }
    
    if (categories.length == 1) {
      final color = getCategoryColor(categories.first);
      return LinearGradient(colors: [color, color]);
    }
    
    final colors = categories.take(3).map((cat) => getCategoryColor(cat)).toList();
    return LinearGradient(
      colors: colors,
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }
  
  /// Get a mixed color when multiple categories are present
  static Color getMixedCategoryColor(List<String> categories) {
    if (categories.isEmpty) return Colors.transparent;
    if (categories.length == 1) return getCategoryColor(categories.first);
    
    // Blend the first two category colors
    final color1 = getCategoryColor(categories[0]);
    final color2 = getCategoryColor(categories[1]);
    
    return Color.lerp(color1, color2, 0.5) ?? color1;
  }
}
