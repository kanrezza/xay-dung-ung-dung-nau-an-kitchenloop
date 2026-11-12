import 'package:btl_ltdd/features/recipes/domain/serving_scaler.dart';
import 'package:btl_ltdd/features/recipes/models/ingredient.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('scaleQuantity', () {
    test('200 g cho 2 người → 5 người = 500 g', () => expect(scaleQuantity(200, 2, 5), 500));
    test('200 g cho 2 người → 1 người = 100 g', () => expect(scaleQuantity(200, 2, 1), 100));
    test('giữ nguyên khi khẩu phần không đổi', () => expect(scaleQuantity(3.5, 4, 4), 3.5));
    test('gấp đôi', () => expect(scaleQuantity(1.5, 2, 4), 3));

    test('null (vừa đủ) giữ nguyên null', () {
      expect(scaleQuantity(null, 2, 5), isNull);
      expect(scaleQuantity(null, 2, 2), isNull);
    });

    test('làm tròn tối đa 2 chữ số thập phân', () {
      expect(scaleQuantity(1, 3, 2), 0.67); // 0,666…
      expect(scaleQuantity(1, 3, 1), 0.33); // 0,333…
      expect(scaleQuantity(10, 3, 7), 23.33);
      expect(scaleQuantity(1, 6, 5), 0.83);
    });

    test('số 0 vẫn là 0', () => expect(scaleQuantity(0, 2, 5), 0));

    test('lượng nhỏ khác 0 không bị làm tròn xuống 0', () {
      expect(scaleQuantity(0.1, 100, 1), 0.01);
    });

    test('khẩu phần đích ≤ 0 ném lỗi tham số', () {
      expect(() => scaleQuantity(200, 2, 0), throwsArgumentError);
      expect(() => scaleQuantity(200, 2, -3), throwsArgumentError);
    });

    test('khẩu phần gốc ≤ 0 ném lỗi tham số', () {
      expect(() => scaleQuantity(200, 0, 2), throwsArgumentError);
      expect(() => scaleQuantity(200, -1, 2), throwsArgumentError);
    });

    test('ném lỗi cả khi quantity null (tham số sai luôn là lỗi)', () {
      expect(() => scaleQuantity(null, 0, 2), throwsArgumentError);
    });
  });

  group('scaleIngredient', () {
    const meat = Ingredient(id: 'i', name: 'thịt', quantity: 200, unit: 'g', price: 90000, kcal: 500);

    test('nhân số lượng, giá và kcal theo cùng tỉ lệ', () {
      final scaled = scaleIngredient(meat, 2, 5);
      expect(scaled.quantity, 500);
      expect(scaled.price, 225000);
      expect(scaled.kcal, 1250);
    });

    test('giữ nguyên tên, đơn vị, id', () {
      final scaled = scaleIngredient(meat, 2, 4);
      expect(scaled.id, 'i');
      expect(scaled.name, 'thịt');
      expect(scaled.unit, 'g');
    });

    test('không có số lượng ("vừa đủ"): giữ nguyên cả dòng', () {
      const salt = Ingredient(id: 's', name: 'muối', price: 1000, kcal: 0);
      final scaled = scaleIngredient(salt, 2, 10);
      expect(scaled.quantity, isNull);
      expect(scaled.price, 1000);
      expect(scaled.kcal, 0);
    });

    test('giá và kcal trống vẫn trống', () {
      const egg = Ingredient(id: 'e', name: 'trứng', quantity: 2, unit: 'quả');
      final scaled = scaleIngredient(egg, 2, 6);
      expect(scaled.quantity, 6);
      expect(scaled.price, isNull);
      expect(scaled.kcal, isNull);
    });

    group('đơn vị đếm (quả, tép...) làm tròn tới số nguyên', () {
      test('3 tép cho 4 người → 6 người: 4,5 thành 5 tép', () {
        const garlic = Ingredient(id: 'g', name: 'tỏi băm', quantity: 3, unit: 'tép');
        expect(scaleIngredient(garlic, 4, 6).quantity, 5);
      });

      test('6 quả cho 4 người → 6 người: đúng 9 quả', () {
        const egg = Ingredient(id: 'e', name: 'trứng vịt', quantity: 6, unit: 'quả');
        expect(scaleIngredient(egg, 4, 6).quantity, 9);
      });

      test('không bao giờ làm tròn xuống 0: 1 quả cho 4 người → 1 người vẫn là 1 quả', () {
        const lemon = Ingredient(id: 'l', name: 'chanh', quantity: 1, unit: 'quả');
        expect(scaleIngredient(lemon, 4, 1).quantity, 1);
      });

      test('không phân biệt hoa thường, bỏ khoảng trắng; có cả đơn vị tiếng Anh', () {
        const a = Ingredient(id: 'a', name: 'x', quantity: 1, unit: ' Quả ');
        const b = Ingredient(id: 'b', name: 'garlic', quantity: 1, unit: 'cloves');
        expect(scaleIngredient(a, 2, 3).quantity, 2);
        expect(scaleIngredient(b, 2, 3).quantity, 2);
      });

      test('không đổi khẩu phần thì giữ nguyên số lẻ gốc ("0,5 quả chanh")', () {
        const lemon = Ingredient(id: 'l', name: 'chanh', quantity: 0.5, unit: 'quả');
        expect(scaleIngredient(lemon, 2, 2).quantity, 0.5);
      });

      test('đơn vị đo (g, ml, muỗng) vẫn giữ số lẻ', () {
        const fish = Ingredient(id: 'f', name: 'nước mắm', quantity: 3, unit: 'muỗng canh');
        expect(scaleIngredient(fish, 4, 6).quantity, 4.5);
      });

      test('giá và kcal vẫn theo tỉ lệ khẩu phần', () {
        const egg = Ingredient(id: 'e', name: 'trứng', quantity: 3, unit: 'quả', price: 12000, kcal: 210);
        final scaled = scaleIngredient(egg, 4, 6);
        expect(scaled.quantity, 5);
        expect(scaled.price, 18000);
        expect(scaled.kcal, 315);
      });
    });

    test('dòng giữ chỗ không bị đổi', () {
      const placeholder = Ingredient(id: 'p', name: '(Chưa có nguyên liệu)', isPlaceholder: true);
      expect(scaleIngredient(placeholder, 2, 5).isPlaceholder, isTrue);
    });

    test('không làm thay đổi đối tượng gốc', () {
      scaleIngredient(meat, 2, 5);
      expect(meat.quantity, 200);
    });

    test('khẩu phần không hợp lệ ném lỗi', () {
      expect(() => scaleIngredient(meat, 2, 0), throwsArgumentError);
    });
  });
}
