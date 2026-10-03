import 'package:flutter/cupertino.dart';
import '../models/category.dart';
import '../models/transaction_type.dart';
import '../widgets/transaction_row.dart' show categoryIcon;

import 'package:flutter/material.dart';
import '../core/theme/theme_x.dart';


/// Categories screen — grouped by type (Expense/Income), the way budgets
/// and the transaction filters both key off type already.
///
/// Default categories (`is_default: true`, `user_id: null` — seeded by
/// the backend for everyone) can't be deleted here; only a household
/// member's own custom categories can be.
class CategoriesScreen extends StatefulWidget {
  final List<Category> categories;
  final void Function(CategoryCreate) onCreate;
  final void Function(int id) onDelete;

  const CategoriesScreen({
    super.key,
    required this.categories,
    required this.onCreate,
    required this.onDelete,
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

  List<Category> _byType(TransactionType type) =>
      _categories.where((c) => c.type == type).toList()
        ..sort((a, b) => a.name.compareTo(b.name));

  Future<void> _confirmDelete(Category category) async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text('Delete "${category.name}"?'),
        content: const Text(
          'Existing transactions in this category will keep their record, '
          'but you won\'t be able to pick it for new ones.',
        ),
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
      setState(() => _categories.removeWhere((c) => c.id == category.id));
      widget.onDelete(category.id);
    }
  }

  Future<void> _showAddCategorySheet() async {
    final created = await showCupertinoModalPopup<CategoryCreate>(
      context: context,
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
        ));
      });
      widget.onCreate(created);
    }
  }

  @override
  Widget build(BuildContext context) {

    return CupertinoPageScaffold(
      backgroundColor: context.colors.surface,
      child: CustomScrollView(
        slivers: [
          CupertinoSliverNavigationBar(
            backgroundColor: context.colors.surface,
            border: null,
            largeTitle: const Text('Categories'),
            trailing: CupertinoButton(
              padding: EdgeInsets.zero,
              minimumSize: const Size(32, 32),
              onPressed: _showAddCategorySheet,
              child: Icon(
                CupertinoIcons.add_circled_solid,
                color: context.colors.primary,
                size: 28,
              ),
            ),
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
                  ),
                  const SizedBox(height: 28),
                  _CategorySection(
                    title: 'Income',
                    categories: _byType(TransactionType.income),
                    onDelete: _confirmDelete,
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

  const _CategorySection({
    required this.title,
    required this.categories,
    required this.onDelete,
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
              color: CupertinoColors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: context.colors.outlineVariant),
            ),
            child: Column(
              children: [
                for (int i = 0; i < categories.length; i++) ...[
                  _CategoryRow(
                    category: categories[i],
                    onDelete: () => onDelete(categories[i]),
                  ),
                  if (i != categories.length - 1) const Divider(indent: 56),
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

  const _CategoryRow({required this.category, required this.onDelete});

  @override
  Widget build(BuildContext context) {

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: context.colors.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Icon(categoryIcon(category.icon),
                size: 16, color: context.colors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(category.name, style: context.text.bodyMedium?.copyWith(fontSize: 14)),
          ),
          if (category.isDefault)
            Text('Default', style: context.text.bodySmall)
          else
            CupertinoButton(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              onPressed: onDelete,
              child: Icon(CupertinoIcons.minus_circle,
                  size: 20, color: context.colors.error),
            ),
        ],
      ),
    );
  }
}

/// Modal sheet for creating a category: name, type, icon.
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
                  Text('New Category', style: context.text.titleLarge?.copyWith(fontSize: 16)),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
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
              CupertinoTextField(
                controller: _nameController,
                placeholder: 'e.g. Pet Care',
                autofocus: true,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                style: context.text.bodyMedium,
                placeholderStyle: context.text.bodyMedium?.copyWith(color: context.colors.outline),
                decoration: BoxDecoration(
                  color: CupertinoColors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: context.colors.outlineVariant),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 18),
              Text('Type', style: context.text.labelMedium),
              const SizedBox(height: 6),
              CupertinoSlidingSegmentedControl<TransactionType>(
                backgroundColor: context.colors.surfaceContainerHigh,
                thumbColor: CupertinoColors.white,
                groupValue: _type,
                children: {
                  TransactionType.expense: _segmentLabel(context, 'Expense'),
                  TransactionType.income: _segmentLabel(context, 'Income'),
                },
                onValueChanged: (value) {
                  if (value != null) setState(() => _type = value);
                },
              ),
              const SizedBox(height: 18),
              Text('Icon', style: context.text.labelMedium),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (final key in _iconChoices)
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      onPressed: () => setState(() => _icon = key),
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: _icon == key
                              ? context.colors.primary.withValues(alpha:0.15)
                              : context.colors.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _icon == key
                                ? context.colors.primary
                                : const Color(0x00000000),
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Icon(categoryIcon(key),
                            size: 18, color: context.colors.primary),
                      ),
                    ),
                ],
              ),
            ],
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