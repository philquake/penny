import '../core/api_client.dart';
import '../models/debt.dart';

class DebtsRepository {
  final ApiClient _client;
  const DebtsRepository(this._client);

  Future<List<Debt>> list() async {
    final r = await _client.dio.get('/debts');
    return (r.data as List)
        .map((j) => Debt.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  Future<Debt> create(DebtCreate data) async {
    final r = await _client.dio.post('/debts', data: data.toJson());
    return Debt.fromJson(r.data as Map<String, dynamic>);
  }

  Future<void> delete(int id) async => _client.dio.delete('/debts/$id');

  Future<List<DebtEntry>> entries(int id) async {
    final r = await _client.dio.get('/debts/$id/entries');
    return (r.data as List)
        .map((j) => DebtEntry.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  Future<void> addEntry(int id, DebtEntryCreate data) async =>
      _client.dio.post('/debts/$id/entries', data: data.toJson());

  Future<void> deleteEntry(int debtId, int entryId) async =>
      _client.dio.delete('/debts/$debtId/entries/$entryId');

  Future<PayoffResult> payoff(int id, String monthlyPayment) async {
    final r = await _client.dio.get(
      '/debts/$id/payoff',
      queryParameters: {'monthly_payment': monthlyPayment},
    );
    return PayoffResult.fromJson(r.data as Map<String, dynamic>);
  }

  Future<PlanResult> plan(String extra, String strategy) async {
    final r = await _client.dio.get(
      '/debts/payoff-plan',
      queryParameters: {'extra': extra, 'strategy': strategy},
    );
    return PlanResult.fromJson(r.data as Map<String, dynamic>);
  }
}