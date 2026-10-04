import 'package:flutter/material.dart';
import '../models/category.dart';
import '../models/transaction_type.dart';
import '../models/transactions.dart';
import '../widgets/transaction_row.dart';
import '../core/theme/theme_x.dart';

enum _FlowFilter { all, income, expenses }

/// Full transaction ledger: searchable, filterable by flow direction,
/// grouped into date sections the way a paper ledger would read.
///
/// Takes the real transactions/categories lists from the caller —
/// [onTransactionTap] is how the parent wires up navigating to
/// AddEditTransactionScreen pre-filled for editing.
class TransactionsScreen extends StatefulWidget {
  final List<Transaction> transactions;
  final List<Category> categories;
  final void Function(Transaction) onTransactionTap;

  const TransactionsScreen({
    super.key,
    required this.transactions,
    required this.categories,
    required this.onTransactionTap,
  });

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
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

  Map<String, List<Transaction>> get _grouped {
    final groups = <String, List<Transaction>>{};
    for (final t in _filtered) {
      final key = _sectionLabel(t.transactionDate);
      groups.putIfAbsent(key, () => []).add(t);
    }
    return groups;
  }

  String _sectionLabel(DateTime date) {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    if (date.year == now.year && date.month == now.month) {
      if (!date.isBefore(startOfWeek)) return 'This week';
      return 'Earlier this month';
    }
    const monthNames = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return '${monthNames[date.month - 1]} ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final groups = _grouped;

    return Scaffold(
      backgroundColor: context.colors.surface,
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            backgroundColor: context.colors.surface,
            scrolledUnderElevation: 0,
            title: const Text('Transactions'),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Column(
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
                        label: _segmentLabel(context, 'All'),
                      ),
                      ButtonSegment(
                        value: _FlowFilter.income,
                        label: _segmentLabel(context, 'Income'),
                      ),
                      ButtonSegment(
                        value: _FlowFilter.expenses,
                        label: _segmentLabel(context, 'Expenses'),
                      ),
                    ],
                    selected: {_filter},
                    onSelectionChanged: (selection) =>
                        setState(() => _filter = selection.first),
                  ),
                ],
              ),
            ),
          ),
          if (groups.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _EmptyState(hasQuery: _searchController.text.isNotEmpty),
            )
          else
            for (final entry in groups.entries)
              SliverMainAxisGroup(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                      child: Text(entry.key, style: context.text.labelMedium),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Container(
                        decoration: BoxDecoration(
                          color: context.colors.surfaceContainerLowest,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: context.colors.outlineVariant),
                        ),
                        child: Column(
                          children: [
                            for (int i = 0; i < entry.value.length; i++) ...[
                              Builder(builder: (context) {
                                final category = _categoryFor(entry.value[i].categoryId);
                                if (category == null) return const SizedBox.shrink();
                                return TransactionRow(
                                  transaction: entry.value[i],
                                  category: category,
                                  onTap: () => widget.onTransactionTap(entry.value[i]),
                                );
                              }),
                              if (i != entry.value.length - 1)
                                const Divider(height: 1, indent: 56),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
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
}

class _EmptyState extends StatelessWidget {
  final bool hasQuery;
  const _EmptyState({required this.hasQuery});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_rounded,
                size: 32, color: context.colors.outline),
            const SizedBox(height: 12),
            Text(
              hasQuery ? 'No matching transactions' : 'No transactions yet',
              style: context.text.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              hasQuery
                  ? 'Try a different search or filter.'
                  : 'Transactions you add will show up here.',
              style: context.text.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}