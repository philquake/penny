enum DebtKind { creditCard, loan }

extension DebtKindX on DebtKind {
  String get value => this == DebtKind.creditCard ? 'credit_card' : 'loan';
  String get label => this == DebtKind.creditCard ? 'Credit card' : 'Loan';
  static DebtKind fromValue(String v) =>
      v == 'credit_card' ? DebtKind.creditCard : DebtKind.loan;
}

enum DebtEntryType { charge, payment, interest, fee }

class Debt {
  final int id;
  final String name;
  final DebtKind kind;
  final String balance;
  final String apr;
  final String minimumPayment;
  final String? creditLimit;
  final String? utilizationPercent;
  final DateTime? nextDueDate;
  final String monthlyInterestEstimate;

  const Debt({
    required this.id,
    required this.name,
    required this.kind,
    required this.balance,
    required this.apr,
    required this.minimumPayment,
    required this.creditLimit,
    required this.utilizationPercent,
    required this.nextDueDate,
    required this.monthlyInterestEstimate,
  });

  factory Debt.fromJson(Map<String, dynamic> json) => Debt(
    id: json['id'] as int,
    name: json['name'] as String,
    kind: DebtKindX.fromValue(json['kind'] as String),
    balance: json['balance'].toString(),
    apr: json['apr'].toString(),
    minimumPayment: json['minimum_payment'].toString(),
    creditLimit: json['credit_limit']?.toString(),
    utilizationPercent: json['utilization_percent']?.toString(),
    nextDueDate: json['next_due_date'] == null
        ? null
        : DateTime.parse(json['next_due_date'] as String),
    monthlyInterestEstimate: json['monthly_interest_estimate'].toString(),
  );
}

class DebtCreate {
  final String name;
  final DebtKind kind;
  final String openingBalance;
  final String apr;
  final String minimumPayment;
  final String? creditLimit;
  final int? dueDay;
  final DateTime startDate;

  const DebtCreate({
    required this.name,
    required this.kind,
    required this.openingBalance,
    required this.apr,
    required this.minimumPayment,
    this.creditLimit,
    this.dueDay,
    required this.startDate,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'kind': kind.value,
    'opening_balance': openingBalance,
    'apr': apr,
    'minimum_payment': minimumPayment,
    'credit_limit': creditLimit,
    'due_day': dueDay,
    'start_date': startDate.toIso8601String().split('T').first,
  };
}

class DebtEntry {
  final int id;
  final DebtEntryType type;
  final String amount;
  final DateTime entryDate;
  final String? note;

  const DebtEntry({
    required this.id,
    required this.type,
    required this.amount,
    required this.entryDate,
    required this.note,
  });

  factory DebtEntry.fromJson(Map<String, dynamic> json) => DebtEntry(
    id: json['id'] as int,
    type: DebtEntryType.values.byName(json['type'] as String),
    amount: json['amount'].toString(),
    entryDate: DateTime.parse(json['entry_date'] as String),
    note: json['note'] as String?,
  );
}

class DebtEntryCreate {
  final DebtEntryType type;
  final String amount;
  final DateTime entryDate;
  final String? note;

  const DebtEntryCreate({
    required this.type,
    required this.amount,
    required this.entryDate,
    this.note,
  });

  Map<String, dynamic> toJson() => {
    'type': type.name,
    'amount': amount,
    'entry_date': entryDate.toIso8601String().split('T').first,
    'note': note,
  };
}

class PayoffResult {
  final bool payable;
  final int? months;
  final String totalInterest;
  final DateTime? payoffDate;

  const PayoffResult({
    required this.payable,
    required this.months,
    required this.totalInterest,
    required this.payoffDate,
  });

  factory PayoffResult.fromJson(Map<String, dynamic> json) => PayoffResult(
    payable: json['payable'] as bool,
    months: json['months'] as int?,
    totalInterest: json['total_interest'].toString(),
    payoffDate: json['payoff_date'] == null
        ? null
        : DateTime.parse(json['payoff_date'] as String),
  );
}

class PlanResult {
  final String strategy;
  final bool payable;
  final int? months;
  final String? totalInterest;
  final List<String> order;

  const PlanResult({
    required this.strategy,
    required this.payable,
    required this.months,
    required this.totalInterest,
    required this.order,
  });

  factory PlanResult.fromJson(Map<String, dynamic> json) => PlanResult(
    strategy: json['strategy'] as String,
    payable: json['payable'] as bool,
    months: json['months'] as int?,
    totalInterest: json['total_interest']?.toString(),
    order: [
      for (final s in json['payoff_order'] as List)
        '${s['name']} (month ${s['month']})',
    ],
  );
}