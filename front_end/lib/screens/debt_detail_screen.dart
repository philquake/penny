import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/theme_x.dart';
import '../core/widgets/amount_text.dart';
import '../models/debt.dart';
import '../providers/data_providers.dart';

class DebtDetailScreen extends ConsumerStatefulWidget {
  final Debt debt;
  const DebtDetailScreen({super.key, required this.debt});
  @override
  ConsumerState<DebtDetailScreen> createState() => _DebtDetailScreenState();
}

class _DebtDetailScreenState extends ConsumerState<DebtDetailScreen> {
  List<DebtEntry> _entries = [];
  PayoffResult? _payoff;
  final _calc = TextEditingController();
  bool _calculating = false;

  @override
  void initState() {
    super.initState();
    _calc.text = widget.debt.minimumPayment;
    _loadEntries();
  }

  @override
  void dispose() {
    _calc.dispose();
    super.dispose();
  }

  Future<void> _loadEntries() async {
    final list = await ref.read(debtsRepositoryProvider).entries(widget.debt.id);
    if (mounted) setState(() => _entries = list);
  }

  Future<void> _runPayoff() async {
    final payment = double.tryParse(_calc.text);
    if (payment == null || payment <= 0) return;
    setState(() => _calculating = true);
    try {
      final r = await ref
          .read(debtsRepositoryProvider)
          .payoff(widget.debt.id, payment.toStringAsFixed(2));
      if (mounted) setState(() => _payoff = r);
    } finally {
      if (mounted) setState(() => _calculating = false);
    }
  }

  Future<void> _logEntry() async {
    final amount = TextEditingController();
    var type = DebtEntryType.payment;
    final data = await showDialog<DebtEntryCreate>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('Log activity'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SegmentedButton<DebtEntryType>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: DebtEntryType.payment, label: Text('Payment')),
                  ButtonSegment(value: DebtEntryType.charge, label: Text('Charge')),
                  ButtonSegment(value: DebtEntryType.fee, label: Text('Fee')),
                ],
                selected: {type},
                onSelectionChanged: (s) => setLocal(() => type = s.first),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amount,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Amount', prefixText: '\$ '),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel')),
            TextButton(
              onPressed: () {
                final v = double.tryParse(amount.text);
                if (v == null || v <= 0) return;
                Navigator.of(context).pop(DebtEntryCreate(
                  type: type,
                  amount: v.toStringAsFixed(2),
                  entryDate: DateTime.now(),
                ));
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    amount.dispose();
    if (data == null) return;
    await ref.read(debtsProvider.notifier).addEntry(widget.debt.id, data);
    await _loadEntries();
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete "${widget.debt.name}"?'),
        content: const Text('This removes its full history and can\'t be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel')),
          TextButton(
              style: TextButton.styleFrom(foregroundColor: context.colors.error),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(debtsProvider.notifier).delete(widget.debt.id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    // Re-read from the provider so the balance updates after logging an entry.
    final live = ref.watch(debtsProvider).asData?.value
            .where((d) => d.id == widget.debt.id)
            .firstOrNull ??
        widget.debt;
    final p = _payoff;

    return Scaffold(
      appBar: AppBar(
        title: Text(live.name),
        actions: [
          IconButton(
              onPressed: _delete,
              icon: Icon(Icons.delete_outline_rounded, color: context.colors.error)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _logEntry,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Log activity'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
        children: [
          Text('Balance', style: context.text.labelMedium),
          AmountText(live.balance, size: 36, colorBySign: false),
          const SizedBox(height: 4),
          Text(
            '${live.apr}% APR · ≈ \$${live.monthlyInterestEstimate} interest/month',
            style: context.text.bodySmall?.copyWith(color: context.finance.expense),
          ),
          const SizedBox(height: 28),
          Text('Payoff calculator', style: context.text.titleMedium),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _calc,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                      labelText: 'Monthly payment', prefixText: '\$ '),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size(88, 48)),
                onPressed: _calculating ? null : _runPayoff,
                child: const Text('Go'),
              ),
            ],
          ),
          if (p != null) ...[
            const SizedBox(height: 12),
            if (!p.payable)
              Text(
                'That payment doesn\'t cover the monthly interest, so the balance '
                'never shrinks. Pay more than \$${live.monthlyInterestEstimate}.',
                style: TextStyle(color: context.finance.expense),
              )
            else
              Text(
                'Paid off in ${p.months} months '
                '(${p.payoffDate?.month}/${p.payoffDate?.year}), '
                'paying \$${p.totalInterest} in interest.',
                style: context.text.bodyMedium,
              ),
          ],
          const SizedBox(height: 28),
          Text('History', style: context.text.titleMedium),
          const SizedBox(height: 8),
          if (_entries.isEmpty)
            Text('No activity yet.', style: context.text.bodySmall),
          for (final e in _entries)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(e.type.name[0].toUpperCase() + e.type.name.substring(1)),
              subtitle: Text(
                  '${e.entryDate.month}/${e.entryDate.day}/${e.entryDate.year}'
                  '${e.note != null ? ' · ${e.note}' : ''}'),
              trailing: Text(
                '${e.type == DebtEntryType.payment ? '-' : '+'}\$${e.amount}',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: e.type == DebtEntryType.payment
                      ? context.finance.income
                      : context.finance.expense,
                ),
              ),
            ),
        ],
      ),
    );
  }
}