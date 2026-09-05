import 'package:flutter/cupertino.dart';
import '../models/category.dart';
import '../models/transactions.dart';
import '../models/transaction_type.dart';
import '../theme/app_theme.dart';

const _monthAbbr = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// Maps a Category's icon key (e.g. 'bag', 'car') to a Cupertino glyph.
/// Falls back to a generic circle for unrecognized/missing keys so a new
/// category never breaks the UI.
IconData categoryIcon(String? iconKey) {
  switch (iconKey) {
    case 'bag':
      return CupertinoIcons.bag;
    case 'arrow_down_left':
      return CupertinoIcons.arrow_down_left;
    case 'house':
      return CupertinoIcons.house;
    case 'car':
      return CupertinoIcons.car;
    case 'repeat':
      return CupertinoIcons.repeat;
    default:
      return CupertinoIcons.circle;
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
    final signedAmount =
        transaction.type == TransactionType.expense ? -magnitude : magnitude;

    final title = (transaction.description?.trim().isNotEmpty ?? false)
        ? transaction.description!
        : category.name;

    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      onPressed: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: AppColors.paperDim,
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Icon(
                categoryIcon(category.icon),
                size: 16,
                color: AppColors.copperDark,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppType.body.copyWith(fontSize: 14)),
                  const SizedBox(height: 2),
                  Text('${category.name} · $dateLabel', style: AppType.caption),
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