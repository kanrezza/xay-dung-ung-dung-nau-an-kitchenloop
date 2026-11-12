import 'package:btl_ltdd/features/recipes/data/firestore_codec.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final moment = DateTime.utc(2026, 3, 4, 5, 6, 7);

  test('đổi Timestamp ở mức ngoài cùng thành DateTime', () {
    final out = decodeFirestoreMap({'createdAt': Timestamp.fromDate(moment), 'title': 'a'});
    expect(out['createdAt'], isA<DateTime>());
    expect((out['createdAt'] as DateTime).isAtSameMomentAs(moment), isTrue);
    expect(out['title'], 'a');
  });

  test('đổi cả Timestamp lồng trong map con', () {
    final out = decodeFirestoreMap({
      'legacy': {'migratedAt': Timestamp.fromDate(moment), 'title': 't'},
    });
    final legacy = out['legacy'] as Map<String, dynamic>;
    expect(legacy['migratedAt'], isA<DateTime>());
    expect(legacy['title'], 't');
  });

  test('đổi cả Timestamp trong danh sách', () {
    final out = decodeFirestoreMap({
      'times': [Timestamp.fromDate(moment), 5, 'x'],
      'rows': [
        {'at': Timestamp.fromDate(moment)},
      ],
    });
    expect((out['times'] as List)[0], isA<DateTime>());
    expect((out['times'] as List)[1], 5);
    expect(((out['rows'] as List).single as Map)['at'], isA<DateTime>());
  });

  test('giữ nguyên giá trị khác và null', () {
    final out = decodeFirestoreMap({'n': 1, 'd': 2.5, 'b': true, 'z': null, 's': 'x', 'l': <String>['a']});
    expect(out, {'n': 1, 'd': 2.5, 'b': true, 'z': null, 's': 'x', 'l': ['a']});
  });

  test('trả về map kiểu Map<String, dynamic> (không còn Map<Object?, Object?>)', () {
    final out = decodeFirestoreMap({
      'm': {1: Timestamp.fromDate(moment)},
    });
    expect(out['m'], isA<Map<String, dynamic>>());
  });

  test('không làm thay đổi dữ liệu đầu vào', () {
    final input = {'t': Timestamp.fromDate(moment)};
    decodeFirestoreMap(input);
    expect(input['t'], isA<Timestamp>());
  });
}
