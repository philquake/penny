import 'package:shared_preferences/shared_preferences.dart';

/// Device-local savings goal, one per signed-in user.
class SavingsGoalStore {
  static String _key(int userId) => 'savings_goal_$userId';

  static Future<double?> load(int userId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_key(userId));
  }

  static Future<void> save(int userId, double? goal) async {
    final prefs = await SharedPreferences.getInstance();
    if (goal == null) {
      await prefs.remove(_key(userId));
    } else {
      await prefs.setDouble(_key(userId), goal);
    }
  }
}