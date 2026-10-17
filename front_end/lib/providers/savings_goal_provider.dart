import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/savings_goal_store.dart';
import 'data_providers.dart';

class SavingsGoalController extends StateNotifier<AsyncValue<double?>> {
  final int? _userId;

  SavingsGoalController(this._userId) : super(const AsyncValue.loading()) {
    _load();
  }

  Future<void> _load() async {
    final id = _userId;
    if (id == null) {
      state = const AsyncValue.data(null);
      return;
    }
    final next = await AsyncValue.guard(() => SavingsGoalStore.load(id));
    if (!mounted) return;
    state = next;
  }

  Future<void> setGoal(double? goal) async {
    final id = _userId;
    if (id == null) return;
    await SavingsGoalStore.save(id, goal);
    if (mounted) state = AsyncValue.data(goal);
  }
}

final savingsGoalProvider = StateNotifierProvider.autoDispose<
    SavingsGoalController, AsyncValue<double?>>((ref) {
  final userId = ref.watch(sessionUserIdProvider);
  return SavingsGoalController(userId);
});