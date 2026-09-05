import '../core/api_client.dart';
import '../models/budget.dart';

/// Wraps GET/POST/DELETE /budgets and GET /budgets/{id}/status.
///
/// IMPORTANT — two backend bugs found while writing this, unrelated to
/// Flutter, both in app/routers/budgets.py:
///
/// 1. GET /budgets (get_all_budgets) calls `get_budget(db=db,
///    user_id=current_user.id)` — but crud.get_budget requires a
///    `budget_id` too, so this raises a TypeError server-side. It looks
///    like it meant to call `list_budgets(db, user_id)` instead, which
///    already exists in crud/budgets.py.
/// 2. DELETE /budgets/{id} (remove_budget) calls
///    `delete_budget(db=db, budget_id=budget_id, user_id=current_user.id)`
///    — but crud.delete_budget takes a `budget` object, not a budget_id.
///    Even once that's fixed, crud.delete_budget returns None, and the
///    router checks `if not deleted: raise 404`, so it'll 404 every time.
///    It needs a get_budget() lookup first, then pass that Budget in.
///
/// list() and delete() below are written against the intended contract
/// (matching BudgetOut / your test suite), so they'll work once those
/// two are fixed — until then, expect 500s from list() and always-404
/// from delete().
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
}