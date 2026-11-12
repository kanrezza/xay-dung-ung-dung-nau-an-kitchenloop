import 'package:btl_ltdd/features/recipes/domain/recipe_filter.dart';
import 'package:btl_ltdd/features/recipes/models/ingredient.dart';
import 'package:btl_ltdd/features/recipes/models/recipe.dart';
import 'package:btl_ltdd/features/recipes/models/recipe_step.dart';
import 'package:flutter_test/flutter_test.dart';

Recipe recipe(String id, String title, {List<String> ingredients = const ['x'], List<String> tags = const []}) {
  return Recipe(
    id: id,
    ownerId: 'u',
    title: title,
    baseServings: 2,
    ingredients: [for (var i = 0; i < ingredients.length; i++) Ingredient(id: '$id-i$i', name: ingredients[i])],
    steps: const [RecipeStep(id: 's', order: 1, text: 'y')],
    tags: tags,
  );
}

List<String> ids(List<Recipe> list) => list.map((r) => r.id).toList();

void main() {
  final chicken = recipe('r1', 'Gà rán giòn', ingredients: ['đùi gà', 'bột chiên giòn'], tags: ['món sinh viên', 'nhanh']);
  final pork = recipe('r2', 'Thịt kho tàu', ingredients: ['thịt ba chỉ', 'trứng vịt', 'nước dừa'], tags: ['món sinh viên']);
  final soup = recipe('r3', 'Canh chua cá lóc', ingredients: ['cá lóc', 'me', 'cà chua'], tags: ['ăn kiêng']);
  final rice = recipe('r4', 'Cơm chiên dương châu', ingredients: ['cơm nguội', 'gà xé', 'trứng gà'], tags: ['nhanh', 'món sinh viên']);
  final all = [chicken, pork, soup, rice];

  group('filterRecipes: từ khoá', () {
    test('khớp theo tên món', () {
      expect(ids(filterRecipes(all, 'canh chua', {})), ['r3']);
    });

    test('khớp theo tên nguyên liệu', () {
      expect(ids(filterRecipes(all, 'ba chỉ', {})), ['r2']);
      expect(ids(filterRecipes(all, 'me', {})), ['r3']);
    });

    test('khớp theo thẻ', () {
      expect(ids(filterRecipes(all, 'ăn kiêng', {})), ['r3']);
    });

    test('không phân biệt hoa thường', () {
      expect(ids(filterRecipes(all, 'THỊT KHO', {})), ['r2']);
    });

    test('không phân biệt dấu: "ga" ra các món chứa "gà"', () {
      expect(ids(filterRecipes(all, 'ga', {})), containsAll(['r1', 'r4']));
      expect(ids(filterRecipes(all, 'ga ran', {})), ['r1']);
    });

    test('gõ có dấu vẫn khớp dữ liệu không dấu và ngược lại', () {
      final noTone = recipe('n1', 'Pho bo', ingredients: ['thit bo']);
      expect(ids(filterRecipes([noTone], 'phở bò', {})), ['n1']);
      expect(ids(filterRecipes([chicken], 'gà', {})), ['r1']);
    });

    test('nhiều từ: mọi từ đều phải xuất hiện (thứ tự bất kỳ)', () {
      expect(ids(filterRecipes(all, 'trung ga', {})), ['r4']); // "trứng gà" ở nguyên liệu của cơm chiên
      expect(ids(filterRecipes(all, 'gion ga', {})), ['r1']);
      expect(filterRecipes(all, 'ga tau', {}), isEmpty);
    });

    test('từ khoá thừa khoảng trắng', () {
      expect(ids(filterRecipes(all, '   thit   kho  ', {})), ['r2']);
    });

    test('không có kết quả', () {
      expect(filterRecipes(all, 'sushi', {}), isEmpty);
    });

    test('chuỗi rỗng hoặc chỉ khoảng trắng trả về toàn bộ, giữ nguyên thứ tự', () {
      expect(ids(filterRecipes(all, '', {})), ['r1', 'r2', 'r3', 'r4']);
      expect(ids(filterRecipes(all, '   ', {})), ['r1', 'r2', 'r3', 'r4']);
    });

    test('ký tự đặc biệt không gây lỗi (không dùng regex)', () {
      for (final q in ['(*[', '+?\\', '.*', '\$^|', '{', '[a-z]', '(', ')']) {
        expect(() => filterRecipes(all, q, {}), returnsNormally, reason: q);
      }
      expect(filterRecipes(all, '.*', {}), isEmpty);
    });

    test('danh sách rỗng', () {
      expect(filterRecipes(const [], 'gà', {'nhanh'}), isEmpty);
    });
  });

  group('filterRecipes: thẻ', () {
    test('chọn một thẻ: chỉ còn các món có thẻ đó', () {
      expect(ids(filterRecipes(all, '', {'món sinh viên'})), ['r1', 'r2', 'r4']);
    });

    test('chọn nhiều thẻ: phải có đủ các thẻ', () {
      expect(ids(filterRecipes(all, '', {'món sinh viên', 'nhanh'})), ['r1', 'r4']);
      expect(filterRecipes(all, '', {'nhanh', 'ăn kiêng'}), isEmpty);
    });

    test('thẻ không phân biệt hoa thường và dấu', () {
      expect(ids(filterRecipes(all, '', {'MON SINH VIEN'})), ['r1', 'r2', 'r4']);
      expect(ids(filterRecipes(all, '', {'An Kieng'})), ['r3']);
    });

    test('thẻ không tồn tại → không có kết quả', () {
      expect(filterRecipes(all, '', {'không-có'}), isEmpty);
    });
  });

  group('filterRecipes: kết hợp từ khoá và thẻ', () {
    test('chỉ giữ món thoả cả hai điều kiện', () {
      expect(ids(filterRecipes(all, 'ga', {'món sinh viên'})), ['r1', 'r4']);
      expect(ids(filterRecipes(all, 'ga', {'nhanh', 'món sinh viên'})), ['r1', 'r4']);
      expect(ids(filterRecipes(all, 'ga ran', {'nhanh'})), ['r1']);
    });

    test('từ khoá khớp nhưng thiếu thẻ → loại', () {
      expect(filterRecipes(all, 'canh chua', {'nhanh'}), isEmpty);
    });

    test('thẻ khớp nhưng từ khoá không khớp → loại', () {
      expect(filterRecipes(all, 'sushi', {'nhanh'}), isEmpty);
    });
  });

  group('kịch bản nghiệm thu: 10 công thức, 3 cái gắn "món sinh viên"', () {
    final ten = [
      for (var i = 0; i < 10; i++)
        recipe('t$i', i % 2 == 0 ? 'Món gà số $i' : 'Món cá số $i',
            tags: i < 3 ? ['món sinh viên'] : const []),
    ];

    test('lọc theo thẻ còn đúng 3', () {
      expect(ids(filterRecipes(ten, '', {'món sinh viên'})), ['t0', 't1', 't2']);
    });

    test('tìm "ga" ra các món chứa "gà"', () {
      expect(ids(filterRecipes(ten, 'ga', {})), ['t0', 't2', 't4', 't6', 't8']);
    });
  });

  group('hiệu năng (SC-006)', () {
    test('lọc 200 công thức dưới 1 giây', () {
      final many = [
        for (var i = 0; i < 200; i++)
          recipe(
            'p$i',
            'Món số $i rất ngon với gà và cá',
            ingredients: [for (var j = 0; j < 12; j++) 'nguyên liệu $j của món $i'],
            tags: ['thẻ ${i % 7}', 'món sinh viên', 'nhanh'],
          ),
      ];
      final watch = Stopwatch()..start();
      final result = filterRecipes(many, 'ga ca', {'món sinh viên', 'nhanh'});
      watch.stop();
      expect(result, hasLength(200));
      expect(watch.elapsedMilliseconds, lessThan(1000));
    });
  });

  group('collectTags', () {
    test('đếm số công thức theo thẻ, nhiều nhất trước', () {
      final tags = collectTags(all);
      expect(tags.map((t) => t.label), ['món sinh viên', 'nhanh', 'ăn kiêng']);
      expect(tags.map((t) => t.count), [3, 2, 1]);
    });

    test('cùng số lượng thì xếp theo tên', () {
      final tags = collectTags([
        recipe('a', 'A', tags: ['b']),
        recipe('b', 'B', tags: ['a']),
      ]);
      expect(tags.map((t) => t.label), ['a', 'b']);
    });

    test('gộp các cách viết khác nhau của cùng một thẻ, giữ cách viết gặp đầu tiên', () {
      final tags = collectTags([
        recipe('a', 'A', tags: ['Món Sinh Viên']),
        recipe('b', 'B', tags: ['mon sinh vien']),
        recipe('c', 'C', tags: ['MÓN SINH VIÊN']),
      ]);
      expect(tags, hasLength(1));
      expect(tags.single.label, 'Món Sinh Viên');
      expect(tags.single.count, 3);
    });

    test('một công thức có thẻ lặp chỉ được đếm một lần', () {
      final tags = collectTags([
        recipe('a', 'A', tags: ['nhanh', 'Nhanh', 'NHANH']),
      ]);
      expect(tags.single.count, 1);
    });

    test('khoá của thẻ là dạng đã chuẩn hoá để dùng với filterRecipes', () {
      final tag = collectTags([recipe('a', 'A', tags: ['Món Sinh Viên'])]).single;
      expect(tag.key, 'mon sinh vien');
      expect(ids(filterRecipes(all, '', {tag.key})), ['r1', 'r2', 'r4']);
    });

    test('không có công thức hoặc không có thẻ', () {
      expect(collectTags(const []), isEmpty);
      expect(collectTags([recipe('a', 'A')]), isEmpty);
    });

    test('bỏ qua thẻ rỗng', () {
      expect(collectTags([recipe('a', 'A', tags: ['  ', ''])]), isEmpty);
    });
  });
}
