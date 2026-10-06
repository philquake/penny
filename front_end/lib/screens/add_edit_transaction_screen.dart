import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

import '../models/category.dart';
import '../models/transaction_type.dart';
import '../models/transactions.dart';
import '../services/receipt_parser.dart';
import '../core/theme/theme_x.dart';
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
  bool _isScanning = false;
  final ImagePicker _picker = ImagePicker();

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

  Future<void> _scanReceipt() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Scan receipt', style: context.text.titleMedium),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_rounded),
              title: const Text('Use camera'),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Choose photo'),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    final picked = await _picker.pickImage(source: source);
    if (picked == null) return;

    setState(() => _isScanning = true);
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);

    try {
      final image = InputImage.fromFilePath(picked.path);
      final text = await recognizer.processImage(image);
      final parsed = ReceiptTextParser.parse(text.text);

      if (!mounted) return;

      if (parsed.amount != null) {
        _amountController.text = parsed.amount!;
        _amountController.selection = TextSelection.collapsed(
          offset: _amountController.text.length,
        );
      }

      if (parsed.merchant != null &&
          _descriptionController.text.trim().isEmpty) {
        _descriptionController.text = parsed.merchant!;
      }

      if (parsed.date != null) {
        setState(() => _date = parsed.date!);
      }

      if (parsed.amount != null ||
          parsed.merchant != null ||
          parsed.date != null) {
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Receipt parsed'),
            content: Text(
              [
                if (parsed.merchant != null) 'Merchant: ${parsed.merchant}',
                if (parsed.amount != null) 'Amount: \$${parsed.amount}',
                if (parsed.date != null)
                  'Date: ${parsed.date!.month}/${parsed.date!.day}/${parsed.date!.year}',
              ].join('\n'),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (error) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Couldn\'t scan receipt'),
          content: Text(error.toString()),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isScanning = false);
      }
      recognizer.close();
    }
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
                  color: context.colors.onPrimaryContainer,
                ),
                title: Text(category.name, style: context.text.bodyMedium),
                trailing: _category?.id == category.id
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
                label: 'Receipt',
                onTap: _scanReceipt,
                child: Text(
                  _isScanning ? 'Scanning…' : 'Scan receipt',
                  style: context.text.bodyMedium?.copyWith(
                    color: _isScanning
                        ? context.colors.onSurfaceVariant
                        : context.colors.primary,
                  ),
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
    final color = type == TransactionType.income
        ? context.finance.income
        : context.colors.error;
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
