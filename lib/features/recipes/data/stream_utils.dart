import 'dart:async';

/// Với mỗi phần tử của [source], hủy luồng con trước đó và đăng ký luồng con
/// mới do [mapper] tạo ra (kiểu `switchMap` của Rx). Dùng để đổi truy vấn khi
/// người dùng đăng nhập/đăng xuất.
Stream<R> switchMapStream<T, R>(Stream<T> source, Stream<R> Function(T value) mapper) {
  late StreamController<R> controller;
  StreamSubscription<T>? outer;
  StreamSubscription<R>? inner;
  var outerDone = false;

  void closeIfDone() {
    if (outerDone && inner == null && !controller.isClosed) controller.close();
  }

  controller = StreamController<R>(
    onListen: () {
      outer = source.listen(
        (value) {
          inner?.cancel();
          final stream = mapper(value);
          inner = stream.listen(
            controller.add,
            onError: controller.addError,
            onDone: () {
              inner = null;
              closeIfDone();
            },
          );
        },
        onError: controller.addError,
        onDone: () {
          outerDone = true;
          closeIfDone();
        },
      );
    },
    onCancel: () async {
      await inner?.cancel();
      await outer?.cancel();
    },
  );
  return controller.stream;
}
