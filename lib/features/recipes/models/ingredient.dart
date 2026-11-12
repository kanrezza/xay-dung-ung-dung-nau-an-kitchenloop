/// Giá trị đánh dấu "không truyền" cho các tham số tuỳ chọn của `copyWith`,
/// để phân biệt "giữ nguyên" với "đặt về null".
const Object _unset = Object();

/// Một dòng nguyên liệu. Đây là mô hình dùng chung cho mọi giai đoạn
/// (công thức, tủ lạnh, đi chợ, thống kê) — xem data-model.md.
class Ingredient {
  const Ingredient({
    required this.id,
    required this.name,
    this.quantity,
    this.unit,
    this.price,
    this.kcal,
    this.isPlaceholder = false,
  });

  /// uuid ổn định giữa các lần sửa.
  final String id;

  /// 1–100 ký tự (sau khi cắt khoảng trắng).
  final String name;

  /// `null` nghĩa là "vừa đủ/tuỳ khẩu vị" và không bị nhân khi đổi khẩu phần.
  /// Nếu có thì ≥ 0.
  final double? quantity;

  /// Tối đa 20 ký tự.
  final String? unit;

  /// ≥ 0, đơn vị VND, tính cho đúng lượng [quantity] của dòng này.
  final double? price;

  /// ≥ 0, tính cho đúng lượng [quantity] của dòng này.
  final double? kcal;

  /// `true` chỉ cho dòng giữ chỗ do việc chuyển dữ liệu cũ tạo ra.
  final bool isPlaceholder;

  static const int maxNameLength = 100;
  static const int maxUnitLength = 20;

  factory Ingredient.fromMap(Map<String, dynamic> map) {
    return Ingredient(
      id: (map['id'] as String?) ?? '',
      name: (map['name'] as String?) ?? '',
      quantity: (map['quantity'] as num?)?.toDouble(),
      unit: map['unit'] as String?,
      price: (map['price'] as num?)?.toDouble(),
      kcal: (map['kcal'] as num?)?.toDouble(),
      isPlaceholder: (map['isPlaceholder'] as bool?) ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'quantity': quantity,
        'unit': unit,
        'price': price,
        'kcal': kcal,
        'isPlaceholder': isPlaceholder,
      };

  Ingredient copyWith({
    String? id,
    String? name,
    Object? quantity = _unset,
    Object? unit = _unset,
    Object? price = _unset,
    Object? kcal = _unset,
    bool? isPlaceholder,
  }) {
    return Ingredient(
      id: id ?? this.id,
      name: name ?? this.name,
      quantity: identical(quantity, _unset) ? this.quantity : quantity as double?,
      unit: identical(unit, _unset) ? this.unit : unit as String?,
      price: identical(price, _unset) ? this.price : price as double?,
      kcal: identical(kcal, _unset) ? this.kcal : kcal as double?,
      isPlaceholder: isPlaceholder ?? this.isPlaceholder,
    );
  }

  /// Trả về danh sách mã lỗi; rỗng nghĩa là hợp lệ.
  List<String> validate() {
    final errors = <String>[];
    final n = name.trim().length;
    if (n < 1 || n > maxNameLength) errors.add('name_invalid');
    if (quantity != null && quantity! < 0) errors.add('quantity_negative');
    if (unit != null && unit!.length > maxUnitLength) errors.add('unit_too_long');
    if (price != null && price! < 0) errors.add('price_negative');
    if (kcal != null && kcal! < 0) errors.add('kcal_negative');
    return errors;
  }
}
