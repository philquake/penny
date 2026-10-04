import 'package:flutter/material.dart';

import '../models/budget_entry.dart';
import '../models/category.dart';
import '../models/transaction_type.dart';
import '../models/transactions.dart';
import '../core/widgets/amount_text.dart';
import '../widgets/transaction_row.dart';
import '../core/theme/theme_x.dart';

/// Dashboard / Home screen — the first thing a user sees after signing in.
/// Ledger-style: a running balance up top, this month's flow beneath it,
/// a quick budget snapshot, then the most recent lines in the book.
///
/// Takes real data from the caller rather than owning any of its own —
/// totals, the "recent" slice, and category lookups are all derived here
/// from the full lists, so there's one source of truth (the providers)
/// instead of screen-local mock state.
enum _DashboardView { overview, expenses }

class DashboardScreen extends StatefulWidget {
  final List<Category> categories;
  final List<Transaction> transactions;
  final List<BudgetEntry> budgetEntries;
  final VoidCallback onAddTransaction;
  final VoidCallback onViewBudgets;
  final VoidCallback? onViewTransactions;

  const DashboardScreen({
    super.key,
    required this.categories,
    required this.transactions,
    required this.budgetEntries,
    required this.onAddTransaction,
    required this.onViewBudgets,
    this.onViewTransactions,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  _DashboardView _selectedView = _DashboardView.overview;

  double _amount(Transaction t) => double.tryParse(t.amount) ?? 0;

  double get _totalBalance => widget.transactions.fold(0.0, (sum, t) {
    final a = _amount(t);
    return sum + (t.type == TransactionType.expense ? -a : a);
  });

  bool _isThisMonth(DateTime d, DateTime now) =>
      d.year == now.year && d.month == now.month;

  double get _monthIncome {
    final now = DateTime.now();
    return widget.transactions
        .where(
          (t) =>
              t.type == TransactionType.income &&
              _isThisMonth(t.transactionDate, now),
        )
        .fold(0.0, (sum, t) => sum + _amount(t));
  }

  double get _monthExpenses {
    final now = DateTime.now();
    return widget.transactions
        .where(
          (t) =>
              t.type == TransactionType.expense &&
              _isThisMonth(t.transactionDate, now),
        )
        .fold(0.0, (sum, t) => sum + _amount(t));
  }

  List<Transaction> get _recent {
    final sorted = [...widget.transactions]
      ..sort((a, b) => b.transactionDate.compareTo(a.transactionDate));
    return sorted.take(5).toList();
  }

  Category? _categoryFor(int id) {
    final match = widget.categories.where((c) => c.id == id);
    return match.isNotEmpty ? match.first : null;
  }

  Widget _segmentLabel(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Text(
        text,
        style: context.text.bodyMedium?.copyWith(
          fontSize: 13,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final recent = _recent;

    return Scaffold(
      backgroundColor: context.colors.surface,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverAppBar(
                backgroundColor: context.colors.surface,
                scrolledUnderElevation: 0,
                title: const Text('Overview'),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                  child: SegmentedButton<_DashboardView>(
                    showSelectedIcon: false,
                    style: SegmentedButton.styleFrom(
                      backgroundColor: context.colors.surfaceContainerHigh,
                    ),
                    segments: [
                      ButtonSegment(
                        value: _DashboardView.overview,
                        label: _segmentLabel(context, 'Overview'),
                      ),
                      ButtonSegment(
                        value: _DashboardView.expenses,
                        label: _segmentLabel(context, 'Expenses'),
                      ),
                    ],
                    selected: {_selectedView},
                    onSelectionChanged: (selection) =>
                        setState(() => _selectedView = selection.first),
                  ),
                ),
              ),
              if (_selectedView == _DashboardView.overview)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _BalanceBlock(
                          balance: _totalBalance,
                          income: _monthIncome,
                          expenses: _monthExpenses,
                        ),
                        const SizedBox(height: 32),
                        _SectionHeader(
                          title: 'Budgets',
                          actionLabel: 'View all',
                          onAction: widget.onViewBudgets,
                        ),
                        const SizedBox(height: 12),
                        if (widget.budgetEntries.isEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              color: context.colors.surfaceContainerLowest,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: context.colors.outlineVariant),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.bar_chart_rounded,
                                  color: context.colors.onSurfaceVariant,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'No budgets set yet',
                                    style: context.text.bodyMedium?.copyWith(fontSize: 14),
                                  ),
                                ),
                                TextButton(
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                    ),
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  onPressed: widget.onViewBudgets,
                                  child: Text(
                                    'Create budget',
                                    style: context.text.labelSmall?.copyWith(
                                      color: context.colors.primary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          ...widget.budgetEntries
                              .take(3)
                              .map(
                                (entry) => Padding(
                                  padding: const EdgeInsets.only(bottom: 14),
                                  child: _BudgetRow(entry: entry),
                                ),
                              ),
                        const SizedBox(height: 24),
                        _SectionHeader(
                          title: 'Recent',
                          actionLabel: 'View all',
                          onAction: () {
                            widget.onViewTransactions?.call();
                            setState(() => _selectedView = _DashboardView.expenses);
                          },
                        ),
                        const SizedBox(height: 4),
                        if (recent.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Center(
                              child: Text(
                                'No transactions yet',
                                style: context.text.bodySmall,
                              ),
                            ),
                          )
                        else
                          Container(
                            decoration: BoxDecoration(
                              color: context.colors.surfaceContainerLowest,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: context.colors.outlineVariant),
                            ),
                            child: Column(
                              children: [
                                for (int i = 0; i < recent.length; i++) ...[
                                  Builder(
                                    builder: (context) {
                                      final category = _categoryFor(
                                        recent[i].categoryId,
                                      );
                                      if (category == null) {
                                        return const SizedBox.shrink();
                                      }
                                      return TransactionRow(
                                        transaction: recent[i],
                                        category: category,
                                      );
                                    },
                                  ),
                                  if (i != recent.length - 1)
                                    const Divider(height: 1, indent: 56),
                                ],
                              ],
                            ),
                          ),
                        const SizedBox(height: 32),
                        _DailySpendingCalendar(transactions: widget.transactions),
                      ],
                    ),
                  ),
                )
              else
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    child: _ExpensesList(
                      transactions: widget.transactions,
                      categories: widget.categories,
                    ),
                  ),
                ),
            ],
          ),
          Positioned(
            right: 20,
            bottom: 24,
            child: FloatingActionButton(
              backgroundColor: context.colors.primary,
              foregroundColor: context.colors.onPrimary,
              elevation: 0,
              shape: const CircleBorder(),
              onPressed: widget.onAddTransaction,
              child: const Icon(
                Icons.add_rounded,
                size: 28,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpensesList extends StatefulWidget {
  final List<Transaction> transactions;
  final List<Category> categories;

  const _ExpensesList({
    required this.transactions,
    required this.categories,
  });

  @override
  State<_ExpensesList> createState() => _ExpensesListState();
}

class _ExpensesListState extends State<_ExpensesList> {
  final _searchController = TextEditingController();
  _FlowFilter _filter = _FlowFilter.all;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Category? _categoryFor(int id) {
    final match = widget.categories.where((c) => c.id == id);
    return match.isNotEmpty ? match.first : null;
  }

  List<Transaction> get _filtered {
    final query = _searchController.text.trim().toLowerCase();
    return widget.transactions.where((t) {
      final matchesFlow = switch (_filter) {
        _FlowFilter.all => true,
        _FlowFilter.income => t.type == TransactionType.income,
        _FlowFilter.expenses => t.type == TransactionType.expense,
      };
      final category = _categoryFor(t.categoryId);
      final matchesQuery = query.isEmpty ||
          (t.description?.toLowerCase().contains(query) ?? false) ||
          (category?.name.toLowerCase().contains(query) ?? false);
      return matchesFlow && matchesQuery;
    }).toList();
  }

  Widget _label(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Text(text, style: context.text.bodyMedium?.copyWith(fontSize: 13)),
      );

  @override
  Widget build(BuildContext context) {
    final rows = _filtered;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SearchBar(
          controller: _searchController,
          hintText: 'Search description or category',
          textStyle: WidgetStatePropertyAll(context.text.bodyMedium),
          backgroundColor:
              WidgetStatePropertyAll(context.colors.surfaceContainerLowest),
          elevation: const WidgetStatePropertyAll(0),
          leading: const Icon(Icons.search_rounded),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        SegmentedButton<_FlowFilter>(
          showSelectedIcon: false,
          style: SegmentedButton.styleFrom(
            backgroundColor: context.colors.surfaceContainerHigh,
          ),
          segments: [
            ButtonSegment(
              value: _FlowFilter.all,
              label: _label(context, 'All'),
            ),
            ButtonSegment(
              value: _FlowFilter.income,
              label: _label(context, 'Income'),
            ),
            ButtonSegment(
              value: _FlowFilter.expenses,
              label: _label(context, 'Expenses'),
            ),
          ],
          selected: {_filter},
          onSelectionChanged: (selection) =>
              setState(() => _filter = selection.first),
        ),
        const SizedBox(height: 16),
        if (rows.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                _searchController.text.isEmpty
                    ? 'No transactions yet'
                    : 'No matching transactions',
                style: context.text.bodySmall,
              ),
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: context.colors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: context.colors.outlineVariant),
            ),
            child: Column(
              children: [
                for (int i = 0; i < rows.length; i++) ...[
                  Builder(builder: (context) {
                    final category = _categoryFor(rows[i].categoryId);
                    if (category == null) return const SizedBox.shrink();
                    return TransactionRow(
                      transaction: rows[i],
                      category: category,
                    );
                  }),
                  if (i != rows.length - 1)
                    const Divider(height: 1, indent: 56),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

enum _FlowFilter { all, income, expenses }

class _DailySpendingCalendar extends StatefulWidget {
  final List<Transaction> transactions;

  const _DailySpendingCalendar({required this.transactions});

  @override
  State<_DailySpendingCalendar> createState() => _DailySpendingCalendarState();
}

class _DailySpendingCalendarState extends State<_DailySpendingCalendar> {
  static const _monthNames = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  static const _weekdays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  late DateTime _displayedMonth;
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    _displayedMonth = DateTime(today.year, today.month);
    _selectedDate = DateTime(today.year, today.month, today.day);
  }

  Map<int, double> get _dailyExpenses {
    final totals = <int, double>{};
    for (final transaction in widget.transactions) {
      final date = transaction.transactionDate;
      if (transaction.type != TransactionType.expense ||
          date.year != _displayedMonth.year ||
          date.month != _displayedMonth.month) {
        continue;
      }
      totals[date.day] =
          (totals[date.day] ?? 0) + (double.tryParse(transaction.amount) ?? 0);
    }
    return totals;
  }

  double get _selectedTotal {
    if (_selectedDate.year != _displayedMonth.year ||
        _selectedDate.month != _displayedMonth.month) {
      return 0;
    }
    return _dailyExpenses[_selectedDate.day] ?? 0;
  }

  void _changeMonth(int amount) {
    final nextMonth = DateTime(
      _displayedMonth.year,
      _displayedMonth.month + amount,
    );
    final today = DateTime.now();
    if (nextMonth.isAfter(DateTime(today.year, today.month))) {
      return;
    }

    final lastDay = DateTime(nextMonth.year, nextMonth.month + 1, 0).day;
    setState(() {
      _displayedMonth = nextMonth;
      _selectedDate = DateTime(
        nextMonth.year,
        nextMonth.month,
        _selectedDate.day.clamp(1, lastDay),
      );
    });
  }

  String _compactAmount(double amount) {
    if (amount >= 10000) return '\$${(amount / 1000).toStringAsFixed(0)}k';
    if (amount >= 1000) return '\$${(amount / 1000).toStringAsFixed(1)}k';
    return '\$${amount.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    final daysInMonth = DateTime(
      _displayedMonth.year,
      _displayedMonth.month + 1,
      0,
    ).day;
    final leadingDays =
        DateTime(_displayedMonth.year, _displayedMonth.month).weekday - 1;
    final cellCount = ((leadingDays + daysInMonth + 6) ~/ 7) * 7;
    final dailyExpenses = _dailyExpenses;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Daily spending',
                style: context.text.titleLarge?.copyWith(
                  fontSize: 17,
                ),
              ),
            ),
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              onPressed: () => _changeMonth(-1),
              icon: Icon(
                Icons.chevron_left_rounded,
                size: 17,
                color: context.colors.onSurfaceVariant,
              ),
            ),
            Text(
              '${_monthNames[_displayedMonth.month - 1]} ${_displayedMonth.year}',
              style: context.text.labelMedium,
            ),
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              onPressed:
                  _displayedMonth.year == DateTime.now().year &&
                      _displayedMonth.month == DateTime.now().month
                  ? null
                  : () => _changeMonth(1),
              icon: Icon(
                Icons.chevron_right_rounded,
                size: 17,
                color: context.colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Divider(height: 1),
        const SizedBox(height: 10),
        Row(
          children: [
            for (final weekday in _weekdays)
              Expanded(
                child: Center(
                  child: Text(
                    weekday,
                    style: context.text.bodySmall?.copyWith(
                      fontSize: 10,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: cellCount,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisExtent: 48,
          ),
          itemBuilder: (context, index) {
            final day = index - leadingDays + 1;
            if (day < 1 || day > daysInMonth) return const SizedBox.shrink();

            final date = DateTime(
              _displayedMonth.year,
              _displayedMonth.month,
              day,
            );
            final total = dailyExpenses[day] ?? 0;
            final isSelected = date == _selectedDate;
            final isToday =
                date ==
                DateTime.now().copyWith(
                  hour: 0,
                  minute: 0,
                  second: 0,
                  millisecond: 0,
                  microsecond: 0,
                );

            return Padding(
              padding: const EdgeInsets.all(2),
              child: Material(
                color: isSelected
                    ? context.colors.surfaceContainerHighest
                    : Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                  side: isToday && !isSelected
                      ? BorderSide(color: context.colors.outlineVariant)
                      : BorderSide.none,
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: () => setState(() => _selectedDate = date),
                  child: SizedBox(
                    width: double.infinity,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$day',
                          style: context.text.bodyMedium?.copyWith(
                            fontSize: 12,
                          ),
                        ),
                        if (total > 0)
                          Text(
                            _compactAmount(total),
                            maxLines: 1,
                            overflow: TextOverflow.clip,
                            style: context.text.bodySmall?.copyWith(
                              fontSize: 8,
                              fontWeight: FontWeight.w500,
                              color: context.colors.error,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        const Divider(height: 1),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: Text(
                'Spent on ${_monthNames[_selectedDate.month - 1]} ${_selectedDate.day}',
                style: context.text.bodySmall,
              ),
            ),
            AmountText(
              _selectedTotal.toStringAsFixed(2),
              colorBySign: false,
            ),
          ],
        ),
      ],
    );
  }
}

class _BalanceBlock extends StatelessWidget {
  final double balance;
  final double income;
  final double expenses;

  const _BalanceBlock({
    required this.balance,
    required this.income,
    required this.expenses,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Total balance', style: context.text.labelMedium),
        const SizedBox(height: 4),
        AmountText(
          balance.toStringAsFixed(2),
          size: 40,
          weight: FontWeight.w600,
          colorBySign: false,
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: _FlowStat(
                label: 'In this month',
                value: income,
                icon: Icons.south_west_rounded,
                color: context.finance.income,
              ),
            ),
            const SizedBox(width: 12),
            Container(width: 1, height: 34, color: context.colors.outlineVariant),
            const SizedBox(width: 12),
            Expanded(
              child: _FlowStat(
                label: 'Out this month',
                value: expenses,
                icon: Icons.north_east_rounded,
                color: context.finance.expense,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _FlowStat extends StatelessWidget {
  final String label;
  final double value;
  final IconData icon;
  final Color color;

  const _FlowStat({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
            Text(label, style: context.text.bodySmall),
          ],
        ),
        const SizedBox(height: 4),
        AmountText(
          value.toStringAsFixed(2),
          size: 17,
          weight: FontWeight.w600,
          colorBySign: false,
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String actionLabel;
  final VoidCallback onAction;

  const _SectionHeader({
    required this.title,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: context.text.titleLarge?.copyWith(fontSize: 17)),
        TextButton(
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          onPressed: onAction,
          child: Text(
            actionLabel,
            style: context.text.bodyMedium?.copyWith(
              color: context.colors.primary,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }
}

class _BudgetRow extends StatelessWidget {
  final BudgetEntry entry;
  const _BudgetRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    final spent = double.tryParse(entry.status.spentAmount) ?? 0;
    final limit = double.tryParse(entry.budget.amount) ?? 1;
    final fraction = limit > 0 ? (spent / limit).clamp(0, 1.4) : 0.0;
    final isOver = entry.status.status == 'exceeded';
    final barColor = isOver ? context.colors.error : context.colors.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              entry.category.name,
              style: context.text.bodyMedium?.copyWith(fontSize: 14),
            ),
            Text(
              '\$${spent.toStringAsFixed(0)} of \$${limit.toStringAsFixed(0)}',
              style: context.text.displaySmall?.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isOver ? context.colors.error : context.colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Stack(
                children: [
                  Container(height: 5, color: context.colors.outlineVariant),
                  Container(
                    height: 5,
                    width: constraints.maxWidth * fraction,
                    color: barColor,
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}