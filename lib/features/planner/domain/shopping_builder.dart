import '../../recipes/domain/serving_scaler.dart';
import '../../recipes/domain/text_normalizer.dart';
import '../../recipes/models/recipe.dart';
import '../models/shopping_state.dart';
import '../models/week_plan.dart';

/// Một dòng của danh sách đi chợ.
class ShoppingItem {
  const ShoppingItem({
    required this.key,
    required this.name,
    this.quantity,
    this.unit,
    this.sources = const [],
    this.extraId,
  });

  /// Khoá bền (tên chuẩn hoá + nhóm đơn vị) để nhớ "đã mua" khi thực đơn thay đổi.
  final String key;
  final String name;

  /// `null`: không có số lượng ("tiêu vừa đủ").
  final double? quantity;
  final String? unit;

  /// Tên các món dùng nguyên liệu này.
  final List<String> sources;

  /// Món lẻ do người dùng thêm (không từ thực đơn).
  final String? extraId;

  bool get isExtra => extraId != null;
}

class ShoppingListResult {
  const ShoppingListResult({required this.items, this.missingRecipes = const []});

  final List<ShoppingItem> items;

  /// Món trong thực đơn mà công thức đã bị xoá (không tính được nguyên liệu).
  final List<String> missingRecipes;
}

/// Nhóm đơn vị: khối lượng (quy về g), thể tích (quy về ml), hoặc giữ nguyên đơn vị.
class _Unit {
  const _Unit(this.group, this.factor);

  /// `g`, `ml`, hoặc chính đơn vị đã chuẩn hoá.
  final String group;

  /// Nhân với số lượng để ra đơn vị gốc của nhóm.
  final double factor;
}

const _mass = {'g': 1.0, 'gr': 1.0, 'gam': 1.0, 'gram': 1.0, 'grams': 1.0, 'kg': 1000.0, 'kilogram': 1000.0, 'ký': 1000.0, 'cân': 1000.0, 'lạng': 100.0};
const _volume = {'ml': 1.0, 'mililit': 1.0, 'l': 1000.0, 'lít': 1000.0, 'lit': 1000.0, 'liter': 1000.0, 'litre': 1000.0};

_Unit _unitOf(String? raw) {
  final u = (raw ?? '').trim().toLowerCase();
  if (_mass.containsKey(u)) return _Unit('g', _mass[u]!);
  if (_volume.containsKey(u)) return _Unit('ml', _volume[u]!);
  return _Unit(u, 1);
}

/// Hiển thị khối lượng/thể tích lớn theo kg/lít: 1500 g → 1,5 kg.
({double quantity, String unit}) _display(double base, String group) {
  if (group == 'g' && base >= 1000) return (quantity: base / 1000, unit: 'kg');
  if (group == 'ml' && base >= 1000) return (quantity: base / 1000, unit: 'l');
  return (quantity: base, unit: group);
}

class _Acc {
  _Acc(this.name, this.group);

  final String name;
  final String group;
  double? total;
  final Set<String> sources = {};
}

/// Tạo danh sách đi chợ từ [plan] và sổ công thức [recipes] (theo id), cộng thêm [extras].
///
/// - Số lượng được quy đổi theo số người ăn của từng bữa (`servings / baseServings`).
/// - Gộp theo tên (không phân biệt hoa thường, dấu) và nhóm đơn vị; g/kg/lạng, ml/lít được quy đổi.
/// - Đơn vị đếm (quả, tép...) được làm tròn LÊN: đi chợ không mua được 4,5 quả trứng.
/// - Dòng giữ chỗ và nguyên liệu không tên bị bỏ qua.
ShoppingListResult buildShoppingList({
  required WeekPlan plan,
  required Map<String, Recipe> recipes,
  List<ShoppingExtra> extras = const [],
}) {
  final acc = <String, _Acc>{};
  final missing = <String>{};

  for (final entry in plan.entries) {
    final recipe = recipes[entry.recipeId];
    if (recipe == null) {
      missing.add(entry.title);
      continue;
    }
    for (final ing in recipe.ingredients) {
      final name = ing.name.trim();
      if (ing.isPlaceholder || name.isEmpty) continue;
      final unit = _unitOf(ing.unit);
      final key = '${normalizeForSearch(name)}|${unit.group}';
      final item = acc.putIfAbsent(key, () => _Acc(name, unit.group));
      item.sources.add(recipe.title);
      if (ing.quantity != null && recipe.baseServings > 0) {
        final scaled = ing.quantity! * entry.servings / recipe.baseServings * unit.factor;
        item.total = (item.total ?? 0) + scaled;
      }
    }
  }

  final items = <ShoppingItem>[];
  acc.forEach((key, a) {
    double? quantity;
    String? unit = a.group.isEmpty ? null : a.group;
    if (a.total != null) {
      if (a.group == 'g' || a.group == 'ml') {
        final d = _display(a.total!, a.group);
        quantity = (d.quantity * 100).round() / 100;
        unit = d.unit;
      } else if (isCountableUnit(a.group)) {
        quantity = (a.total! - 1e-9).ceilToDouble();
      } else {
        quantity = (a.total! * 100).round() / 100;
      }
    }
    items.add(ShoppingItem(key: key, name: a.name, quantity: quantity, unit: unit, sources: a.sources.toList()));
  });
  items.sort((x, y) => normalizeForSearch(x.name).compareTo(normalizeForSearch(y.name)));

  for (final e in extras) {
    items.add(ShoppingItem(key: 'extra:${e.id}', name: e.name, quantity: e.quantity, unit: e.unit, extraId: e.id));
  }
  return ShoppingListResult(items: items, missingRecipes: missing.toList());
}
