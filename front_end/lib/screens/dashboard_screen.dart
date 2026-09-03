import 'package:flutter/cupertino.dart';
import '../models/category.dart';
import '../models/transactions.dart';
import '../models/transaction_type.dart';
import '../theme/app_theme.dart';
import '../widgets/transaction_row.dart';

/// Dashboard / Home screen — the first thing a user sees after signing in.
/// Ledger-style: a running balance up top, this month's flow beneath it,
/// a quick budget snapshot, then the most recent lines in the book.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  // Mock data — replace with providers reading from the FastAPI backend.
  static const _totalBalance = 4820.16;
  static const _monthIncome = 3200.00;
  static const _monthExpenses = 1740.52;

  static final _budgets = [
    _BudgetSnapshot('Groceries', spent: 340.12, limit: 500),
    _BudgetSnapshot('Dining Out', spent: 210.40, limit: 150),
    _BudgetSnapshot('Transport', spent: 88.00, limit: 200),
  ];

  // Mock categories — replace with a provider reading GET /categories.
  static const _categories = {
    1: Category(id: 1, userId: 1, name: 'Groceries', type: TransactionType.expense, icon: 'bag', isDefault: true),
    2: Category(id: 2, userId: 1, name: 'Income', type: TransactionType.income, icon: 'arrow_down_left', isDefault: true),
    3: Category(id: 3, userId: 1, name: 'Subscriptions', type: TransactionType.expense, icon: 'repeat', isDefault: true),
    4: Category(id: 4, userId: 1, name: 'Dining Out', type: TransactionType.expense, icon: 'house', isDefault: true),
    5: Category(id: 5, userId: 1, name: 'Transport', type: TransactionType.expense, icon: 'car', isDefault: true),
  };

  static final _recentTransactions = [
    Transaction(
        id: 1, userId: 1, categoryId: 1, amount: '64.28',
        type: TransactionType.expense, description: 'Whole Foods',
        transactionDate: DateTime(2026, 9, 2), createdAt: DateTime(2026, 9, 2)),
    Transaction(
        id: 2, userId: 1, categoryId: 2, amount: '1600.00',
        type: TransactionType.income, description: 'Paycheck',
        transactionDate: DateTime(2026, 9, 1), createdAt: DateTime(2026, 9, 1)),
    Transaction(
        id: 3, userId: 1, categoryId: 3, amount: '6.00',
        type: TransactionType.expense, description: 'Tailscale',
        transactionDate: DateTime(2026, 8, 31), createdAt: DateTime(2026, 8, 31)),
    Transaction(
        id: 4, userId: 1, categoryId: 4, amount: '28.75',
        type: TransactionType.expense, description: 'Corner Diner',
        transactionDate: DateTime(2026, 8, 30), createdAt: DateTime(2026, 8, 30)),
    Transaction(
        id: 5, userId: 1, categoryId: 5, amount: '41.10',
        type: TransactionType.expense, description: 'Shell',
        transactionDate: DateTime(2026, 8, 29), createdAt: DateTime(2026, 8, 29)),
  ];

  @override
  Widget build(BuildContext context) {
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
              onPressed: () {
                // TODO: navigate to Add Transaction screen
              },
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
                    balance: _totalBalance.toString(),
                    income: _monthIncome,
                    expenses: _monthExpenses,
                  ),
                  const SizedBox(height: 32),
                  _SectionHeader(
                    title: 'Budgets this month',
                    actionLabel: 'View all',
                    onAction: () {
                      // TODO: navigate to Budgets screen
                    },
                  ),
                  const SizedBox(height: 12),
                  ..._budgets.map((b) => Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: _BudgetRow(budget: b),
                      )),
                  const SizedBox(height: 24),
                  _SectionHeader(
                    title: 'Recent',
                    actionLabel: 'View all',
                    onAction: () {
                      // TODO: navigate to Transactions List screen
                    },
                  ),
                  const SizedBox(height: 4),
                  Container(
                    decoration: BoxDecoration(
                      color: CupertinoColors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.hairline),
                    ),
                    child: Column(
                      children: [
                        for (int i = 0; i < _recentTransactions.length; i++) ...[
                          TransactionRow(
                            transaction: _recentTransactions[i],
                            // categoryId: _categories[
                            //     _recentTransactions[i].categoryId]!,
                          ),
                          if (i != _recentTransactions.length - 1)
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
  final String balance;
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
          balance,
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
        AmountText(value.toString(), size: 17, weight: FontWeight.w600, colorBySign: false),
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

class _BudgetSnapshot {
  final String category;
  final double spent;
  final double limit;
  const _BudgetSnapshot(this.category, {required this.spent, required this.limit});
  double get fraction => (spent / limit).clamp(0, 1.4);
  bool get isOver => spent > limit;
}

class _BudgetRow extends StatelessWidget {
  final _BudgetSnapshot budget;
  const _BudgetRow({required this.budget});

  @override
  Widget build(BuildContext context) {
    final barColor = budget.isOver ? AppColors.rust : AppColors.copper;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(budget.category, style: AppType.body.copyWith(fontSize: 14)),
            Text(
              '\$${budget.spent.toStringAsFixed(0)} of \$${budget.limit.toStringAsFixed(0)}',
              style: AppType.amount(
                size: 13,
                weight: FontWeight.w500,
                color: budget.isOver ? AppColors.rust : AppColors.slate,
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
                    width: constraints.maxWidth *
                        (budget.fraction > 1 ? 1 : budget.fraction),
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