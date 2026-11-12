import 'package:cloud_firestore/cloud_firestore.dart';

/// Đổi đệ quy mọi [Timestamp] trong dữ liệu đọc từ Firestore thành [DateTime].
///
/// Đây là ranh giới giữa Firestore và phần còn lại của tính năng: model và logic
/// nghiệp vụ chỉ làm việc với `DateTime` thuần, không biết tới `cloud_firestore`
/// (Constitution IV). Chiều ghi không cần đổi ngược: Firestore tự chuyển
/// `DateTime` thành `Timestamp` khi lưu.
Object? decodeFirestoreValue(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is Map) {
    return <String, dynamic>{for (final e in value.entries) e.key.toString(): decodeFirestoreValue(e.value)};
  }
  if (value is List) return [for (final e in value) decodeFirestoreValue(e)];
  return value;
}

Map<String, dynamic> decodeFirestoreMap(Map<String, dynamic> data) =>
    decodeFirestoreValue(data)! as Map<String, dynamic>;
