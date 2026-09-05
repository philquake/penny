import '../core/api_client.dart';
import '../models/transactions.dart';

/// Wraps GET/POST/PUT/DELETE /transactions, matching
/// app/routers/transactions.py. list() supports the same optional
/// filters the backend does (category_id, start_date, end_date).
class TransactionsRepository {
  final ApiClient _client;
  const TransactionsRepository(this._client);

  Future<List<Transaction>> list({
    int? categoryId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final response = await _client.dio.get('/transactions', queryParameters: {
      'category_id': ?categoryId,
      if (startDate != null) 'start_date': _dateOnly(startDate),
      if (endDate != null) 'end_date': _dateOnly(endDate),
    });
    return (response.data as List)
        .map((json) => Transaction.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<Transaction> create(TransactionCreate data) async {
    final response = await _client.dio.post('/transactions', data: data.toJson());
    return Transaction.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Transaction> update(int id, TransactionUpdate data) async {
    final response =
        await _client.dio.put('/transactions/$id', data: data.toJson());
    return Transaction.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> delete(int id) async {
    await _client.dio.delete('/transactions/$id');
  }

  static String _dateOnly(DateTime date) => date.toIso8601String().split('T').first;
}