enum BudgetPeriod {
  weekly,
  monthly,
  yearly,
  custom,
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
      case BudgetPeriod.custom:
        return 'custom';
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
      case 'custom':
        return BudgetPeriod.custom;
      default:
        throw ArgumentError(
          'Unknown budget period: $value',
        );
    }
  }
}

