import 'package:btl_ltdd/features/recipes/data/cooking_session_store.dart';
import 'package:btl_ltdd/features/recipes/models/cooking_session.dart';
import 'package:btl_ltdd/features/recipes/providers/cooking_mode_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/cooking_fakes.dart';

void main() {
  late DateTime clock;
  late FakeTimerNotifier notifier;
  late FakeScreenAwake awake;
  late CookingSessionStore store;
  final created = <CookingModeProvider>[];

  setUp(() {
    clock = DateTime(2026, 6, 1, 12, 0, 0);
    notifier = FakeTimerNotifier();
    awake = FakeScreenAwake();
    SharedPreferences.setMockInitialValues({});
    store = CookingSessionStore(uidGetter: () => 'alice');
  });

  tearDown(() {
    for (final p in created) {
      p.dispose();
    }
    created.clear();
  });

  CookingModeProvider make() {
    final p = CookingModeProvider(
      recipe: cookingRecipe(),
      store: store,
      notifier: notifier,
      awake: awake,
      now: () => clock,
      tickInterval: const Duration(days: 1), // test tự gọi onTick()
      timerTitle: (step) => 'Hết giờ: bước ${step.order}',
      timerBody: (step) => step.text,
    );
    created.add(p);
    return p;
  }

  Future<CookingModeProvider> begun() async {
    final p = make();
    await p.begin();
    return p;
  }

  void passTime(Duration d) => clock = clock.add(d);

  group('bắt đầu', () {
    test('bước đầu tiên, khẩu phần gốc, bật giữ màn hình sáng', () async {
      final p = await begun();
      expect(p.isActive, isTrue);
      expect(p.stepIndex, 0);
      expect(p.servings, 2);
      expect(p.stepCount, 3);
      expect(p.isFinished, isFalse);
      expect(awake.enabled, isTrue);
    });

    test('loadSavedSession: không có phiên → null', () async {
      expect(await make().loadSavedSession(), isNull);
    });

    test('loadSavedSession: phiên chưa tiến triển (bước 1, không hẹn giờ) → null', () async {
      await store.save(CookingSession(recipeId: 'r1', stepIndex: 0, servings: 2, startedAt: clock));
      expect(await make().loadSavedSession(), isNull);
    });

    test('loadSavedSession: phiên dở dang được trả về', () async {
      await store.save(CookingSession(recipeId: 'r1', stepIndex: 1, servings: 3, startedAt: clock));
      final saved = await make().loadSavedSession();
      expect(saved!.stepIndex, 1);
      expect(saved.servings, 3);
    });
  });

  group('điều hướng', () {
    test('không lùi quá bước 1', () async {
      final p = await begun();
      p.previous();
      expect(p.stepIndex, 0);
      expect(p.canGoPrevious, isFalse);
    });

    test('tiến và lùi', () async {
      final p = await begun();
      p.next();
      p.next();
      expect(p.stepIndex, 2);
      expect(p.isLastStep, isTrue);
      p.previous();
      expect(p.stepIndex, 1);
    });

    test('goTo bị giới hạn trong phạm vi hợp lệ', () async {
      final p = await begun();
      p.goTo(99);
      expect(p.stepIndex, 2);
      p.goTo(-5);
      expect(p.stepIndex, 0);
    });

    test('bước cuối bấm Tiếp → hoàn thành', () async {
      final p = await begun();
      p.goTo(2);
      p.next();
      expect(p.isFinished, isTrue);
      expect(p.isActive, isFalse);
    });

    test('hoàn thành: xoá phiên đã lưu, tắt giữ màn hình, huỷ các hẹn giờ đang chạy', () async {
      final p = await begun();
      p.goTo(1);
      await p.startTimer('s2');
      final id = notifier.scheduled.single.id;
      expect(await store.load('r1'), isNotNull);

      await p.finish();
      expect(await store.load('r1'), isNull);
      expect(awake.enabled, isFalse);
      expect(notifier.cancelled, contains(id));
    });

    test('lưu phiên mỗi lần đổi bước', () async {
      final p = await begun();
      p.next();
      await pumpEventQueue();
      expect((await store.load('r1'))!.stepIndex, 1);
      p.next();
      await pumpEventQueue();
      expect((await store.load('r1'))!.stepIndex, 2);
    });
  });

  group('khẩu phần ban đầu', () {
    CookingModeProvider makeWith(int? initial) {
      final p = CookingModeProvider(
        recipe: cookingRecipe(),
        store: store,
        notifier: notifier,
        awake: awake,
        now: () => clock,
        tickInterval: const Duration(days: 1),
        timerTitle: (_) => 't',
        timerBody: (_) => 'b',
        initialServings: initial,
      );
      created.add(p);
      return p;
    }

    test('mặc định là khẩu phần gốc của công thức', () {
      expect(makeWith(null).servings, 2);
    });

    test('dùng khẩu phần người dùng đã chọn ở màn hình chi tiết', () async {
      final p = makeWith(5);
      await p.begin();
      expect(p.servings, 5);
    });

    test('giá trị không hợp lệ (0, âm, quá 100) quay về khẩu phần gốc', () {
      expect(makeWith(0).servings, 2);
      expect(makeWith(-4).servings, 2);
      expect(makeWith(101).servings, 2);
    });

    test('tiếp tục phiên dở thì dùng khẩu phần đã lưu, không dùng giá trị ban đầu', () async {
      final saved = CookingSession(recipeId: 'r1', stepIndex: 1, servings: 3, startedAt: clock);
      final p = makeWith(8);
      await p.begin(resumeFrom: saved);
      expect(p.servings, 3);
    });
  });

  group('khẩu phần', () {
    test('đổi và được lưu cùng phiên', () async {
      final p = await begun();
      p.setServings(5);
      await pumpEventQueue();
      expect(p.servings, 5);
      expect((await store.load('r1'))!.servings, 5);
    });

    test('0, âm hoặc quá 100 bị từ chối, giữ giá trị cũ', () async {
      final p = await begun();
      expect(p.setServings(0), isFalse);
      expect(p.setServings(-3), isFalse);
      expect(p.setServings(101), isFalse);
      expect(p.servings, 2);
      expect(p.setServings(100), isTrue);
    });
  });

  group('hẹn giờ', () {
    test('bắt đầu: lên lịch thông báo đúng thời điểm kết thúc tuyệt đối', () async {
      final p = await begun();
      await p.startTimer('s2');
      expect(notifier.permissionRequests, 1);
      final call = notifier.scheduled.single;
      expect(call.endAt, clock.add(const Duration(seconds: 120)));
      expect(call.title, 'Hết giờ: bước 2');
      expect(call.body, 'Luộc trứng');
      expect(p.stateOf('s2'), TimerState.running);
      expect(p.remainingSec('s2'), 120);
    });

    test('còn lại = endAt - now, kể cả khi thời gian trôi lúc app ở nền (không có tick)', () async {
      final p = await begun();
      await p.startTimer('s2');
      p.setForeground(false);
      passTime(const Duration(seconds: 45)); // không ai gọi onTick
      expect(p.remainingSec('s2'), 75);
      passTime(const Duration(seconds: 70)); // tổng 115 giây < 120
      expect(p.remainingSec('s2'), 5);
      passTime(const Duration(seconds: 10)); // tổng 125 giây ≥ 120
      expect(p.remainingSec('s2'), 0);
    });

    test('bước không có thời gian: bỏ qua', () async {
      final p = await begun();
      await p.startTimer('s1');
      expect(p.stateOf('s1'), TimerState.idle);
      expect(notifier.scheduled, isEmpty);
    });

    test('bước không tồn tại: bỏ qua', () async {
      final p = await begun();
      await p.startTimer('khong-co');
      expect(notifier.scheduled, isEmpty);
    });

    test('bắt đầu hai lần liên tiếp chỉ lên lịch một lần', () async {
      final p = await begun();
      await p.startTimer('s2');
      await p.startTimer('s2');
      expect(notifier.scheduled, hasLength(1));
    });

    test('tạm dừng: huỷ thông báo và giữ số giây còn lại', () async {
      final p = await begun();
      await p.startTimer('s2');
      final id = notifier.scheduled.single.id;
      passTime(const Duration(seconds: 30));
      await p.pauseTimer('s2');
      expect(notifier.cancelled, [id]);
      expect(p.stateOf('s2'), TimerState.paused);
      expect(p.remainingSec('s2'), 90);

      passTime(const Duration(minutes: 10)); // đang tạm dừng: không giảm
      expect(p.remainingSec('s2'), 90);
    });

    test('tiếp tục sau tạm dừng: lên lịch lại theo số giây còn lại', () async {
      final p = await begun();
      await p.startTimer('s2');
      passTime(const Duration(seconds: 30));
      await p.pauseTimer('s2');
      passTime(const Duration(minutes: 3));
      await p.startTimer('s2');
      expect(notifier.scheduled, hasLength(2));
      expect(notifier.scheduled.last.endAt, clock.add(const Duration(seconds: 90)));
      expect(p.stateOf('s2'), TimerState.running);
    });

    test('đặt lại: huỷ thông báo và trở về trạng thái chưa chạy', () async {
      final p = await begun();
      await p.startTimer('s2');
      final id = notifier.scheduled.single.id;
      await p.resetTimer('s2');
      expect(notifier.cancelled, [id]);
      expect(p.stateOf('s2'), TimerState.idle);
      expect(p.remainingSec('s2'), 120);
    });

    test('đặt lại khi đang tạm dừng không cần huỷ thông báo nữa', () async {
      final p = await begun();
      await p.startTimer('s2');
      await p.pauseTimer('s2');
      notifier.cancelled.clear();
      await p.resetTimer('s2');
      expect(notifier.cancelled, isEmpty);
      expect(p.stateOf('s2'), TimerState.idle);
    });

    test('nhiều hẹn giờ chạy song song, kể cả khi đã chuyển sang bước khác', () async {
      final p = await begun();
      p.goTo(1);
      await p.startTimer('s2');
      p.goTo(2);
      await p.startTimer('s3');
      p.goTo(0);
      expect(p.stateOf('s2'), TimerState.running);
      expect(p.stateOf('s3'), TimerState.running);
      expect(p.activeTimers.map((t) => t.stepId), ['s2', 's3']);
    });

    test('bị từ chối quyền thông báo: vẫn chạy hẹn giờ trong app, không lên lịch', () async {
      notifier.permissionResult = false;
      final p = await begun();
      await p.startTimer('s2');
      expect(p.stateOf('s2'), TimerState.running);
      expect(notifier.scheduled, isEmpty);
      expect(p.notificationsDenied, isTrue);
    });

    test('chỉ xin quyền thông báo một lần cho mỗi phiên nấu', () async {
      final p = await begun();
      await p.startTimer('s2');
      await p.startTimer('s3');
      expect(notifier.permissionRequests, 1);
    });

    test('hết giờ khi đang ở nền: KHÔNG huỷ thông báo, chưa báo trong app', () async {
      final p = await begun();
      await p.startTimer('s2');
      p.setForeground(false);
      passTime(const Duration(seconds: 130));
      p.onTick();
      expect(p.alarms, isEmpty);
      expect(notifier.cancelled, isEmpty);
    });

    test('hết giờ khi đang mở app: báo trong app và huỷ thông báo để khỏi báo hai lần', () async {
      final p = await begun();
      await p.startTimer('s2');
      final id = notifier.scheduled.single.id;
      passTime(const Duration(seconds: 121));
      p.onTick();
      expect(p.alarms, {'s2'});
      expect(p.stateOf('s2'), TimerState.finished);
      expect(notifier.cancelled, [id]);
      p.onTick(); // không báo lại
      expect(notifier.cancelled, [id]);
    });

    test('quay lại app sau khi hết giờ lúc ở nền: báo trong app', () async {
      final p = await begun();
      await p.startTimer('s2');
      p.setForeground(false);
      passTime(const Duration(minutes: 5));
      p.setForeground(true);
      expect(p.alarms, {'s2'});
      expect(p.stateOf('s2'), TimerState.finished);
    });

    test('acknowledgeAlarm tắt cảnh báo nhưng hẹn giờ vẫn ở trạng thái hết giờ', () async {
      final p = await begun();
      await p.startTimer('s2');
      passTime(const Duration(seconds: 121));
      p.onTick();
      p.acknowledgeAlarm('s2');
      expect(p.alarms, isEmpty);
      expect(p.stateOf('s2'), TimerState.finished);
    });

    test('bắt đầu lại hẹn giờ đã hết giờ: chạy lại từ đầu', () async {
      final p = await begun();
      await p.startTimer('s2');
      passTime(const Duration(seconds: 121));
      p.onTick();
      await p.startTimer('s2');
      expect(p.stateOf('s2'), TimerState.running);
      expect(p.remainingSec('s2'), 120);
      expect(notifier.scheduled, hasLength(2));
    });
  });

  group('thoát và xuống nền', () {
    test('thoát chế độ nấu KHÔNG huỷ thông báo đã lên lịch và vẫn giữ phiên', () async {
      final p = await begun();
      p.goTo(1);
      await p.startTimer('s2');
      await pumpEventQueue();
      p.dispose();
      created.remove(p);
      await pumpEventQueue();

      expect(notifier.cancelled, isEmpty);
      expect(notifier.cancelAllCalls, 0);
      final saved = await store.load('r1');
      expect(saved!.timers.single.stepId, 's2');
      expect(saved.timers.single.endAt, clock.add(const Duration(seconds: 120)));
    });

    test('thoát: tắt giữ màn hình sáng', () async {
      final p = await begun();
      expect(awake.enabled, isTrue);
      p.dispose();
      created.remove(p);
      await pumpEventQueue();
      expect(awake.enabled, isFalse);
    });

    test('xuống nền: tắt giữ màn hình, không huỷ thông báo; về lại: bật lại', () async {
      final p = await begun();
      await p.startTimer('s2');
      p.setForeground(false);
      await pumpEventQueue();
      expect(awake.enabled, isFalse);
      expect(notifier.cancelled, isEmpty);

      p.setForeground(true);
      await pumpEventQueue();
      expect(awake.enabled, isTrue);
    });

    test('đã hoàn thành thì về lại từ nền không bật giữ màn hình nữa', () async {
      final p = await begun();
      await p.finish();
      p.setForeground(false);
      p.setForeground(true);
      await pumpEventQueue();
      expect(awake.enabled, isFalse);
    });
  });

  group('tiếp tục phiên dở', () {
    test('khôi phục bước, khẩu phần và hẹn giờ đang chạy', () async {
      final endAt = clock.add(const Duration(seconds: 80));
      final saved = CookingSession(
        recipeId: 'r1',
        stepIndex: 1,
        servings: 4,
        startedAt: clock.subtract(const Duration(minutes: 5)),
        timers: [StepTimer(stepId: 's2', totalSec: 120, endAt: endAt, notificationId: 7)],
      );
      final p = make();
      await p.begin(resumeFrom: saved);
      expect(p.stepIndex, 1);
      expect(p.servings, 4);
      expect(p.stateOf('s2'), TimerState.running);
      expect(p.remainingSec('s2'), 80);
      expect(p.alarms, isEmpty);
    });

    test('hẹn giờ đã hết trong lúc thoát: báo ngay khi quay lại', () async {
      final saved = CookingSession(
        recipeId: 'r1',
        stepIndex: 1,
        servings: 2,
        startedAt: clock.subtract(const Duration(minutes: 10)),
        timers: [
          StepTimer(
            stepId: 's2',
            totalSec: 120,
            endAt: clock.subtract(const Duration(minutes: 2)),
            notificationId: 9,
          ),
        ],
      );
      final p = make();
      await p.begin(resumeFrom: saved);
      expect(p.alarms, {'s2'});
      expect(p.stateOf('s2'), TimerState.finished);
    });

    test('bỏ qua hẹn giờ của bước không còn tồn tại và chỉ số bước vượt giới hạn', () async {
      final saved = CookingSession(
        recipeId: 'r1',
        stepIndex: 99,
        servings: 2,
        startedAt: clock,
        timers: const [StepTimer(stepId: 'khong-co', totalSec: 10, pausedRemainingSec: 5)],
      );
      final p = make();
      await p.begin(resumeFrom: saved);
      expect(p.stepIndex, 2);
      expect(p.activeTimers, isEmpty);
    });

    test('discardSaved: huỷ thông báo của phiên cũ và xoá phiên', () async {
      final saved = CookingSession(
        recipeId: 'r1',
        stepIndex: 1,
        servings: 2,
        startedAt: clock,
        timers: [StepTimer(stepId: 's2', totalSec: 120, endAt: clock.add(const Duration(minutes: 1)), notificationId: 55)],
      );
      await store.save(saved);
      final p = make();
      await p.discardSaved(saved);
      expect(notifier.cancelled, [55]);
      expect(await store.load('r1'), isNull);
    });
  });
}
