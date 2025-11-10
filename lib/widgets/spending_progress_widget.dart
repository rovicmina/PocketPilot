import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class SpendingProgressWidget extends StatefulWidget {
  final double budgetUsedPercentage;
  final double totalBudget;
  final Map<String, double> categorySpending;
  final Map<String, double> categoryBudgets;

  const SpendingProgressWidget({
    super.key,
    required this.budgetUsedPercentage,
    required this.totalBudget,
    required this.categorySpending,
    required this.categoryBudgets,
  });

  @override
  State<SpendingProgressWidget> createState() => _SpendingProgressWidgetState();
}

class _SpendingProgressWidgetState extends State<SpendingProgressWidget> {
  List<CategoryProgress> _categoryProgressList = [];
  CategoryProgress? _biggestSpender;

  @override
  void initState() {
    super.initState();
    _calculateCategoryProgress();
  }

  @override
  void didUpdateWidget(covariant SpendingProgressWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.categorySpending != widget.categorySpending ||
        oldWidget.categoryBudgets != widget.categoryBudgets) {
      _calculateCategoryProgress();
    }
  }

  void _calculateCategoryProgress() {
    _categoryProgressList = [];
    
    // Calculate progress for each category
    widget.categorySpending.forEach((category, spent) {
      final budget = widget.categoryBudgets[category] ?? 0;
      if (budget > 0) {
        final percentage = (spent / budget) * 100;
        _categoryProgressList.add(CategoryProgress(
          category: category,
          spent: spent,
          budget: budget,
          percentage: percentage,
        ));
      }
    });

    // Sort by spent amount to find biggest spender
    _categoryProgressList.sort((a, b) => b.spent.compareTo(a.spent));
    if (_categoryProgressList.isNotEmpty) {
      _biggestSpender = _categoryProgressList.first;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Spending Progress',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          
          // Circular progress chart and biggest spender
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Circular progress chart
              Expanded(
                flex: 1,
                child: _buildCircularProgressChart(),
              ),
              const SizedBox(width: 16),
              
              // Biggest spender category
              Expanded(
                flex: 1,
                child: _biggestSpender != null
                    ? _buildBiggestSpenderCard(_biggestSpender!)
                    : _buildNoDataPlaceholder(),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Progress text
          _buildProgressText(),
          
          const SizedBox(height: 12),
          
          // Category progress list
          if (_categoryProgressList.isNotEmpty) ...[
            Text(
              'All Categories',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 8),
            ..._categoryProgressList.take(3).map((progress) => _buildCategoryProgressItem(progress)),
          ],
        ],
      ),
    );
  }

  Widget _buildCircularProgressChart() {
    final progress = (widget.budgetUsedPercentage / 100).clamp(0.0, 1.0);
    Color progressColor;
    
    if (progress < 0.5) {
      progressColor = Colors.green;
    } else if (progress < 0.8) {
      progressColor = Colors.orange;
    } else {
      progressColor = Colors.red;
    }
    
    return Stack(
      alignment: Alignment.center,
      children: [
        SizedBox(
          width: 120,
          height: 120,
          child: PieChart(
            PieChartData(
              sections: [
                PieChartSectionData(
                  value: progress,
                  color: progressColor,
                  radius: 50,
                  showTitle: false,
                ),
                PieChartSectionData(
                  value: 1 - progress,
                  color: Colors.grey.withValues(alpha: 0.2),
                  radius: 50,
                  showTitle: false,
                ),
              ],
              centerSpaceRadius: 40,
              sectionsSpace: 2,
              pieTouchData: PieTouchData(enabled: false),
            ),
          ),
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${widget.budgetUsedPercentage.toStringAsFixed(0)}%',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'Used',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBiggestSpenderCard(CategoryProgress progress) {
    Color categoryColor;
    
    if (progress.percentage < 50) {
      categoryColor = Colors.green;
    } else if (progress.percentage < 80) {
      categoryColor = Colors.orange;
    } else {
      categoryColor = Colors.red;
    }
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: categoryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: categoryColor.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: categoryColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Biggest Spender',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: categoryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            progress.category,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            '₱${progress.spent.toStringAsFixed(0)}',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${progress.percentage.toStringAsFixed(0)}% used',
            style: TextStyle(
              fontSize: 14,
              color: categoryColor,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (progress.percentage / 100).clamp(0.0, 1.0),
              backgroundColor: Colors.grey.withValues(alpha: 0.2),
              valueColor: AlwaysStoppedAnimation<Color>(categoryColor),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoDataPlaceholder() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey.withValues(alpha: 0.2),
        ),
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.pie_chart_outline,
            size: 32,
            color: Colors.grey,
          ),
          SizedBox(height: 8),
          Text(
            'No data',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressText() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Total Progress',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            '${widget.budgetUsedPercentage.toStringAsFixed(0)}% of total budget',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryProgressItem(CategoryProgress progress) {
    Color progressColor;
    
    if (progress.percentage < 50) {
      progressColor = Colors.green;
    } else if (progress.percentage < 80) {
      progressColor = Colors.orange;
    } else {
      progressColor = Colors.red;
    }
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  progress.category,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '₱${progress.spent.toStringAsFixed(0)} / ₱${progress.budget.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${progress.percentage.toStringAsFixed(0)}%',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: progressColor,
            ),
          ),
        ],
      ),
    );
  }
}

class CategoryProgress {
  final String category;
  final double spent;
  final double budget;
  final double percentage;

  CategoryProgress({
    required this.category,
    required this.spent,
    required this.budget,
    required this.percentage,
  });
}