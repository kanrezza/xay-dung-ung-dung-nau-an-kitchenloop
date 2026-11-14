import 'dart:io';
import 'dart:typed_data';

import 'package:btl_ltdd/features/account/data/profile_repository.dart';
import 'package:btl_ltdd/features/account/providers/profile_provider.dart';
import 'package:btl_ltdd/features/account/providers/theme_mode_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/profile_fakes.dart';

void main() {
  group('UserProfile', () {
    test('tên hiển thị: dùng tên, thiếu tên thì dùng phần trước @ của email', () {
      expect(const UserProfile(uid: 'u', email: 'an@x.com', name: ' An ').displayName, 'An');
      expect(const UserProfile(uid: 'u', email: 'an.nguyen@x.com', name: '').displayName, 'an.nguyen');
    });

    test('chữ cái đầu cho ảnh mặc định', () {
      expect(const UserProfile(uid: 'u', email: 'a@x', name: 'Nguyễn Văn An').initials, 'NA');
      expect(const UserProfile(uid: 'u', email: 'a@x', name: 'Ân').initials, 'Â');
      expect(const UserProfile(uid: 'u', email: 'bob@x', name: '').initials, 'B');
    });
  });

  group('kiểm tra tên hiển thị (khớp firestore.rules)', () {
    test('hợp lệ', () => expect(validateDisplayName('An Nguyễn'), isNull));
    test('rỗng', () => expect(validateDisplayName('   '), NameError.empty));
    test('quá 40 ký tự', () => expect(validateDisplayName('a' * 41), NameError.tooLong));
    test('link, từ cấm', () {
      expect(validateDisplayName('shop.vn giá rẻ'), NameError.notAllowed);
      expect(validateDisplayName('casino 88'), NameError.notAllowed);
    });
  });

  group('FirebaseProfileRepository (fake Firestore)', () {
    late FakeFirebaseFirestore db;
    late FirebaseProfileRepository repo;

    setUp(() async {
      db = FakeFirebaseFirestore();
      await db.collection('users').doc('alice').set({'name': 'An', 'role': 'blogger'});
      repo = FirebaseProfileRepository(
        firestore: db,
        auth: MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: 'alice', email: 'an@example.com')),
        offlineGrace: const Duration(milliseconds: 50),
      );
    });

    test('đọc hồ sơ: tên từ users, email từ tài khoản', () async {
      final p = (await repo.watchProfile().first)!;
      expect([p.name, p.email, p.avatarUrl], ['An', 'an@example.com', null]);
    });

    test('đổi tên chỉ ghi trường name, giữ các trường khác', () async {
      await repo.updateName('  An Nguyễn ');
      final d = (await db.collection('users').doc('alice').get()).data()!;
      expect(d['name'], 'An Nguyễn');
      expect(d['role'], 'blogger');
    });

    test('đặt ảnh: lưu data URI trong hồ sơ (không cần Storage), đọc lại ra byte ảnh', () async {
      final dir = await Directory.systemTemp.createTemp('avatar');
      final file = File('${dir.path}/a.png')..writeAsBytesSync(FakeProfileRepository.tinyPng);
      await repo.uploadAvatar(file);
      final d = (await db.collection('users').doc('alice').get()).data()!;
      expect((d['avatarData'] as String).startsWith('data:image/png;base64,'), isTrue);
      expect(d['avatarUrl'], isNull);
      final p = (await repo.watchProfile().first)!;
      expect(p.avatarBytes, FakeProfileRepository.tinyPng);
      expect(p.hasAvatar, isTrue);
      await dir.delete(recursive: true);
    });

    test('ảnh quá lớn (> 110 KB) bị từ chối trước khi ghi', () async {
      final dir = await Directory.systemTemp.createTemp('avatar');
      final file = File('${dir.path}/big.jpg')..writeAsBytesSync(List.filled(avatarMaxBytes + 1, 0));
      await expectLater(repo.uploadAvatar(file), throwsA(isA<AvatarTooLargeException>()));
      expect((await db.collection('users').doc('alice').get()).data()!['avatarData'], isNull);
      await dir.delete(recursive: true);
    });

    test('xoá ảnh: avatarData và avatarUrl về null', () async {
      await db.collection('users').doc('alice').set({'avatarData': encodeAvatarData(FakeProfileRepository.tinyPng)}, SetOptions(merge: true));
      await repo.removeAvatar();
      final d = (await db.collection('users').doc('alice').get()).data()!;
      expect([d['avatarData'], d['avatarUrl']], [null, null]);
    });

    test('mã hoá / giải mã ảnh; dữ liệu hỏng trả về null', () {
      final uri = encodeAvatarData(FakeProfileRepository.tinyPng);
      expect(uri.startsWith('data:image/png;base64,'), isTrue);
      expect(decodeAvatarData(uri), FakeProfileRepository.tinyPng);
      expect(encodeAvatarData(Uint8List.fromList([0xFF, 0xD8, 0xFF, 1])).startsWith('data:image/jpeg;'), isTrue);
      expect(decodeAvatarData('data:image/png;base64,@@@'), isNull);
      expect(decodeAvatarData('https://x'), isNull);
      expect(decodeAvatarData(42), isNull);
    });
  });

  group('ProfileProvider', () {
    test('đổi tên hợp lệ / không hợp lệ / lỗi mạng', () async {
      final fake = FakeProfileRepository();
      final p = ProfileProvider(repository: fake);
      await Future<void>.delayed(Duration.zero);
      expect(p.profile!.name, 'An Nguyễn');
      expect(await p.rename('Bếp của An'), isNull);
      expect(fake.profile.name, 'Bếp của An');
      expect(await p.rename(''), NameError.empty);
      fake.fail = true;
      expect(await p.rename('Tên mới'), NameError.failed);
      p.dispose();
    });

    test('đặt và xoá ảnh đại diện; gửi email đặt lại mật khẩu', () async {
      final fake = FakeProfileRepository();
      final p = ProfileProvider(repository: fake);
      expect(await p.setAvatar(File('a.jpg')), isTrue);
      await Future<void>.delayed(Duration.zero);
      expect(p.profile!.hasAvatar, isTrue);
      expect(await p.removeAvatar(), isTrue);
      await Future<void>.delayed(Duration.zero);
      expect(p.profile!.hasAvatar, isFalse);
      expect(await p.sendPasswordReset(), isTrue);
      expect(fake.resets, 1);
      p.dispose();
    });
  });

  group('ThemeModeProvider', () {
    test('mặc định theo máy; lưu lựa chọn và đọc lại khi mở app', () async {
      SharedPreferences.setMockInitialValues({});
      final a = ThemeModeProvider();
      await Future<void>.delayed(Duration.zero);
      expect(a.mode, ThemeMode.system);
      await a.setMode(ThemeMode.dark);
      final b = ThemeModeProvider();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(b.mode, ThemeMode.dark);
    });
  });
}

