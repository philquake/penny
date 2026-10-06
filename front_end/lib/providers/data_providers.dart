import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/budgets_repository.dart';
import '../data/categories_repository.dart';
import '../data/transactions_repository.dart';
import '../models/budget.dart';
import '../models/budget_entry.dart';
import '../models/category.dart';
import '../models/transactions.dart';
import '../services/budget_notification_service.dart';
import 'session.dart';

final categoriesRepositoryProvider = Provider(
  (ref) => CategoriesRepository(ref.watch(apiClientProvider)),
);
final transactionsRepositoryProvider = Provider(
  (ref) => TransactionsRepository(ref.watch(apiClientProvider)),
);
final budgetsRepositoryProvider = Provider(
  (ref) => BudgetsRepository(ref.watch(apiClientProvider)),
);

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
    state = state.whenData((list) => list.where((c) => c.id != id).toList());
  }

  Future<void> update(int id, CategoryUpdate data) async {
    final updated = await _repo.update(id, data);
    state = state.whenData(
      (list) => [for (final c in list) c.id == id ? updated : c],
    );
  }
}

final categoriesProvider =
    StateNotifierProvider<CategoriesController, AsyncValue<List<Category>>>(
      (ref) => CategoriesController(ref.watch(categoriesRepositoryProvider)),
    );

/// Transactions: same refresh-on-mutation pattern as categories.
class TransactionsController
    extends StateNotifier<AsyncValue<List<Transaction>>> {
  final TransactionsRepository _repo;
  final Ref _ref;
  TransactionsController(this._repo, this._ref)
    : super(const AsyncValue.loading()) {
    refresh();
  }

  Future<void> refresh({bool silent = false}) async {
    if (!silent) state = const AsyncValue.loading();
    final next = await AsyncValue.guard(() => _repo.list());
    if (!mounted) return;
    if (silent && next.hasError) return; 
    state = next;
  }

  Future<void> _afterMutation() async {
    await Future.wait([
      refresh(silent: true),
      _ref.read(budgetsProvider.notifier).refresh(silent: true),
    ]);
  }


  Future<void> create(TransactionCreate data) async {
    await _repo.create(data);
    await _afterMutation();
  }

  Future<void> update(int id, TransactionUpdate data) async {
    await _repo.update(id, data);
    await _afterMutation();
  }

  Future<void> delete(int id) async {
    await _repo.delete(id);
    state = state.whenData((list) => list.where((t) => t.id != id).toList());
    await _afterMutation();
  }
}

final transactionsProvider =
    StateNotifierProvider<
      TransactionsController,
      AsyncValue<List<Transaction>>
    >(
      (ref) => TransactionsController(
        ref.watch(transactionsRepositoryProvider),
        ref,
      ),
    );

/// Budgets: fetches the list, then fetches each budget's status
/// (GET /budgets/{id}/status) and zips them with the resolved Category
/// into the BudgetEntry shape BudgetsScreen/DashboardScreen expect.
///

class BudgetsController extends StateNotifier<AsyncValue<List<BudgetEntry>>> {
  final BudgetsRepository _repo;
  final Ref _ref;

  BudgetsController(this._repo, this._ref) : super(const AsyncValue.loading()) {
    refresh();
  }

  Future<void> refresh({bool silent = false}) async {
    final categoriesState = _ref.read(categoriesProvider);
    if (!categoriesState.hasValue)
      return; // wait; the listener below re-triggers us

    if (!silent) state = const AsyncValue.loading();

    final next = await AsyncValue.guard(() async {
      final budgets = await _repo.list();
      final categories = categoriesState.value!;

      final entries = <BudgetEntry>[];
      for (final budget in budgets) {
        final status = await _repo.status(budget.id);

        final match = categories.where((c) => c.id == budget.categoryId);
        if (match.isEmpty) continue;

        final entry = BudgetEntry(budget, status, match.first);
        entries.add(entry);
        await BudgetNotificationService.instance.updateBudget(entry);
      }
      return entries;
    });

    if (mounted) {
      if (silent && next.hasError) return; // keep showing the last good data
      state = next;
    }
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
    StateNotifierProvider<BudgetsController, AsyncValue<List<BudgetEntry>>>((
      ref,
    ) {
      final controller = BudgetsController(
        ref.watch(budgetsRepositoryProvider),
        ref,
      );

      ref.listen<AsyncValue<List<Category>>>(categoriesProvider, (prev, next) {
        if (next.hasValue) controller.refresh();
      });

      return controller;
    });
