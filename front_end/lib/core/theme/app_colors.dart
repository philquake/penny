import 'package:flutter/material.dart';

@immutable
class FinanceColors extends ThemeExtension<FinanceColors> {
  final Color income;
  final Color incomeContainer;
  final Color expense;
  final Color expenseContainer;
  final Color warning;
  final Color warningContainer;
  final Color savings;
  final Color neutral;

  const FinanceColors({
    required this.income,
    required this.incomeContainer,
    required this.expense,
    required this.expenseContainer,
    required this.warning,
    required this.warningContainer,
    required this.savings,
    required this.neutral,
  });

  static const light = FinanceColors(
    income: Color(0xFF16835B),
    incomeContainer: Color(0xFFD6F5E5),
    expense: Color(0xFFC94B4B),
    expenseContainer: Color(0xFFFFE0DE),
    warning: Color(0xFFA66A00),
    warningContainer: Color(0xFFFFE7B3),
    savings: Color(0xFF087F5B),
    neutral: Color(0xFF66706A),
  );

  static const dark = FinanceColors(
    income: Color(0xFF5DDBA3),
    incomeContainer: Color(0xFF123D2E),
    expense: Color(0xFFFF8A83),
    expenseContainer: Color(0xFF54201F),
    warning: Color(0xFFF4C35F),
    warningContainer: Color(0xFF4A3608),
    savings: Color(0xFF55D6A2),
    neutral: Color(0xFFAAB4AE),
  );

  @override
  FinanceColors copyWith({
    Color? income,
    Color? incomeContainer,
    Color? expense,
    Color? expenseContainer,
    Color? warning,
    Color? warningContainer,
    Color? savings,
    Color? neutral,
  }) {
    return FinanceColors(
      income: income ?? this.income,
      incomeContainer: incomeContainer ?? this.incomeContainer,
      expense: expense ?? this.expense,
      expenseContainer: expenseContainer ?? this.expenseContainer,
      warning: warning ?? this.warning,
      warningContainer: warningContainer ?? this.warningContainer,
      savings: savings ?? this.savings,
      neutral: neutral ?? this.neutral,
    );
  }

  @override
  FinanceColors lerp(ThemeExtension<FinanceColors>? other, double t) {
    if (other is! FinanceColors) return this;

    return FinanceColors(
      income: Color.lerp(income, other.income, t) ?? income,
      incomeContainer:
          Color.lerp(incomeContainer, other.incomeContainer, t) ??
          incomeContainer,
      expense: Color.lerp(expense, other.expense, t) ?? expense,
      expenseContainer:
          Color.lerp(expenseContainer, other.expenseContainer, t) ??
          expenseContainer,
      warning: Color.lerp(warning, other.warning, t) ?? warning,
      warningContainer:
          Color.lerp(warningContainer, other.warningContainer, t) ??
          warningContainer,
      savings: Color.lerp(savings, other.savings, t) ?? savings,
      neutral: Color.lerp(neutral, other.neutral, t) ?? neutral,
    );
  }
}
