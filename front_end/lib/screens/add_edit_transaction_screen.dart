import 'package:flutter/cupertino.dart';
import '../models/category.dart';
import '../models/transaction_type.dart';
import '../models/transactions.dart';
import '../theme/app_theme.dart';
import '../widgets/transaction_row.dart' show categoryIcon;

/// Add/Edit Transaction screen.
///
/// One screen handles both flows: pass [existing] to edit a transaction
/// (fields pre-filled, a Delete action appears), or omit it to create a
/// new one. [categories] should be the full list from GET /categories —
/// this screen filters it by the selected [TransactionType] itself, since
/// a category's type and a transaction's type are expected to match.
class AddEditTransactionScreen extends StatefulWidget {
  final List<Category> categories;
  final Transaction? existing;
  final Future<void> Function(TransactionCreate) onCreate;
  final Future<void> Function(int id, TransactionUpdate) onUpdate;
  final Future<void> Function(int id)? onDelete;

  const AddEditTransactionScreen({
    super.key,
    required this.categories,
    required this.onCreate,
    required this.onUpdate,
    this.existing,
    this.onDelete,
  });

  bool get isEditing => existing != null;

  @override
  State<AddEditTransactionScreen> createState() =>
      _AddEditTransactionScreenState();
}

class _AddEditTransactionScreenState extends State<AddEditTransactionScreen> {
  late TransactionType _type;
  late final TextEditingController _amountController;
  late final TextEditingController _descriptionController;
  late DateTime _date;
  Category? _category;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _type = existing?.type ?? TransactionType.expense;
    _amountController = TextEditingController(text: existing?.amount ?? '');
    _descriptionController =
        TextEditingController(text: existing?.description ?? '');
    _date = existing?.transactionDate ?? DateTime.now();

