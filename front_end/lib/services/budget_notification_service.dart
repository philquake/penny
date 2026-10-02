import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/budget_entry.dart';

class BudgetNotificationService {
  BudgetNotificationService._();

  static final instance = BudgetNotificationService._();

  static const _enabledKey = 'budget_notifications_enabled';
  static const _sentBudgetIdsKey = 'budget_notifications_sent_ids';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
  }

  Future<bool> isEnabled() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(_enabledKey) ?? false;
  }

  Future<bool> setEnabled(bool enabled) async {
    final preferences = await SharedPreferences.getInstance();
    if (!enabled) {
      await preferences.setBool(_enabledKey, false);
      return true;
    }

    bool? granted;
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      granted = await android.requestNotificationsPermission();
    }

    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      granted = await ios.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    }

    final allowed = granted ?? true;
    await preferences.setBool(_enabledKey, allowed);
    return allowed;
  }

  Future<void> updateBudget(BudgetEntry entry) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final sentIds = preferences.getStringList(_sentBudgetIdsKey) ?? [];
      final key = '${entry.budget.userId}:${entry.budget.id}';

      if (!entry.status.thresholdCrossed) {
        if (sentIds.remove(key)) {
          await preferences.setStringList(_sentBudgetIdsKey, sentIds);
        }
        return;
      }

      if (!(preferences.getBool(_enabledKey) ?? false) || sentIds.contains(key)) {
        return;
      }

      final percentage =
          double.tryParse(entry.status.percentageUsed)?.round() ?? 0;
      await _plugin.show(
        id: entry.budget.id,
        title: '${entry.category.name} budget alert',
        body: 'You have used $percentage% of this budget.',
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'budget_alerts',
            'Budget alerts',
            channelDescription: 'Alerts when spending reaches a budget limit.',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
      );
      sentIds.add(key);
      await preferences.setStringList(_sentBudgetIdsKey, sentIds);
    } catch (_) {
      // Notification failures should not prevent budget data from loading.
    }
  }
}