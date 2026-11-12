import 'package:btl_ltdd/features/recipes/data/screen_awake.dart';
import 'package:btl_ltdd/features/recipes/data/timer_notifier.dart';
import 'package:btl_ltdd/features/recipes/models/ingredient.dart';
import 'package:btl_ltdd/features/recipes/models/recipe.dart';
import 'package:btl_ltdd/features/recipes/models/recipe_step.dart';

/// Một lần gọi `schedule` của [FakeTimerNotifier].
class ScheduledCall {
  ScheduledCall(this.id, this.endAt, this.title, this.body);

  final int id;
  final DateTime endAt;
  final String title;
  final String body;
}

/// Bản giả của [TimerNotifier]: ghi lại mọi lần lên lịch/huỷ để kiểm tra.
class FakeTimerNotifier implements TimerNotifier {
  bool permissionResult = true;
  int permissionRequests = 0;
  final scheduled = <ScheduledCall>[];
  final cancelled = <int>[];
  int cancelAllCalls = 0;
  int _nextId = 100;

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return permissionResult;
  }

  @override
  Future<int> schedule({required DateTime endAt, required String title, required String body}) async {
    final id = _nextId++;
    scheduled.add(ScheduledCall(id, endAt, title, body));
    return id;
  }

  @override
  Future<void> cancel(int notificationId) async => cancelled.add(notificationId);

  @override
  Future<void> cancelAll() async => cancelAllCalls++;
}

/// Bản giả của [ScreenAwake]: ghi lại trạng thái bật/tắt.
class FakeScreenAwake implements ScreenAwake {
  bool enabled = false;
  final log = <String>[];

  @override
  Future<void> enable() async {
    enabled = true;
    log.add('enable');
  }

  @override
  Future<void> disable() async {
    enabled = false;
    log.add('disable');
  }
}

/// Công thức mẫu: bước 1 không có thời gian, bước 2 là 2 phút, bước 3 là 10 phút.
Recipe cookingRecipe({String id = 'r1'}) => Recipe(
      id: id,
      ownerId: 'alice',
      title: 'Thịt kho trứng',
      baseServings: 2,
      ingredients: const [
        Ingredient(id: 'i1', name: 'thịt', quantity: 200, unit: 'g'),
        Ingredient(id: 'i2', name: 'trứng', quantity: 4, unit: 'quả'),
      ],
      steps: const [
        RecipeStep(id: 's1', order: 1, text: 'Sơ chế nguyên liệu'),
        RecipeStep(id: 's2', order: 2, text: 'Luộc trứng', durationSec: 120),
        RecipeStep(id: 's3', order: 3, text: 'Kho thịt với trứng', durationSec: 600),
      ],
    );
