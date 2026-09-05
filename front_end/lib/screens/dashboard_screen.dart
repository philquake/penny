import 'package:flutter/cupertino.dart';
import '../models/budget_entry.dart';
import '../models/category.dart';
import '../models/transaction_type.dart';
import '../models/transactions.dart';
import '../theme/app_theme.dart';
import '../widgets/transaction_row.dart';

/// Dashboard / Home screen — the first thing a user sees after signing in.
/// Ledger-style: a running balance up top, this month's flow beneath it,
/// a quick budget snapshot, then the most recent lines in the book.
///
/// Takes real data from the caller rather than owning any of its own —
/// totals, the "recent" slice, and category lookups are all derived here
/// from the full lists, so there's one source of truth (the providers)
/// instead of screen-local mock state.
class DashboardScreen extends StatelessWidget {
  final List<Category> categories;
  final List<Transaction> transactions;
  final List<BudgetEntry> budgetEntries;
  final VoidCallback onAddTransaction;
  final VoidCallback onViewBudgets;
  final VoidCallback onViewTransactions;

  const DashboardScreen({
    super.key,
    required this.categories,
    required this.transactions,
    required this.budgetEntries,
    required this.onAddTransaction,
    required this.onViewBudgets,
    required this.onViewTransactions,
  });

  double _amount(Transaction t) => double.tryParse(t.amount) ?? 0;

  double get _totalBalance => transactions.fold(0.0, (sum, t) {
        final a = _amount(t);
        return sum + (t.type == TransactionType.expense ? -a : a);
      });

  bool _isThisMonth(DateTime d, DateTime now) =>
      d.year == now.year && d.month == now.month;

  double get _monthIncome {
    final now = DateTime.now();
    return transactions
        .where((t) => t.type == TransactionType.income && _isThisMonth(t.transactionDate, now))
        .fold(0.0, (sum, t) => sum + _amount(t));
  }

  double get _monthExpenses {
    final now = DateTime.now();
    return transactions
        .where((t) => t.type == TransactionType.expense && _isThisMonth(t.transactionDate, now))
        .fold(0.0, (sum, t) => sum + _amount(t));
  }

  List<Transaction> get _recent {
    final sorted = [...transactions]
      ..sort((a, b) => b.transactionDate.compareTo(a.transactionDate));
    return sorted.take(5).toList();
  }

  Category? _categoryFor(int id) {
    final match = categories.where((c) => c.id == id);
    return match.isNotEmpty ? match.first : null;
  }

  @override
  Widget build(BuildContext context) {
    final recent = _recent;

    return CupertinoPageScaffold(
      backgroundColor: AppColors.paper,
      child: CustomScrollView(
        slivers: [
          CupertinoSliverNavigationBar(
            backgroundColor: AppColors.paper,
            border: null,
            largeTitle: const Text('Penny'),
            trailing: CupertinoButton(
              padding: EdgeInsets.zero,
              minimumSize: const Size(32, 32),
              onPressed: onAddTransaction,
              child: const Icon(
                CupertinoIcons.add_circled_solid,
                color: AppColors.copper,
                size: 28,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _BalanceBlock(
                    balance: _totalBalance,
                    income: _monthIncome,
                    expenses: _monthExpenses,
                  ),
                  const SizedBox(height: 32),
                  _SectionHeader(
                    title: 'Budgets this month',
                    actionLabel: 'View all',
                    onAction: onViewBudgets,
                  ),
                  const SizedBox(height: 12),
                  if (budgetEntries.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text('No budgets set yet', style: AppType.caption),
                    )
                  else
                    ...budgetEntries.take(3).map((entry) => Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: _BudgetRow(entry: entry),
                        )),
                  const SizedBox(height: 24),
                  _SectionHeader(
                    title: 'Recent',
                    actionLabel: 'View all',
                    onAction: onViewTransactions,
                  ),
                  const SizedBox(height: 4),
                  if (recent.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Center(
                        child: Text('No transactions yet', style: AppType.caption),
                      ),
                    )
                  else
                    Container(
                      decoration: BoxDecoration(
                        color: CupertinoColors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.hairline),
                      ),
                      child: Column(
                        children: [
                          for (int i = 0; i < recent.length; i++) ...[
                            Builder(builder: (context) {
                              final category = _categoryFor(recent[i].categoryId);
                              if (category == null) return const SizedBox.shrink();
                              return TransactionRow(
                                transaction: recent[i],
                                category: category,
                              );
                            }),
                            if (i != recent.length - 1)
                              const LedgerDivider(indent: 56),
                          ],
                        ],
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

class _BalanceBlock extends StatelessWidget {
  final double balance;
  final double income;
  final double expenses;

  const _BalanceBlock({
    required this.balance,
    required this.income,
    required this.expenses,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Total balance', style: AppType.label),
        const SizedBox(height: 4),
        AmountText(
          balance.toStringAsFixed(2),
          size: 40,
          weight: FontWeight.w600,
          colorBySign: false,
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: _FlowStat(
                label: 'In this month',
                value: income,
                icon: CupertinoIcons.arrow_down_left,
                color: AppColors.ledgerGreen,
              ),
            ),
            const SizedBox(width: 12),
            Container(width: 1, height: 34, color: AppColors.hairline),
            const SizedBox(width: 12),
            Expanded(
              child: _FlowStat(
                label: 'Out this month',
                value: expenses,
                icon: CupertinoIcons.arrow_up_right,
                color: AppColors.rust,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _FlowStat extends StatelessWidget {
  final String label;
  final double value;
  final IconData icon;
  final Color color;

  const _FlowStat({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
            Text(label, style: AppType.caption),
          ],
        ),
        const SizedBox(height: 4),
        AmountText(value.toStringAsFixed(2),
            size: 17, weight: FontWeight.w600, colorBySign: false),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String actionLabel;
  final VoidCallback onAction;

  const _SectionHeader({
    required this.title,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: AppType.title.copyWith(fontSize: 17)),
        CupertinoButton(
          padding: EdgeInsets.zero,
          minimumSize: Size.zero,
          onPressed: onAction,
          child: Text(
            actionLabel,
            style: AppType.body.copyWith(color: AppColors.copper, fontSize: 13),
          ),
        ),
      ],
    );
  }
}

class _BudgetRow extends StatelessWidget {
  final BudgetEntry entry;
  const _BudgetRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    final spent = double.tryParse(entry.status.spentAmount) ?? 0;
    final limit = double.tryParse(entry.budget.amount) ?? 1;
    final fraction = limit > 0 ? (spent / limit).clamp(0, 1.4) : 0.0;
    final isOver = entry.status.status == 'exceeded';
    final barColor = isOver ? AppColors.rust : AppColors.copper;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(entry.category.name, style: AppType.body.copyWith(fontSize: 14)),
            Text(
              '\$${spent.toStringAsFixed(0)} of \$${limit.toStringAsFixed(0)}',
              style: AppType.amount(
                size: 13,
                weight: FontWeight.w500,
                color: isOver ? AppColors.rust : AppColors.slate,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Stack(
                children: [
                  Container(height: 5, color: AppColors.hairline),
                  Container(
                    height: 5,
                    width: constraints.maxWidth * fraction,
                    color: barColor,
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}