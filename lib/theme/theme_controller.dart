import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppFontSize { small, standard, large, extraLarge }

extension AppFontSizeX on AppFontSize {
  /// Applied as a linear text-scale factor app-wide via MediaQuery, on top
  /// of flutter_screenutil's .sp sizing (which already respects the ambient
  /// text scaler because ScreenUtilInit is set up with minTextAdapt: true).
  double get scaleFactor {
    switch (this) {
      case AppFontSize.small:
        return 0.9;
      case AppFontSize.standard:
        return 1.0;
      case AppFontSize.large:
        return 1.15;
      case AppFontSize.extraLarge:
        return 1.3;
    }
  }

  String get label {
    switch (this) {
      case AppFontSize.small:
        return 'Small';
      case AppFontSize.standard:
        return 'Default';
      case AppFontSize.large:
        return 'Large';
      case AppFontSize.extraLarge:
        return 'Extra Large';
    }
  }
}

extension ThemeModeLabelX on ThemeMode {
  String get label {
    switch (this) {
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
      case ThemeMode.system:
        return 'System default';
    }
  }
}

/// Holds the user's Theme and Font Size preferences (Profile > App Settings),
/// persisted locally so they survive app restarts and apply immediately via
/// ChangeNotifier without needing to re-login. Deliberately separate from
/// UserSession/AuthService — these are device/app preferences, not account
/// data, so they aren't cleared on logout the way session state is.
class ThemeController extends ChangeNotifier {
  static const _themeModeKey = 'app_theme_mode';
  static const _fontSizeKey = 'app_font_size';

  ThemeMode _themeMode = ThemeMode.light;
  AppFontSize _fontSize = AppFontSize.standard;

  ThemeMode get themeMode => _themeMode;
  AppFontSize get fontSize => _fontSize;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();

    final modeIndex = prefs.getInt(_themeModeKey);
    if (modeIndex != null && modeIndex >= 0 && modeIndex < ThemeMode.values.length) {
      _themeMode = ThemeMode.values[modeIndex];
    }

    final sizeIndex = prefs.getInt(_fontSizeKey);
    if (sizeIndex != null && sizeIndex >= 0 && sizeIndex < AppFontSize.values.length) {
      _fontSize = AppFontSize.values[sizeIndex];
    }

    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_themeModeKey, mode.index);
  }

  Future<void> setFontSize(AppFontSize size) async {
    if (_fontSize == size) return;
    _fontSize = size;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_fontSizeKey, size.index);
  }
}
