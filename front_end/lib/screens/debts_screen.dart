import 'package:flutter/material.dart';

import '../core/theme/theme_x.dart';
import '../core/widgets/amount_text.dart';
import '../models/debt.dart';

class DebtsScreen extends StatelessWidget {
  final List<Debt> debts;
  final void Function(DebtCreate) onCreate;
  final void Function(Debt) onOpen;
  final Future<PlanResult> Function(String extra, String strategy) onPlan;

  const DebtsScreen({
    super.key,
    required this.debts,
    required this.onCreate,
    required this.onOpen,
    required this.onPlan,
  });

  double _n(String s) => double.tryParse(s) ?? 0;

  Future<void> _add(BuildContext context) async {
    final created = await showModalBottomSheet<DebtCreate>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _AddDebtSheet(),
    );
    if (created != null) onCreate(created);
  }

  @override
  Widget build(BuildContext context) {
    final totalOwed = debts.fold(0.0, (s, d) => s + _n(d.balance));
    final monthlyInterest =
        debts.fold(0.0, (s, d) => s + _n(d.monthlyInterestEstimate));

    return Scaffold(
      backgroundColor: context.colors.surface,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: context.colors.surface,
            scrolledUnderElevation: 0,
            pinned: true,
            title: const Text('Debts'),
            actions: [
              IconButton(
                onPressed: () => _add(context),
                icon: Icon(Icons.add_circle_rounded,
                    color: context.colors.primary, size: 32),
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Total owed', style: context.text.labelMedium),
                  const SizedBox(height: 4),
                  AmountText(totalOwed.toStringAsFixed(2),
                      size: 36, colorBySign: false),
                  const SizedBox(height: 6),
                  Text(
                    '≈ \$${monthlyInterest.toStringAsFixed(2)} interest per month',
                    style: context.text.bodySmall
                        ?.copyWith(color: context.finance.expense),
                  ),
                  const SizedBox(height: 16),
                  if (debts.length > 1)
                    OutlinedButton.icon(
                      onPressed: () => showModalBottomSheet<void>(
                        context: context,
                        isScrollControlled: true,
                        builder: (_) => _PlanSheet(onPlan: onPlan),
                      ),
                      icon: const Icon(Icons.trending_down_rounded, size: 18),
                      label: const Text('Payoff plan'),
                    ),
                  const SizedBox(height: 20),
                  if (debts.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 48),
                      child: Center(
                        child: Text(
                          'No cards or loans yet.\nTap + to add one.',
                          textAlign: TextAlign.center,
                          style: context.text.bodySmall,
                        ),
                      ),
                    ),
                  for (final d in debts)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _DebtCard(debt: d, onTap: () => onOpen(d)),
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

class _DebtCard extends StatelessWidget {
  final Debt debt;
  final VoidCallback onTap;
  const _DebtCard({required this.debt, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isCard = debt.kind == DebtKind.creditCard;
    final util = double.tryParse(debt.utilizationPercent ?? '');
    final hot = util != null && util >= 30;
    final due = debt.nextDueDate;

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: context.colors.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(isCard ? Icons.credit_card_rounded : Icons.account_balance_rounded,
                    size: 18, color: context.colors.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(debt.name,
                          style: context.text.bodyMedium?.copyWith(
                              fontSize: 15, fontWeight: FontWeight.w600)),
                      Text('${debt.kind.label} · ${debt.apr}% APR',
                          style: context.text.bodySmall),
                    ],
                  ),
                ),
                AmountText(debt.balance, colorBySign: false),
              ],
            ),
            if (isCard && util != null) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: (util / 100).clamp(0.0, 1.0),
                  minHeight: 6,
                  color: hot ? context.finance.expense : context.colors.primary,
                  backgroundColor: context.colors.outlineVariant,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${util.toStringAsFixed(0)}% of \$${debt.creditLimit} limit'
                '${hot ? ' · aim for under 30%' : ''}',
                style: context.text.bodySmall,
              ),
            ],
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Min \$${debt.minimumPayment}', style: context.text.bodySmall),
                if (due != null)
                  Text('Due ${due.month}/${due.day}', style: context.text.bodySmall),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AddDebtSheet extends StatefulWidget {
  const _AddDebtSheet();
  @override
  State<_AddDebtSheet> createState() => _AddDebtSheetState();
}

class _AddDebtSheetState extends State<_AddDebtSheet> {
  final _name = TextEditingController();
  final _balance = TextEditingController();
  final _apr = TextEditingController();
  final _min = TextEditingController();
  final _limit = TextEditingController();
  final _dueDay = TextEditingController();
  DebtKind _kind = DebtKind.creditCard;

