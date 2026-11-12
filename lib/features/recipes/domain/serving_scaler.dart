import '../models/ingredient.dart';

/// Quy đổi một số lượng từ [baseServings] người ăn sang [targetServings] người.
///
/// - `quantity == null` ("vừa đủ", "tuỳ khẩu vị") giữ nguyên `null`.
/// - Kết quả làm tròn tối đa 2 chữ số thập phân; một lượng dương không bao giờ
///   bị làm tròn xuống 0 (tối thiểu 0,01) để khỏi hiện "0 g" gây hiểu nhầm.
/// - Ném [ArgumentError] nếu [baseServings] hoặc [targetServings] ≤ 0.
double? scaleQuantity(double? quantity, int baseServings, int targetServings) {
  if (baseServings <= 0) {
    throw ArgumentError.value(baseServings, 'baseServings', 'phải lớn hơn 0');
  }
  if (targetServings <= 0) {
    throw ArgumentError.value(targetServings, 'targetServings', 'phải lớn hơn 0');
  }
  if (quantity == null) return null;

  final scaled = quantity * targetServings / baseServings;
  final rounded = (scaled * 100).round() / 100;
  if (quantity > 0 && rounded == 0) return 0.01;
  return rounded;
}

/// Đơn vị đếm theo từng cái: "4,5 tép tỏi" hay "1,5 quả trứng" không dùng được
/// trong bếp nên khi quy đổi, số lượng của các đơn vị này được làm tròn tới số nguyên.
const countableUnits = {
  'quả', 'trái', 'tép', 'củ', 'cái', 'con', 'miếng', 'lát', 'gói', 'hộp', 'lon',
  'chai', 'bó', 'cây', 'nhánh', 'khúc', 'viên', 'túi', 'bịch',
  'piece', 'pieces', 'pc', 'pcs', 'clove', 'cloves', 'egg', 'eggs', 'can', 'cans',
  'bottle', 'bottles', 'pack', 'packs', 'slice', 'slices',
};

/// `true` nếu [unit] là đơn vị đếm (không phân biệt hoa thường, bỏ khoảng trắng thừa).
bool isCountableUnit(String? unit) =>
    unit != null && countableUnits.contains(unit.trim().toLowerCase());

/// Quy đổi cả dòng nguyên liệu. Giá và kcal tính cho đúng lượng `quantity` của
/// dòng đó nên được nhân theo tỉ lệ khẩu phần. Dòng không có số lượng được giữ nguyên
/// hoàn toàn. Không thay đổi đối tượng gốc.
Ingredient scaleIngredient(Ingredient ingredient, int baseServings, int targetServings) {
  var quantity = scaleQuantity(ingredient.quantity, baseServings, targetServings);
  if (ingredient.quantity == null) return ingredient;
  // Đơn vị đếm: làm tròn tới số nguyên gần nhất, ít nhất 1 (không có "0 quả").
  // Chỉ áp dụng khi thật sự đổi khẩu phần; "0,5 quả chanh" gốc giữ nguyên.
  if (baseServings != targetServings && isCountableUnit(ingredient.unit) && quantity! > 0) {
    quantity = quantity.round() < 1 ? 1 : quantity.round().toDouble();
  }
  return ingredient.copyWith(
    quantity: quantity,
    price: scaleQuantity(ingredient.price, baseServings, targetServings),
    kcal: scaleQuantity(ingredient.kcal, baseServings, targetServings),
  );
}
