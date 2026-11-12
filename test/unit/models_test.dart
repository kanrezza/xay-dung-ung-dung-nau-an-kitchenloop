import 'package:btl_ltdd/features/recipes/models/ingredient.dart';
import 'package:btl_ltdd/features/recipes/models/recipe.dart';
import 'package:btl_ltdd/features/recipes/models/recipe_step.dart';
import 'package:flutter_test/flutter_test.dart';

Ingredient ing({String id = 'i1', String name = 'thịt bò', double? quantity = 200, String? unit = 'g'}) =>
    Ingredient(id: id, name: name, quantity: quantity, unit: unit);

RecipeStep step({String id = 's1', int order = 1, String text = 'Luộc trứng', int? durationSec}) =>
    RecipeStep(id: id, order: order, text: text, durationSec: durationSec);

Recipe recipe({
  String title = 'Thịt kho',
  int baseServings = 2,
  List<Ingredient>? ingredients,
  List<RecipeStep>? steps,
  List<String> tags = const [],
  String note = '',
}) =>
    Recipe(
      id: 'r1',
      ownerId: 'u1',
      title: title,
      baseServings: baseServings,
      ingredients: ingredients ?? [ing()],
      steps: steps ?? [step()],
      tags: tags,
      note: note,
    );

void main() {
  group('Ingredient', () {
    test('toMap/fromMap hai chiều', () {
      const original = Ingredient(
        id: 'i1',
        name: 'trứng',
        quantity: 2,
        unit: 'quả',
        price: 6000,
        kcal: 140,
        isPlaceholder: true,
      );
      final copy = Ingredient.fromMap(original.toMap());
      expect(copy.id, 'i1');
      expect(copy.name, 'trứng');
      expect(copy.quantity, 2);
      expect(copy.unit, 'quả');
      expect(copy.price, 6000);
      expect(copy.kcal, 140);
      expect(copy.isPlaceholder, isTrue);
    });

    test('thiếu trường tuỳ chọn → null, isPlaceholder mặc định false', () {
      final i = Ingredient.fromMap({'id': 'i1', 'name': 'muối'});
      expect(i.quantity, isNull);
      expect(i.unit, isNull);
      expect(i.price, isNull);
      expect(i.kcal, isNull);
      expect(i.isPlaceholder, isFalse);
    });

    test('quantity kiểu int trong Firestore được đọc thành double', () {
      final i = Ingredient.fromMap({'id': 'i1', 'name': 'x', 'quantity': 3});
      expect(i.quantity, 3.0);
      expect(i.quantity, isA<double>());
    });

    test('copyWith cho phép xoá giá trị tuỳ chọn', () {
      final i = ing().copyWith(quantity: null, unit: null);
      expect(i.quantity, isNull);
      expect(i.unit, isNull);
      expect(i.name, 'thịt bò');
    });

    test('hợp lệ → không có lỗi', () => expect(ing().validate(), isEmpty));
    test('quantity null (vừa đủ) hợp lệ', () => expect(ing(quantity: null).validate(), isEmpty));
    test('quantity = 0 hợp lệ', () => expect(ing(quantity: 0).validate(), isEmpty));

    test('tên rỗng/khoảng trắng bị từ chối', () {
      expect(ing(name: '').validate(), contains('name_invalid'));
      expect(ing(name: '   ').validate(), contains('name_invalid'));
    });
    test('tên 100 ký tự ok, 101 ký tự lỗi', () {
      expect(ing(name: 'a' * 100).validate(), isEmpty);
      expect(ing(name: 'a' * 101).validate(), contains('name_invalid'));
    });
    test('quantity âm', () => expect(ing(quantity: -1).validate(), contains('quantity_negative')));
    test('đơn vị 20 ký tự ok, 21 lỗi', () {
      expect(ing(unit: 'a' * 20).validate(), isEmpty);
      expect(ing(unit: 'a' * 21).validate(), contains('unit_too_long'));
    });
    test('giá và kcal không âm', () {
      expect(const Ingredient(id: 'i', name: 'x', price: -1).validate(), contains('price_negative'));
      expect(const Ingredient(id: 'i', name: 'x', kcal: -1).validate(), contains('kcal_negative'));
    });
  });

  group('RecipeStep', () {
    test('toMap/fromMap hai chiều', () {
      const original = RecipeStep(
        id: 's1',
        order: 2,
        text: 'Kho thịt',
        imageUrl: 'https://x/y.jpg',
        durationSec: 600,
        isPlaceholder: true,
      );
      final copy = RecipeStep.fromMap(original.toMap());
      expect(copy.id, 's1');
      expect(copy.order, 2);
      expect(copy.text, 'Kho thịt');
      expect(copy.imageUrl, 'https://x/y.jpg');
      expect(copy.durationSec, 600);
      expect(copy.isPlaceholder, isTrue);
    });

    test('thiếu trường → mặc định', () {
      final s = RecipeStep.fromMap({'id': 's', 'order': 1, 'text': 'a'});
      expect(s.imageUrl, isNull);
      expect(s.durationSec, isNull);
      expect(s.isPlaceholder, isFalse);
    });

    test('hợp lệ', () => expect(step().validate(), isEmpty));
    test('nội dung rỗng', () => expect(step(text: ' ').validate(), contains('text_invalid')));
    test('nội dung 1000 ký tự ok, 1001 lỗi', () {
      expect(step(text: 'a' * 1000).validate(), isEmpty);
      expect(step(text: 'a' * 1001).validate(), contains('text_invalid'));
    });
    test('durationSec ≤ 0 bị từ chối', () {
      expect(step(durationSec: 0).validate(), contains('duration_invalid'));
      expect(step(durationSec: -5).validate(), contains('duration_invalid'));
    });
    test('durationSec tối đa 86400', () {
      expect(step(durationSec: 86400).validate(), isEmpty);
      expect(step(durationSec: 86401).validate(), contains('duration_invalid'));
    });
    test('order < 1', () => expect(step(order: 0).validate(), contains('order_invalid')));
  });

  group('Recipe', () {
    test('toMap/fromMap hai chiều, gồm legacy và thời gian', () {
      final created = DateTime.utc(2026, 1, 2, 3, 4, 5);
      final original = Recipe(
        id: 'r1',
        ownerId: 'u1',
        title: 'Thịt kho',
        imageUrl: 'https://x/a.jpg',
        baseServings: 4,
        ingredients: [ing(), ing(id: 'i2', name: 'muối', quantity: null, unit: null)],
        steps: [step(durationSec: 90), step(id: 's2', order: 2, text: 'Kho')],
        tags: ['món sinh viên', 'nhanh'],
        note: 'ghi chú',
        createdAt: created,
        updatedAt: created,
        legacy: RecipeLegacy(
          title: 'Thịt kho cũ',
          ingredients: const ['200g thịt bò', 'muối'],
          instructions: '1. Luộc\n2. Kho',
          migratedAt: created,
        ),
      );
      final map = original.toMap();
      expect(map['createdAt'], isA<DateTime>()); // model không biết tới Timestamp
      final copy = Recipe.fromMap(map, 'r1');
      expect(copy.id, 'r1');
      expect(copy.ownerId, 'u1');
      expect(copy.title, 'Thịt kho');
      expect(copy.imageUrl, 'https://x/a.jpg');
      expect(copy.baseServings, 4);
      expect(copy.ingredients.length, 2);
      expect(copy.ingredients[1].quantity, isNull);
      expect(copy.steps.length, 2);
      expect(copy.steps.first.durationSec, 90);
      expect(copy.tags, ['món sinh viên', 'nhanh']);
      expect(copy.note, 'ghi chú');
      // Timestamp.toDate() trả về giờ địa phương nên so theo thời điểm.
      expect(copy.createdAt!.isAtSameMomentAs(created), isTrue);
      expect(copy.legacy!.migratedAt!.isAtSameMomentAs(created), isTrue);
      expect(copy.schemaVersion, 1);
      expect(copy.legacy, isNotNull);
      expect(copy.legacy!.title, 'Thịt kho cũ');
      expect(copy.legacy!.ingredients, ['200g thịt bò', 'muối']);
      expect(copy.legacy!.sourceCollection, 'foods');
    });

    test('createdAt/updatedAt null (chờ máy chủ) vẫn đọc được', () {
      final r = Recipe.fromMap({
        'ownerId': 'u1',
        'title': 'a',
        'baseServings': 2,
        'ingredients': [ing().toMap()],
        'steps': [step().toMap()],
        'createdAt': null,
      }, 'r9');
      expect(r.createdAt, isNull);
      expect(r.updatedAt, isNull);
      expect(r.legacy, isNull);
      expect(r.tags, isEmpty);
    });

    test('toMap không chứa id và không có legacy khi không có', () {
      final map = recipe().toMap();
      expect(map.containsKey('id'), isFalse);
      expect(map.containsKey('legacy'), isFalse);
      expect(map['schemaVersion'], 1);
    });

    test('hợp lệ → không có lỗi', () => expect(recipe().validate(), isEmpty));

    test('tên rỗng, khoảng trắng, quá dài', () {
      expect(recipe(title: '').validate(), contains('title_required'));
      expect(recipe(title: '   ').validate(), contains('title_required'));
      expect(recipe(title: 'a' * 120).validate(), isEmpty);
      expect(recipe(title: 'a' * 121).validate(), contains('title_too_long'));
    });

    test('baseServings ngoài 1–100', () {
      expect(recipe(baseServings: 0).validate(), contains('servings_invalid'));
      expect(recipe(baseServings: -2).validate(), contains('servings_invalid'));
      expect(recipe(baseServings: 101).validate(), contains('servings_invalid'));
      expect(recipe(baseServings: 1).validate(), isEmpty);
      expect(recipe(baseServings: 100).validate(), isEmpty);
    });

    test('0 nguyên liệu và quá 100 nguyên liệu', () {
      expect(recipe(ingredients: []).validate(), contains('ingredients_required'));
      final many = List.generate(101, (i) => ing(id: 'i$i'));
      expect(recipe(ingredients: many).validate(), contains('ingredients_too_many'));
      expect(recipe(ingredients: many.take(100).toList()).validate(), isEmpty);
    });

    test('0 bước và quá 100 bước', () {
      expect(recipe(steps: []).validate(), contains('steps_required'));
      final many = List.generate(101, (i) => step(id: 's$i', order: i + 1));
      expect(recipe(steps: many).validate(), contains('steps_too_many'));
      expect(recipe(steps: many.take(100).toList()).validate(), isEmpty);
    });

    test('lỗi của nguyên liệu/bước được gắn vị trí', () {
      final errors = recipe(
        ingredients: [ing(), ing(id: 'i2', name: '')],
        steps: [step(), step(id: 's2', order: 2, durationSec: 0)],
      ).validate();
      expect(errors, contains('ingredients[1].name_invalid'));
      expect(errors, contains('steps[1].duration_invalid'));
    });

    test('thứ tự bước phải liên tục từ 1', () {
      expect(
        recipe(steps: [step(order: 1), step(id: 's2', order: 3)]).validate(),
        contains('steps_order_invalid'),
      );
      expect(
        recipe(steps: [step(order: 2)]).validate(),
        contains('steps_order_invalid'),
      );
      expect(
        recipe(steps: [step(order: 1), step(id: 's2', order: 1)]).validate(),
        contains('steps_order_invalid'),
      );
    });

    test('thẻ: tối đa 20, mỗi thẻ 1–30 ký tự', () {
      expect(recipe(tags: List.generate(20, (i) => 't$i')).validate(), isEmpty);
      expect(recipe(tags: List.generate(21, (i) => 't$i')).validate(), contains('tags_too_many'));
      expect(recipe(tags: ['a' * 30]).validate(), isEmpty);
      expect(recipe(tags: ['a' * 31]).validate(), contains('tag_invalid'));
      expect(recipe(tags: ['  ']).validate(), contains('tag_invalid'));
    });

    test('validate() không loại thẻ trùng (việc đó làm lúc nhập)', () {
      expect(recipe(tags: ['Nhanh', 'nhanh']).validate(), isEmpty);
    });

    test('ghi chú tối đa 2000 ký tự', () {
      expect(recipe(note: 'a' * 2000).validate(), isEmpty);
      expect(recipe(note: 'a' * 2001).validate(), contains('note_too_long'));
    });

    test('nhiều lỗi cùng lúc được liệt kê hết', () {
      final errors = recipe(title: '', baseServings: 0, ingredients: [], steps: []).validate();
      expect(errors, containsAll(['title_required', 'servings_invalid', 'ingredients_required', 'steps_required']));
    });

    test('copyWith giữ nguyên các trường không đổi', () {
      final r = recipe().copyWith(title: 'Mới', tags: ['a']);
      expect(r.title, 'Mới');
      expect(r.tags, ['a']);
      expect(r.ownerId, 'u1');
      expect(r.baseServings, 2);
    });
  });

  group('RecipeLegacy.extra', () {
    test('mặc định rỗng và không ghi vào map khi rỗng', () {
      const legacy = RecipeLegacy(title: 't', ingredients: [], instructions: '');
      expect(legacy.extra, isEmpty);
      expect(legacy.toMap().containsKey('extra'), isFalse);
    });

    test('hai chiều khi có dữ liệu', () {
      const legacy = RecipeLegacy(
        title: 't',
        ingredients: [],
        instructions: '',
        extra: {'time': '45 phút', 'difficulty': 'Dễ'},
      );
      final copy = RecipeLegacy.fromMap(legacy.toMap());
      expect(copy.extra, {'time': '45 phút', 'difficulty': 'Dễ'});
    });

    test('bản ghi cũ chưa có extra vẫn đọc được', () {
      final copy = RecipeLegacy.fromMap({'title': 't', 'ingredients': ['a'], 'instructions': 'b'});
      expect(copy.extra, isEmpty);
      expect(copy.ingredients, ['a']);
    });
  });

  group('Recipe.isSyncing (trạng thái hiển thị, không lưu)', () {
    Map<String, dynamic> raw() => {
          'ownerId': 'u',
          'title': 'a',
          'baseServings': 2,
          'ingredients': [const Ingredient(id: 'i', name: 'x').toMap()],
          'steps': [const RecipeStep(id: 's', order: 1, text: 'y').toMap()],
        };

    test('mặc định false', () {
      expect(Recipe.fromMap(raw(), 'r').isSyncing, isFalse);
    });

    test('fromMap nhận isSyncing từ siêu dữ liệu của Firestore', () {
      expect(Recipe.fromMap(raw(), 'r', isSyncing: true).isSyncing, isTrue);
    });

    test('không được ghi vào Firestore', () {
      final map = Recipe.fromMap(raw(), 'r', isSyncing: true).toMap();
      expect(map.containsKey('isSyncing'), isFalse);
    });

    test('copyWith đổi được và giữ nguyên khi không truyền', () {
      final r = Recipe.fromMap(raw(), 'r');
      expect(r.copyWith(isSyncing: true).isSyncing, isTrue);
      expect(r.copyWith(title: 'b').isSyncing, isFalse);
      expect(Recipe.fromMap(raw(), 'r', isSyncing: true).copyWith(title: 'b').isSyncing, isTrue);
    });
  });
}
