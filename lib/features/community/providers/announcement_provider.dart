import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/community_repository.dart';
import '../domain/moderation.dart';

/// Giới hạn độ dài thông báo chung (khớp firestore.rules).
const announcementMax = 200;

/// Thông báo chung do quản trị viên viết (spec 007). Người dùng ẩn được trên máy mình;
/// khi quản trị viên đổi nội dung, thông báo hiện lại.
class AnnouncementProvider extends ChangeNotifier {
  AnnouncementProvider({required CommunityRepository repository}) : _repository = repository;

  static const _dismissedKey = 'dismissed_announcement';

  final CommunityRepository _repository;
  StreamSubscription<String>? _sub;
  String _text = '';
  String? _dismissed;

  /// Nội dung hiện tại (kể cả khi người dùng đã ẩn) — dùng cho ô soạn của quản trị viên.
  String get text => _text;

  /// Nội dung cần hiện (rỗng nếu không có hoặc đã ẩn).
  String get visibleText => _text.isEmpty || _text == _dismissed ? '' : _text;

  void ensureListening() {
    if (_sub != null) return;
    _loadDismissed();
    _sub = _repository.watchAnnouncement().listen((t) {
      _text = t;
      notifyListeners();
    }, onError: (Object _) {
      // Chưa đăng nhập / bị khoá / mất mạng: coi như không có thông báo.
      _text = '';
      notifyListeners();
    });
  }

  Future<void> _loadDismissed() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _dismissed = prefs.getString(_dismissedKey);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> dismiss() async {
    _dismissed = _text;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_dismissedKey, _text);
    } catch (_) {}
  }

  /// Quản trị viên lưu thông báo (chuỗi rỗng = gỡ). Trả về các lỗi kiểm duyệt (rỗng = đã lưu);
  /// ném lỗi nếu máy chủ từ chối hoặc mất mạng.
  Future<Set<ModerationIssue>> save(String value) async {
    final t = value.trim();
    final issues = {...checkText(t), if (t.length > announcementMax) ModerationIssue.noteTooLong};
    if (issues.isNotEmpty) return issues;
    await _repository.setAnnouncement(t);
    return const {};
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
