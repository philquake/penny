import 'package:flutter/material.dart';

import '../core/theme/theme_x.dart';
import '../core/widgets/amount_text.dart';
import '../models/debt.dart';
import '../models/transaction_type.dart';
import '../models/transactions.dart';

/// Wallet: net worth, debt and savings as cards.
/// Debt card opens the full Debts screen; Savings card sets a goal, which
/// shows as a progress bar beneath the card.
class WalletScreen extends StatelessWidget {
  final List<Debt> debts;
  final List<Transaction> transactions;
  final double? savingsGoal;
  final Future<void> Function(double? goal) onSetGoal;
  final VoidCallback onOpenDebts;

  const WalletScreen({
    super.key,
    required this.debts,
    required this.transactions,
    required this.savingsGoal,
    required this.onSetGoal,
    required this.onOpenDebts,
  });

  double _n(String s) => double.tryParse(s) ?? 0;

  double _sum(TransactionType type) => transactions
      .where((t) => t.type == type)
      .fold(0.0, (sum, t) => sum + _n(t.amount));

  double get _totalDebt => debts.fold(0.0, (s, d) => s + _n(d.balance));
  double get _monthlyInterest =>
      debts.fold(0.0, (s, d) => s + _n(d.monthlyInterestEstimate));
  double get _savings => _sum(TransactionType.savings);

  // cash (income - expense - savings) + savings - debt
  double get _netWorth =>
      _sum(TransactionType.income) -
      _sum(TransactionType.expense) -
      _totalDebt;

  Future<void> _editGoal(BuildContext context) async {
    final result = await showModalBottomSheet<_GoalResult>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _GoalSheet(current: savingsGoal, saved: _savings),
    );
    if (result != null) await onSetGoal(result.goal);
  }

  @override
  Widget build(BuildContext context) {
    final goal = savingsGoal;

    return Scaffold(
      backgroundColor: context.colors.surface,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: context.colors.surface,
            scrolledUnderElevation: 0,
            pinned: true,
            title: const Text('Wallet'),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _WalletCard(
                    icon: Icons.account_balance_wallet_rounded,
                    label: 'Net worth',
                    amount: _netWorth.toStringAsFixed(2),
                    colorBySign: true,
                    subtitle: 'Cash + savings − debt',
                  ),
                  const SizedBox(height: 14),
                  _WalletCard(
                    icon: Icons.credit_card_rounded,
                    label: 'Debt',
                    amount: _totalDebt.toStringAsFixed(2),
                    subtitle: debts.isEmpty
                        ? 'No debts. Tap to add one.'
                        : '${debts.length} ${debts.length == 1 ? 'account' : 'accounts'}'
                            ' · ≈ \$${_monthlyInterest.toStringAsFixed(2)} interest/month',
                    subtitleColor: debts.isEmpty ? null : context.finance.expense,
                    onTap: onOpenDebts,
                  ),
                  const SizedBox(height: 14),
                  _WalletCard(
                    icon: Icons.savings_outlined,
                    label: 'Savings',
                    amount: _savings.toStringAsFixed(2),
                    subtitle: goal == null
                        ? 'Tap to set a goal'
                        : 'Goal \$${goal.toStringAsFixed(0)}',
                    onTap: () => _editGoal(context),
                  ),
                  if (goal != null && goal > 0)
                    _GoalProgress(saved: _savings, goal: goal),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WalletCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String amount;
  final String subtitle;
  final Color? subtitleColor;
  final bool colorBySign;
  final VoidCallback? onTap;

  const _WalletCard({
    required this.icon,
    required this.label,
    required this.amount,
    required this.subtitle,
    this.subtitleColor,
    this.colorBySign = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.colors.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: context.colors.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: context.colors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 19, color: context.colors.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: context.text.labelMedium),
                    const SizedBox(height: 4),
                    AmountText(
                      amount,
                      size: 26,
                      colorBySign: colorBySign,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: context.text.bodySmall?.copyWith(
                        color: subtitleColor,
                      ),
                    ),
                  ],
                ),
              ),
              if (onTap != null)
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: context.colors.outline,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GoalProgress extends StatelessWidget {
  final double saved;
  final double goal;
  const _GoalProgress({required this.saved, required this.goal});

  @override
  Widget build(BuildContext context) {
    final fraction = (saved / goal).clamp(0.0, 1.0);
    final reached = saved >= goal;

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 10, 4, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 6,
              color: context.finance.savings,
              backgroundColor: context.colors.outlineVariant,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                reached
                    ? 'Goal reached'
                    : '\$${saved.toStringAsFixed(0)} of \$${goal.toStringAsFixed(0)}',
                style: context.text.bodySmall,
              ),
              Text(
                '${(fraction * 100).round()}%',
                style: context.text.bodySmall,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// goal == null means "remove the goal". A dismissed sheet returns null
/// from showModalBottomSheet instead, so cancel never clears anything.
class _GoalResult {
  final double? goal;
  const _GoalResult(this.goal);
}

class _GoalSheet extends StatefulWidget {
  final double? current;
  final double saved;
  const _GoalSheet({required this.current, required this.saved});

  @override
  State<_GoalSheet> createState() => _GoalSheetState();
}

class _GoalSheetState extends State<_GoalSheet> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.current == null ? '' : widget.current!.toStringAsFixed(2),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _valid => (double.tryParse(_controller.text.trim()) ?? 0) > 0;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        4,
        20,
        24 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Savings goal', style: context.text.titleMedium),
          const SizedBox(height: 4),
          Text(
            'You\'ve saved \$${widget.saved.toStringAsFixed(2)} so far.',
            style: context.text.bodySmall,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Goal amount',
              prefixText: '\$ ',
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _valid
                ? () => Navigator.of(context).pop(
                      _GoalResult(double.parse(_controller.text.trim())),
                    )
                : null,
            child: const Text('Save goal'),
          ),
          if (widget.current != null)
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: context.colors.error,
              ),
              onPressed: () => Navigator.of(context).pop(const _GoalResult(null)),
              child: const Text('Remove goal'),
            ),
        ],
      ),
    );
  }
}