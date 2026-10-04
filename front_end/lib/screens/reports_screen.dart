import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart'; 
import '../models/category.dart';
import '../models/transaction_type.dart';
import '../models/transactions.dart';
import '../core/widgets/amount_text.dart';
import '../core/theme/theme_x.dart';

enum _ReportRange { month, quarter, year }


/// Multi-category chart palette. Was a `const` list, but theme colors are
/// runtime values, so it's now a function. The fixed hues stay muted/warm.
List<Color> _chartPalette(ColorScheme colors, FinanceColors finance) => [
  colors.primary,                // Emerald
const Color(0xFF7A6A9C),       // Dusty plum
const Color(0xFFB99A3E),       // Muted ochre
const Color(0xFF4A7A8C),       // Dusty teal
const Color(0xFFC94B4B),       // Coral
const Color(0xFF8C6F52),       // Warm taupe
const Color(0xFF5267A9),       // Slate blue
const Color(0xFF4D9078),       // Sage
const Color(0xFFD9827B),       // Muted rose
const Color(0xFF356B7A),       // Deep ocean
];

/// Reports screen: spending composition and an income/expense trend.
/// Aggregates client-side (no /reports consumption yet).
class ReportsScreen extends StatefulWidget {
  final List<Transaction> transactions;
  final List<Category> categories;

  const ReportsScreen({
    super.key,
    required this.transactions,
    required this.categories,
  });

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  _ReportRange _range = _ReportRange.month;

  DateTime get _now => DateTime.now();

  DateTime get _rangeStart {
    switch (_range) {
      case _ReportRange.month:
        return DateTime(_now.year, _now.month, 1);
      case _ReportRange.quarter:
        return DateTime(_now.year, _now.month - 2, 1);
      case _ReportRange.year:
        return DateTime(_now.year, 1, 1);
    }
  }

  List<Transaction> get _inRange => widget.transactions
      .where((t) => !t.transactionDate.isBefore(_rangeStart))
      .toList();

  Category? _categoryFor(int id) {
    final match = widget.categories.where((c) => c.id == id);
    return match.isNotEmpty ? match.first : null;
  }

  double _amount(Transaction t) => double.tryParse(t.amount) ?? 0;

  double get _totalIncome => _inRange
      .where((t) => t.type == TransactionType.income)
      .fold(0.0, (sum, t) => sum + _amount(t));

  double get _totalExpenses => _inRange
      .where((t) => t.type == TransactionType.expense)
      .fold(0.0, (sum, t) => sum + _amount(t));

  /// categoryId -> total spent, expenses only, sorted descending.
  List<MapEntry<int, double>> get _expenseByCategory {
    final totals = <int, double>{};
    for (final t in _inRange.where((t) => t.type == TransactionType.expense)) {
      totals[t.categoryId] = (totals[t.categoryId] ?? 0) + _amount(t);
    }
    return totals.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  }