  @override
  void dispose() {
    for (final c in [_name, _balance, _apr, _min, _limit, _dueDay]) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _canSave =>
      _name.text.trim().isNotEmpty &&
      double.tryParse(_balance.text) != null &&
      double.tryParse(_apr.text) != null;

  void _save() {
    final dueDay = int.tryParse(_dueDay.text);
    final limit = double.tryParse(_limit.text);
    Navigator.of(context).pop(
      DebtCreate(
        name: _name.text.trim(),
        kind: _kind,
        openingBalance: double.parse(_balance.text).toStringAsFixed(2),
        apr: double.parse(_apr.text).toStringAsFixed(3),
        minimumPayment:
            (double.tryParse(_min.text) ?? 0).toStringAsFixed(2),
        creditLimit: _kind == DebtKind.creditCard && limit != null
            ? limit.toStringAsFixed(2)
            : null,
        dueDay: dueDay != null && dueDay >= 1 && dueDay <= 31 ? dueDay : null,
        startDate: DateTime.now(),
      ),
    );
  }

  Widget _field(String label, TextEditingController c,
      {bool number = true, String? prefix}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c,
        keyboardType: number
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
        decoration: InputDecoration(labelText: label, prefixText: prefix),
        onChanged: (_) => setState(() {}),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
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
                      child: const Text('Cancel')),
                  Text('New Debt', style: context.text.titleLarge?.copyWith(fontSize: 16)),
                  TextButton(
                      onPressed: _canSave ? _save : null,
                      child: const Text('Add')),
                ],
              ),
              const SizedBox(height: 12),
              SegmentedButton<DebtKind>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: DebtKind.creditCard, label: Text('Credit card')),
                  ButtonSegment(value: DebtKind.loan, label: Text('Loan')),
                ],
                selected: {_kind},
                onSelectionChanged: (s) => setState(() => _kind = s.first),
              ),
              const SizedBox(height: 16),
              _field('Name (e.g. Visa, Car loan)', _name, number: false),
              _field('Current balance', _balance, prefix: '\$ '),
              _field('APR %', _apr),
              _field('Minimum monthly payment', _min, prefix: '\$ '),
              if (_kind == DebtKind.creditCard)
                _field('Credit limit', _limit, prefix: '\$ '),
              _field('Due day of month (1-31)', _dueDay),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlanSheet extends StatefulWidget {
  final Future<PlanResult> Function(String extra, String strategy) onPlan;
  const _PlanSheet({required this.onPlan});
  @override
  State<_PlanSheet> createState() => _PlanSheetState();
}

class _PlanSheetState extends State<_PlanSheet> {
  final _extra = TextEditingController(text: '0');
  String _strategy = 'avalanche';
  PlanResult? _result;
  bool _loading = false;

  @override
  void dispose() {
    _extra.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    setState(() => _loading = true);
    try {
      final r = await widget.onPlan(
        (double.tryParse(_extra.text) ?? 0).toStringAsFixed(2),
        _strategy,
      );
      if (mounted) setState(() => _result = r);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = _result;
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 8, 20, 24 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Payoff plan', style: context.text.titleMedium),
          const SizedBox(height: 12),
          SegmentedButton<String>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: 'avalanche', label: Text('Avalanche')),
              ButtonSegment(value: 'snowball', label: Text('Snowball')),
            ],
            selected: {_strategy},
            onSelectionChanged: (s) => setState(() => _strategy = s.first),
          ),
          const SizedBox(height: 4),
          Text(
            _strategy == 'avalanche'
                ? 'Highest APR first: the least total interest.'
                : 'Smallest balance first: quicker wins.',
            style: context.text.bodySmall,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _extra,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
                labelText: 'Extra per month on top of minimums', prefixText: '\$ '),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _loading ? null : _run,
            child: Text(_loading ? 'Calculating…' : 'Calculate'),
          ),
          if (r != null) ...[
            const SizedBox(height: 16),
            if (!r.payable)
              Text('This budget never clears the debts. Raise the extra amount.',
                  style: TextStyle(color: context.finance.expense))
            else ...[
              Text('Debt-free in ${r.months} months', style: context.text.titleMedium),
              Text('Total interest: \$${r.totalInterest}', style: context.text.bodyMedium),
              const SizedBox(height: 8),
              for (final step in r.order)
                Text('• $step', style: context.text.bodySmall),
            ],
          ],
        ],
      ),
    );
  }
}