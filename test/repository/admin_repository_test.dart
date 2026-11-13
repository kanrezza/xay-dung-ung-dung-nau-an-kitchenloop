import 'package:btl_ltdd/features/admin/data/admin_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeFirebaseFirestore firestore;

  setUp(() async {
    firestore = FakeFirebaseFirestore();
    await firestore.collection('users').doc('a').set({
      'name': 'An',
      'email': 'an@example.com',
      'createdAt': Timestamp.fromDate(DateTime(2026, 1, 2)),
      'isLocked': false,
    });
    await firestore.collection('users').doc('b').set({'email': 'b@example.com', 'isLocked': true});
  });

  FirestoreAdminRepository repo({Map<String, dynamic>? claims, bool signedIn = true}) => FirestoreAdminRepository(
        firestore: firestore,
        auth: MockFirebaseAuth(signedIn: signedIn, mockUser: MockUser(uid: 'boss', customClaim: claims)),
      );

  test('có custom claim admin == true thì là quản trị viên', () async {
    expect(await repo(claims: {'admin': true}).isCurrentUserAdmin(), isTrue);
  });

  test('không có claim, claim khác true, hoặc chưa đăng nhập: không phải quản trị viên', () async {
    expect(await repo().isCurrentUserAdmin(), isFalse);
    expect(await repo(claims: {'admin': 'true'}).isCurrentUserAdmin(), isFalse);
    expect(await repo(claims: {'admin': true}, signedIn: false).isCurrentUserAdmin(), isFalse);
  });

  test('watchUsers đọc hồ sơ, đổi Timestamp sang DateTime', () async {
    final users = await repo().watchUsers().first;
    final a = users.firstWhere((u) => u.id == 'a');
    expect(a.name, 'An');
    expect(a.createdAt, DateTime(2026, 1, 2));
    expect(users.firstWhere((u) => u.id == 'b').isLocked, isTrue);
  });

  test('setLocked ghi isLocked và lockedAt; mở khoá xoá lockedAt', () async {
    await repo().setLocked('a', true);
    var data = (await firestore.collection('users').doc('a').get()).data()!;
    expect(data['isLocked'], isTrue);
    expect(data['lockedAt'], isNotNull);
    expect(data['name'], 'An', reason: 'không đụng tới trường khác');

    await repo().setLocked('a', false);
    data = (await firestore.collection('users').doc('a').get()).data()!;
    expect(data['isLocked'], isFalse);
    expect(data['lockedAt'], isNull);
  });

  test('currentUid là UID đang đăng nhập', () {
    expect(repo().currentUid, 'boss');
  });
}
