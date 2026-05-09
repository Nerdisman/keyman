import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  static const _darkModeKey = 'dark_mode';
  final SharedPreferences _prefs;
  bool _isDarkMode = false;

  ThemeProvider(this._prefs) {
    _loadDarkMode();
  }

  bool get isDarkMode => _isDarkMode;

  void _loadDarkMode() {
    _isDarkMode = _prefs.getBool(_darkModeKey) ?? false;
    notifyListeners();
  }

  void toggleDarkMode() {
    _isDarkMode = !_isDarkMode;
    _prefs.setBool(_darkModeKey, _isDarkMode);
    notifyListeners();
  }

  void setSystemMode() {
    final brightness = WidgetsBinding.instance.platformDispatcher.platformBrightness;
    _isDarkMode = brightness == Brightness.dark;
    _prefs.setBool(_darkModeKey, _isDarkMode);
    notifyListeners();
  }
}
