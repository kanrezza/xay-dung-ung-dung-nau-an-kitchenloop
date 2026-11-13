import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/cooking_session.dart';

/// Lưu phiên nấu dở trong `shared_preferences` (chỉ trên máy, không đồng bộ).
/// Khoá: `cooking_session_<uid>_<recipeId>`, nên mỗi tài khoản và mỗi công
/// thức có phiên riêng.
class CookingSessionStore {
  CookingSessionStore({required String? Function() uidGetter}) : _uidGetter = uidGetter;

  final String? Function() _uidGetter;

  static String keyFor(String uid, String recipeId) => 'cooking_session_${uid}_$recipeId';

  String? _key(String recipeId) {
    final uid = _uidGetter();
    return uid == null ? null : keyFor(uid, recipeId);
  }

  /// Đọc phiên đã lưu; `null` nếu không có, chưa đăng nhập hoặc dữ liệu hỏng
  /// (dữ liệu hỏng được xoá đi).
  Future<CookingSession?> load(String recipeId) async {
    final key = _key(recipeId);
    if (key == null) return null;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null) return null;
    try {
      return CookingSession.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (e) {
      debugPrint('Phiên nấu bị hỏng, bỏ qua: $e');
      await prefs.remove(key);
      return null;
    }
  }

  /// Mọi phiên nấu dở của tài khoản đang đăng nhập (trang chủ: "Nấu tiếp").
  /// Dữ liệu hỏng được bỏ qua.
  Future<List<CookingSession>> loadAll() async {
    final uid = _uidGetter();
    if (uid == null) return const [];
    final prefix = 'cooking_session_${uid}_';
    final prefs = await SharedPreferences.getInstance();
    final sessions = <CookingSession>[];
    for (final key in prefs.getKeys().where((k) => k.startsWith(prefix))) {
      final raw = prefs.getString(key);
      if (raw == null) continue;
      try {
        sessions.add(CookingSession.fromJson(jsonDecode(raw) as Map<String, dynamic>));
      } catch (_) {
        // Bỏ qua phiên hỏng; load() sẽ dọn nó khi mở đúng công thức.
      }
    }
    return sessions;
  }

  Future<void> save(CookingSession session) async {
    final key = _key(session.recipeId);
    if (key == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(session.toJson()));
  }

  Future<void> clear(String recipeId) async {
    final key = _key(recipeId);
    if (key == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  }
}
