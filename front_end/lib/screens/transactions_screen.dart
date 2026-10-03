import 'package:flutter/cupertino.dart';
import '../models/category.dart';
import '../models/transaction_type.dart';
import '../models/transactions.dart';
import '../widgets/transaction_row.dart';

import 'package:flutter/material.dart';

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
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final groups = _grouped;

    return CupertinoPageScaffold(
      backgroundColor: colors.surface,
      child: CustomScrollView(
        slivers: [
          CupertinoSliverNavigationBar(
            backgroundColor: colors.surface,
            border: null,
            largeTitle: const Text('Transactions'),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  CupertinoSearchTextField(
                    controller: _searchController,
                    placeholder: 'Search description or category',
                    style: theme.textTheme.bodyMedium,
                    backgroundColor: CupertinoColors.white,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 12),
                  CupertinoSlidingSegmentedControl<_FlowFilter>(
                    backgroundColor: colors.surfaceContainerHigh,
                    thumbColor: CupertinoColors.white,
                    groupValue: _filter,
                    children: {
                      _FlowFilter.all: _segmentLabel(context, 'All'),
                      _FlowFilter.income: _segmentLabel(context,'Income'),
                      _FlowFilter.expenses: _segmentLabel(context, 'Expenses'),
                    },
                    onValueChanged: (value) {
                      if (value != null) setState(() => _filter = value);
                    },
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
                      child: Text(entry.key, style: theme.textTheme.labelMedium),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Container(
                        decoration: BoxDecoration(
                          color: CupertinoColors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: colors.outlineVariant),
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
                                const Divider(indent: 56),
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
  final theme = Theme.of(context);

  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Text(
      text,
      style: theme.textTheme.bodyMedium?.copyWith(
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
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(CupertinoIcons.doc_text_search,
                size: 32, color: colors.outline),
            const SizedBox(height: 12),
            Text(
              hasQuery ? 'No matching transactions' : 'No transactions yet',
              style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              hasQuery
                  ? 'Try a different search or filter.'
                  : 'Transactions you add will show up here.',
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}