import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../recipes/data/recipe_exceptions.dart';
import '../../recipes/data/recipe_repository.dart' show settleWrite;
import '../../recipes/data/stream_utils.dart';

/// Hồ sơ hiển thị của tài khoản đang đăng nhập (spec 005).
class UserProfile {
  const UserProfile({required this.uid, required this.email, required this.name, this.avatarUrl, this.avatarBytes});

  final String uid;
  final String email;

  /// Tên hiển thị (hiện trên bài cộng đồng). Rỗng thì giao diện dùng phần trước @ của email.
  final String name;
  final String? avatarUrl;

  /// Ảnh đại diện lưu thẳng trong hồ sơ (đã giải mã từ data URI). Ưu tiên hơn [avatarUrl].
  final Uint8List? avatarBytes;

  bool get hasAvatar => avatarBytes != null || avatarUrl != null;

  String get displayName => name.trim().isNotEmpty ? name.trim() : email.split('@').first;

  /// Chữ cái đầu cho ảnh đại diện mặc định.
  String get initials {
    final words = displayName.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return '?';
    final first = words.first.characters.first;
    final last = words.length > 1 ? words.last.characters.first : '';
    return (first + last).toUpperCase();
  }
}

extension on String {
  Iterable<String> get characters => runes.map(String.fromCharCode);
}

/// Ảnh vượt giới hạn lưu trong hồ sơ (khớp firestore.rules: 150 000 ký tự base64).
class AvatarTooLargeException implements Exception {}

/// Giới hạn kích thước ảnh gốc (~110 KB): base64 làm dài thêm 4/3.
const avatarMaxBytes = 110 * 1024;

/// "data:image/jpeg;base64,..." → byte ảnh; `null` nếu không hợp lệ.
Uint8List? decodeAvatarData(Object? raw) {
  if (raw is! String) return null;
  final i = raw.indexOf(';base64,');
  if (!raw.startsWith('data:image/') || i < 0) return null;
  try {
    return base64Decode(raw.substring(i + 8));
  } catch (_) {
    return null;
  }
}

/// Byte ảnh → data URI (đoán loại ảnh theo phần mở đầu của file).
String encodeAvatarData(Uint8List bytes) {
  final png = bytes.length > 4 && bytes[0] == 0x89 && bytes[1] == 0x50;
  final webp = bytes.length > 12 && bytes[8] == 0x57 && bytes[9] == 0x45;
  final type = png ? 'png' : (webp ? 'webp' : 'jpeg');
  return 'data:image/$type;base64,${base64Encode(bytes)}';
}

abstract class ProfileRepository {
  Stream<UserProfile?> watchProfile();
  Future<void> updateName(String name);

  /// Đặt ảnh đại diện (ảnh đã thu nhỏ). Ném [AvatarTooLargeException] nếu ảnh quá lớn.
  Future<void> uploadAvatar(File file);
  Future<void> removeAvatar();

  /// Gửi email đặt lại mật khẩu tới email của tài khoản đang đăng nhập.
  Future<void> sendPasswordReset();
}

class FirebaseProfileRepository implements ProfileRepository {
  FirebaseProfileRepository({
    required FirebaseFirestore firestore,
    required FirebaseAuth auth,
    this.offlineGrace = const Duration(seconds: 2),
  })  : _firestore = firestore,
        _auth = auth;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final Duration offlineGrace;

  Stream<String?> _userIds() async* {
    yield _auth.currentUser?.uid;
    yield* _auth.authStateChanges().map((u) => u?.uid);
  }

  User _requireUser() {
    final user = _auth.currentUser;
    if (user == null) throw NotSignedInException();
    return user;
  }

  DocumentReference<Map<String, dynamic>> _doc(String uid) => _firestore.collection('users').doc(uid);

  @override
  Stream<UserProfile?> watchProfile() => switchMapStream<String?, UserProfile?>(_userIds().distinct(), (uid) {
        if (uid == null) return Stream.value(null);
        final email = _auth.currentUser?.email ?? '';
        return _doc(uid).snapshots().map((snap) {
          final d = snap.data() ?? const {};
          final avatar = d['avatarUrl'];
          return UserProfile(
            uid: uid,
            email: email,
            name: d['name'] is String ? d['name'] as String : '',
            avatarUrl: avatar is String && avatar.isNotEmpty ? avatar : null,
            avatarBytes: decodeAvatarData(d['avatarData']),
          );
        });
      });

  @override
  Future<void> updateName(String name) async {
    final user = _requireUser();
    await settleWrite(_doc(user.uid).set({'name': name.trim()}, SetOptions(merge: true)), offlineGrace);
  }

  /// Ảnh lưu thẳng trong hồ sơ `users/{uid}.avatarData` (không cần Cloud Storage, chạy được trên
  /// gói Spark). Ảnh đã được thu nhỏ ở bước chọn ảnh (tối đa 256 px).
  @override
  Future<void> uploadAvatar(File file) async {
    final user = _requireUser();
    final bytes = await file.readAsBytes();
    if (bytes.length > avatarMaxBytes) throw AvatarTooLargeException();
    await settleWrite(
      _doc(user.uid).set({'avatarData': encodeAvatarData(bytes), 'avatarUrl': null}, SetOptions(merge: true)),
      offlineGrace,
    );
  }

  @override
  Future<void> removeAvatar() async {
    final user = _requireUser();
    await settleWrite(_doc(user.uid).set({'avatarData': null, 'avatarUrl': null}, SetOptions(merge: true)), offlineGrace);
  }

  @override
  Future<void> sendPasswordReset() async {
    final email = _requireUser().email;
    if (email == null || email.isEmpty) throw NotSignedInException();
    await _auth.sendPasswordResetEmail(email: email);
  }
}
