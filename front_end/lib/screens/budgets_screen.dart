import 'package:flutter/cupertino.dart';
import '../models/budget.dart';
import '../models/budget_entry.dart';
import '../models/budget_period.dart';
import '../models/category.dart';
import '../models/transaction_type.dart';
import '../theme/app_theme.dart';
import '../widgets/transaction_row.dart' show categoryIcon;

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

  Future<void> _confirmDelete(BudgetEntry entry) async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text('Delete budget for "${entry.category.name}"?'),
        content: const Text('This can\'t be undone.'),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(context).pop(false),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('Delete'),
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _entries.removeWhere((e) => e.budget.id == entry.budget.id));
      widget.onDelete(entry.budget.id);
    }
  }

  Future<void> _showAddBudgetSheet() async {
    if (widget.expenseCategories.isEmpty) return;

    final created = await showCupertinoModalPopup<BudgetCreate>(
      context: context,
      builder: (context) => _AddBudgetSheet(categories: widget.expenseCategories),
    );

    if (created != null) {
      widget.onCreate(created);
      // Optimistic placeholder — real spend comes from the server on
      // next fetch; show it fresh (0% used) until then.
      setState(() {
        _entries.add(BudgetEntry(
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
          widget.expenseCategories.firstWhere((c) => c.id == created.categoryId),
        ));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppColors.paper,
      child: CustomScrollView(
        slivers: [
          CupertinoSliverNavigationBar(
            backgroundColor: AppColors.paper,
            border: null,
            largeTitle: const Text('Budgets'),
            trailing: CupertinoButton(
              padding: EdgeInsets.zero,
              minimumSize: const Size(32, 32),
              onPressed: _showAddBudgetSheet,
              child: const Icon(
                CupertinoIcons.add_circled_solid,
                color: AppColors.copper,
                size: 28,
              ),
            ),
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

  Color get _barColor {
    switch (entry.status.status) {
      case 'exceeded':
        return AppColors.rust;
      case 'alert':
        return AppColors.rust.withValues(alpha: 0.6);
      default:
        return AppColors.copper;
    }
  }

  String get _periodLabel {
    switch (entry.budget.period) {
      case BudgetPeriod.weekly:
        return 'Weekly';
      case BudgetPeriod.monthly:
        return 'Monthly';
      case BudgetPeriod.yearly:
        return 'Yearly';
    }
  }

  @override
  Widget build(BuildContext context) {
    final spent = double.tryParse(entry.status.spentAmount) ?? 0;
    final limit = double.tryParse(entry.budget.amount) ?? 1;
    final fraction = limit > 0 ? (spent / limit).clamp(0, 1.2) : 0.0;
    final remaining = double.tryParse(entry.status.remainingAmount) ?? 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CupertinoColors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.hairline),
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
                  color: AppColors.paperDim,
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Icon(categoryIcon(entry.category.icon),
                    size: 15, color: AppColors.copperDark),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(entry.category.name,
                        style: AppType.body.copyWith(
                            fontSize: 15, fontWeight: FontWeight.w600)),
                    Text(_periodLabel, style: AppType.caption),
                  ],
                ),
              ),
              CupertinoButton(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                onPressed: onDelete,
                child: const Icon(CupertinoIcons.ellipsis_circle,
                    size: 20, color: AppColors.slateLight),
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
                    Container(height: 6, color: AppColors.hairline),
                    Container(
                      height: 6,
                      width: constraints.maxWidth * fraction,
                      color: _barColor,
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
                style: AppType.amount(size: 13, color: AppColors.ink),
              ),
              Text(
                remaining >= 0
                    ? '\$${remaining.toStringAsFixed(0)} left'
                    : '\$${remaining.abs().toStringAsFixed(0)} over',
                style: AppType.amount(
                  size: 13,
                  color: remaining >= 0 ? AppColors.slate : AppColors.rust,
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
            const Icon(CupertinoIcons.chart_bar_alt_fill,
                size: 32, color: AppColors.slateLight),
            const SizedBox(height: 12),
            Text('No budgets yet',
                style: AppType.body.copyWith(fontWeight: FontWeight.w500)),
            const SizedBox(height: 4),
            Text(
              'Set a spending limit for a category to track it here.',
              style: AppType.caption,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            CupertinoButton(
              color: AppColors.copper,
              borderRadius: BorderRadius.circular(8),
              onPressed: onAdd,
              child: const Text('Add Budget'),
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
  double _threshold = 80;

  @override
  void initState() {
    super.initState();
    _category = widget.categories.first;
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
        return DateTime(_start.year, _start.month + 1, _start.day)
            .subtract(const Duration(days: 1));
      case BudgetPeriod.yearly:
        return DateTime(_start.year + 1, _start.month, _start.day)
            .subtract(const Duration(days: 1));
    }
  }

  bool get _canSave => (double.tryParse(_amountController.text.trim()) ?? 0) > 0;

  void _handleSave() {
    if (!_canSave) return;
    Navigator.of(context).pop(BudgetCreate(
      categoryId: _category.id,
      amount: double.parse(_amountController.text.trim()).toStringAsFixed(2),
      period: _period,
      periodStart: _start,
      periodEnd: _computedEnd,
      alertThresholdPercent: _threshold.round(),
    ));
  }

  Future<void> _pickCategory() async {
    final picked = await showCupertinoModalPopup<Category>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text('Category', style: AppType.label),
        actions: [
          for (final category in widget.categories)
            CupertinoActionSheetAction(
              onPressed: () => Navigator.of(context).pop(category),
              child: Text(category.name, style: AppType.body),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ),
    );
    if (picked != null) setState(() => _category = picked);
  }

  Future<void> _pickStartDate() async {
    await showCupertinoModalPopup(
      context: context,
      builder: (context) => Container(
        height: 260,
        color: AppColors.paper,
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  CupertinoButton(
                    child: const Text('Done'),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              Expanded(
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.date,
                  initialDateTime: _start,
                  onDateTimeChanged: (value) => setState(() => _start = value),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static const _monthAbbr = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      decoration: const BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  Text('New Budget', style: AppType.title.copyWith(fontSize: 16)),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: _canSave ? _handleSave : null,
                    child: Text(
                      'Add',
                      style: TextStyle(
                        color: _canSave ? AppColors.copper : AppColors.slateLight,
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
                child: Text(_category.name, style: AppType.body),
              ),
              const LedgerDivider(),
              _SheetFieldRow(
                label: 'Amount',
                child: CupertinoTextField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  placeholder: '0.00',
                  prefix: Text('\$ ', style: AppType.amount(size: 15)),
                  padding: EdgeInsets.zero,
                  decoration: const BoxDecoration(),
                  style: AppType.amount(size: 15),
                  placeholderStyle: AppType.amount(size: 15, color: AppColors.slateLight),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const LedgerDivider(),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Row(
                  children: [
                    SizedBox(width: 100, child: Text('Period', style: AppType.label)),
                    Expanded(
                      child: CupertinoSlidingSegmentedControl<BudgetPeriod>(
                        backgroundColor: AppColors.paperDim,
                        thumbColor: CupertinoColors.white,
                        groupValue: _period,
                        children: {
                          BudgetPeriod.weekly: _segmentLabel('Weekly'),
                          BudgetPeriod.monthly: _segmentLabel('Monthly'),
                          BudgetPeriod.yearly: _segmentLabel('Yearly'),
                        },
                        onValueChanged: (value) {
                          if (value != null) setState(() => _period = value);
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const LedgerDivider(),
              _SheetFieldRow(
                label: 'Starts',
                onTap: _pickStartDate,
                child: Text(
                  '${_monthAbbr[_start.month - 1]} ${_start.day}, ${_start.year}',
                  style: AppType.body,
                ),
              ),
              const LedgerDivider(),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Alert threshold', style: AppType.label),
                        Text('${_threshold.round()}%',
                            style: AppType.amount(size: 13, color: AppColors.copper)),
                      ],
                    ),
                    CupertinoSlider(
                      value: _threshold,
                      min: 0,
                      max: 100,
                      divisions: 20,
                      activeColor: AppColors.copper,
                      onChanged: (value) => setState(() => _threshold = value),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _segmentLabel(String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Text(text, style: AppType.body.copyWith(fontSize: 12)),
      );
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
          SizedBox(width: 100, child: Text(label, style: AppType.label)),
          Expanded(child: child),
          if (onTap != null)
            const Icon(CupertinoIcons.chevron_right,
                size: 14, color: AppColors.slateLight),
        ],
      ),
    );
    if (onTap == null) return row;
    return CupertinoButton(padding: EdgeInsets.zero, onPressed: onTap, child: row);
  }
}