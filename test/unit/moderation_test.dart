import 'dart:io';

import 'package:btl_ltdd/features/community/domain/community_stats.dart';
import 'package:btl_ltdd/features/community/domain/moderation.dart';
import 'package:btl_ltdd/features/community/models/community_post.dart';
import 'package:btl_ltdd/features/recipes/models/ingredient.dart';
import 'package:btl_ltdd/features/recipes/models/recipe.dart';
import 'package:btl_ltdd/features/recipes/models/recipe_step.dart';
import 'package:flutter_test/flutter_test.dart';

List<ModerationIssue> check({
  String title = 'Thịt kho trứng',
  String note = '',
  List<String> ings = const ['thịt ba chỉ', 'trứng vịt'],
  List<String> steps = const ['Luộc trứng 10 phút rồi bóc vỏ.', 'Kho thịt với nước dừa 45 phút.'],
  List<String> tags = const [],
}) =>
    checkPost(title: title, note: note, ingredientNames: ings, stepTexts: steps, tags: tags);

void main() {
  group('kiểm duyệt bài chia sẻ', () {
    test('bài tử tế: đạt', () {
      expect(check(), isEmpty);
      expect(check(title: 'Bánh trung thu lồng đèn'), isEmpty, reason: '"lồng" không bị chặn nhầm');
      expect(check(title: 'Canh chua cá lóc', note: 'Nấu với me chua.\nĂn nóng.'), isEmpty);
    });

    test('tên quá ngắn, quá dài, không có chữ', () {
      expect(check(title: 'ab'), contains(ModerationIssue.titleTooShort));
      expect(check(title: 'a' * 81), contains(ModerationIssue.titleTooLong));
      expect(check(title: '12345 !!!'), contains(ModerationIssue.titleNoLetters));
    });

    test('gõ bừa lặp ký tự', () {
      expect(check(title: 'ngonnnnnn quá'), contains(ModerationIssue.repeatedChars));
      expect(check(title: 'Gà 11111'), contains(ModerationIssue.repeatedChars));
      expect(check(title: 'Gà rán ngonnnn'), isNot(contains(ModerationIssue.repeatedChars)), reason: '4 lần thì cho qua');
    });

    test('link và tên miền ở tên, ghi chú, bước nấu, kể cả sau dấu xuống dòng', () {
      expect(check(title: 'Mua tại shop.vn nhé'), contains(ModerationIssue.link));
      expect(check(note: 'Ngon.\nXem www.quangcao.xyz'), contains(ModerationIssue.link));
      expect(check(steps: ['Xem https://a.b để biết', 'Kho thịt với nước dừa.']), contains(ModerationIssue.link));
      expect(check(note: 'Dùng 0.5 lít nước'), isNot(contains(ModerationIssue.link)));
    });

    test('từ cấm, không phân biệt hoa thường', () {
      expect(check(title: 'CASINO uy tín'), contains(ModerationIssue.bannedWord));
      expect(check(title: 'Nhận vay tiền nhanh'), contains(ModerationIssue.bannedWord));
      expect(check(steps: ['Liên hệ zalo: 0909 để mua', 'Kho thịt với nước dừa.']), contains(ModerationIssue.bannedWord));
      expect(check(tags: ['xxx']), contains(ModerationIssue.bannedWord));
    });

    test('ứng dụng kiểm tra MỌI nguyên liệu và bước (rules chỉ kiểm tra 2 cái đầu)', () {
      expect(check(ings: ['thịt', 'trứng', 'x']), contains(ModerationIssue.ingredientTooShort));
      expect(check(steps: ['Luộc trứng 10 phút.', 'Kho thịt 45 phút.', 'nấu']), contains(ModerationIssue.stepTooShort));
    });

    test('số nguyên liệu, số bước, ghi chú, thẻ', () {
      expect(check(ings: ['thịt']), contains(ModerationIssue.tooFewIngredients));
      expect(check(steps: ['Luộc trứng 10 phút.']), contains(ModerationIssue.tooFewSteps));
      expect(check(ings: List.filled(51, 'thịt')), contains(ModerationIssue.tooManyIngredients));
      expect(check(note: 'a ' * 501), contains(ModerationIssue.noteTooLong));
      expect(check(tags: List.filled(11, 'nhanh')), contains(ModerationIssue.tooManyTags));
    });
  });

  test('bộ quy tắc ở ứng dụng và ở firestore.rules khớp nhau (cùng mẫu regex, cùng giới hạn)', () {
    final rules = File('firestore.rules').readAsStringSync();
    expect(rules, contains("'(?s).*$bannedPattern.*'"));
    expect(rules, contains("'(?s).*$linkPattern.*'"));
    expect(rules, contains("'(?s).*$repeatPattern.*'"));
    expect(rules, contains("'(?s).*$lettersPattern.*'"));
    expect(rules, contains('d.title.trim().size() >= $titleMin && d.title.size() <= $titleMax'));
    expect(rules, contains('d.note.size() <= $noteMax'));
    expect(rules, contains('d.ingredients.size() >= $minIngredients && d.ingredients.size() <= $maxIngredients'));
    expect(rules, contains('d.steps.size() >= $minSteps && d.steps.size() <= $maxSteps'));
    expect(rules, contains('st.text.trim().size() >= $stepTextMin'));
    expect(rules, contains('d.tags.size() <= $maxTags'));
    expect(rules, contains("duration.value(${postCooldown.inMinutes}, 'm')"));
    expect(rules, contains('n >= $reportsToHide'));
    for (final reason in reportReasonIds.values) {
      expect(rules, contains("'$reason'"));
    }
  });

  group('CommunityPost', () {
    final recipe = Recipe(
      id: 'r1',
      ownerId: 'u1',
      title: ' Phở bò ',
      baseServings: 4,
      ingredients: const [
        Ingredient(id: 'a', name: 'bánh phở', quantity: 1, unit: 'kg'),
        Ingredient(id: 'p', name: '(Chưa có nguyên liệu)', isPlaceholder: true),
      ],
      steps: const [RecipeStep(id: 's', order: 1, text: 'Hầm xương 3 giờ.', imageUrl: 'https://img', durationSec: 10800)],
      tags: const ['cuối tuần'],
    );

    test('tạo từ công thức: id gắn tác giả + công thức, bỏ dòng giữ chỗ và ảnh, không có email', () {
      final post = CommunityPost.fromRecipe(recipe, authorName: 'An');
      expect(post.id, 'u1_r1');
      expect(post.title, 'Phở bò');
      expect(post.ingredients.length, 1);
      final map = post.contentMap();
      expect((map['steps'] as List).single, isNot(contains('imageUrl')));
      expect(map.keys, isNot(contains('email')));
    });

    test('fromMap chịu được dữ liệu thiếu; toRecipe để lưu vào sổ người đọc', () {
      final post = CommunityPost.fromMap('x', {
        'title': 'Phở',
        'ingredients': [
          {'id': 'a', 'name': 'bánh phở'},
        ],
        'status': 'lạ',
      });
      expect(post.status, PostStatus.hidden, reason: 'trạng thái lạ: coi như ẩn cho an toàn');
      expect(post.baseServings, 1);
      final mine = post.toRecipe(id: '', ownerId: 'me');
      expect(mine.ownerId, 'me');
      expect(mine.ingredients.single.name, 'bánh phở');
    });
  });

  test('thống kê cộng đồng: trạng thái, báo cáo, bài theo ngày, số tác giả', () {
    final now = DateTime(2026, 11, 14, 20);
    CommunityPost p(String id, String author, PostStatus s, int reports, DateTime? at) => CommunityPost(
          id: id,
          authorId: author,
          authorName: author,
          sourceRecipeId: id,
          title: 't',
          baseServings: 1,
          ingredients: const [],
          steps: const [],
          status: s,
          reportCount: reports,
          createdAt: at,
        );
    final stats = computeCommunityStats([
      p('1', 'a', PostStatus.visible, 0, DateTime(2026, 11, 14, 8)),
      p('2', 'a', PostStatus.visible, 1, DateTime(2026, 11, 13, 23)),
      p('3', 'b', PostStatus.hidden, 3, DateTime(2026, 11, 8, 1)),
      p('4', 'c', PostStatus.removed, 4, DateTime(2026, 11, 1)),
      p('5', 'c', PostStatus.visible, 0, null),
    ], now);
    expect([stats.total, stats.visible, stats.hidden, stats.removed], [5, 3, 1, 1]);
    expect(stats.totalReports, 8);
    expect(stats.authors, 3);
    expect(stats.perDay, [1, 0, 0, 0, 0, 1, 1], reason: '8/11 … 14/11');
  });
}
