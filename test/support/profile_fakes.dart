import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:btl_ltdd/features/account/data/profile_repository.dart';

/// Hồ sơ giả trong bộ nhớ.
class FakeProfileRepository implements ProfileRepository {
  FakeProfileRepository({String name = 'An Nguyễn', String email = 'an.nguyen@example.com', bool withPhoto = false})
      : _profile = UserProfile(uid: 'alice', email: email, name: name, avatarBytes: withPhoto ? tinyPng : null);

  /// Ảnh PNG 1×1 hợp lệ.
  static final tinyPng = Uint8List.fromList(base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=='));

  UserProfile _profile;
  final _ctrl = StreamController<UserProfile?>.broadcast();
  int resets = 0;
  bool fail = false;

  UserProfile get profile => _profile;

  void _set(UserProfile p) {
    _profile = p;
    _ctrl.add(p);
  }

  @override
  Stream<UserProfile?> watchProfile() async* {
    yield _profile;
    yield* _ctrl.stream;
  }

  @override
  Future<void> updateName(String name) async {
    if (fail) throw Exception('offline');
    _set(UserProfile(uid: _profile.uid, email: _profile.email, name: name.trim(), avatarBytes: _profile.avatarBytes));
  }

  @override
  Future<void> uploadAvatar(File file) async {
    if (fail) throw Exception('offline');
    _set(UserProfile(uid: _profile.uid, email: _profile.email, name: _profile.name, avatarBytes: tinyPng));
  }

  @override
  Future<void> removeAvatar() async {
    _set(UserProfile(uid: _profile.uid, email: _profile.email, name: _profile.name));
  }

  @override
  Future<void> sendPasswordReset() async {
    if (fail) throw Exception('offline');
    resets++;
  }
}
