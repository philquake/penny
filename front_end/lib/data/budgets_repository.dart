import '../core/api_client.dart';
import '../models/budget.dart';

/// Wraps GET/POST/PUT/DELETE /budgets and GET /budgets/{id}/status.
///
/// Rolling budgets (weekly/monthly/yearly) report on the window containing
/// today; the server derives period_end for them, so the stored dates
/// describe the first period. Custom budgets keep their fixed range.
class BudgetsRepository {
  final ApiClient _client;
  const BudgetsRepository(this._client);

  Future<List<Budget>> list() async {
    final response = await _client.dio.get('/budgets');
    return (response.data as List)
        .map((json) => Budget.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<Budget> create(BudgetCreate data) async {
    final response = await _client.dio.post('/budgets', data: data.toJson());
    return Budget.fromJson(response.data as Map<String, dynamic>);
  }

  Future<BudgetStatus> status(int budgetId) async {
    final response = await _client.dio.get('/budgets/$budgetId/status');
    return BudgetStatus.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> delete(int id) async {
    await _client.dio.delete('/budgets/$id');
  }

  Future<Budget> update(int id, BudgetUpdate data) async {
  final response = await _client.dio.put('/budgets/$id', data: data.toJson());
  return Budget.fromJson(response.data as Map<String, dynamic>);
  }
}