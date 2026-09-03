import 'package:flutter/cupertino.dart';
import '../models/category.dart';
import '../models/transactions.dart';
import '../models/transaction_type.dart';
import '../theme/app_theme.dart';
import '../widgets/transaction_row.dart';

enum _FlowFilter { all, income, expenses }

/// Full transaction ledger: searchable, filterable by flow direction,
/// grouped into date sections the way a paper ledger would read.
class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  final _searchController = TextEditingController();
  _FlowFilter _filter = _FlowFilter.all;

  // Mock categories -- replace with a provider reading GET /categories.
  static const _categories = {
    1: Category(id: 1, userId: 1, name: 'Groceries', type: TransactionType.expense, icon: 'bag', isDefault: true),
    2: Category(id: 2, userId: 1, name: 'Income', type: TransactionType.income, icon: 'bag', isDefault: true),
    3: Category(id: 3, userId: 1, name: 'Subscriptions', type: TransactionType.expense, icon: 'bag', isDefault: true),
    4: Category(id: 4, userId: 1, name: 'Dining Out', type: TransactionType.expense, icon: 'bag', isDefault: true),
    5: Category(id: 5, userId: 1, name: 'Transport', type: TransactionType.expense, icon: 'bag', isDefault: true),
  };

  // Mock data -- replace with a provider backed by GET /transactions.
  static final _all = [
    Transaction(id: 1, userId: 1, categoryId: 1, amount: '64.28', type: TransactionType.expense, description: 'Whole Foods', transactionDate: DateTime(2026, 9, 2), createdAt: DateTime(2026, 9, 2)),
    Transaction(id: 2, userId: 1, categoryId: 2, amount: '1600.00', type: TransactionType.income, description: 'Paycheck', transactionDate: DateTime(2026, 9, 1), createdAt: DateTime(2026, 9, 1)),
    Transaction(id: 3, userId: 1, categoryId: 3, amount: '6.00', type: TransactionType.expense, description: 'Tailscale', transactionDate: DateTime(2026, 8, 31), createdAt: DateTime(2026, 8, 31)),
    Transaction(id: 4, userId: 1, categoryId: 4, amount: '28.75', type: TransactionType.expense, description: 'Corner Diner', transactionDate: DateTime(2026, 8, 30), createdAt: DateTime(2026, 8, 30)),
    Transaction(id: 5, userId: 1, categoryId: 5, amount: '41.10', type: TransactionType.expense, description: 'Shell', transactionDate: DateTime(2026, 8, 29), createdAt: DateTime(2026, 8, 29)),
    Transaction(id: 6, userId: 1, categoryId: 1, amount: '52.40', type: TransactionType.expense, description: "Trader Joe's", transactionDate: DateTime(2026, 8, 29), createdAt: DateTime(2026, 8, 29)),
    Transaction(id: 7, userId: 1, categoryId: 2, amount: '400.00', type: TransactionType.income, description: 'Freelance invoice', transactionDate: DateTime(2026, 8, 26), createdAt: DateTime(2026, 8, 26)),
    Transaction(id: 8, userId: 1, categoryId: 5, amount: '89.00', type: TransactionType.expense, description: 'Amtrak', transactionDate: DateTime(2026, 8, 22), createdAt: DateTime(2026, 8, 22)),
    Transaction(id: 9, userId: 1, categoryId: 3, amount: '15.49', type: TransactionType.expense, description: 'Netflix', transactionDate: DateTime(2026, 8, 20), createdAt: DateTime(2026, 8, 20)),
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Transaction> get _filtered {
    final query = _searchController.text.trim().toLowerCase();
    return _all.where((t) {
      final matchesFlow = switch (_filter) {
        _FlowFilter.all => true,
        _FlowFilter.income => t.type == TransactionType.income,
        _FlowFilter.expenses => t.type == TransactionType.expense,
      };
      final category = _categories[t.categoryId];
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
    final now = DateTime(2026, 9, 3); // matches conversation's current date
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

    return CupertinoPageScaffold(
      backgroundColor: AppColors.paper,
      child: CustomScrollView(
        slivers: [
          CupertinoSliverNavigationBar(
            backgroundColor: AppColors.paper,
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
                    style: AppType.body,
                    backgroundColor: CupertinoColors.white,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 12),
                  CupertinoSlidingSegmentedControl<_FlowFilter>(
                    backgroundColor: AppColors.paperDim,
                    thumbColor: CupertinoColors.white,
                    groupValue: _filter,
                    children: {
                      _FlowFilter.all: _segmentLabel('All'),
                      _FlowFilter.income: _segmentLabel('Income'),
                      _FlowFilter.expenses: _segmentLabel('Expenses'),
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
                      child: Text(entry.key, style: AppType.label),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Container(
                        decoration: BoxDecoration(
                          color: CupertinoColors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.hairline),
                        ),
                        child: Column(
                          children: [
                            for (int i = 0; i < entry.value.length; i++) ...[
                              TransactionRow(
                                transaction: entry.value[i],
                                    // _categories[entry.value[i].categoryId]!,
                                onTap: () {
                                  // TODO: navigate to Add/Edit Transaction
                                  // pre-filled with entry.value[i]
                                },
                              ),
                              if (i != entry.value.length - 1)
                                const LedgerDivider(indent: 56),
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

  Widget _segmentLabel(String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Text(text, style: AppType.body.copyWith(fontSize: 13)),
      );
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
            const Icon(CupertinoIcons.doc_text_search,
                size: 32, color: AppColors.slateLight),
            const SizedBox(height: 12),
            Text(
              hasQuery ? 'No matching transactions' : 'No transactions yet',
              style: AppType.body.copyWith(fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              hasQuery
                  ? 'Try a different search or filter.'
                  : 'Transactions you add will show up here.',
              style: AppType.caption,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}