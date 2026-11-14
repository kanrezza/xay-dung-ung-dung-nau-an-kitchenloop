import 'dart:io';
import 'dart:typed_data';

import 'package:btl_ltdd/features/recipes/data/recipe_repository.dart';
import 'package:btl_ltdd/features/recipes/data/video_repository.dart';
import 'package:btl_ltdd/features/recipes/domain/video_chunks.dart';
import 'package:btl_ltdd/features/recipes/models/recipe.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeFirebaseFirestore db;
  late Directory tmp;
  late FirestoreVideoRepository repo;
  final auth = MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: 'alice'));

  Future<File> videoFile(int size) async {
    final f = File('${tmp.path}/in_$size.mp4');
    await f.writeAsBytes(Uint8List.fromList(List.generate(size, (i) => i % 256)));
    return f;
  }

  setUp(() async {
    db = FakeFirebaseFirestore();
    tmp = await Directory.systemTemp.createTemp('video_test');
    repo = FirestoreVideoRepository(firestore: db, auth: auth, cacheDir: () async => tmp);
    await db.collection('recipes').doc('r1').set({'ownerId': 'alice', 'title': 'Phở'});
  });

  tearDown(() => tmp.delete(recursive: true));

  Future<int> chunkCount() async => (await db.collection('recipes').doc('r1').collection('videoChunks').get()).docs.length;

  test('tải lên: cắt mẩu ≤ 750 KB (kiểu bytes), báo tiến độ, gắn thông tin video vào công thức', () async {
    final progress = <String>[];
    final video =
        await repo.upload('r1', await videoFile(videoChunkBytes + 1000), durationMs: 2333, onProgress: (d, t) => progress.add('$d/$t'));
    expect(video.chunkCount, 2);
    expect(progress, ['0/2', '1/2', '2/2']);
    final chunk = (await db.collection('recipes').doc('r1').collection('videoChunks').doc(videoChunkId(video.id, 0)).get()).data()!;
    expect(chunk['data'], isA<Blob>());
    expect((chunk['data'] as Blob).bytes.length, videoChunkBytes);
    expect([chunk['ownerId'], chunk['videoId'], chunk['index']], ['alice', video.id, 0]);
    final saved = RecipeVideo.fromMap((await db.collection('recipes').doc('r1').get()).data()!['video'])!;
    expect([saved.id, saved.chunkCount, saved.durationMs], [video.id, 2, 2333]);
  });

  test('tải về: ghép đúng nguyên bản; lần sau dùng file đã lưu trên máy', () async {
    final input = await videoFile(videoChunkBytes * 2 + 7);
    final video = await repo.upload('r1', input);
    // Xoá bản lưu sẵn để buộc tải lại từ các mẩu.
    File('${tmp.path}/recipe_videos/${video.id}.mp4').deleteSync();
    final progress = <String>[];
    final out = await repo.load('r1', video, onProgress: (d, t) => progress.add('$d/$t'));
    expect(out.readAsBytesSync(), input.readAsBytesSync());
    expect(progress.last, '3/3');
    progress.clear();
    await repo.load('r1', video, onProgress: (d, t) => progress.add('$d/$t'));
    expect(progress, isEmpty, reason: 'đã có file trên máy: không tải lại');
  });

  test('thay video: mẩu của video cũ bị xoá sau khi video mới gắn xong', () async {
    final first = await repo.upload('r1', await videoFile(1000));
    final second = await repo.upload('r1', await videoFile(2000));
    final ids = (await db.collection('recipes').doc('r1').collection('videoChunks').get()).docs.map((d) => d.id);
    expect(ids, everyElement(startsWith(second.id)));
    expect(ids.any((id) => id.startsWith(first.id)), isFalse);
  });

  test('xoá video: bỏ thông tin video và xoá mẩu', () async {
    final video = await repo.upload('r1', await videoFile(1000));
    await repo.remove('r1', video);
    expect((await db.collection('recipes').doc('r1').get()).data()!['video'], isNull);
    expect(await chunkCount(), 0);
  });

  test('video quá ~20 MB bị từ chối, không ghi gì', () async {
    await expectLater(repo.upload('r1', await videoFile(maxVideoBytes + 1)), throwsA(isA<VideoTooLargeException>()));
    expect(await chunkCount(), 0);
  });

  test('xoá công thức thì xoá luôn mẩu video', () async {
    await db.collection('recipes').doc('r1').set({'ownerId': 'alice', 'title': 'Phở', 'baseServings': 2, 'ingredients': [], 'steps': []});
    await repo.upload('r1', await videoFile(1000));
    final recipes = FirestoreRecipeRepository(firestore: db, auth: auth, offlineGrace: const Duration(milliseconds: 50));
    await recipes.delete('r1');
    expect(await chunkCount(), 0);
    expect((await db.collection('recipes').doc('r1').get()).exists, isFalse);
  });
}
