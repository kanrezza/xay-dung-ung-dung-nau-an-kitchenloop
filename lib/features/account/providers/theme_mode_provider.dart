import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Chế độ giao diện (Theo máy / Sáng / Tối), lưu trên máy để giữ sau khi mở lại app.
class ThemeModeProvider extends ChangeNotifier {
  ThemeModeProvider() {
    _load();
  }

  static const _key = 'theme_mode';
  ThemeMode _mode = ThemeMode.system;

  ThemeMode get mode => _mode;

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = ThemeMode.values.where((m) => m.name == prefs.getString(_key));
      if (saved.isNotEmpty && saved.first != _mode) {
        _mode = saved.first;
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> setMode(ThemeMode mode) async {
    if (mode == _mode) return;
    _mode = mode;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, mode.name);
    } catch (_) {}
  }
}
