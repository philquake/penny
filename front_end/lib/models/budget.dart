import 'budget_period.dart';

class BudgetCreate {
  final int categoryId;
  final String amount;
  final BudgetPeriod period;
  final DateTime periodStart;
  final DateTime periodEnd;
  final int alertThresholdPercent;

  const BudgetCreate({
    required this.categoryId,
    required this.amount,
    required this.period,
    required this.periodStart,
    required this.periodEnd,
    required this.alertThresholdPercent,
  });

  Map<String, dynamic> toJson() {
    return {
      'category_id': categoryId,
      'amount': amount,
      'period': period.value,
      'period_start': _dateOnly(periodStart),
      'period_end': _dateOnly(periodEnd),
      'alert_threshold_percent': alertThresholdPercent,
    };
  }

  static String _dateOnly(DateTime date) {
    return date.toIso8601String().split('T').first;
  }
}

class Budget {
  final int id;
  final int userId;
  final int categoryId;
  final String amount;
  final BudgetPeriod period;
  final DateTime periodStart;
  final DateTime periodEnd;
  final int alertThresholdPercent;

  const Budget({
    required this.id,
    required this.userId,
    required this.categoryId,
    required this.amount,
    required this.period,
    required this.periodStart,
    required this.periodEnd,
    required this.alertThresholdPercent,
  });

  factory Budget.fromJson(Map<String, dynamic> json) {
    return Budget(
      id: json['id'] as int,
      userId: json['user_id'] as int,
      categoryId: json['category_id'] as int,
      amount: json['amount'].toString(),
      period: BudgetPeriodExtension.fromValue(
        json['period'] as String,
      ),
      periodStart: DateTime.parse(
        json['period_start'] as String,
      ),
      periodEnd: DateTime.parse(
        json['period_end'] as String,
      ),
      alertThresholdPercent:
          json['alert_threshold_percent'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'category_id': categoryId,
      'amount': amount,
      'period': period.value,
      'period_start': _dateOnly(periodStart),
      'period_end': _dateOnly(periodEnd),
      'alert_threshold_percent': alertThresholdPercent,
    };
  }

  static String _dateOnly(DateTime date) {
    return date.toIso8601String().split('T').first;
  }
}

class BudgetStatus {
  final int budgetId;
  final String spentAmount;
  final String remainingAmount;
  final String percentageUsed;
  final String status;
  final bool thresholdCrossed;

  const BudgetStatus({
    required this.budgetId,
    required this.spentAmount,
    required this.remainingAmount,
    required this.percentageUsed,
    required this.status,
    required this.thresholdCrossed,
  });

  factory BudgetStatus.fromJson(Map<String, dynamic> json) {
    return BudgetStatus(
      budgetId: json['budget_id'] as int,
      spentAmount: json['spent_amount'].toString(),
      remainingAmount: json['remaining_amount'].toString(),
      percentageUsed: json['percentage_used'].toString(),
      status: json['status'] as String,
      thresholdCrossed: json['threshold_crossed'] as bool,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'budget_id': budgetId,
      'spent_amount': spentAmount,
      'remaining_amount': remainingAmount,
      'percentage_used': percentageUsed,
      'status': status,
      'threshold_crossed': thresholdCrossed,
    };
  }
}

