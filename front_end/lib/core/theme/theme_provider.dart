import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

enum ThemePreference { system, light, dark }

extension ThemePreferenceX on ThemePreference {
  ThemeMode get mode => switch (this) {
    ThemePreference.system => ThemeMode.system,
    ThemePreference.light => ThemeMode.light,
    ThemePreference.dark => ThemeMode.dark,
  };
}

class ThemeController extends StateNotifier<ThemePreference> {
  static const _storageKey = 'theme_preference';
  final FlutterSecureStorage _storage;

  ThemeController(this._storage) : super(ThemePreference.system) {
    _load();
  }

  Future<void> _load() async {
    final value = await _storage.read(key: _storageKey);
    if (!mounted) return;

    final next = switch (value) {
      'light' => ThemePreference.light,
      'dark' => ThemePreference.dark,
      _ => ThemePreference.system,
    };

    state = next;
  }

  Future<void> setPreference(ThemePreference preference) async {
    await _storage.write(key: _storageKey, value: preference.name);
    if (mounted) {
      state = preference;
    }
  }
}

final themeControllerProvider =
    StateNotifierProvider<ThemeController, ThemePreference>(
      (ref) => ThemeController(const FlutterSecureStorage()),
    );

final themeProvider = Provider<ThemePreference>((ref) {
  return ref.watch(themeControllerProvider);
});

final themeModeProvider = Provider<ThemeMode>((ref) {
  final preference = ref.watch(themeProvider);
  return preference.mode;
});
