import '../models/budget.dart';
import 'api_client.dart';

class TransactionApi {
  final ApiClient client;

  TransactionApi(this.client);

  Future<List<Budget>> getBudgets(
    String token,
  ) async {
    final response = await client.get(
      '/budgets',
      token: token,
    );

    return (response as List)
        .map(
          (json) => Budget.fromJson(json),
        )
        .toList();
  }

  Future<Budget> getBudget(
    int id,
    String token,
  ) async {
    final response = await client.get(
      '/budgets/$id',
      token: token,
    );

    return Budget.fromJson(response);
  }

  Future<Budget> createBudget({
    required double amount,
    required String description,
    required String transactionDate,
    required String type,
    required String token,
  }) async {
    final response = await client.post(
      '/budgets',
      token: token,
      body: {
        'amount': amount,
        'description': description,
        'transaction_date': transactionDate,
        'type': type,
      },
    );

    return Budget.fromJson(response);
  }
}