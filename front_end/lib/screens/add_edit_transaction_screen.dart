import 'package:flutter/material.dart';

import '../models/category.dart';
import '../models/debt.dart';
import '../models/transaction_type.dart';
import '../models/transactions.dart';
import '../core/theme/theme_x.dart';
import '../widgets/transaction_row.dart' show categoryIcon;
import '../core/theme/chart_colors.dart';

/// Add/Edit Transaction screen.
///
/// One screen handles both flows: pass [existing] to edit a transaction
/// (fields pre-filled, a Delete action appears), or omit it to create a
/// new one. [categories] should be the full list from GET /categories —
/// this screen filters it by the selected [TransactionType] itself, since
/// a category's type and a transaction's type are expected to match.
///
/// Picking the default "Debt Payment" expense category reveals a "Pay debt"
/// row; the backend turns that into a linked payment on the chosen debt.
class AddEditTransactionScreen extends StatefulWidget {
  final List<Category> categories;
  final List<Debt> debts;
  final Transaction? existing;
  final Future<void> Function(TransactionCreate) onCreate;
  final Future<void> Function(int id, TransactionUpdate) onUpdate;
  final Future<void> Function(int id)? onDelete;

  const AddEditTransactionScreen({
    super.key,
    required this.categories,
    required this.onCreate,
    required this.onUpdate,
    this.debts = const [],
    this.existing,
    this.onDelete,
  });

  bool get isEditing => existing != null;

  @override
  State<AddEditTransactionScreen> createState() =>
      _AddEditTransactionScreenState();
}

class _AddEditTransactionScreenState extends State<AddEditTransactionScreen> {
  static const _debtPaymentCategoryName = 'Debt Payment';

  late TransactionType _type;
  late final TextEditingController _amountController;
  late final TextEditingController _descriptionController;
  late DateTime _date;
  Category? _category;
  Debt? _debt;
  bool _isSaving = false;


  bool _autoSelectsDefault(TransactionType type) =>
      type == TransactionType.income || type == TransactionType.savings;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _type = existing?.type ?? TransactionType.expense;
    _amountController = TextEditingController(text: existing?.amount ?? '');
    _descriptionController = TextEditingController(
      text: existing?.description ?? '',
    );
    _date = existing?.transactionDate ?? DateTime.now();

