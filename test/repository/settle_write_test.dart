import 'dart:async';

import 'package:btl_ltdd/features/recipes/data/recipe_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

/// Khi mất mạng, Firestore xếp lần ghi vào hàng đợi cục bộ nhưng `Future` của lần
/// ghi chỉ hoàn tất khi máy chủ xác nhận. `settleWrite` phải làm cho giao diện
/// không bị treo trong lúc đó (FR-019, US6).
void main() {
  group('settleWrite', () {
    test('lần ghi hoàn tất sớm: trả về ngay, không chờ hết thời gian chờ', () async {
      final watch = Stopwatch()..start();
      await settleWrite(Future<void>.value(), const Duration(seconds: 5));
      expect(watch.elapsedMilliseconds, lessThan(500));
    });

    test('offline (lần ghi không bao giờ hoàn tất): trả về sau thời gian chờ thay vì treo mãi', () async {
      final neverCompletes = Completer<void>();
      final watch = Stopwatch()..start();
      await settleWrite(neverCompletes.future, const Duration(milliseconds: 80));
      expect(watch.elapsedMilliseconds, inInclusiveRange(60, 1000));
      expect(neverCompletes.isCompleted, isFalse); // lần ghi vẫn đang chờ ở nền
    });

    test('lỗi trả về sớm (ví dụ bị từ chối quyền) được ném ra', () async {
      final failing = Future<void>.error(FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied'));
      await expectLater(
        settleWrite(failing, const Duration(seconds: 5)),
        throwsA(isA<FirebaseException>().having((e) => e.code, 'code', 'permission-denied')),
      );
    });

    test('lỗi xảy ra sau thời gian chờ không gây lỗi chưa xử lý', () async {
      final late = Completer<void>();
      await settleWrite(late.future, const Duration(milliseconds: 20));
      late.completeError(FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'));
      // Nhường thời gian cho lỗi lan ra; nếu không được xử lý, test này sẽ thất bại.
      await Future<void>.delayed(const Duration(milliseconds: 60));
    });

    test('lần ghi hoàn tất sau thời gian chờ không gây lỗi', () async {
      final late = Completer<void>();
      await settleWrite(late.future, const Duration(milliseconds: 20));
      late.complete();
      await Future<void>.delayed(const Duration(milliseconds: 30));
    });

    test('nhiều lần ghi chờ song song độc lập với nhau', () async {
      final a = Completer<void>();
      final b = Completer<void>();
      final results = await Future.wait([
        settleWrite(a.future, const Duration(milliseconds: 30)),
        settleWrite(b.future, const Duration(milliseconds: 30)),
        settleWrite(Future<void>.value(), const Duration(seconds: 5)),
      ]);
      expect(results, hasLength(3));
    });

    test('thời gian chờ bằng 0 thì trả về ngay cả khi lần ghi chưa xong', () async {
      final never = Completer<void>();
      await settleWrite(never.future, Duration.zero).timeout(const Duration(seconds: 1));
    });
  });
}
