import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../community/domain/moderation.dart';
import '../data/profile_repository.dart';

/// Lỗi khi đổi tên hiển thị.
enum NameError { empty, tooLong, notAllowed, failed }

const nameMax = 40;

/// Kiểm tra tên hiển thị (cùng quy tắc với firestore.rules: 1–40 ký tự, không link/từ cấm).
NameError? validateDisplayName(String name) {
  final t = name.trim();
  if (t.isEmpty) return NameError.empty;
  if (t.length > nameMax) return NameError.tooLong;
  if (checkText(t).isNotEmpty) return NameError.notAllowed;
  return null;
}

/// Hồ sơ của tài khoản đang đăng nhập: tên, ảnh đại diện (tab Tài khoản, trang chủ).
class ProfileProvider extends ChangeNotifier {
  ProfileProvider({required ProfileRepository repository}) : _repository = repository {
    _sub = _repository.watchProfile().listen((p) {
      _profile = p;
      notifyListeners();
    }, onError: (_) {});
  }

  final ProfileRepository _repository;
  StreamSubscription<UserProfile?>? _sub;
  UserProfile? _profile;
  bool _uploading = false;

  UserProfile? get profile => _profile;
  bool get uploading => _uploading;

  Future<NameError?> rename(String name) async {
    final error = validateDisplayName(name);
    if (error != null) return error;
    try {
      await _repository.updateName(name);
      return null;
    } catch (_) {
      return NameError.failed;
    }
  }

  /// `true` nếu thành công.
  Future<bool> setAvatar(File file) => _busy(() => _repository.uploadAvatar(file));
  Future<bool> removeAvatar() => _busy(_repository.removeAvatar);

  Future<bool> _busy(Future<Object?> Function() action) async {
    _uploading = true;
    notifyListeners();
    try {
      await action();
      return true;
    } catch (_) {
      return false;
    } finally {
      _uploading = false;
      notifyListeners();
    }
  }

  Future<bool> sendPasswordReset() async {
    try {
      await _repository.sendPasswordReset();
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
