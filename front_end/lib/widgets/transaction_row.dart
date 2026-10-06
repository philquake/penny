import 'package:flutter/material.dart';

import '../models/category.dart';
import '../models/transactions.dart';
import '../models/transaction_type.dart';
import '../core/widgets/amount_text.dart';
import '../core/theme/theme_x.dart';

const _monthAbbr = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// Maps a Category's icon key (e.g. 'bag', 'car') to a Material glyph.
/// Falls back to a generic circle for unrecognized/missing keys so a new
/// category never breaks the UI.
IconData categoryIcon(String? iconKey) {
  switch (iconKey) {
    case 'bag':
      return Icons.shopping_bag_outlined;
    case 'arrow_down_left':
      return Icons.south_west_rounded;
    case 'house':
      return Icons.home_outlined;
    case 'car':
      return Icons.directions_car_outlined;
    case 'repeat':
      return Icons.repeat_rounded;
    default:
      return Icons.circle_outlined;
  }
}

/// A single ledger line: category glyph, description (or category name as
/// fallback), category · date, amount.
///
/// Takes the resolved [Category] rather than looking it up itself — the
/// caller (screen) owns the id -> Category map, keeping this widget a pure
/// display component with no data-layer knowledge.
class TransactionRow extends StatelessWidget {
  final Transaction transaction;
  final Category category;
  final VoidCallback? onTap;

  const TransactionRow({
    super.key,
    required this.transaction,
    required this.category,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final d = transaction.transactionDate;
    final dateLabel = '${_monthAbbr[d.month - 1]} ${d.day}';

    // amount is always a positive Decimal-as-string from the backend;
    // sign for display comes from `type`, not the raw value.
    final magnitude = double.tryParse(transaction.amount) ?? 0;
    final signedAmount = transaction.type == TransactionType.expense
        ? -magnitude
        : magnitude;

    final title = (transaction.description?.trim().isNotEmpty ?? false)
        ? transaction.description!
        : category.name;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
              child: Icon(
                categoryIcon(category.icon),
                size: 16,
                color: context.colors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: context.text.bodyMedium?.copyWith(fontSize: 14),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${category.name} · $dateLabel',
                    style: context.text.bodySmall,
                  ),
                ],
              ),
            ),
            AmountText(signedAmount.toStringAsFixed(2), size: 14),
          ],
        ),
      ),
    );
  }
}