    if (existing != null) {
      final match = widget.categories.where((c) => c.id == existing.categoryId);
      _category = match.isNotEmpty ? match.first : null;
    } else if (_type == TransactionType.income) {
      final options = widget.categories.where((c) => c.type == _type).toList();
      final defaults = options.where((category) => category.isDefault);
      _category = defaults.isNotEmpty
          ? defaults.first
          : (options.isNotEmpty ? options.first : null);
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  List<Category> get _categoriesForType =>
      widget.categories.where((c) => c.type == _type).toList();

  double? get _parsedAmount => double.tryParse(_amountController.text.trim());

  bool get _canSave =>
      _category != null && (_parsedAmount != null && _parsedAmount! > 0);

  void _handleTypeChanged(TransactionType type) {
    setState(() {
      _type = type;
      if (type == TransactionType.income) {
        // Auto-select the seeded default income category.
        final options = widget.categories.where((c) => c.type == type).toList();
        final defaults = options.where((category) => category.isDefault);
        _category = defaults.isNotEmpty
            ? defaults.first
            : (options.isNotEmpty ? options.first : null);
      } else {
        // Expense always starts empty — no default guess.
        _category = null;
      }
    });
  }

  Future<void> _pickCategory() async {
    final options = _categoriesForType;
    if (options.isEmpty) return;

    final picked = await showCupertinoModalPopup<Category>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text('Category', style: AppType.label),
        actions: [
          for (final category in options)
            CupertinoActionSheetAction(
              onPressed: () => Navigator.of(context).pop(category),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(categoryIcon(category.icon),
                      size: 18, color: AppColors.copperDark),
                  const SizedBox(width: 8),
                  Text(category.name, style: AppType.body),
                  if (_category?.id == category.id) ...[
                    const SizedBox(width: 8),
                    const Icon(CupertinoIcons.check_mark,
                        size: 16, color: AppColors.copper),
                  ],
                ],
              ),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(context).pop(),
          isDestructiveAction: false,
          child: const Text('Cancel'),
        ),
      ),
    );

    if (picked != null) setState(() => _category = picked);
  }

  Future<void> _pickDate() async {
    await showCupertinoModalPopup(
      context: context,
      builder: (context) => Container(
        height: 300,
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
                  initialDateTime: _date,
                  maximumDate: DateTime.now(),
                  onDateTimeChanged: (value) => setState(() => _date = value),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleSave() async {
    if (!_canSave || _isSaving) return;
    final amountString = _parsedAmount!.toStringAsFixed(2);

    setState(() => _isSaving = true);

    try {
      if (widget.isEditing) {
        await widget.onUpdate(
          widget.existing!.id,
          TransactionUpdate(
            categoryId: _category!.id,
            amount: amountString,
            type: _type,
            description: _descriptionController.text.trim().isEmpty
                ? null
                : _descriptionController.text.trim(),
            transactionDate: _date,
          ),
        );
      } else {
        await widget.onCreate(
          TransactionCreate(
            categoryId: _category!.id,
            amount: amountString,
            type: _type,
            description: _descriptionController.text.trim().isEmpty
                ? null
                : _descriptionController.text.trim(),
            transactionDate: _date,
          ),
        );
      }
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      await showCupertinoDialog<void>(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('Couldn\'t save transaction'),
          content: Text(error.toString()),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _handleDelete() async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Delete transaction?'),
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

    if (confirmed == true && widget.onDelete != null) {
      await widget.onDelete!(widget.existing!.id);
      if (mounted) Navigator.of(context).pop();
    }
  }

  static const _monthAbbr = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppColors.paper,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: AppColors.paper,
        border: null,
        middle: Text(widget.isEditing ? 'Edit Transaction' : 'Add Transaction'),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _canSave && !_isSaving ? _handleSave : null,
          child: Text(
            'Save',
            style: TextStyle(
              color: _canSave ? AppColors.copper : AppColors.slateLight,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
      child: SafeArea(
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
                    ? Text('Select category',
                        style: AppType.body.copyWith(color: AppColors.slateLight))
                    : Row(
                        children: [
                          Icon(categoryIcon(_category!.icon),
                              size: 16, color: AppColors.copperDark),
                          const SizedBox(width: 8),
                          Text(_category!.name, style: AppType.body),
                        ],
                      ),
              ),
              const LedgerDivider(),
              _FieldRow(
                label: 'Date',
                onTap: _pickDate,
                child: Text(
                  '${_monthAbbr[_date.month - 1]} ${_date.day}, ${_date.year}',
                  style: AppType.body,
                ),
              ),
              const LedgerDivider(),
              _FieldRow(
                label: 'Description',
                child: CupertinoTextField(
                  controller: _descriptionController,
                  placeholder: 'Optional note',
                  padding: EdgeInsets.zero,
                  decoration: const BoxDecoration(),
                  style: AppType.body,
                  placeholderStyle:
                      AppType.body.copyWith(color: AppColors.slateLight),
                ),
              ),
              if (widget.isEditing && widget.onDelete != null) ...[
                const SizedBox(height: 36),
                SizedBox(
                  height: 46,
                  child: CupertinoButton(
                    padding: EdgeInsets.zero,
                    color: AppColors.rust.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    onPressed: _handleDelete,
                    child: Text(
                      'Delete Transaction',
                      style: AppType.body.copyWith(
                        color: AppColors.rust,
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
    return CupertinoSlidingSegmentedControl<TransactionType>(
      backgroundColor: AppColors.paperDim,
      thumbColor: CupertinoColors.white,
      groupValue: type,
      children: {
        TransactionType.expense: _label('Expense'),
        TransactionType.income: _label('Income'),
      },
      onValueChanged: (value) {
        if (value != null) onChanged(value);
      },
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(text, style: AppType.body.copyWith(fontSize: 14)),
      );
}

class _AmountField extends StatelessWidget {
  final TextEditingController controller;
  final TransactionType type;

  const _AmountField({required this.controller, required this.type});

  @override
  Widget build(BuildContext context) {
    final color =
        type == TransactionType.income ? AppColors.ledgerGreen : AppColors.rust;
    return IntrinsicWidth(
      child: CupertinoTextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        textAlign: TextAlign.center,
        prefix: Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Text('\$', style: AppType.amount(size: 34, color: color)),
        ),
        placeholder: '0.00',
        placeholderStyle: AppType.amount(size: 34, color: AppColors.slateLight),
        style: AppType.amount(size: 34, weight: FontWeight.w600, color: color),
        decoration: const BoxDecoration(),
        padding: EdgeInsets.zero,
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
            child: Text(label, style: AppType.label),
          ),
          Expanded(child: child),
          if (onTap != null)
            const Icon(CupertinoIcons.chevron_right,
                size: 15, color: AppColors.slateLight),
        ],
      ),
    );

    if (onTap == null) return row;

    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: row,
    );
  }
}