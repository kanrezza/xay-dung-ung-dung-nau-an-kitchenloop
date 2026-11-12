import 'package:btl_ltdd/features/recipes/data/cooking_session_store.dart';
import 'package:btl_ltdd/features/recipes/models/cooking_session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  String? uid = 'alice';

  setUp(() {
    uid = 'alice';
    SharedPreferences.setMockInitialValues({});
  });

  CookingSessionStore newStore() => CookingSessionStore(uidGetter: () => uid);

  final endAt = DateTime.fromMillisecondsSinceEpoch(1790000123456);

  CookingSession session({String recipeId = 'r1', int stepIndex = 1}) => CookingSession(
        recipeId: recipeId,
        stepIndex: stepIndex,
        servings: 4,
        startedAt: DateTime.fromMillisecondsSinceEpoch(1789999000000),
        timers: [
          StepTimer(stepId: 's2', totalSec: 120, endAt: endAt, notificationId: 4242),
          const StepTimer(stepId: 's3', totalSec: 600, pausedRemainingSec: 321),
        ],
      );

  group('StepTimer', () {
    test('đang chạy: remainingSec tính theo endAt tuyệt đối', () {
      final t = StepTimer(stepId: 's', totalSec: 120, endAt: endAt);
      expect(t.isRunning, isTrue);
      expect(t.isPaused, isFalse);
      expect(t.remainingSec(endAt.subtract(const Duration(seconds: 90))), 90);
      expect(t.remainingSec(endAt.subtract(const Duration(milliseconds: 1500))), 2); // làm tròn lên
      expect(t.remainingSec(endAt), 0);
      expect(t.remainingSec(endAt.add(const Duration(minutes: 5))), 0);
    });

    test('hết giờ khi now ≥ endAt', () {
      final t = StepTimer(stepId: 's', totalSec: 60, endAt: endAt);
      expect(t.isFinished(endAt.subtract(const Duration(milliseconds: 1))), isFalse);
      expect(t.isFinished(endAt), isTrue);
    });

    test('tạm dừng: giữ nguyên số giây còn lại, không phụ thuộc đồng hồ', () {
      const t = StepTimer(stepId: 's', totalSec: 600, pausedRemainingSec: 321);
      expect(t.isPaused, isTrue);
      expect(t.isRunning, isFalse);
      expect(t.remainingSec(DateTime(2030)), 321);
      expect(t.isFinished(DateTime(2030)), isFalse);
    });

    test('chưa chạy: còn nguyên totalSec', () {
      const t = StepTimer(stepId: 's', totalSec: 90);
      expect(t.remainingSec(DateTime.now()), 90);
    });
  });

  group('CookingSession JSON', () {
    test('hai chiều, endAt giữ nguyên chính xác đến mili giây', () {
      final copy = CookingSession.fromJson(session().toJson());
      expect(copy.recipeId, 'r1');
      expect(copy.stepIndex, 1);
      expect(copy.servings, 4);
      expect(copy.startedAt.millisecondsSinceEpoch, 1789999000000);
      expect(copy.timers, hasLength(2));
      expect(copy.timers[0].endAt!.millisecondsSinceEpoch, endAt.millisecondsSinceEpoch);
      expect(copy.timers[0].notificationId, 4242);
      expect(copy.timers[1].endAt, isNull);
      expect(copy.timers[1].pausedRemainingSec, 321);
    });

    test('hasProgress: có khi đã qua bước 1 hoặc có hẹn giờ', () {
      final fresh = CookingSession(recipeId: 'r', stepIndex: 0, servings: 2, startedAt: DateTime(2026));
      expect(fresh.hasProgress, isFalse);
      expect(fresh.copyWith(stepIndex: 1).hasProgress, isTrue);
      expect(fresh.copyWith(timers: const [StepTimer(stepId: 's', totalSec: 10)]).hasProgress, isTrue);
    });
  });

  group('CookingSessionStore', () {
    test('khoá theo dạng cooking_session_<uid>_<recipeId>', () {
      expect(CookingSessionStore.keyFor('alice', 'r1'), 'cooking_session_alice_r1');
    });

    test('save rồi load trả lại đúng phiên', () async {
      final store = newStore();
      await store.save(session());
      final loaded = await store.load('r1');
      expect(loaded, isNotNull);
      expect(loaded!.stepIndex, 1);
      expect(loaded.timers.first.endAt!.millisecondsSinceEpoch, endAt.millisecondsSinceEpoch);
    });

    test('ghi vào SharedPreferences đúng khoá', () async {
      await newStore().save(session());
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('cooking_session_alice_r1'), isTrue);
    });

    test('load khi chưa có → null', () async {
      expect(await newStore().load('khong-co'), isNull);
    });

    test('clear xoá phiên', () async {
      final store = newStore();
      await store.save(session());
      await store.clear('r1');
      expect(await store.load('r1'), isNull);
    });

    test('phiên của từng công thức độc lập', () async {
      final store = newStore();
      await store.save(session(recipeId: 'a', stepIndex: 1));
      await store.save(session(recipeId: 'b', stepIndex: 2));
      expect((await store.load('a'))!.stepIndex, 1);
      expect((await store.load('b'))!.stepIndex, 2);
      await store.clear('a');
      expect(await store.load('a'), isNull);
      expect(await store.load('b'), isNotNull);
    });

    test('phiên của từng tài khoản độc lập', () async {
      final store = newStore();
      await store.save(session());
      uid = 'bob';
      expect(await store.load('r1'), isNull);
      uid = 'alice';
      expect(await store.load('r1'), isNotNull);
    });

    test('chưa đăng nhập: save/load/clear không làm gì và không lỗi', () async {
      uid = null;
      final store = newStore();
      await store.save(session());
      expect(await store.load('r1'), isNull);
      await store.clear('r1');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getKeys(), isEmpty);
    });

    test('dữ liệu hỏng → null và được dọn đi, không ném lỗi', () async {
      SharedPreferences.setMockInitialValues({'cooking_session_alice_r1': '{không phải json'});
      final store = newStore();
      expect(await store.load('r1'), isNull);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('cooking_session_alice_r1'), isFalse);
    });

    test('JSON hợp lệ nhưng sai cấu trúc → null', () async {
      SharedPreferences.setMockInitialValues({'cooking_session_alice_r1': '{"stepIndex":"abc"}'});
      expect(await newStore().load('r1'), isNull);
    });
  });
}
