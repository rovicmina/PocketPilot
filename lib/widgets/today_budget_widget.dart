import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/widget_data_service.dart';

/// Widget that displays today's budget and expenses - can be used in app and as basis for home screen widget
class TodayBudgetWidget extends StatefulWidget {
  final bool isCompact;
  final VoidCallback? onTap;
  
  const TodayBudgetWidget({
    super.key,
    this.isCompact = false,
    this.onTap,
  });

  @override
  State<TodayBudgetWidget> createState() => _TodayBudgetWidgetState();
}

class _TodayBudgetWidgetState extends State<TodayBudgetWidget> {
  Map<String, dynamic> _widgetData = {};
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _loadWidgetData();
  }
  
  Future<void> _loadWidgetData() async {
    try {
      // First load cached data for immediate display
      final cachedData = await WidgetDataService.getCachedWidgetData();
      if (mounted) {
        setState(() {
          _widgetData = cachedData;
          _isLoading = false;
        });
      }
      
      // Then refresh with current data
      await WidgetDataService.updateWidgetData();
      final freshData = await WidgetDataService.getCachedWidgetData();
      
      if (mounted) {
        setState(() {
          _widgetData = freshData;
        });
      }
    } catch (e) {
      // Removed debug print statement for production
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildLoadingWidget();
    }
    
    return widget.isCompact ? _buildCompactWidget() : _buildFullWidget();
  }
  
  Widget _buildLoadingWidget() {
    return Container(
      height: widget.isCompact ? 80 : 120,
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
      ),
      child: const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
  
  Widget _buildCompactWidget() {
    final budget = _widgetData['budget'] ?? 0.0;
    final expenses = _widgetData['expenses'] ?? 0.0;
    final percentage = _widgetData['percentage'] ?? 0.0;
    
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        height: 80,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.blue.withValues(alpha: 0.1),
              Colors.blue.withValues(alpha: 0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            // Icon
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.account_balance_wallet,
                color: Colors.blue,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            
            // Budget info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Today\'s Budget',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600]!,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '\u20b1${NumberFormat('#,##0').format(budget)}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ],
              ),
            ),
            
            // Expenses info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Spent Today',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600]!,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '\u20b1${NumberFormat('#,##0').format(expenses)}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: percentage > 100 ? Colors.red : Colors.green,
                    ),
                  ),
                ],
              ),
            ),
            
            // Progress indicator
            if (budget > 0)
              CircularProgressIndicator(
                value: (percentage / 100).clamp(0.0, 1.0),
                backgroundColor: Colors.grey[300]!,
                valueColor: AlwaysStoppedAnimation<Color>(
                  percentage > 100 ? Colors.red : 
                  percentage > 80 ? Colors.orange : Colors.green,
                ),
                strokeWidth: 3,
              ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildFullWidget() {
    final budget = _widgetData['budget'] ?? 0.0;
    final expenses = _widgetData['expenses'] ?? 0.0;
    final remaining = _widgetData['remaining'] ?? 0.0;
    final percentage = _widgetData['percentage'] ?? 0.0;
    final lastUpdate = _widgetData['lastUpdate'] as DateTime?;
    
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.blue.withValues(alpha: 0.1),
              Colors.blue.withValues(alpha: 0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(
              color: Colors.blue.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.today,
                    color: Colors.blue,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Today\'s Budget Overview',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                      if (lastUpdate != null)
                        Text(
                          'Updated ${_formatLastUpdate(lastUpdate)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600]!,
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _loadWidgetData,
                  icon: const Icon(Icons.refresh, color: Colors.blue),
                  tooltip: 'Refresh',
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Budget and expenses cards
            Row(
              children: [
                Expanded(
                  child: _buildInfoCard(
                    'Budget Today',
                    '\u20b1${NumberFormat('#,##0').format(budget)}',
                    Icons.account_balance_wallet,
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildInfoCard(
                    'Expenses Today',
                    '\u20b1${NumberFormat('#,##0').format(expenses)}',
                    Icons.shopping_cart,
                    percentage > 100 ? Colors.red : Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Remaining budget card
            _buildRemainingBudgetCard(remaining, percentage),
            
            // Progress bar
            if (budget > 0) ...[
              const SizedBox(height: 12),
              _buildProgressBar(percentage),
            ],
          ],
        ),
      ),
    );
  }
  
  Widget _buildInfoCard(String title, String amount, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600]!,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            amount,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildRemainingBudgetCard(double remaining, double percentage) {
    final isOverBudget = remaining < 0;
    final color = isOverBudget ? Colors.red : Colors.green;
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(
            isOverBudget ? Icons.warning : Icons.check_circle,
            color: color,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isOverBudget ? 'Over Budget' : 'Remaining Budget',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600]!,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '\u20b1${NumberFormat('#,##0').format(remaining.abs())}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${percentage.toStringAsFixed(0)}%',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildProgressBar(double percentage) {
    final progress = (percentage / 100).clamp(0.0, 1.0);
    final color = percentage > 100 ? Colors.red : 
                 percentage > 80 ? Colors.orange : Colors.green;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Budget Usage',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600]!,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: progress,
          backgroundColor: Colors.grey[300]!,
          valueColor: AlwaysStoppedAnimation<Color>(color),
          minHeight: 6,
        ),
      ],
    );
  }
  
  String _formatLastUpdate(DateTime lastUpdate) {
    final now = DateTime.now();
    final difference = now.difference(lastUpdate);
    
    if (difference.inMinutes < 1) {
      return 'just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return DateFormat('MMM d, h:mm a').format(lastUpdate);
    }
  }
}