    if (existing != null) {
      final match = widget.categories.where((c) => c.id == existing.categoryId);
      _category = match.isNotEmpty ? match.first : null;

      if (existing.debtId != null) {
        final debtMatch = widget.debts.where((d) => d.id == existing.debtId);
        _debt = debtMatch.isNotEmpty ? debtMatch.first : null;
      }
    } else if (_autoSelectsDefault(_type)) {
      _category = _defaultCategoryFor(_type);
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Category? _defaultCategoryFor(TransactionType type) {
    final options = widget.categories.where((c) => c.type == type).toList();
    final defaults = options.where((category) => category.isDefault);
    if (defaults.isNotEmpty) return defaults.first;
    return options.isNotEmpty ? options.first : null;
  }

  List<Category> get _categoriesForType =>
      widget.categories.where((c) => c.type == _type).toList();

  double? get _parsedAmount => double.tryParse(_amountController.text.trim());

  /// True when the selected category is the seeded "Debt Payment" expense
  /// category. Mirrors the backend's is_debt_payment_category check.
  bool get _isDebtPayment =>
      _type == TransactionType.expense &&
      _category != null &&
      _category!.isDefault &&
      _category!.name == _debtPaymentCategoryName;

  bool get _canSave =>
      _category != null &&
      (_parsedAmount != null && _parsedAmount! > 0) &&
      (!_isDebtPayment || _debt != null);

  void _handleTypeChanged(TransactionType type) {
    setState(() {
      _type = type;
      _debt = null;
      // Income and savings auto-select their seeded default category;
      // expense always starts empty — no default guess.
      _category = _autoSelectsDefault(type) ? _defaultCategoryFor(type) : null;
    });
  }


  Future<void> _pickCategory() async {
    final options = _categoriesForType;
    if (options.isEmpty) return;

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
            for (final category in options)
              ListTile(
                leading: Icon(
                  categoryIcon(category.icon),
                  size: 18,
                  color: categoryColor(_category!.id, hex: _category!.color),
                ),
                title: Text(category.name, style: context.text.bodyMedium),
                trailing: _category?.id == category.id
                    ? Icon(
                        Icons.check_rounded,
                        size: 16,
                        color: categoryColor(_category!.id, hex: _category!.color),
                      )
                    : null,
                onTap: () => Navigator.of(context).pop(category),
              ),
          ],
        ),
      ),
    );

    if (picked != null) {
      setState(() {
        _category = picked;
        // Leaving the Debt Payment category drops the debt selection.
        if (!_isDebtPayment) _debt = null;
      });
    }
  }

  Future<void> _pickDebt() async {
    final picked = await showModalBottomSheet<Debt>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text('Pay which debt?', style: context.text.titleMedium),
            ),
            for (final debt in widget.debts)
              ListTile(
                leading: Icon(
                  debt.kind == DebtKind.creditCard
                      ? Icons.credit_card_rounded
                      : Icons.account_balance_rounded,
                  size: 18,
                  color: context.colors.primary,
                ),
                title: Text(debt.name, style: context.text.bodyMedium),
                subtitle: Text(
                  '\$${debt.balance} owed · ${debt.apr}% APR',
                  style: context.text.bodySmall,
                ),
                trailing: _debt?.id == debt.id
                    ? Icon(
                        Icons.check_rounded,
                        size: 16,
                        color: context.colors.primary,
                      )
                    : null,
                onTap: () => Navigator.of(context).pop(debt),
              ),
          ],
        ),
      ),
    );

    if (picked != null) setState(() => _debt = picked);
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date.isAfter(now) ? now : _date,
      firstDate: DateTime(2000),
      lastDate: now,
    );

    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _handleSave() async {
    if (!_canSave || _isSaving) return;
    final amountString = _parsedAmount!.toStringAsFixed(2);
    final debtId = _isDebtPayment ? _debt!.id : null;

    setState(() => _isSaving = true);

    try {
      if (widget.isEditing) {
        await widget.onUpdate(
          widget.existing!.id,
          TransactionUpdate(
            categoryId: _category!.id,
            amount: amountString,
            type: _type,
            description: _descriptionController.text.trim(),
            transactionDate: _date,
            debtId: debtId,
          ),
        );
      } else {
        await widget.onCreate(
          TransactionCreate(
            categoryId: _category!.id,
            amount: amountString,
            type: _type,
            description: _descriptionController.text.trim(),
            transactionDate: _date,
            debtId: debtId,
          ),
        );
      }
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Couldn\'t save transaction'),
          content: Text(error.toString()),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _handleDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete transaction?'),
        content: Text(
          widget.existing?.debtId != null
              ? 'This also removes the payment from the debt\'s history. '
                  'This can\'t be undone.'
              : 'This can\'t be undone.',
        ),
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

    if (confirmed == true && widget.onDelete != null) {
      await widget.onDelete!(widget.existing!.id);
      if (mounted) Navigator.of(context).pop();
    }
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
    return Scaffold(
      backgroundColor: context.colors.surface,
      appBar: AppBar(
        backgroundColor: context.colors.surface,
        scrolledUnderElevation: 0,
        centerTitle: true,
        title: Text(widget.isEditing ? 'Edit Transaction' : 'Add Transaction'),
        leadingWidth: 80,
        leading: TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        actions: [
          TextButton(
            onPressed: _canSave && !_isSaving ? _handleSave : null,
            child: Text(
              'Save',
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
      body: SafeArea(
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          behavior: HitTestBehavior.opaque,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
            children: [
              _TypeToggle(type: _type, onChanged: _handleTypeChanged),
              const SizedBox(height: 24),
              Center(
                child: _AmountField(controller: _amountController, type: _type),
              ),
              const SizedBox(height: 32),
              _FieldRow(
                label: 'Category',
                onTap: _pickCategory,
                child: _category == null
                    ? Text(
                        'Select category',
                        style: context.text.bodyMedium?.copyWith(
                          color: context.colors.outline,
                        ),
                      )
                    : Row(
                        children: [
                          Icon(
                            categoryIcon(_category!.icon),
                            size: 16,
                            color: context.colors.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(_category!.name, style: context.text.bodyMedium),
                        ],
                      ),
              ),
              const Divider(),
              if (_isDebtPayment) ...[
                _FieldRow(
                  label: 'Pay debt',
                  onTap: widget.debts.isEmpty ? null : _pickDebt,
                  child: _debt != null
                      ? Text(
                          '${_debt!.name} · \$${_debt!.balance} owed',
                          style: context.text.bodyMedium,
                        )
                      : Text(
                          widget.debts.isEmpty
                              ? 'No debts yet. Add one from Wallet..'
                              : 'Select debt',
                          style: context.text.bodyMedium?.copyWith(
                            color: context.colors.outline,
                          ),
                        ),
                ),
                const Divider(),
              ],
              _FieldRow(
                label: 'Date',
                onTap: _pickDate,
                child: Text(
                  '${_monthAbbr[_date.month - 1]} ${_date.day}, ${_date.year}',
                  style: context.text.bodyMedium,
                ),
              ),
              const Divider(),
              _FieldRow(
                label: 'Description',
                child: TextField(
                  controller: _descriptionController,
                  style: context.text.bodyMedium,
                  decoration: InputDecoration(
                    hintText: 'Optional note',
                    hintStyle: context.text.bodyMedium?.copyWith(
                      color: context.colors.outline,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              if (widget.isEditing && widget.onDelete != null) ...[
                const SizedBox(height: 36),
                SizedBox(
                  height: 46,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      padding: EdgeInsets.zero,
                      backgroundColor: context.colors.errorContainer,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: _handleDelete,
                    child: Text(
                      'Delete Transaction',
                      style: context.text.bodyMedium?.copyWith(
                        color: context.colors.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TypeToggle extends StatelessWidget {
  final TransactionType type;
  final ValueChanged<TransactionType> onChanged;

  const _TypeToggle({required this.type, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<TransactionType>(
      showSelectedIcon: false,
      style: SegmentedButton.styleFrom(
        backgroundColor: context.colors.surfaceContainerHigh,
        textStyle: context.text.bodyMedium?.copyWith(fontSize: 14),
      ),
      segments: const [
        ButtonSegment(value: TransactionType.expense, label: Text('Expense')),
        ButtonSegment(value: TransactionType.income, label: Text('Income')),
        ButtonSegment(value: TransactionType.savings, label: Text('Savings')),
      ],
      selected: {type},
      onSelectionChanged: (selection) => onChanged(selection.first),
    );
  }
}

class _AmountField extends StatelessWidget {
  final TextEditingController controller;
  final TransactionType type;

  const _AmountField({required this.controller, required this.type});

  @override
  Widget build(BuildContext context) {
    final color = switch (type) {
      TransactionType.income => context.finance.income,
      TransactionType.savings => context.finance.savings,
      _ => context.colors.error,
    };
    return IntrinsicWidth(
      child: TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        textAlign: TextAlign.center,
        style: context.text.displaySmall?.copyWith(color: color),
        decoration: InputDecoration(
          prefix: Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              '\$',
              style: context.text.displaySmall?.copyWith(color: color),
            ),
          ),
          hintText: '0.00',
          hintStyle: context.text.displaySmall?.copyWith(
            color: context.colors.outline,
          ),
          border: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.zero,
        ),
      ),
    );
  }
}

class _FieldRow extends StatelessWidget {
  final String label;
  final Widget child;
  final VoidCallback? onTap;

  const _FieldRow({required this.label, required this.child, this.onTap});

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
              size: 15,
              color: context.colors.outline,
            ),
        ],
      ),
    );

    if (onTap == null) return row;

    return InkWell(onTap: onTap, child: row);
  }
}