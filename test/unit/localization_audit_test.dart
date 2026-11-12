import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Rà soát đa ngôn ngữ cho `lib/features/recipes/` (Constitution VI, T061):
/// mọi văn bản hiển thị phải đi qua `.tr()` và mọi khoá đang dùng phải có cả bản
/// tiếng Việt lẫn tiếng Anh.
void main() {
  const base = 'lib/features/recipes';

  List<File> dartFiles() => Directory(base)
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

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

  Map<String, String> load(String lang) =>
      flatten(json.decode(File('assets/langs/$lang.json').readAsStringSync()) as Map<String, dynamic>);

  /// Các khoá `.tr()` xuất hiện trong mã: `'a.b'.tr(` và `(cond ? 'a.b' : 'c.d').tr(`.
  Set<String> usedKeys() {
    final keys = <String>{};
    final direct = RegExp(r'''['"]([A-Za-z_][\w.]*)['"]\s*\.(?:tr|plural)\(''');
    final ternary = RegExp(r'''\(\s*[^()]*\?\s*['"]([\w.]+)['"]\s*:\s*['"]([\w.]+)['"]\s*\)\s*\.tr\(''');
    for (final f in dartFiles()) {
      final text = f.readAsStringSync();
      for (final m in direct.allMatches(text)) {
        keys.add(m.group(1)!);
      }
      for (final m in ternary.allMatches(text)) {
        keys..add(m.group(1)!)..add(m.group(2)!);
      }
    }
    return keys;
  }

  test('mọi khoá .tr() đang dùng đều có trong tiếng Việt và tiếng Anh', () {
    final vi = load('vi');
    final en = load('en');
    final keys = usedKeys();
    expect(keys.length, greaterThan(40), reason: 'bộ quét khoá có vấn đề');
    expect(keys.where((k) => !vi.containsKey(k)).toList()..sort(), isEmpty, reason: 'thiếu ở vi');
    expect(keys.where((k) => !en.containsKey(k)).toList()..sort(), isEmpty, reason: 'thiếu ở en');
  });

  test('không có văn bản hiển thị nào bị viết cứng', () {
    // Tên ngôn ngữ luôn viết bằng chính ngôn ngữ đó nên không dịch.
    const allowed = {'Tiếng Việt', 'English'};
    final literal = RegExp(
      r'''(?:Text\(|labelText:|hintText:|helperText:|errorText:|tooltip:|message:|semanticLabel:|title:|content:|label:)\s*(?:const\s+Text\(\s*)?(['"])([^'"\n]*)\1(?!\s*\.(?:tr|plural))''',
    );
    final hardcoded = <String>[];
    for (final f in dartFiles()) {
      final text = f.readAsStringSync();
      for (final m in literal.allMatches(text)) {
        // Bỏ phần nội suy ($x, ${...}) rồi xem còn chữ nào không.
        final visible = m.group(2)!.replaceAll(RegExp(r'\$\{[^}]*\}|\$\w+'), '');
        if (!RegExp(r'[A-Za-zÀ-ỹ]{2,}').hasMatch(visible)) continue;
        if (allowed.contains(m.group(2))) continue;
        final line = text.substring(0, m.start).split('\n').length;
        hardcoded.add('${f.path}:$line: "${m.group(2)}"');
      }
    }
    expect(hardcoded, isEmpty, reason: 'chuỗi cứng chưa qua .tr():\n${hardcoded.join('\n')}');
  });

  test('bộ quét chuỗi cứng thực sự phát hiện được chuỗi cứng (kiểm tra chính nó)', () {
    final literal = RegExp(
      r'''(?:Text\(|labelText:|hintText:)\s*(?:const\s+Text\(\s*)?(['"])([^'"\n]*)\1(?!\s*\.tr)''',
    );
    expect(literal.hasMatch("Text('Xin chào')"), isTrue);
    expect(literal.hasMatch("labelText: 'Tên món'"), isTrue);
    expect(literal.hasMatch("Text('recipes.title'.tr())"), isFalse);
    expect(literal.hasMatch("hintText: 'recipes.f_title'.tr()"), isFalse);
  });

  test('vi và en có cùng tập khoá của GĐ1', () {
    final vi = load('vi');
    final en = load('en');
    bool phase1(String k) => k.startsWith('recipes.') || k.startsWith('account.') || k.startsWith('common.');
    expect(en.keys.where(phase1).toSet(), vi.keys.where(phase1).toSet());
  });
}

const _pluralForms = {'zero', 'one', 'two', 'few', 'many', 'other'};
