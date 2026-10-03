import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/theme_x.dart';

class AmountText extends StatelessWidget {
  final String value;
  final double size;
  final FontWeight weight;
  final bool colorBySign;
  final String prefix;

  const AmountText(
    this.value, {
    super.key,
    this.size = 16,
    this.weight = FontWeight.w600,
    this.colorBySign = true,
    this.prefix = '\$',
  });

  @override
  Widget build(BuildContext context) {
    final parsed = double.tryParse(value) ?? 0;
    final isNegative = parsed < 0;
    final display =
        '${isNegative ? '-' : ''}$prefix${parsed.abs().toStringAsFixed(2)}';

    final finance = context.finance;
    final color = colorBySign
        ? (isNegative ? finance.expense : finance.income)
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
