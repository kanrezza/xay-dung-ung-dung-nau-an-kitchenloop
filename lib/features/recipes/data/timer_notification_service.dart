import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'timer_notifier.dart';

/// Báo hết giờ khi ứng dụng ở nền bằng thông báo cục bộ đã lên lịch sẵn.
///
/// Thời điểm lên lịch là một mốc tuyệt đối (UTC) nên không phụ thuộc múi giờ
/// của thiết bị. Nếu thiết bị không cho báo thức chính xác thì dùng lịch gần
/// đúng (có thể trễ vài chục giây); ứng dụng vẫn báo đúng giờ khi đang mở.
class TimerNotificationService implements TimerNotifier {
  TimerNotificationService({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  Future<void>? _initFuture;
  int _lastId = 0;

  static const String _channelId = 'step_timers';

  static const NotificationDetails _details = NotificationDetails(
    android: AndroidNotificationDetails(
      _channelId,
      'Hẹn giờ nấu ăn',
      channelDescription: 'Báo khi hết giờ của một bước nấu',
      importance: Importance.max,
      priority: Priority.high,
      category: AndroidNotificationCategory.alarm,
    ),
    iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
  );

  bool get _isAndroid => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  bool get _isIOS => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
  bool get _isSupported => _isAndroid || _isIOS;

  /// Khởi tạo một lần, khi cần dùng lần đầu. Không tự xin quyền lúc khởi tạo.
  Future<void> _ensureInitialized() => _initFuture ??= _initialize();

  Future<void> _initialize() async {
    tzdata.initializeTimeZones();
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
  }

  /// Mã thông báo tăng dần, nằm trong khoảng số nguyên 32 bit dương.
  int _newId() {
    final base = (DateTime.now().millisecondsSinceEpoch ~/ 1000) & 0x7FFFFFFF;
    _lastId = math.max(_lastId + 1, base);
    return _lastId;
  }

  @override
  Future<bool> requestPermission() async {
    if (!_isSupported) return false;
    await _ensureInitialized();
    if (_isAndroid) {
      final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      return await android?.requestNotificationsPermission() ?? false;
    }
    final ios = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    return await ios?.requestPermissions(alert: true, sound: true) ?? false;
  }

  @override
  Future<int> schedule({required DateTime endAt, required String title, required String body}) async {
    if (!_isSupported) throw UnsupportedError('Thông báo hẹn giờ chỉ hỗ trợ Android và iOS');
    await _ensureInitialized();

    var mode = AndroidScheduleMode.exactAllowWhileIdle;
    if (_isAndroid) {
      final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      final canExact = await android?.canScheduleExactNotifications() ?? false;
      if (!canExact) mode = AndroidScheduleMode.inexactAllowWhileIdle;
    }

    final id = _newId();
    await _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: tz.TZDateTime.from(endAt, tz.UTC),
      notificationDetails: _details,
      androidScheduleMode: mode,
    );
    return id;
  }

  @override
  Future<void> cancel(int notificationId) async {
    if (!_isSupported) return;
    await _ensureInitialized();
    await _plugin.cancel(id: notificationId);
  }

  @override
  Future<void> cancelAll() async {
    if (!_isSupported) return;
    await _ensureInitialized();
    await _plugin.cancelAll();
  }
}
