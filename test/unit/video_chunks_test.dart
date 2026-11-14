import 'dart:typed_data';

import 'package:btl_ltdd/features/recipes/domain/video_chunks.dart';
import 'package:btl_ltdd/features/recipes/models/recipe.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Uint8List bytes(int n) => Uint8List.fromList(List.generate(n, (i) => i % 251));

  test('cắt thành mẩu ≤ 750 000 byte rồi ghép lại đúng nguyên bản', () {
    final video = bytes(videoChunkBytes * 2 + 123);
    final chunks = splitVideo(video);
    expect(chunks.length, 3);
    expect(chunks.map((c) => c.length), [videoChunkBytes, videoChunkBytes, 123]);
    expect(joinVideoChunks(chunks), video);
  });

  test('video nhỏ hơn một mẩu: một mẩu duy nhất', () {
    expect(splitVideo(bytes(600 * 1024)).length, 1);
  });

  test('rỗng hoặc vượt ~20 MB bị từ chối', () {
    expect(() => splitVideo(Uint8List(0)), throwsArgumentError);
    expect(() => splitVideo(Uint8List(maxVideoBytes + 1)), throwsArgumentError);
    expect(splitVideo(Uint8List(maxVideoBytes)).length, maxVideoChunks);
  });

  test('tên mẩu đánh số 2 chữ số để sắp xếp đúng', () {
    expect(videoChunkId('v1', 3), 'v1_03');
    expect(videoChunkId('v1', 27), 'v1_27');
  });

  group('RecipeVideo', () {
    test('toMap / fromMap', () {
      const v = RecipeVideo(id: 'v1', chunkCount: 2, sizeBytes: 900000, durationMs: 2333);
      final back = RecipeVideo.fromMap(v.toMap())!;
      expect([back.id, back.chunkCount, back.sizeBytes, back.durationMs, back.mime], ['v1', 2, 900000, 2333, 'video/mp4']);
    });

    test('dữ liệu hỏng: coi như chưa có video', () {
      expect(RecipeVideo.fromMap(null), isNull);
      expect(RecipeVideo.fromMap({'id': 'v', 'chunkCount': 0, 'sizeBytes': 1}), isNull);
      expect(RecipeVideo.fromMap({'id': '', 'chunkCount': 1, 'sizeBytes': 1}), isNull);
    });

    test('Recipe đọc video nhưng toMap KHÔNG ghi video (sửa công thức không đè video)', () {
      final r = Recipe.fromMap({
        'ownerId': 'u',
        'title': 'Phở',
        'baseServings': 2,
        'ingredients': [],
        'steps': [],
        'video': {'id': 'v1', 'chunkCount': 1, 'sizeBytes': 10},
      }, 'r1');
      expect(r.video!.id, 'v1');
      expect(r.toMap().containsKey('video'), isFalse);
      expect(r.copyWith(video: null).video, isNull);
      expect(r.copyWith(title: 'x').video!.id, 'v1');
    });
  });
}
