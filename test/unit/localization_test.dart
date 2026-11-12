import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Làm phẳng JSON lồng nhau thành các khoá dạng `recipes.title`.
Map<String, String> flatten(Map<String, dynamic> map, [String prefix = '']) {
  final out = <String, String>{};
  map.forEach((key, value) {
    final full = prefix.isEmpty ? key : '$prefix.$key';
    // Khoá số nhiều của easy_localization ({"one": ..., "other": ...}) là MỘT khoá;
    // dạng "other" được dùng để so sánh giữa hai ngôn ngữ.
    if (value is Map<String, dynamic> && value.containsKey('other') && value.keys.every(_pluralForms.contains)) {
      out[full] = value['other'].toString();
    } else if (value is Map<String, dynamic>) {
      out.addAll(flatten(value, full));
    } else {
      out[full] = value.toString();
    }
  });
  return out;
}

Map<String, String> load(String lang) {
  final raw = File('assets/langs/$lang.json').readAsStringSync();
  return flatten(json.decode(raw) as Map<String, dynamic>);
}

int placeholders(String s) => '{}'.allMatches(s).length;

void main() {
  const namespaces = ['recipes.', 'account.', 'common.'];
  late Map<String, String> vi;
  late Map<String, String> en;

  setUpAll(() {
    vi = load('vi');
    en = load('en');
  });

  Set<String> scoped(Map<String, String> m) =>
      m.keys.where((k) => namespaces.any(k.startsWith)).toSet();

  test('vi và en có cùng tập khoá của GĐ1 (recipes, account, common)', () {
    expect(scoped(vi), isNotEmpty);
    expect(scoped(en), scoped(vi));
  });

  test('không có bản dịch rỗng', () {
    for (final k in scoped(vi)) {
      expect(vi[k]!.trim(), isNotEmpty, reason: 'vi.$k rỗng');
      expect(en[k]!.trim(), isNotEmpty, reason: 'en.$k rỗng');
    }
  });

  test('số chỗ trống {} khớp nhau giữa vi và en', () {
    for (final k in scoped(vi)) {
      expect(placeholders(en[k]!), placeholders(vi[k]!), reason: 'khoá $k');
    }
  });

  test('có đủ các khoá bắt buộc trong contracts/screens.md', () {
    const required = [
      'recipes.title', 'recipes.search_hint', 'recipes.empty', 'recipes.empty_filtered',
      'recipes.add', 'recipes.ingredients', 'recipes.steps', 'recipes.servings',
      'recipes.start_cooking', 'recipes.continue_cooking', 'recipes.restart', 'recipes.step_of',
      'recipes.timer_start', 'recipes.timer_done', 'recipes.migrated_summary',
      'recipes.err_title_required', 'recipes.err_no_ingredient', 'recipes.err_no_step',
      'recipes.err_offline_image', 'recipes.syncing', 'recipes.original_content',
      'recipes.placeholder_ingredient', 'recipes.placeholder_step', 'recipes.placeholder_title',
      'account.title', 'account.language', 'account.logout', 'account.logout_confirm',
      'common.save', 'common.cancel', 'common.delete_confirm',
    ];
    for (final k in required) {
      expect(vi.containsKey(k), isTrue, reason: 'thiếu vi.$k');
      expect(en.containsKey(k), isTrue, reason: 'thiếu en.$k');
    }
  });

  test('các khoá cũ vẫn còn nguyên', () {
    for (final k in ['title_profile', 'logout', 'ingredients', 'instructions']) {
      expect(vi.containsKey(k), isTrue, reason: 'mất khoá cũ vi.$k');
      expect(en.containsKey(k), isTrue, reason: 'mất khoá cũ en.$k');
    }
  });
}

const _pluralForms = {'zero', 'one', 'two', 'few', 'many', 'other'};
