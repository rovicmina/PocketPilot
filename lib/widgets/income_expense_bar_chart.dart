import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

class IncomeExpenseBarChart extends StatelessWidget {
  final double income;
  final double expenses;
  final double savings;
  final double debt;
  final String timeFrameLabel;

  const IncomeExpenseBarChart({
    super.key,
    required this.income,
    required this.expenses,
    required this.savings,
    required this.debt,
    required this.timeFrameLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return LayoutBuilder(
      builder: (context, constraints) {
        // Determine responsive layout parameters following app's design system
        final isNarrowScreen = constraints.maxWidth < 600;
        final isVeryNarrowScreen = constraints.maxWidth < 400;
        final isWideScreen = constraints.maxWidth > 1200;
        
        // Responsive sizing following typography standards
        final noDataIconSize = isNarrowScreen ? 32.0 : 40.0;
        final noDataTextFontSize = isNarrowScreen ? 12.0 : 14.0;
        final containerPadding = isNarrowScreen ? 16.0 : 20.0;
        final chartHeight = isNarrowScreen ? 200.0 : isWideScreen ? 240.0 : 220.0;
        final labelFontSize = isNarrowScreen ? 10.0 : 12.0;
        final valueFontSize = isNarrowScreen ? 8.0 : 10.0;
        final legendSpacing = isNarrowScreen ? 4.0 : 6.0;
        
        // Check if we have any data to show
        if (income == 0 && expenses == 0 && savings == 0 && debt == 0) {
          return Container(
            width: double.infinity,
            padding: EdgeInsets.all(containerPadding),
            decoration: BoxDecoration(
              color: theme.cardTheme.color,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: theme.shadowColor.withValues(alpha: 0.1),
                  spreadRadius: 0.5,
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.bar_chart,
                    size: noDataIconSize,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    isVeryNarrowScreen
                        ? 'No data recorded'
                        : 'No financial data recorded for this period',
                    style: TextStyle(
                      fontSize: noDataTextFontSize,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                    textAlign: TextAlign.center,
                    maxLines: isVeryNarrowScreen ? 2 : 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        }

        // Calculate max value for chart scaling
        final maxValue = [income, expenses, savings, debt].reduce((a, b) => a > b ? a : b);
        final chartMaxValue = maxValue * 1.2; // Add 20% padding at top

        return Container(
          width: double.infinity,
          padding: EdgeInsets.all(containerPadding),
          decoration: BoxDecoration(
            color: theme.cardTheme.color,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: theme.shadowColor.withValues(alpha: 0.1),
                spreadRadius: 0.5,
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              
              Text(
                timeFrameLabel,
                style: TextStyle(
                  fontSize: labelFontSize,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              
              // Bar Chart
              SizedBox(
                height: chartHeight,
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: chartMaxValue,
                    minY: 0,
                    barTouchData: BarTouchData(
                      enabled: true,
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipColor: (group) => theme.colorScheme.inverseSurface,
                        tooltipRoundedRadius: 6,
                        getTooltipItem: (group, groupIndex, rod, rodIndex) {
                          final labels = ['Income', 'Expenses', 'Savings', 'Debt'];
                          final label = labels[group.x];
                          final value = rod.toY;
                          return BarTooltipItem(
                            '$label\n₱${NumberFormat('#,##0.00').format(value)}',
                            TextStyle(
                              color: theme.colorScheme.onInverseSurface,
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                          );
                        },
                      ),
                    ),
                    titlesData: FlTitlesData(
                      show: true,
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            // Improved label handling with better text wrapping
                            switch (value.toInt()) {
                              case 0:
                                return Padding(
                                  padding: const EdgeInsets.only(top: 4.0),
                                  child: Text(
                                    'Income',
                                    style: TextStyle(
                                      fontSize: labelFontSize,
                                      fontWeight: FontWeight.w500,
                                      color: theme.colorScheme.onSurface,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                );
                              case 1:
                                return Padding(
                                  padding: const EdgeInsets.only(top: 4.0),
                                  child: Text(
                                    'Expenses',
                                    style: TextStyle(
                                      fontSize: labelFontSize,
                                      fontWeight: FontWeight.w500,
                                      color: theme.colorScheme.onSurface,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                );
                              case 2:
                                return Padding(
                                  padding: const EdgeInsets.only(top: 4.0),
                                  child: Text(
                                    'Savings',
                                    style: TextStyle(
                                      fontSize: labelFontSize,
                                      fontWeight: FontWeight.w500,
                                      color: theme.colorScheme.onSurface,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                );
                              case 3:
                                return Padding(
                                  padding: const EdgeInsets.only(top: 4.0),
                                  child: Text(
                                    'Debt',
                                    style: TextStyle(
                                      fontSize: labelFontSize,
                                      fontWeight: FontWeight.w500,
                                      color: theme.colorScheme.onSurface,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                );
                              default:
                                return const Text('');
                            }
                          },
                          reservedSize: isNarrowScreen ? 28 : 32,
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: isNarrowScreen ? 40 : 50,
                          getTitlesWidget: (value, meta) {
                            if (value == 0) return const Text('');
                            return Text(
                              '₱${_formatCurrency(value)}',
                              style: TextStyle(
                                fontSize: valueFontSize,
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                              ),
                            );
                          },
                        ),
                      ),
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                    ),
                    gridData: FlGridData(
                      show: true,
                      drawHorizontalLine: true,
                      horizontalInterval: chartMaxValue / 5,
                      getDrawingHorizontalLine: (value) {
                        return FlLine(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
                          strokeWidth: 0.5,
                        );
                      },
                      drawVerticalLine: false,
                    ),
                    borderData: FlBorderData(
                      show: true,
                      border: Border(
                        bottom: BorderSide(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                          width: 0.5,
                        ),
                        left: BorderSide(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                          width: 0.5,
                        ),
                      ),
                    ),
                    barGroups: [
                      // Income bar
                      BarChartGroupData(
                        x: 0,
                        barRods: [
                          BarChartRodData(
                            toY: income,
                            color: Colors.green.shade600,
                            width: isNarrowScreen ? 20 : 25,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(4),
                              topRight: Radius.circular(4),
                            ),
                            backDrawRodData: BackgroundBarChartRodData(
                              show: true,
                              toY: chartMaxValue,
                              color: Colors.green.withValues(alpha: 0.1),
                            ),
                          ),
                        ],
                      ),
                      // Expenses bar
                      BarChartGroupData(
                        x: 1,
                        barRods: [
                          BarChartRodData(
                            toY: expenses,
                            color: Colors.red.shade600,
                            width: isNarrowScreen ? 20 : 25,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(4),
                              topRight: Radius.circular(4),
                            ),
                            backDrawRodData: BackgroundBarChartRodData(
                              show: true,
                              toY: chartMaxValue,
                              color: Colors.red.withValues(alpha: 0.1),
                            ),
                          ),
                        ],
                      ),
                      // Savings bar
                      BarChartGroupData(
                        x: 2,
                        barRods: [
                          BarChartRodData(
                            toY: savings,
                            color: Colors.blue.shade600,
                            width: isNarrowScreen ? 20 : 25,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(4),
                              topRight: Radius.circular(4),
                            ),
                            backDrawRodData: BackgroundBarChartRodData(
                              show: true,
                              toY: chartMaxValue,
                              color: Colors.blue.withValues(alpha: 0.1),
                            ),
                          ),
                        ],
                      ),
                      // Debt bar
                      BarChartGroupData(
                        x: 3,
                        barRods: [
                          BarChartRodData(
                            toY: debt,
                            color: Colors.orange.shade600,
                            width: isNarrowScreen ? 20 : 25,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(4),
                              topRight: Radius.circular(4),
                            ),
                            backDrawRodData: BackgroundBarChartRodData(
                              show: true,
                              toY: chartMaxValue,
                              color: Colors.orange.withValues(alpha: 0.1),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              
              // Summary row with amounts
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildSummaryItem(
                      'Income',
                      income,
                      Colors.green.shade600,
                      theme,
                      labelFontSize,
                      isVeryNarrowScreen,
                    ),
                  ),
                  SizedBox(width: legendSpacing),
                  Expanded(
                    child: _buildSummaryItem(
                      'Expenses',
                      expenses,
                      Colors.red.shade600,
                      theme,
                      labelFontSize,
                      isVeryNarrowScreen,
                    ),
                  ),
                  SizedBox(width: legendSpacing),
                  Expanded(
                    child: _buildSummaryItem(
                      'Savings',
                      savings,
                      Colors.blue.shade600,
                      theme,
                      labelFontSize,
                      isVeryNarrowScreen,
                    ),
                  ),
                  SizedBox(width: legendSpacing),
                  Expanded(
                    child: _buildSummaryItem(
                      'Debt',
                      debt,
                      Colors.orange.shade600,
                      theme,
                      labelFontSize,
                      isVeryNarrowScreen,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSummaryItem(
    String label,
    double amount,
    Color color,
    ThemeData theme,
    double fontSize,
    bool isVeryNarrowScreen,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: fontSize - 1,
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Padding(
          padding: const EdgeInsets.only(left: 14),
          child: Text(
            '₱${NumberFormat('#,##0').format(amount.abs())}',
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
            maxLines: isVeryNarrowScreen ? 2 : 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  String _formatCurrency(double value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    } else if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(0)}K';
    } else {
      return value.toStringAsFixed(0);
    }
  }
}