import 'package:flutter/material.dart';

// Sample widget demonstrating the UI component structure
class SampleBudgetWidget extends StatelessWidget {
  final double budget;
  final double expenses;
  final double remaining;
  
  const SampleBudgetWidget({
    super.key,
    required this.budget,
    required this.expenses,
    required this.remaining,
  });

  @override
  Widget build(BuildContext context) {
    final percentage = budget > 0 ? (expenses / budget) * 100 : 0;
    final color = percentage > 100 ? Colors.red : 
                 percentage > 80 ? Colors.orange : Colors.green;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Today\'s Budget',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Budget:'),
              Text('₱${budget.toStringAsFixed(2)}'),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Expenses:'),
              Text('₱${expenses.toStringAsFixed(2)}'),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Remaining:'),
              Text(
                '₱${remaining.toStringAsFixed(2)}',
                style: TextStyle(
                  color: remaining < 0 ? Colors.red : Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: (percentage / 100).clamp(0.0, 1.0),
            backgroundColor: Colors.grey[300],
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
          const SizedBox(height: 4),
          Text('${percentage.toStringAsFixed(0)}% used'),
        ],
      ),
    );
  }
}