import 'package:flutter/material.dart';

import '../models/budget.dart';
import '../models/budget_entry.dart';
import '../models/budget_period.dart';
import '../models/category.dart';
import '../core/theme/app_colors.dart';
import '../widgets/transaction_row.dart' show categoryIcon;
import '../core/theme/theme_x.dart';

/// Budgets screen — one ledger card per budget: category, period, a
/// progress bar colored by the backend's computed status, spent/remaining.
class BudgetsScreen extends StatefulWidget {
  final List<BudgetEntry> entries;
  final List<Category> expenseCategories;
  final void Function(BudgetCreate) onCreate;
  final void Function(int id) onDelete;

  const BudgetsScreen({
    super.key,
    required this.entries,
    required this.expenseCategories,
    required this.onCreate,
    required this.onDelete,
  });

  @override
  State<BudgetsScreen> createState() => _BudgetsScreenState();
}

class _BudgetsScreenState extends State<BudgetsScreen> {
  late List<BudgetEntry> _entries;

  @override
  void initState() {
    super.initState();
    _entries = List.of(widget.entries);
  }

  @override
  void didUpdateWidget(covariant BudgetsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _entries = List.of(widget.entries);
  }

  Future<void> _confirmDelete(BudgetEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete budget for "${entry.category.name}"?'),
        content: const Text('This can\'t be undone.'),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(context).pop(false),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: context.colors.error),
            child: const Text('Delete'),
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(
        () => _entries.removeWhere((e) => e.budget.id == entry.budget.id),
      );
      widget.onDelete(entry.budget.id);
    }
  }

  Future<void> _showAddBudgetSheet() async {
    if (widget.expenseCategories.isEmpty) return;

    final created = await showModalBottomSheet<BudgetCreate>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          _AddBudgetSheet(categories: widget.expenseCategories),
    );

    if (created != null) {
      widget.onCreate(created);
      // Optimistic placeholder — real spend comes from the server on
      // next fetch; show it fresh (0% used) until then.
      setState(() {
        _entries.add(
          BudgetEntry(
            Budget(
              id: -_entries.length - 1,
              userId: 1,
              categoryId: created.categoryId,
              amount: created.amount,
              period: created.period,
              periodStart: created.periodStart,
              periodEnd: created.periodEnd,
              alertThresholdPercent: created.alertThresholdPercent,
            ),
            BudgetStatus(
              budgetId: -_entries.length - 1,
              spentAmount: '0.00',
              remainingAmount: created.amount,
              percentageUsed: '0',
              status: 'normal',
              thresholdCrossed: false,
            ),
            widget.expenseCategories.firstWhere(
              (c) => c.id == created.categoryId,
            ),
          ),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.surface,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: context.colors.surface,
            scrolledUnderElevation: 0,
            title: const Text('Budgets'),
            pinned: true,
            actions: [
              IconButton(
                onPressed: _showAddBudgetSheet,
                icon: Icon(
                  Icons.add_circle_rounded,
                  color: context.colors.primary,
                  size: 36,
                ),
              ),
            ],
          ),
          if (_entries.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _EmptyState(onAdd: _showAddBudgetSheet),
            )
          else
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                child: Column(
                  children: [
                    for (final entry in _entries)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: _BudgetCard(
                          entry: entry,
                          onDelete: () => _confirmDelete(entry),
                        ),
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

class _BudgetCard extends StatelessWidget {
  final BudgetEntry entry;
  final VoidCallback onDelete;

  const _BudgetCard({required this.entry, required this.onDelete});

  // Was a getter, but it needs theme colors, so it now takes them in.
  Color _barColor(ColorScheme colors, FinanceColors finance) {
    switch (entry.status.status) {
      case 'exceeded':
        return finance.expense;
      case 'alert':
        return finance.expense.withValues(alpha: 0.6);
      default:
        return colors.primary;
    }
  }

  String get _periodLabel {
    switch (entry.budget.period) {
      case BudgetPeriod.weekly:
        return 'Weekly';
      case BudgetPeriod.monthly:
        return 'Monthly (day ${entry.budget.periodStart.day})';
      case BudgetPeriod.yearly:
        return 'Yearly';
      case BudgetPeriod.custom:
        final start = entry.budget.periodStart;
        final end = entry.budget.periodEnd;
        return 'Custom (${start.month}/${start.day} - ${end.month}/${end.day})';
    }
  }

  @override
  Widget build(BuildContext context) {
    final spent = double.tryParse(entry.status.spentAmount) ?? 0;
    final limit = double.tryParse(entry.budget.amount) ?? 1;
    final fraction = limit > 0 ? (spent / limit).clamp(0.0, 1.2) : 0.0;
    final remaining = double.tryParse(entry.status.remainingAmount) ?? 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: context.colors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Icon(
                  categoryIcon(entry.category.icon),
                  size: 15,
                  color: context.colors.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.category.name,
                      style: context.text.bodyMedium?.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(_periodLabel, style: context.text.bodySmall),
                  ],
                ),
              ),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                onPressed: onDelete,
                icon: Icon(
                  Icons.more_horiz_rounded,
                  size: 20,
                  color: context.colors.outline,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Stack(
                  children: [
                    Container(height: 6, color: context.colors.outlineVariant),
                    Container(
                      height: 6,
                      width: constraints.maxWidth * fraction,
                      color: _barColor(context.colors, context.finance),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '\$${spent.toStringAsFixed(0)} of \$${limit.toStringAsFixed(0)}',
                style: context.text.headlineMedium?.copyWith(
                  fontSize: 13,
                  color: context.colors.onSurface,
                ),
              ),
              Text(
                remaining >= 0
                    ? '\$${remaining.toStringAsFixed(0)} left'
                    : '\$${remaining.abs().toStringAsFixed(0)} over',
                style: context.text.headlineMedium?.copyWith(
                  fontSize: 13,
                  color: remaining >= 0
                      ? context.colors.onSurfaceVariant
                      : context.finance.expense,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.bar_chart_rounded,
              size: 32,
              color: context.colors.outline,
            ),
            const SizedBox(height: 12),
            Text(
              'No budgets yet',
              style: context.text.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Set a spending limit for a category to track it here.',
              style: context.text.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: context.colors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: onAdd,
              child: Text(
                'Add Budget',
                style: context.text.bodyMedium?.copyWith(
                  color: context.colors.onPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Modal sheet for creating a budget: category (expense-type only, since
/// budgets track spending), amount, period, start date, alert threshold.
/// period_end is derived from period_start + period rather than asked for
/// directly — one less date for the person to get wrong.
class _AddBudgetSheet extends StatefulWidget {
  final List<Category> categories;
  const _AddBudgetSheet({required this.categories});

  @override
  State<_AddBudgetSheet> createState() => _AddBudgetSheetState();
}

class _AddBudgetSheetState extends State<_AddBudgetSheet> {
  late Category _category;
  final _amountController = TextEditingController();
  BudgetPeriod _period = BudgetPeriod.monthly;
  DateTime _start = DateTime.now();
  late DateTime _customEnd;
  double _threshold = 80;

  @override
  void initState() {
    super.initState();
    _category = widget.categories.first;
    _customEnd = _start.add(const Duration(days: 29));
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  DateTime get _computedEnd {
    switch (_period) {
      case BudgetPeriod.weekly:
        return _start.add(const Duration(days: 6));
      case BudgetPeriod.monthly:
        final nextMonth = DateTime(_start.year, _start.month + 1);
        final lastDay = DateTime(nextMonth.year, nextMonth.month + 1, 0).day;
        return DateTime(
          nextMonth.year,
          nextMonth.month,
          _start.day.clamp(1, lastDay),
        ).subtract(const Duration(days: 1));
      case BudgetPeriod.yearly:
        return DateTime(
          _start.year + 1,
          _start.month,
          _start.day,
        ).subtract(const Duration(days: 1));
      case BudgetPeriod.custom:
        return _customEnd;
    }
  }

  bool get _canSave =>
      (double.tryParse(_amountController.text.trim()) ?? 0) > 0;

  void _handleSave() {
    if (!_canSave) return;
    Navigator.of(context).pop(
      BudgetCreate(
        categoryId: _category.id,
        amount: double.parse(_amountController.text.trim()).toStringAsFixed(2),
        period: _period,
        periodStart: _start,
        periodEnd: _computedEnd,
        alertThresholdPercent: _threshold.round(),
      ),
    );
  }

  Future<void> _pickCategory() async {
    final picked = await showModalBottomSheet<Category>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text('Category', style: context.text.titleMedium),
            ),
            for (final category in widget.categories)
              ListTile(
                title: Text(category.name, style: context.text.bodyMedium),
                trailing: _category.id == category.id
                    ? Icon(
                        Icons.check_rounded,
                        size: 16,
                        color: context.colors.primary,
                      )
                    : null,
                onTap: () => Navigator.of(context).pop(category),
              ),
          ],
        ),
      ),
    );
    if (picked != null) setState(() => _category = picked);
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _start,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      _start = picked;
      if (_customEnd.isBefore(_start)) {
        _customEnd = _start.add(const Duration(days: 29));
      }
    });
  }

  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _customEnd.isBefore(_start) ? _start : _customEnd,
      firstDate: _start,
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _customEnd = picked);
  }

  Future<void> _pickMonthlyDay() async {
    final day = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text('Monthly start day', style: context.text.titleMedium),
            ),
            for (var value = 1; value <= 31; value++)
              ListTile(
                title: Text('Day $value', style: context.text.bodyMedium),
                onTap: () => Navigator.of(context).pop(value),
              ),
          ],
        ),
      ),
    );
    if (day == null) return;
    setState(() {
      final lastDay = DateTime(_start.year, _start.month + 1, 0).day;
      _start = DateTime(_start.year, _start.month, day.clamp(1, lastDay));
    });
  }

  static const _monthAbbr = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    Text(
                      'New Budget',
                      style: context.text.titleLarge?.copyWith(fontSize: 16),
                    ),
                    TextButton(
                      onPressed: _canSave ? _handleSave : null,
                      child: Text(
                        'Add',
                        style: TextStyle(
                          color: _canSave
                              ? context.colors.primary
                              : context.colors.outline,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _SheetFieldRow(
                  label: 'Category',
                  onTap: _pickCategory,
                  child: Text(_category.name, style: context.text.bodyMedium),
                ),
                const Divider(height: 1),
                _SheetFieldRow(
                  label: 'Amount',
                  child: TextField(
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    style: context.text.headlineMedium?.copyWith(fontSize: 15),
                    decoration: InputDecoration(
                      hintText: '0.00',
                      hintStyle: context.text.headlineMedium?.copyWith(
                        fontSize: 15,
                        color: context.colors.outline,
                      ),
                      prefixText: '\$ ',
                      prefixStyle: context.text.headlineMedium?.copyWith(
                        fontSize: 15,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Period', style: context.text.labelMedium),
                            const SizedBox(height: 8),
                            SegmentedButton<BudgetPeriod>(
                              showSelectedIcon: false,
                              style: SegmentedButton.styleFrom(
                                backgroundColor:
                                    context.colors.surfaceContainerHigh,
                              ),
                              segments: [
                                ButtonSegment(
                                  value: BudgetPeriod.weekly,
                                  label: _segmentLabel(context, 'Week'),
                                ),
                                ButtonSegment(
                                  value: BudgetPeriod.monthly,
                                  label: _segmentLabel(context, 'Month'),
                                ),
                                ButtonSegment(
                                  value: BudgetPeriod.yearly,
                                  label: _segmentLabel(context, 'Year'),
                                ),
                                ButtonSegment(
                                  value: BudgetPeriod.custom,
                                  label: _segmentLabel(context, 'Custom'),
                                ),
                              ],
                              selected: {_period},
                              onSelectionChanged: (selection) {
                                final value = selection.first;
                                setState(() {
                                  _period = value;
                                  if (value == BudgetPeriod.custom &&
                                      _customEnd.isBefore(_start)) {
                                    _customEnd = _start.add(
                                      const Duration(days: 29),
                                    );
                                  }
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                _SheetFieldRow(
                  label: _period == BudgetPeriod.monthly ? 'Starts' : 'From',
                  onTap: _pickStartDate,
                  child: Text(
                    '${_monthAbbr[_start.month - 1]} ${_start.day}, ${_start.year}',
                    style: context.text.bodyMedium,
                  ),
                ),
                if (_period == BudgetPeriod.monthly) ...[
                  const Divider(height: 1),
                  _SheetFieldRow(
                    label: 'Monthly day',
                    onTap: _pickMonthlyDay,
                    child: Text(
                      'Day ${_start.day}',
                      style: context.text.bodyMedium,
                    ),
                  ),
                ],
                if (_period == BudgetPeriod.custom) ...[
                  const Divider(height: 1),
                  _SheetFieldRow(
                    label: 'Until',
                    onTap: _pickEndDate,
                    child: Text(
                      '${_monthAbbr[_customEnd.month - 1]} ${_customEnd.day}, ${_customEnd.year}',
                      style: context.text.bodyMedium,
                    ),
                  ),
                ],
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Alert threshold',
                            style: context.text.labelMedium,
                          ),
                          Text(
                            _threshold == 0 ? 'Off' : '${_threshold.round()}%',
                            style: context.text.headlineMedium?.copyWith(
                              fontSize: 13,
                              color: context.colors.primary,
                            ),
                          ),
                        ],
                      ),
                      Slider(
                        value: _threshold,
                        min: 0,
                        max: 100,
                        divisions: 20,
                        activeColor: context.colors.primary,
                        onChanged: (value) =>
                            setState(() => _threshold = value),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _segmentLabel(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Text(text, style: context.text.bodyMedium?.copyWith(fontSize: 12)),
    );
  }
}

class _SheetFieldRow extends StatelessWidget {
  final String label;
  final Widget child;
  final VoidCallback? onTap;

  const _SheetFieldRow({required this.label, required this.child, this.onTap});

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: context.text.labelMedium),
          ),
          Expanded(child: child),
          if (onTap != null)
            Icon(
              Icons.chevron_right_rounded,
              size: 14,
              color: context.colors.outline,
            ),
        ],
      ),
    );
    if (onTap == null) return row;
    return InkWell(onTap: onTap, child: row);
  }
}
