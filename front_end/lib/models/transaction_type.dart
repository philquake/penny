enum TransactionType {
  income,
  expense,
  transfer,
  savings,
  debt,
}

extension TransactionTypeExtension on TransactionType {
  String get value {
    switch (this) {
      case TransactionType.income:
        return 'income';
      case TransactionType.expense:
        return 'expense';
      case TransactionType.transfer:
        return 'transfer';
      case TransactionType.savings:
        return 'savings';
      case TransactionType.debt:
        return 'debt';
    }
  }

  static TransactionType fromValue(String value) {
    switch (value) {
      case 'income':
        return TransactionType.income;
      case 'expense':
        return TransactionType.expense;
      case 'transfer':
        return TransactionType.transfer;
      case 'savings':
        return TransactionType.savings;
      case 'debt':
        return TransactionType.debt;
      default:
        throw ArgumentError(
          'Unknown transaction type: $value',
        );
    }
  }
}

