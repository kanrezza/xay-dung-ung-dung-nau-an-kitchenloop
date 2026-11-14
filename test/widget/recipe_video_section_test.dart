import 'dart:async';
import 'dart:io';

import 'package:btl_ltdd/features/recipes/data/video_compressor.dart';
import 'package:btl_ltdd/features/recipes/data/video_repository.dart';
import 'package:btl_ltdd/features/recipes/models/recipe.dart';
import 'package:btl_ltdd/features/recipes/view/widgets/recipe_video_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class FakeVideoRepository implements VideoRepository {
  Completer<File>? loading;
  ChunkProgress? lastProgress;
  final removed = <String>[];

  @override
  Future<File> load(String recipeId, RecipeVideo video, {ChunkProgress? onProgress}) {
    lastProgress = onProgress;
    loading = Completer<File>();
    return loading!.future;
  }

  @override
  Future<void> remove(String recipeId, RecipeVideo video) async => removed.add('$recipeId/${video.id}');

  @override
  Future<RecipeVideo> upload(String recipeId, File file, {int? durationMs, ChunkProgress? onProgress}) => throw UnimplementedError();
}

class FakeCompressor implements VideoCompressor {
  @override
  Future<CompressedVideo> compress(File input) async => CompressedVideo(input, null);
}

Recipe recipe({RecipeVideo? video}) => Recipe(
      id: 'r1',
      ownerId: 'alice',
      title: 'Phở bò',
      baseServings: 2,
      ingredients: const [],
      steps: const [],
      video: video,
    );

const sample = RecipeVideo(id: 'abc123def', chunkCount: 2, sizeBytes: 1048576, durationMs: 2300);

void main() {
  late FakeVideoRepository repo;

  setUp(() => repo = FakeVideoRepository());

  Future<void> pump(WidgetTester tester, Recipe r) => tester.pumpWidget(MultiProvider(
        providers: [
          Provider<VideoRepository>.value(value: repo),
          Provider<VideoCompressor>.value(value: FakeCompressor()),
        ],
        child: MaterialApp(home: Scaffold(body: SingleChildScrollView(child: RecipeVideoSection(recipe: r)))),
      ));

  testWidgets('chưa có video: hiện nút thêm, không có menu', (tester) async {
    await pump(tester, recipe());
    expect(find.byKey(const Key('add_video')), findsOneWidget);
    expect(find.byKey(const Key('video_menu')), findsNothing);
    expect(find.byKey(const Key('video_play')), findsNothing);
  });

  testWidgets('có video: hiện ô phát với thời lượng và dung lượng', (tester) async {
    await pump(tester, recipe(video: sample));
    expect(find.byKey(const Key('video_play')), findsOneWidget);
    expect(find.text('3 s · 1.0 MB'), findsOneWidget);
    expect(find.byKey(const Key('add_video')), findsNothing);
  });

  testWidgets('chạm phát: tải từng phần có thanh tiến độ; lỗi thì quay lại và báo', (tester) async {
    await pump(tester, recipe(video: sample));
    await tester.tap(find.byKey(const Key('video_play')));
    await tester.pump();
    expect(find.byKey(const Key('video_progress')), findsOneWidget);
    expect(find.byKey(const Key('video_menu')), findsNothing, reason: 'không cho thay/xoá khi đang tải');

    repo.lastProgress!(1, 2);
    await tester.pump();
    expect(tester.widget<LinearProgressIndicator>(find.byKey(const Key('video_progress'))).value, 0.5);

    repo.loading!.completeError(Exception('mất mạng'));
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('video_progress')), findsNothing);
    expect(find.byKey(const Key('video_play')), findsOneWidget);
    expect(find.text('recipes.video_load_failed'), findsOneWidget);
  });

  testWidgets('xoá video qua menu, có hỏi xác nhận', (tester) async {
    await pump(tester, recipe(video: sample));
    await tester.tap(find.byKey(const Key('video_menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('recipes.video_remove'));
    await tester.pumpAndSettle();
    expect(repo.removed, isEmpty);
    await tester.tap(find.byKey(const Key('video_remove_confirm')));
    await tester.pumpAndSettle();
    expect(repo.removed, ['r1/abc123def']);
    expect(find.text('recipes.video_removed'), findsOneWidget);
  });
}