  /// Last 6 calendar months of income/expense totals, oldest first.
  List<_MonthTotal> get _monthlyTrend {
    final months = List.generate(
      6,
      (i) => DateTime(_now.year, _now.month - (5 - i), 1),
    );

    return months.map((monthStart) {
      final monthEnd = DateTime(monthStart.year, monthStart.month + 1, 1);
      final inMonth = widget.transactions.where((t) =>
          !t.transactionDate.isBefore(monthStart) &&
          t.transactionDate.isBefore(monthEnd));

      final income = inMonth
          .where((t) => t.type == TransactionType.income)
          .fold(0.0, (sum, t) => sum + _amount(t));
      final expense = inMonth
          .where((t) => t.type == TransactionType.expense)
          .fold(0.0, (sum, t) => sum + _amount(t));

      return _MonthTotal(monthStart, income, expense);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final finance = context.finance;
    final palette = _chartPalette(colors, finance);

    final breakdown = _expenseByCategory;
    final net = _totalIncome - _totalExpenses;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          const SliverAppBar(title: Text('Reports')),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SegmentedButton<_ReportRange>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(
                        value: _ReportRange.month,
                        label: Text('This Month'),
                      ),
                      ButtonSegment(
                        value: _ReportRange.quarter,
                        label: Text('3 Months'),
                      ),
                      ButtonSegment(
                        value: _ReportRange.year,
                        label: Text('This Year'),
                      ),
                    ],
                    selected: {_range},
                    onSelectionChanged: (s) => setState(() => _range = s.first),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: _SummaryStat(
                          label: 'Income',
                          value: _totalIncome,
                          color: finance.income,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _SummaryStat(
                          label: 'Expenses',
                          value: _totalExpenses,
                          color: finance.expense,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _SummaryStat(
                          label: 'Net',
                          value: net,
                          color: net >= 0 ? finance.income : finance.expense,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'Spending by category',
                    style: context.text.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  if (breakdown.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text(
                          'No expenses in this period',
                          style: context.text.bodySmall?.copyWith(
                            color: context.colors.onSurfaceVariant,
                          ),
                        ),
                      ),
                    )
                  else ...[
                    SizedBox(
                      height: 180,
                      child: PieChart(
                        PieChartData(
                          sectionsSpace: 2,
                          centerSpaceRadius: 44,
                          sections: [
                            for (int i = 0; i < breakdown.length; i++)
                              PieChartSectionData(
                                value: breakdown[i].value,
                                color: palette[i % palette.length],
                                radius: 34,
                                showTitle: false,
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      decoration: BoxDecoration(
                        color: context.colors.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: context.colors.outlineVariant),
                      ),
                      child: Column(
                        children: [
                          for (int i = 0; i < breakdown.length; i++) ...[
                            _CategoryBreakdownRow(
                              category: _categoryFor(breakdown[i].key),
                              amount: breakdown[i].value,
                              percent: _totalExpenses > 0
                                  ? breakdown[i].value / _totalExpenses
                                  : 0,
                              color: palette[i % palette.length],
                            ),
                            if (i != breakdown.length - 1)
                              Divider(
                                height: 1,
                                indent: 40,
                                color: context.colors.outlineVariant,
                              ),
                          ],
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 32),
                  Text(
                    'Income vs. expenses',
                    style: context.text.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Last 6 months',
                    style: context.text.bodySmall?.copyWith(
                      color: context.colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 180,
                    child: _MonthlyTrendChart(months: _monthlyTrend),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _LegendDot(color: finance.income, label: 'Income'),
                      const SizedBox(width: 20),
                      _LegendDot(color: finance.expense, label: 'Expenses'),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthTotal {
  final DateTime month;
  final double income;
  final double expense;
  const _MonthTotal(this.month, this.income, this.expense);
}

class _SummaryStat extends StatelessWidget {
  final String label;
  final double value;
  final Color color;

  const _SummaryStat({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final sign = value < 0 ? '-' : '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: context.text.bodySmall?.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '$sign\$${value.abs().toStringAsFixed(0)}',
          style: context.text.titleMedium?.copyWith(
            color: color,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _CategoryBreakdownRow extends StatelessWidget {
  final Category? category;
  final double amount;
  final double percent;
  final Color color;

  const _CategoryBreakdownRow({
    required this.category,
    required this.amount,
    required this.percent,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              category?.name ?? 'Uncategorized',
              style: context.text.bodyMedium,
            ),
          ),
          Text(
            '${(percent * 100).round()}%',
            style: context.text.bodySmall?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 10),
          AmountText(
            amount.toStringAsFixed(2),
            size: 13,
            colorBySign: false, 
          ),
        ],
      ),
    );
  }
}

class _MonthlyTrendChart extends StatelessWidget {
  final List<_MonthTotal> months;
  const _MonthlyTrendChart({required this.months});

  static const _monthAbbr = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  @override
  Widget build(BuildContext context) {
    final finance = context.finance;
    final labelStyle = context.text.bodySmall?.copyWith(
      color: context.colors.onSurfaceVariant,
    );

    final maxVal = months.fold<double>(
      1,
      (max, m) => [max, m.income, m.expense].reduce((a, b) => a > b ? a : b),
    );

    return BarChart(
      BarChartData(
        maxY: maxVal * 1.15,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= months.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    _monthAbbr[months[i].month.month - 1],
                    style: labelStyle,
                  ),
                );
              },
            ),
          ),
        ),
        barGroups: [
          for (int i = 0; i < months.length; i++)
            BarChartGroupData(
              x: i,
              barsSpace: 4,
              barRods: [
                BarChartRodData(
                  toY: months[i].income,
                  color: finance.income,
                  width: 7,
                  borderRadius: BorderRadius.circular(2),
                ),
                BarChartRodData(
                  toY: months[i].expense,
                  color: finance.expense,
                  width: 7,
                  borderRadius: BorderRadius.circular(2),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: context.text.bodySmall?.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}