import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppThemeMode {
  classicLight,
  darkFuturistic,
}

class ThemeProvider extends ChangeNotifier {
  static const String _prefKey = 'app_theme_mode';

  AppThemeMode _themeMode = AppThemeMode.classicLight;
  bool _isInitialized = false;

  AppThemeMode get themeMode => _themeMode;
  bool get isInitialized => _isInitialized;
  bool get isDarkFuturistic => _themeMode == AppThemeMode.darkFuturistic;

  /// Loads saved theme preference from local storage
  Future<void> loadTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefKey);
      if (saved == AppThemeMode.darkFuturistic.name) {
        _themeMode = AppThemeMode.darkFuturistic;
      } else {
        _themeMode = AppThemeMode.classicLight;
      }
    } catch (e) {
      debugPrint('Error loading theme preference: $e');
    } finally {
      _isInitialized = true;
      notifyListeners();
    }
  }

  /// Sets the theme explicitly
  Future<void> setTheme(AppThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, mode.name);
    } catch (e) {
      debugPrint('Error saving theme preference: $e');
    }
  }

  /// Toggles between Classic Light and Dark Futuristic
  Future<void> toggleTheme() async {
    final next = isDarkFuturistic
        ? AppThemeMode.classicLight
        : AppThemeMode.darkFuturistic;
    await setTheme(next);
  }
}
