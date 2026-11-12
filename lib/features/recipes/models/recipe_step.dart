const Object _unset = Object();

/// Một bước nấu theo thứ tự trong công thức.
class RecipeStep {
  const RecipeStep({
    required this.id,
    required this.order,
    required this.text,
    this.imageUrl,
    this.durationSec,
    this.isPlaceholder = false,
  });

  /// uuid ổn định.
  final String id;

  /// Bắt đầu từ 1, liên tục, không trùng trong một công thức.
  final int order;

  /// 1–1000 ký tự (sau khi cắt khoảng trắng).
  final String text;

  final String? imageUrl;

  /// Nếu có thì > 0 và ≤ 86400 (24 giờ).
  final int? durationSec;

  /// `true` chỉ cho bước giữ chỗ do việc chuyển dữ liệu cũ tạo ra.
  final bool isPlaceholder;

  static const int maxTextLength = 1000;
  static const int maxDurationSec = 86400;

  factory RecipeStep.fromMap(Map<String, dynamic> map) {
    return RecipeStep(
      id: (map['id'] as String?) ?? '',
      order: (map['order'] as num?)?.toInt() ?? 0,
      text: (map['text'] as String?) ?? '',
      imageUrl: map['imageUrl'] as String?,
      durationSec: (map['durationSec'] as num?)?.toInt(),
      isPlaceholder: (map['isPlaceholder'] as bool?) ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'order': order,
        'text': text,
        'imageUrl': imageUrl,
        'durationSec': durationSec,
        'isPlaceholder': isPlaceholder,
      };

  RecipeStep copyWith({
    String? id,
    int? order,
    String? text,
    Object? imageUrl = _unset,
    Object? durationSec = _unset,
    bool? isPlaceholder,
  }) {
    return RecipeStep(
      id: id ?? this.id,
      order: order ?? this.order,
      text: text ?? this.text,
      imageUrl: identical(imageUrl, _unset) ? this.imageUrl : imageUrl as String?,
      durationSec: identical(durationSec, _unset) ? this.durationSec : durationSec as int?,
      isPlaceholder: isPlaceholder ?? this.isPlaceholder,
    );
  }

  /// Trả về danh sách mã lỗi; rỗng nghĩa là hợp lệ.
  List<String> validate() {
    final errors = <String>[];
    final n = text.trim().length;
    if (n < 1 || n > maxTextLength) errors.add('text_invalid');
    if (order < 1) errors.add('order_invalid');
    if (durationSec != null && (durationSec! <= 0 || durationSec! > maxDurationSec)) {
      errors.add('duration_invalid');
    }
    return errors;
  }
}
