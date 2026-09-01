import 'transaction_type.dart';

class TransactionCreate {
  final int categoryId;
  final String amount;
  final TransactionType type;
  final String? description;
  final DateTime transactionDate;

  const TransactionCreate({
    required this.categoryId,
    required this.amount,
    required this.type,
    this.description,
    required this.transactionDate,
  });

  Map<String, dynamic> toJson() {
    return {
      'category_id': categoryId,
      'amount': amount,
      'type': type.value,
      'description': description,
      'transaction_date': _dateOnly(transactionDate),
    };
  }

  static String _dateOnly(DateTime date) {
    return date.toIso8601String().split('T').first;
  }
}

class TransactionUpdate {
  final int? categoryId;
  final String? amount;
  final TransactionType? type;
  final String? description;
  final DateTime? transactionDate;

  const TransactionUpdate({
    this.categoryId,
    this.amount,
    this.type,
    this.description,
    this.transactionDate,
  });

  Map<String, dynamic> toJson() {
    return {
      if (categoryId != null) 'category_id': categoryId,
      if (amount != null) 'amount': amount,
      if (type != null) 'type': type!.value,
      if (description != null) 'description': description,
      if (transactionDate != null)
        'transaction_date': _dateOnly(transactionDate!),
    };
  }

  static String _dateOnly(DateTime date) {
    return date.toIso8601String().split('T').first;
  }
}

class Transaction {
  final int id;
  final int userId;
  final int categoryId;
  final String amount;
  final TransactionType type;
  final String? description;
  final DateTime transactionDate;
  final DateTime createdAt;

  const Transaction({
    required this.id,
    required this.userId,
    required this.categoryId,
    required this.amount,
    required this.type,
    required this.description,
    required this.transactionDate,
    required this.createdAt,
  });

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: json['id'] as int,
      userId: json['user_id'] as int,
      categoryId: json['category_id'] as int,
      amount: json['amount'].toString(),
      type: TransactionTypeExtension.fromValue(
        json['type'] as String,
      ),
      description: json['description'] as String?,
      transactionDate: DateTime.parse(
        json['transaction_date'] as String,
      ),
      createdAt: DateTime.parse(
        json['created_at'] as String,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'category_id': categoryId,
      'amount': amount,
      'type': type.value,
      'description': description,
      'transaction_date': _dateOnly(transactionDate),
      'created_at': createdAt.toIso8601String(),
    };
  }

  static String _dateOnly(DateTime date) {
    return date.toIso8601String().split('T').first;
  }
}

