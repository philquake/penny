import 'package:flutter/cupertino.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/category.dart';
import '../models/transaction_type.dart';
import '../models/transactions.dart';
import '../theme/app_theme.dart';

enum _ReportRange { month, quarter, year }

/// A small, desaturated palette used only for multi-category chart slices.
/// Kept separate from AppColors (which stays a single-accent system) —
/// a breakdown chart genuinely needs several distinguishable hues, but
/// they're chosen to sit in the same muted/warm family as the rest of Penny
/// rather than defaulting to a bright rainbow.
const _chartPalette = [
  AppColors.copper,
  AppColors.ledgerGreen,
  Color(0xFF7A6A9C), // dusty plum
  Color(0xFFB99A3E), // muted ochre
  Color(0xFF4A7A8C), // dusty teal
  AppColors.rust,
  Color(0xFF8C6F52), // warm taupe
];

/// Reports screen — spending composition and an income/expense trend.
///
/// Takes the raw [transactions]/[categories] lists and aggregates them
/// client-side. There's no /reports endpoint on the backend yet (Phase 3
/// per the build plan), and for a self-hosted household of ~5 users,
/// client-side aggregation is cheap enough that it may never need to move
/// server-side — keeps with the zero-marginal-cost philosophy.
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

  static final _now = DateTime(2026, 9, 3); // matches conversation's current date

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
    final entries = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries;
  }

  /// Last 6 calendar months of income/expense totals, oldest first.
  List<_MonthTotal> get _monthlyTrend {
    final months = List.generate(6, (i) {
      final d = DateTime(_now.year, _now.month - (5 - i), 1);
      return d;
    });

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
    final breakdown = _expenseByCategory;
    final net = _totalIncome - _totalExpenses;

    return CupertinoPageScaffold(
      backgroundColor: AppColors.paper,
      child: CustomScrollView(
        slivers: [
          CupertinoSliverNavigationBar(
            backgroundColor: AppColors.paper,
            border: null,
            largeTitle: const Text('Reports'),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CupertinoSlidingSegmentedControl<_ReportRange>(
                    backgroundColor: AppColors.paperDim,
                    thumbColor: CupertinoColors.white,
                    groupValue: _range,
                    children: {
                      _ReportRange.month: _segmentLabel('This Month'),
                      _ReportRange.quarter: _segmentLabel('3 Months'),
                      _ReportRange.year: _segmentLabel('This Year'),
                    },
                    onValueChanged: (value) {
                      if (value != null) setState(() => _range = value);
                    },
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: _SummaryStat(
                          label: 'Income',
                          value: _totalIncome,
                          color: AppColors.ledgerGreen,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _SummaryStat(
                          label: 'Expenses',
                          value: _totalExpenses,
                          color: AppColors.rust,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _SummaryStat(
                          label: 'Net',
                          value: net,
                          color: net >= 0 ? AppColors.ledgerGreen : AppColors.rust,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  Text('Spending by category',
                      style: AppType.title.copyWith(fontSize: 17)),
                  const SizedBox(height: 16),
                  if (breakdown.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text('No expenses in this period',
                            style: AppType.caption),
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
                                color: _chartPalette[i % _chartPalette.length],
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
                        color: CupertinoColors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.hairline),
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
                              color: _chartPalette[i % _chartPalette.length],
                            ),
                            if (i != breakdown.length - 1)
                              const LedgerDivider(indent: 40),
                          ],
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 32),
                  Text('Income vs. expenses',
                      style: AppType.title.copyWith(fontSize: 17)),
                  const SizedBox(height: 4),
                  Text('Last 6 months', style: AppType.caption),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 180,
                    child: _MonthlyTrendChart(months: _monthlyTrend),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _LegendDot(color: AppColors.ledgerGreen, label: 'Income'),
                      const SizedBox(width: 20),
                      _LegendDot(color: AppColors.rust, label: 'Expenses'),
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

  Widget _segmentLabel(String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(text, style: AppType.body.copyWith(fontSize: 12)),
      );
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

  const _SummaryStat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppType.caption),
        const SizedBox(height: 4),
        Text(
          '\$${value.abs().toStringAsFixed(0)}',
          style: AppType.amount(size: 18, weight: FontWeight.w600, color: color),
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
              style: AppType.body.copyWith(fontSize: 14),
            ),
          ),
          Text('${(percent * 100).round()}%',
              style: AppType.caption.copyWith(fontSize: 12)),
          const SizedBox(width: 10),
          AmountText(amount.toStringAsFixed(2), size: 13, colorBySign: false),
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
                    style: AppType.caption,
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
              barRods: [
                BarChartRodData(
                  toY: months[i].income,
                  color: AppColors.ledgerGreen,
                  width: 7,
                  borderRadius: BorderRadius.circular(2),
                ),
                BarChartRodData(
                  toY: months[i].expense,
                  color: AppColors.rust,
                  width: 7,
                  borderRadius: BorderRadius.circular(2),
                ),
              ],
              barsSpace: 4,
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
        Text(label, style: AppType.caption),
      ],
    );
  }
}