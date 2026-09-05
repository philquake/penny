enum BudgetPeriod {
  weekly,
  monthly,
  yearly,
}

extension BudgetPeriodExtension on BudgetPeriod {
  String get value {
    switch (this) {
      case BudgetPeriod.weekly:
        return 'weekly';
      case BudgetPeriod.monthly:
        return 'monthly';
      case BudgetPeriod.yearly:
        return 'yearly';
    }
  }

  static BudgetPeriod fromValue(String value) {
    switch (value) {
      case 'weekly':
        return BudgetPeriod.weekly;
      case 'monthly':
        return BudgetPeriod.monthly;
      case 'yearly':
        return BudgetPeriod.yearly;
      default:
        throw ArgumentError(
          'Unknown budget period: $value',
        );
    }
  }
}