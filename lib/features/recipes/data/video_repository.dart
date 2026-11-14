import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:path_provider/path_provider.dart';

import '../domain/video_chunks.dart';
import '../models/recipe.dart';
import 'recipe_exceptions.dart';

/// Video vượt giới hạn (~20 MB sau khi nén).
class VideoTooLargeException implements Exception {}

/// Báo tiến độ: đã xong [done] trên [total] mẩu.
typedef ChunkProgress = void Function(int done, int total);

/// Video hướng dẫn cắt mẩu trong Firestore (spec 006).
abstract class VideoRepository {
  /// Tải [file] lên làm video của công thức [recipeId] (thay video cũ nếu có). Trả về thông tin video mới.
  Future<RecipeVideo> upload(String recipeId, File file, {int? durationMs, ChunkProgress? onProgress});

  /// Tải các mẩu về, ghép thành file trên máy (lưu lại để xem offline) và trả về file đó.
  Future<File> load(String recipeId, RecipeVideo video, {ChunkProgress? onProgress});

  /// Bỏ video khỏi công thức và xoá các mẩu.
  Future<void> remove(String recipeId, RecipeVideo video);
}

class FirestoreVideoRepository implements VideoRepository {
  FirestoreVideoRepository({
    required FirebaseFirestore firestore,
    required FirebaseAuth auth,
    Future<Directory> Function()? cacheDir,
    this.chunkTimeout = const Duration(seconds: 90),
  })  : _firestore = firestore,
        _auth = auth,
        _cacheDir = cacheDir ?? getTemporaryDirectory;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final Future<Directory> Function() _cacheDir;

  /// Mỗi mẩu ~750 KB phải được máy chủ xác nhận; quá lâu thì coi như mất mạng.
  final Duration chunkTimeout;

  final _random = Random.secure();

  CollectionReference<Map<String, dynamic>> _chunks(String recipeId) =>
      _firestore.collection('recipes').doc(recipeId).collection('videoChunks');

  String _newId() {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    return List.generate(16, (_) => chars[_random.nextInt(chars.length)]).join();
  }

  String _requireUid() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw NotSignedInException();
    return uid;
  }

  Future<T> _timed<T>(Future<T> f) async {
    try {
      return await f.timeout(chunkTimeout);
    } on TimeoutException {
      throw OfflineException();
    }
  }

  @override
  Future<RecipeVideo> upload(String recipeId, File file, {int? durationMs, ChunkProgress? onProgress}) async {
    final uid = _requireUid();
    final bytes = await file.readAsBytes();
    if (bytes.length > maxVideoBytes) throw VideoTooLargeException();
    final parts = splitVideo(bytes);
    final videoId = _newId();
    onProgress?.call(0, parts.length);
    // Ghi các mẩu TRƯỚC, từng mẩu một (mỗi lần ghi ≤ 1 MiB), rồi mới gắn video vào công thức.
    for (var i = 0; i < parts.length; i++) {
      await _timed(_chunks(recipeId).doc(videoChunkId(videoId, i)).set({
        'ownerId': uid,
        'videoId': videoId,
        'index': i,
        'data': Blob(parts[i]),
      }));
      onProgress?.call(i + 1, parts.length);
    }
    final recipeRef = _firestore.collection('recipes').doc(recipeId);
    final old = RecipeVideo.fromMap((await recipeRef.get()).data()?['video']);
    final video = RecipeVideo(id: videoId, chunkCount: parts.length, sizeBytes: bytes.length, durationMs: durationMs);
    await _timed(recipeRef.update({'video': video.toMap()}));
    // Video mới đã gắn xong mới xoá mẩu của video cũ.
    if (old != null) await _deleteChunks(recipeId, old);
    await _writeCache(video, bytes);
    return video;
  }

  Future<File> _cacheFile(RecipeVideo video) async {
    final dir = Directory('${(await _cacheDir()).path}/recipe_videos');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return File('${dir.path}/${video.id}.mp4');
  }

  Future<void> _writeCache(RecipeVideo video, Uint8List bytes) async {
    try {
      await (await _cacheFile(video)).writeAsBytes(bytes, flush: true);
    } catch (_) {}
  }

  @override
  Future<File> load(String recipeId, RecipeVideo video, {ChunkProgress? onProgress}) async {
    _requireUid();
    final file = await _cacheFile(video);
    if (file.existsSync() && file.lengthSync() == video.sizeBytes) return file;
    final parts = <Uint8List>[];
    onProgress?.call(0, video.chunkCount);
    for (var i = 0; i < video.chunkCount; i++) {
      final snap = await _timed(_chunks(recipeId).doc(videoChunkId(video.id, i)).get());
      final data = snap.data()?['data'];
      if (data is! Blob) throw StateError('Thiếu mẩu video $i');
      parts.add(data.bytes);
      onProgress?.call(i + 1, video.chunkCount);
    }
    final bytes = joinVideoChunks(parts);
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  Future<void> _deleteChunks(String recipeId, RecipeVideo video) async {
    for (var i = 0; i < video.chunkCount; i++) {
      try {
        await _chunks(recipeId).doc(videoChunkId(video.id, i)).delete();
      } catch (_) {
        // Mẩu sót lại không ảnh hưởng hiển thị; chỉ chiếm dung lượng.
      }
    }
    try {
      final f = await _cacheFile(video);
      if (f.existsSync()) await f.delete();
    } catch (_) {}
  }

  @override
  Future<void> remove(String recipeId, RecipeVideo video) async {
    _requireUid();
    await _timed(_firestore.collection('recipes').doc(recipeId).update({'video': null}));
    await _deleteChunks(recipeId, video);
  }

  /// Xoá mẩu video khi xoá cả công thức (gọi TRƯỚC khi xoá tài liệu công thức).
  static Future<void> deleteChunksOf(FirebaseFirestore firestore, String recipeId) async {
    try {
      final video = RecipeVideo.fromMap((await firestore.collection('recipes').doc(recipeId).get()).data()?['video']);
      if (video == null) return;
      final col = firestore.collection('recipes').doc(recipeId).collection('videoChunks');
      for (var i = 0; i < video.chunkCount; i++) {
        await col.doc(videoChunkId(video.id, i)).delete();
      }
    } catch (_) {}
  }
}
