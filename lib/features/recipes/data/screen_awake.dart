import 'package:flutter/foundation.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Cổng giữ màn hình luôn sáng trong chế độ nấu. Tách thành giao diện để
/// provider test được bằng bản giả.
abstract class ScreenAwake {
  Future<void> enable();
  Future<void> disable();
}

/// Bản thật dùng `wakelock_plus`. Lỗi nền tảng (ví dụ nền tảng không hỗ trợ)
/// chỉ được ghi log, không làm hỏng chế độ nấu.
class WakelockScreenAwake implements ScreenAwake {
  const WakelockScreenAwake();

  @override
  Future<void> enable() => _safely(() => WakelockPlus.enable());

  @override
  Future<void> disable() => _safely(() => WakelockPlus.disable());

  Future<void> _safely(Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      debugPrint('Không điều khiển được chế độ giữ màn hình sáng: $e');
    }
  }
}
