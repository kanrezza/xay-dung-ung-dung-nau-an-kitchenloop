import '../models/ingredient.dart';
import '../models/recipe.dart';
import '../models/recipe_step.dart';

/// Bộ công thức mẫu (món Việt quen thuộc) để người mới có sẵn món mà nấu, xếp thực đơn, đi chợ.
/// Giá (VND) và kcal là ước lượng cho đúng lượng nguyên liệu của dòng đó.
/// Mỗi nguyên liệu: (tên, số lượng, đơn vị, giá, kcal); mỗi bước: (nội dung, giây hẹn giờ).
typedef _I = (String, double?, String?, double?, double?);
typedef _S = (String, int?);

class _Starter {
  const _Starter(this.title, this.servings, this.tags, this.ingredients, this.steps, [this.note = '']);
  final String title;
  final int servings;
  final List<String> tags;
  final List<_I> ingredients;
  final List<_S> steps;
  final String note;
}

const _starters = <_Starter>[
  _Starter('Cơm rang dưa bò', 2, [
    'món sinh viên',
    'nhanh'
  ], [
    ('Cơm nguội', 2, 'bát', 6000, 520),
    ('Thịt bò', 150, 'g', 45000, 375),
    ('Dưa cải chua', 150, 'g', 10000, 30),
    ('Trứng gà', 1, 'quả', 3500, 70),
    ('Hành lá', 2, 'cây', 1000, 5),
    ('Nước mắm', null, null, null, null),
  ], [
    ('Bò thái mỏng, ướp chút nước mắm, tiêu. Dưa cải vắt ráo, thái nhỏ.', null),
    ('Xào dưa cải với ít dầu cho thơm rồi để riêng.', 180),
    ('Xào bò lửa lớn tới khi vừa tái, để riêng.', 90),
    ('Đánh trứng vào cơm, rang cơm tới khi hạt săn và vàng nhẹ.', 300),
    ('Cho dưa và bò vào đảo đều, nêm lại, rắc hành lá rồi tắt bếp.', 60),
  ]),
  _Starter(
      'Bún chả Hà Nội',
      4,
      ['cuối tuần', 'cơm nhà'],
      [
        ('Bún tươi', 1, 'kg', 25000, 1100),
        ('Thịt ba chỉ', 300, 'g', 45000, 1550),
        ('Thịt nạc vai xay', 300, 'g', 42000, 650),
        ('Hành tím, tỏi', 50, 'g', 5000, 40),
        ('Đu đủ xanh, cà rốt', 300, 'g', 15000, 90),
        ('Rau sống', 300, 'g', 15000, 45),
        ('Nước mắm, đường, giấm', null, null, null, null),
      ],
      [
        ('Ướp ba chỉ thái miếng và thịt xay với hành tỏi băm, nước mắm, đường, tiêu, dầu hào.', 1800),
        ('Viên thịt xay thành chả dẹt.', null),
        ('Nướng chả và ba chỉ (than hoặc nồi chiên không dầu 200°C), lật giữa chừng.', 900),
        ('Pha nước chấm: 1 mắm, 1 đường, 1 giấm, 4 nước ấm; thả đu đủ, cà rốt thái mỏng.', null),
        ('Thả thịt nướng vào bát nước chấm, ăn cùng bún và rau sống.', null),
      ],
      'Nướng xong thả thịt ngay vào nước chấm ấm để thịt ngấm.'),
  _Starter('Gỏi cuốn tôm thịt', 3, [
    'ăn kiêng',
    'cuối tuần'
  ], [
    ('Bánh tráng', 15, 'lá', 10000, 300),
    ('Tôm', 250, 'g', 60000, 250),
    ('Thịt ba chỉ', 200, 'g', 30000, 1030),
    ('Bún tươi', 300, 'g', 8000, 330),
    ('Xà lách, rau thơm', 200, 'g', 12000, 30),
    ('Tương đen, lạc rang', 100, 'g', 15000, 350),
  ], [
    ('Luộc thịt ba chỉ chín tới, vớt ra để nguội rồi thái mỏng.', 1200),
    ('Luộc tôm, bóc vỏ, chẻ đôi.', 180),
    ('Nhúng bánh tráng qua nước, xếp rau, bún, thịt, tôm rồi cuốn chặt tay.', null),
    ('Pha tương đen với chút nước, đun sôi, rắc lạc rang giã dập.', 120),
  ]),
  _Starter('Canh bí đỏ thịt bằm', 3, [
    'cơm nhà',
    'nhanh'
  ], [
    ('Bí đỏ', 500, 'g', 12000, 130),
    ('Thịt nạc xay', 150, 'g', 20000, 320),
    ('Hành lá, ngò', 1, 'nắm', 3000, 5),
    ('Muối, hạt nêm', null, null, null, null),
  ], [
    ('Bí đỏ gọt vỏ, cắt miếng vừa ăn.', null),
    ('Xào thịt xay với hành tím cho săn, thêm 1 lít nước, đun sôi.', 300),
    ('Cho bí vào, nấu nhỏ lửa tới khi bí mềm.', 900),
    ('Nêm vừa ăn, rắc hành ngò rồi tắt bếp.', null),
  ]),
  _Starter('Đậu phụ sốt cà chua', 2, [
    'món sinh viên',
    'món chay',
    'nhanh'
  ], [
    ('Đậu phụ', 4, 'bìa', 12000, 380),
    ('Cà chua', 3, 'quả', 9000, 60),
    ('Hành lá', 2, 'cây', 1000, 5),
    ('Nước mắm hoặc xì dầu', null, null, null, null),
  ], [
    ('Đậu cắt miếng, chiên vàng các mặt.', 480),
    ('Phi hành, cho cà chua thái múi cau vào xào nhừ, thêm chút nước.', 300),
    ('Cho đậu vào, nêm vừa ăn, đun liu riu cho ngấm sốt.', 300),
    ('Rắc hành lá rồi tắt bếp.', null),
  ]),
  _Starter(
      'Rau muống xào tỏi',
      2,
      ['nhanh', 'món chay', 'cơm nhà'],
      [
        ('Rau muống', 1, 'bó', 10000, 50),
        ('Tỏi', 5, 'tép', 2000, 20),
        ('Dầu ăn', 2, 'thìa', 1000, 240),
        ('Hạt nêm', null, null, null, null),
      ],
      [
        ('Nhặt rau, rửa sạch, chần qua nước sôi có chút muối rồi vớt ra ngâm nước lạnh.', 60),
        ('Phi thơm tỏi đập dập.', 30),
        ('Cho rau vào xào lửa thật lớn, nêm hạt nêm, đảo nhanh rồi tắt bếp.', 90),
      ],
      'Chần trước và xào lửa lớn giúp rau xanh, giòn.'),
  _Starter('Cá kho tộ', 4, [
    'cơm nhà',
    'món mặn'
  ], [
    ('Cá basa hoặc cá lóc', 600, 'g', 70000, 600),
    ('Thịt ba chỉ', 100, 'g', 15000, 515),
    ('Nước màu, nước mắm, đường', null, null, null, null),
    ('Hành tím, tỏi, ớt', 50, 'g', 5000, 40),
    ('Tiêu', null, null, null, null),
  ], [
    ('Ướp cá với nước mắm, đường, nước màu, hành tỏi băm, tiêu.', 1200),
    ('Xào ba chỉ cho ra mỡ, xếp cá lên trên.', 180),
    ('Thêm nước ngập nửa cá, kho lửa nhỏ, thỉnh thoảng rưới nước kho lên.', 1800),
    ('Kho tới khi nước sệt lại, rắc tiêu, ớt.', 600),
  ]),
  _Starter('Mì xào bò rau cải', 2, [
    'món sinh viên',
    'nhanh'
  ], [
    ('Mì trứng hoặc mì tôm', 2, 'gói', 8000, 700),
    ('Thịt bò', 150, 'g', 45000, 375),
    ('Cải ngọt', 300, 'g', 10000, 50),
    ('Tỏi', 3, 'tép', 1000, 12),
    ('Dầu hào, xì dầu', null, null, null, null),
  ], [
    ('Luộc mì vừa chín, xả nước lạnh, để ráo.', 180),
    ('Bò thái mỏng, ướp dầu hào, tỏi; xào lửa lớn rồi để riêng.', 90),
    ('Xào cải với tỏi tới khi vừa chín.', 120),
    ('Cho mì vào đảo cùng xì dầu, thêm bò, đảo đều rồi tắt bếp.', 120),
  ]),
  _Starter('Cháo gà hành gừng', 4, [
    'ăn sáng',
    'ăn kiêng'
  ], [
    ('Gạo tẻ', 150, 'g', 4000, 540),
    ('Gà ta', 500, 'g', 70000, 750),
    ('Gừng', 1, 'củ', 2000, 10),
    ('Hành lá', 3, 'cây', 1500, 5),
    ('Muối, tiêu', null, null, null, null),
  ], [
    ('Luộc gà với gừng đập dập và chút muối; vớt gà, giữ nước luộc.', 1500),
    ('Rang gạo hơi vàng rồi cho vào nước luộc gà, nấu nhừ, khuấy thường xuyên.', 2400),
    ('Xé thịt gà, nêm cháo vừa ăn.', null),
    ('Múc cháo ra bát, thêm gà, hành lá, tiêu.', null),
  ]),
  _Starter('Bánh mì trứng ốp la', 1, [
    'ăn sáng',
    'món sinh viên',
    'nhanh'
  ], [
    ('Bánh mì', 1, 'ổ', 5000, 280),
    ('Trứng gà', 2, 'quả', 7000, 140),
    ('Dưa chuột', 0.5, 'quả', 2000, 8),
    ('Tương ớt, xì dầu', null, null, null, null),
  ], [
    ('Làm nóng chảo với chút dầu, đập trứng vào, giữ lửa vừa.', 180),
    ('Nướng giòn bánh mì.', 120),
    ('Kẹp trứng, dưa chuột, rưới xì dầu và tương ớt.', null),
  ]),
  _Starter('Sinh tố bơ', 2, [
    'tráng miệng',
    'nhanh'
  ], [
    ('Bơ sáp', 1, 'quả', 25000, 320),
    ('Sữa đặc', 3, 'thìa', 4000, 190),
    ('Sữa tươi không đường', 200, 'ml', 7000, 130),
    ('Đá viên', 1, 'cốc', null, 0),
  ], [
    ('Bổ bơ, lấy phần thịt.', null),
    ('Xay bơ với sữa đặc, sữa tươi và đá tới khi mịn.', 60),
    ('Rót ra cốc, dùng ngay.', null),
  ]),
  _Starter('Chè đậu xanh', 4, [
    'tráng miệng',
    'món chay'
  ], [
    ('Đậu xanh cà vỏ', 200, 'g', 15000, 700),
    ('Đường', 120, 'g', 3000, 460),
    ('Nước cốt dừa', 100, 'ml', 10000, 200),
    ('Bột năng', 1, 'thìa', 1000, 35),
  ], [
    ('Ngâm đậu xanh cho nở mềm.', 3600),
    ('Nấu đậu với 1,2 lít nước tới khi nhừ.', 1500),
    ('Thêm đường, khuấy tan; hoà bột năng với nước rồi đổ vào cho sánh.', 300),
    ('Đun nước cốt dừa với chút muối, rưới lên khi ăn.', 120),
  ]),
];

/// Số món trong bộ mẫu.
int get starterRecipeCount => _starters.length;

/// Dựng các bản nháp công thức mẫu (chưa có chủ, chưa có ID document).
/// [newId] sinh ID cho từng nguyên liệu và bước.
List<Recipe> buildStarterRecipes(String Function() newId) => [
      for (final s in _starters)
        Recipe(
          id: '',
          ownerId: '',
          title: s.title,
          baseServings: s.servings,
          tags: s.tags,
          note: s.note,
          ingredients: [
            for (final (name, quantity, unit, price, kcal) in s.ingredients)
              Ingredient(id: newId(), name: name, quantity: quantity, unit: unit, price: price, kcal: kcal),
          ],
          steps: [
            for (final (i, (text, seconds)) in s.steps.indexed) RecipeStep(id: newId(), order: i + 1, text: text, durationSec: seconds),
          ],
        ),
    ];
