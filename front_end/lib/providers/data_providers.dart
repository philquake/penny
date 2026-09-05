import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/budgets_repository.dart';
import '../data/categories_repository.dart';
import '../data/transactions_repository.dart';
import '../models/budget.dart';
import '../models/budget_entry.dart';
import '../models/category.dart';
import '../models/transactions.dart';
import 'session.dart';

final categoriesRepositoryProvider =
    Provider((ref) => CategoriesRepository(ref.watch(apiClientProvider)));
final transactionsRepositoryProvider =
    Provider((ref) => TransactionsRepository(ref.watch(apiClientProvider)));
final budgetsRepositoryProvider =
    Provider((ref) => BudgetsRepository(ref.watch(apiClientProvider)));

/// Categories: loaded once per session, mutated in place on create/delete
/// so every screen watching this provider stays in sync without refetching.
class CategoriesController extends StateNotifier<AsyncValue<List<Category>>> {
  final CategoriesRepository _repo;
  CategoriesController(this._repo) : super(const AsyncValue.loading()) {
    refresh();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _repo.list());
  }

  Future<void> create(CategoryCreate data) async {
    final created = await _repo.create(data);
    state = state.whenData((list) => [...list, created]);
  }

  Future<void> delete(int id) async {
    await _repo.delete(id);
    state = state.whenData(
      (list) => list.where((c) => c.id != id).toList(),
    );
  }
}

final categoriesProvider =
    StateNotifierProvider<CategoriesController, AsyncValue<List<Category>>>(
  (ref) => CategoriesController(ref.watch(categoriesRepositoryProvider)),
);

/// Transactions: same refresh-on-mutation pattern as categories.
class TransactionsController extends StateNotifier<AsyncValue<List<Transaction>>> {
  final TransactionsRepository _repo;
  TransactionsController(this._repo) : super(const AsyncValue.loading()) {
    refresh();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _repo.list());
  }

  Future<void> create(TransactionCreate data) async {
    await _repo.create(data);
    await refresh();
  }

  Future<void> update(int id, TransactionUpdate data) async {
    await _repo.update(id, data);
    await refresh();
  }

  Future<void> delete(int id) async {
    await _repo.delete(id);
    state = state.whenData(
      (list) => list.where((t) => t.id != id).toList(),
    );
  }
}

final transactionsProvider =
    StateNotifierProvider<TransactionsController, AsyncValue<List<Transaction>>>(
  (ref) => TransactionsController(ref.watch(transactionsRepositoryProvider)),
);

/// Budgets: fetches the list, then fetches each budget's status
/// (GET /budgets/{id}/status) and zips them with the resolved Category
/// into the BudgetEntry shape BudgetsScreen/DashboardScreen expect.
///
/// NOTE: GET /budgets currently 500s and DELETE /budgets/{id} currently
/// always 404s — see data/budgets_repository.dart for the two backend
/// bugs causing that. This controller is written against the intended
/// contract and will work once those are fixed.
class BudgetsController extends StateNotifier<AsyncValue<List<BudgetEntry>>> {
  final BudgetsRepository _repo;
  final Ref _ref;

  BudgetsController(this._repo, this._ref) : super(const AsyncValue.loading()) {
    refresh();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final budgets = await _repo.list();
      final categories =
          _ref.read(categoriesProvider).asData?.value ?? const <Category>[];

      final entries = <BudgetEntry>[];
      for (final budget in budgets) {
        final status = await _repo.status(budget.id);
        final category = categories.where((c) => c.id == budget.categoryId);
        if (category.isEmpty) continue;
        entries.add(BudgetEntry(budget, status, category.first));
      }
      return entries;
    });
  }

  Future<void> create(BudgetCreate data) async {
    await _repo.create(data);
    await refresh();
  }

  Future<void> delete(int id) async {
    await _repo.delete(id);
    await refresh();
  }
}

final budgetsProvider =
    StateNotifierProvider<BudgetsController, AsyncValue<List<BudgetEntry>>>(
  (ref) => BudgetsController(ref.watch(budgetsRepositoryProvider), ref),
);