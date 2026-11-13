/// Món lẻ người dùng tự thêm vào danh sách đi chợ (ngoài thực đơn).
class ShoppingExtra {
  const ShoppingExtra({required this.id, required this.name, this.quantity, this.unit});

  final String id;
  final String name;
  final double? quantity;
  final String? unit;

  Map<String, dynamic> toMap() => {'id': id, 'name': name, 'quantity': quantity, 'unit': unit};

  static ShoppingExtra? fromMap(Object? raw) {
    if (raw is! Map || raw['id'] is! String || raw['name'] is! String) return null;
    final q = raw['quantity'];
    return ShoppingExtra(
      id: raw['id'] as String,
      name: raw['name'] as String,
      quantity: q is num ? q.toDouble() : null,
      unit: raw['unit'] is String && (raw['unit'] as String).trim().isNotEmpty ? raw['unit'] as String : null,
    );
  }
}

/// Phần người dùng tự quản lý của danh sách đi chợ một tuần: đã mua gì, món lẻ nào.
/// Danh sách nguyên liệu thì luôn được tính lại từ thực đơn (không lưu).
class ShoppingState {
  const ShoppingState({this.checked = const {}, this.extras = const []});

  /// Khoá của các dòng đã mua (xem `ShoppingItem.key`).
  final Set<String> checked;
  final List<ShoppingExtra> extras;

  static const maxChecked = 500;
  static const maxExtras = 100;

  ShoppingState copyWith({Set<String>? checked, List<ShoppingExtra>? extras}) =>
      ShoppingState(checked: checked ?? this.checked, extras: extras ?? this.extras);

  Map<String, dynamic> toMap({required String ownerId, required String weekKey}) => {
        'ownerId': ownerId,
        'weekStart': weekKey,
        'checked': checked.toList()..sort(),
        'extras': extras.map((e) => e.toMap()).toList(),
      };

  factory ShoppingState.fromMap(Map<String, dynamic>? data) {
    final checked = data?['checked'];
    final extras = data?['extras'];
    return ShoppingState(
      checked: checked is List ? checked.whereType<String>().toSet() : <String>{},
      extras: extras is List ? extras.map(ShoppingExtra.fromMap).whereType<ShoppingExtra>().toList() : const [],
    );
  }
}
