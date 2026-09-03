import 'package:flutter/cupertino.dart';
import '../models/transactions.dart';
import '../theme/app_theme.dart';

const _monthAbbr = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

IconData categoryIcon(String category) {
  switch (category) {
    case 'Groceries':
      return CupertinoIcons.bag;
    case 'Income':
      return CupertinoIcons.arrow_down_left;
    case 'Dining Out':
      return CupertinoIcons.house;
    case 'Transport':
      return CupertinoIcons.car;
    case 'Subscriptions':
      return CupertinoIcons.repeat;
    default:
      return CupertinoIcons.circle;
  }
}

/// A single ledger line: category glyph, merchant, category · date, amount.
/// Used on the Dashboard's "Recent" list and the full Transactions List.
class TransactionRow extends StatelessWidget {
  final Transaction transaction;
  final VoidCallback? onTap;

  const TransactionRow({super.key, required this.transaction, this.onTap});

  @override
  Widget build(BuildContext context) {
    final d = transaction.transactionDate;
    final dateLabel = '${_monthAbbr[d.month - 1]} ${d.day}';

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
                categoryIcon(transaction.categoryId.toString()),
                size: 16,
                color: AppColors.copperDark,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(transaction.categoryId.toString(),
                      style: AppType.body.copyWith(fontSize: 14),
                      textAlign: TextAlign.left),
                  const SizedBox(height: 2),
                  Text('${transaction.categoryId} · $dateLabel',
                      style: AppType.caption),
                ],
              ),
            ),
            AmountText(transaction.amount, size: 14),
          ],
        ),
      ),
    );
  }
}