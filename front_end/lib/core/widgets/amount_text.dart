import 'package:flutter/material.dart';
import '../theme/theme_x.dart';

class AmountText extends StatelessWidget {
  final String value;
  final double size;
  final FontWeight weight;
  final bool colorBySign;
  final String currencySymbol;

  const AmountText(
    this.value, {
    super.key,
    this.size = 16,
    this.weight = FontWeight.w600,
    this.colorBySign = true,
    this.currencySymbol = r'$',
  });

  @override
  Widget build(BuildContext context) {
    final amount = double.tryParse(value) ?? 0;
    final isNegative = amount < 0;
    final display =
        '${isNegative ? '-' : ''}$currencySymbol${amount.abs().toStringAsFixed(2)}';
    final color = colorBySign
        ? (isNegative ? context.finance.expense : context.finance.income)
        : context.colors.onSurface;

    return Text(
      display,
      style: context.text.titleMedium?.copyWith(
            color: color,
            fontSize: size,
            fontWeight: weight,
          ) ??
          TextStyle(
            fontSize: size,
            fontWeight: weight,
            color: color,
          ),
    );
  }
}
