import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App-wide theme mode, persisted across restarts.
///
/// ThemeMode.system is Flutter's built-in "follow the OS theme" mode — it
/// already updates live with no restart required, so "Automatic" needs no
/// custom platform-brightness-listening code at all.
class ThemeStore {
  static const _key = 'theme_mode';
  static final ValueNotifier<ThemeMode> mode = ValueNotifier(ThemeMode.system);

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key);
    switch (saved) {
      case 'light':
        mode.value = ThemeMode.light;
        break;
      case 'dark':
        mode.value = ThemeMode.dark;
        break;
      default:
        mode.value = ThemeMode.system; // default for a fresh install
    }
  }

  static Future<void> set(ThemeMode newMode) async {
    mode.value = newMode;
    final prefs = await SharedPreferences.getInstance();
    String stored;
    switch (newMode) {
      case ThemeMode.light:
        stored = 'light';
        break;
      case ThemeMode.dark:
        stored = 'dark';
        break;
      case ThemeMode.system:
        stored = 'auto';
        break;
    }
    await prefs.setString(_key, stored);
  }
}
