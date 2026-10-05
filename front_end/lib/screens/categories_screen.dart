import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

import '../models/category.dart';
import '../models/transaction_type.dart';
import '../widgets/transaction_row.dart' show categoryIcon;
import '../core/widgets/category_color_picker.dart';
import '../core/theme/chart_colors.dart';
import '../core/theme/theme_x.dart';

/// Categories screen — grouped by type (Expense/Income), the way budgets
/// and the transaction filters both key off type already.
///
/// Default categories (`is_default: true`, `user_id: null` — seeded by
/// the backend for everyone) can't be deleted or recolored here; only a
/// household member's own custom categories can be.
class CategoriesScreen extends StatefulWidget {
  final List<Category> categories;
  final void Function(CategoryCreate) onCreate;
  final Future<void> Function(int id) onDelete;
  final Future<void> Function(int id, CategoryUpdate data)? onUpdate;

  const CategoriesScreen({
    super.key,
    required this.categories,
    required this.onCreate,
    required this.onDelete,
    this.onUpdate,
  });

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  late List<Category> _categories;

  @override
  void initState() {
    super.initState();
    _categories = List.of(widget.categories);
  }

  String _errorMessage(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map && data['detail'] is String) return data['detail'] as String;
    }
    return 'Something went wrong. Please try again.';
  }

  List<Category> _byType(TransactionType type) =>
      _categories.where((c) => c.type == type).toList()
        ..sort((a, b) => a.name.compareTo(b.name));

  Future<void> _changeColor(Category category) async {
    final update = widget.onUpdate;
    if (update == null) return;

    final hex = await showCategoryColorSheet(context, current: category.color);
    if (hex == null || hex == category.color) return;

    final index = _categories.indexWhere((c) => c.id == category.id);
    if (index == -1) return;
    final previous = _categories[index];

    // Optimistic: repaint immediately, roll back if the server rejects it.
    setState(() {
      _categories[index] = Category(
        id: previous.id,
        userId: previous.userId,
        name: previous.name,
        type: previous.type,
        icon: previous.icon,
        isDefault: previous.isDefault,
        color: hex,
      );
    });

    try {
      await update(category.id, CategoryUpdate(color: hex));
    } catch (error) {
      if (!mounted) return;
      setState(() {
        final i = _categories.indexWhere((c) => c.id == category.id);
        if (i != -1) _categories[i] = previous;
      });
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Can\'t change color'),
          content: Text(_errorMessage(error)),
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

  Future<void> _confirmDelete(Category category) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete "${category.name}"?'),
        content: const Text(
          'This can\'t be undone. Categories that still have transactions '
          'or budgets can\'t be deleted.',
        ),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(context).pop(false),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: context.colors.error,
            ),
            child: const Text('Delete'),
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await widget.onDelete(category.id);
      if (!mounted) return;
      setState(() => _categories.removeWhere((c) => c.id == category.id));
    } catch (error) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Can\'t delete category'),
          content: Text(_errorMessage(error)),
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

  Future<void> _showAddCategorySheet() async {
    final created = await showModalBottomSheet<CategoryCreate>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AddCategorySheet(),
    );

    if (created != null) {
      // Optimistic local id — the real id comes back from POST /categories;
      // caller should reconcile this with the server response.
      final tempId = (_categories.map((c) => c.id).fold<int>(0, (a, b) => a > b ? a : b)) + 1;
      setState(() {
        _categories.add(Category(
          id: tempId,
          userId: 1,
          name: created.name,
          type: created.type,
          icon: created.icon,
          isDefault: false,
          color: created.color,
        ));
      });
      widget.onCreate(created);
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
            title: const Text('Categories'),
            actions: [
              IconButton(
                onPressed: _showAddCategorySheet,
                icon: Icon(
                  Icons.add_circle_rounded,
                  color: context.colors.primary,
                  size: 28,
                ),
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _CategorySection(
                    title: 'Expense',
                    categories: _byType(TransactionType.expense),
                    onDelete: _confirmDelete,
                    onColorTap: widget.onUpdate == null ? null : _changeColor,
                  ),
                  const SizedBox(height: 28),
                  _CategorySection(
                    title: 'Income',
                    categories: _byType(TransactionType.income),
                    onDelete: _confirmDelete,
                    onColorTap: widget.onUpdate == null ? null : _changeColor,
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

class _CategorySection extends StatelessWidget {
  final String title;
  final List<Category> categories;
  final void Function(Category) onDelete;
  final void Function(Category)? onColorTap;

  const _CategorySection({
    required this.title,
    required this.categories,
    required this.onDelete,
    this.onColorTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: context.text.titleLarge?.copyWith(fontSize: 17)),
        const SizedBox(height: 8),
        if (categories.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text('No categories yet', style: context.text.bodySmall),
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
                for (int i = 0; i < categories.length; i++) ...[
                  _CategoryRow(
                    category: categories[i],
                    onDelete: () => onDelete(categories[i]),
                    onColorTap: onColorTap == null || categories[i].isDefault
                        ? null
                        : () => onColorTap!(categories[i]),
                  ),
                  if (i != categories.length - 1)
                    const Divider(height: 1, indent: 56),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _CategoryRow extends StatelessWidget {
  final Category category;
  final VoidCallback onDelete;
  final VoidCallback? onColorTap;

  const _CategoryRow({
    required this.category,
    required this.onDelete,
    this.onColorTap,
  });

  @override
  Widget build(BuildContext context) {
    final color =
        categoryColor(category.id, hex: category.color);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          GestureDetector(
            onTap: onColorTap,
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Icon(categoryIcon(category.icon), size: 16, color: color),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(category.name, style: context.text.bodyMedium?.copyWith(fontSize: 14)),
          ),
          if (category.isDefault)
            Text('Default', style: context.text.bodySmall)
          else
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              onPressed: onDelete,
              icon: Icon(Icons.remove_circle_outline_rounded,
                  size: 20, color: context.colors.error),
            ),
        ],
      ),
    );
  }
}

/// Modal sheet for creating a category: name, type, icon, color.
/// Icon choices are limited to the keys `categoryIcon()` actually knows
/// about — extend that mapping in transaction_row.dart before adding more.
class _AddCategorySheet extends StatefulWidget {
  @override
  State<_AddCategorySheet> createState() => _AddCategorySheetState();
}

class _AddCategorySheetState extends State<_AddCategorySheet> {
  final _nameController = TextEditingController();
  TransactionType _type = TransactionType.expense;
  String _icon = 'bag';
  String? _color;

  static const _iconChoices = ['bag', 'house', 'car', 'repeat', 'arrow_down_left'];

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  bool get _canSave => _nameController.text.trim().isNotEmpty;

  void _handleSave() {
    if (!_canSave) return;
    Navigator.of(context).pop(CategoryCreate(
      name: _nameController.text.trim(),
      type: _type,
      icon: _icon,
      color: _color,
    ));
  }

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
                    Text('New Category', style: context.text.titleLarge?.copyWith(fontSize: 16)),
                    TextButton(
                      onPressed: _canSave ? _handleSave : null,
                      child: Text(
                        'Add',
                        style: TextStyle(
                          color: _canSave ? context.colors.primary : context.colors.outline,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text('Name', style: context.text.labelMedium),
                const SizedBox(height: 6),
                TextField(
                  controller: _nameController,
                  autofocus: true,
                  style: context.text.bodyMedium,
                  decoration: InputDecoration(
                    hintText: 'e.g. Pet Care',
                    hintStyle: context.text.bodyMedium?.copyWith(color: context.colors.outline),
                    filled: true,
                    fillColor: context.colors.surfaceContainerLowest,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: context.colors.outlineVariant),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: context.colors.primary),
                    ),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 18),
                Text('Type', style: context.text.labelMedium),
                const SizedBox(height: 6),
                SegmentedButton<TransactionType>(
                  showSelectedIcon: false,
                  style: SegmentedButton.styleFrom(
                    backgroundColor: context.colors.surfaceContainerHigh,
                  ),
                  segments: [
                    ButtonSegment(
                      value: TransactionType.expense,
                      label: _segmentLabel(context, 'Expense'),
                    ),
                    ButtonSegment(
                      value: TransactionType.income,
                      label: _segmentLabel(context, 'Income'),
                    ),
                  ],
                  selected: {_type},
                  onSelectionChanged: (selection) =>
                      setState(() => _type = selection.first),
                ),
                const SizedBox(height: 18),
                Text('Icon', style: context.text.labelMedium),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    for (final key in _iconChoices)
                      InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => setState(() => _icon = key),
                        child: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: _icon == key
                                ? context.colors.primary.withValues(alpha: 0.15)
                                : context.colors.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _icon == key
                                  ? context.colors.primary
                                  : Colors.transparent,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Icon(categoryIcon(key),
                              size: 18, color: context.colors.primary),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 18),
                Text('Color', style: context.text.labelMedium),
                const SizedBox(height: 8),
                CategoryColorPicker(
                  selectedHex: _color,
                  onChanged: (hex) => setState(() => _color = hex),
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
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        text,
        style: context.text.bodyMedium?.copyWith(
          fontSize: 14,
        ),
      ),
    );
  }
}