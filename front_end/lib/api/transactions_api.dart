import '../models/transactions.dart';
import 'api_client.dart';

class TransactionApi {
  final ApiClient client;

  TransactionApi(this.client);

  Future<List<Transaction>> getTransactions(
    String token,
  ) async {
    final response = await client.get(
      '/transactions',
      token: token,
    );

    return (response as List)
        .map(
          (json) => Transaction.fromJson(json),
        )
        .toList();
  }

  Future<Transaction> getTransaction(
    int id,
    String token,
  ) async {
    final response = await client.get(
      '/transactions/$id',
      token: token,
    );

    return Transaction.fromJson(response);
  }

  Future<Transaction> createTransaction({
    required double amount,
    required String description,
    required String transactionDate,
    required String type,
    required String token,
  }) async {
    final response = await client.post(
      '/transactions',
      token: token,
      body: {
        'amount': amount,
        'description': description,
        'transaction_date': transactionDate,
        'type': type,
      },
    );

    return Transaction.fromJson(response);
  }
}