/// Cổng báo "hết giờ" khi ứng dụng ở nền. Tách thành giao diện để provider
/// test được bằng bản giả; bản thật là `TimerNotificationService`.
abstract class TimerNotifier {
  /// Xin quyền thông báo (và quyền báo thức chính xác nếu cần). Trả về `false`
  /// nếu người dùng từ chối; khi đó ứng dụng vẫn báo trong lúc đang mở.
  Future<bool> requestPermission();

  /// Lên lịch một thông báo tại thời điểm tuyệt đối [endAt]; trả về mã thông báo.
  Future<int> schedule({required DateTime endAt, required String title, required String body});

  /// Huỷ một thông báo đã lên lịch.
  Future<void> cancel(int notificationId);

  /// Huỷ mọi thông báo đã lên lịch (dùng khi đăng xuất).
  Future<void> cancelAll();
}
