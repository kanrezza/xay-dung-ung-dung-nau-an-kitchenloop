import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import '../models/recipe.dart';
import 'firestore_codec.dart';
import 'recipe_exceptions.dart';
import 'stream_utils.dart';

export 'recipe_exceptions.dart';

/// Truy cập dữ liệu công thức của người dùng hiện tại. Giao diện chỉ được gọi
/// qua lớp này, không gọi Firebase trực tiếp (Constitution IV).
abstract class RecipeRepository {
  /// Công thức của người dùng hiện tại, mới sửa nhất trước. Lấy từ bộ nhớ đệm
  /// khi offline. Chưa đăng nhập → danh sách rỗng.
  Stream<List<Recipe>> watchMyRecipes();

  /// Một công thức; `null` nếu không tồn tại hoặc không thuộc người dùng.
  Stream<Recipe?> watchRecipe(String id);

  /// UID người dùng hiện tại; phát lại khi đăng nhập/đăng xuất/đổi tài khoản.
  Stream<String?> watchUserId();

  /// Tạo công thức, trả về `id`. Đặt `ownerId`, `createdAt`, `updatedAt`.
  /// Ném [RecipeValidationException] nếu dữ liệu sai, [NotSignedInException]
  /// nếu chưa đăng nhập.
  Future<String> create(Recipe draft);

  /// Cập nhật công thức; giữ nguyên `ownerId`, `createdAt` và `legacy`.
  /// Ném [RecipeNotFoundException] nếu công thức không tồn tại.
  Future<void> update(Recipe recipe);

  Future<void> delete(String id);

  /// Tải ảnh lên Storage và trả về URL tải xuống. [recipeId] chỉ dùng làm tên
  /// thư mục (có thể là id tạm của công thức chưa lưu).
  /// Ném [OfflineException] khi không có mạng.
  Future<String> uploadImage(File file, {required String recipeId});
}

/// Kiểu nội dung (MIME) của ảnh theo đuôi file; mặc định `image/jpeg`.
/// Storage rules chỉ nhận file có contentType bắt đầu bằng `image/`.
String imageContentType(String path) {
  final dot = path.lastIndexOf('.');
  final ext = dot < 0 ? '' : path.substring(dot + 1).toLowerCase();
  switch (ext) {
    case 'png':
      return 'image/png';
    case 'gif':
      return 'image/gif';
    case 'webp':
      return 'image/webp';
    case 'heic':
      return 'image/heic';
    default:
      return 'image/jpeg';
  }
}

class FirestoreRecipeRepository implements RecipeRepository {
  /// [offlineGrace]: thời gian tối đa chờ máy chủ xác nhận một lần ghi. Khi
  /// offline, lần ghi được xếp hàng và đồng bộ sau, nên không chờ vô hạn.
  FirestoreRecipeRepository({
    required FirebaseFirestore firestore,
    required FirebaseAuth auth,
    FirebaseStorage? storage,
    this.offlineGrace = const Duration(seconds: 2),
    this.uploadTimeout = const Duration(seconds: 25),
  })  : _firestore = firestore,
        _auth = auth,
        _storage = storage;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final FirebaseStorage? _storage;
  final Duration offlineGrace;

  /// Quá thời gian này mà chưa tải xong thì coi như không có mạng.
  final Duration uploadTimeout;

  CollectionReference<Map<String, dynamic>> get _col => _firestore.collection('recipes');

  String _requireUid() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw NotSignedInException();
    return uid;
  }

  @override
  Stream<String?> watchUserId() => _userIds().distinct();

  /// Phát ngay UID hiện tại rồi theo dõi thay đổi đăng nhập, để người nghe mới
  /// không phải chờ sự kiện đầu tiên của `authStateChanges()`.
  Stream<String?> _userIds() async* {
    yield _auth.currentUser?.uid;
    yield* _auth.authStateChanges().map((user) => user?.uid);
  }

  @override
  Stream<List<Recipe>> watchMyRecipes() {
    return switchMapStream<String?, List<Recipe>>(watchUserId(), (uid) {
      if (uid == null) return Stream.value(const <Recipe>[]);
      // includeMetadataChanges: nhận cả sự kiện "đã được máy chủ xác nhận" để cập nhật nhãn đang đồng bộ.
      return _col.where('ownerId', isEqualTo: uid).snapshots(includeMetadataChanges: true).map((snap) {
        final now = DateTime.now();
        final recipes = snap.docs
            .map((doc) => Recipe.fromMap(decodeFirestoreMap(doc.data()), doc.id, isSyncing: doc.metadata.hasPendingWrites))
            .where((r) => r.ownerId == uid)
            .toList();
        // updatedAt == null: đang chờ máy chủ đặt thời gian → coi là mới nhất.
        recipes.sort((a, b) => (b.updatedAt ?? now).compareTo(a.updatedAt ?? now));
        return recipes;
      });
    });
  }

  @override
  Stream<Recipe?> watchRecipe(String id) {
    return switchMapStream<String?, Recipe?>(watchUserId(), (uid) {
      if (uid == null) return Stream.value(null);
      return _col.doc(id).snapshots(includeMetadataChanges: true).map<Recipe?>((snap) {
        final data = snap.data();
        if (!snap.exists || data == null) return null;
        final recipe = Recipe.fromMap(decodeFirestoreMap(data), snap.id, isSyncing: snap.metadata.hasPendingWrites);
        return recipe.ownerId == uid ? recipe : null;
      }).transform(StreamTransformer<Recipe?, Recipe?>.fromHandlers(
        handleError: (error, stackTrace, sink) {
          // Document chưa tồn tại hoặc của người khác → "không có".
          if (error is FirebaseException && error.code == 'permission-denied') {
            sink.add(null);
          } else {
            sink.addError(error, stackTrace);
          }
        },
      ));
    });
  }

  @override
  Future<String> create(Recipe draft) async {
    final uid = _requireUid();
    final errors = draft.validate();
    if (errors.isNotEmpty) throw RecipeValidationException(errors);

    final ref = _col.doc();
    final data = draft.toMap()
      ..['ownerId'] = uid
      ..['schemaVersion'] = Recipe.currentSchemaVersion
      ..['createdAt'] = FieldValue.serverTimestamp()
      ..['updatedAt'] = FieldValue.serverTimestamp();
    await settleWrite(ref.set(data), offlineGrace);
    return ref.id;
  }

  @override
  Future<void> update(Recipe recipe) async {
    _requireUid();
    if (recipe.id.isEmpty) throw RecipeNotFoundException(recipe.id);
    final errors = recipe.validate();
    if (errors.isNotEmpty) throw RecipeValidationException(errors);

    // Không gửi các trường bất biến hoặc do hệ thống quản lý.
    final data = recipe.toMap()
      ..remove('ownerId')
      ..remove('createdAt')
      ..remove('legacy')
      ..['updatedAt'] = FieldValue.serverTimestamp();
    try {
      await settleWrite(_col.doc(recipe.id).update(data), offlineGrace);
    } on FirebaseException catch (e) {
      if (e.code == 'not-found') throw RecipeNotFoundException(recipe.id);
      rethrow;
    }
  }

  @override
  Future<void> delete(String id) async {
    _requireUid();
    await settleWrite(_col.doc(id).delete(), offlineGrace);
  }

  @override
  Future<String> uploadImage(File file, {required String recipeId}) async {
    final uid = _requireUid();
    final storage = _storage;
    if (storage == null) throw StateError('FirestoreRecipeRepository chưa được cấu hình FirebaseStorage');

    // Dùng đường dẫn foods/{uid}/... vì Storage rules hiện có đã cho phép chủ sở hữu ghi ảnh ở đó.
    final ref = storage.ref('foods/$uid/recipes/$recipeId/${DateTime.now().millisecondsSinceEpoch}.jpg');
    final task = ref.putFile(file, SettableMetadata(contentType: imageContentType(file.path)));
    try {
      await task.timeout(uploadTimeout);
      return await ref.getDownloadURL();
    } on TimeoutException {
      await task.cancel();
      throw OfflineException();
    } on FirebaseException catch (e) {
      if (const {'retry-limit-exceeded', 'network-request-failed', 'canceled'}.contains(e.code)) {
        throw OfflineException();
      }
      rethrow;
    }
  }
}

/// Chờ một lần ghi Firestore tối đa [grace].
///
/// Khi mất mạng, Firestore xếp lần ghi vào hàng đợi cục bộ (hiện ngay trong
/// `snapshots()` với `hasPendingWrites`) nhưng `Future` của lần ghi chỉ hoàn tất
/// khi máy chủ xác nhận, có thể rất lâu. Hàm này làm cho giao diện không bị treo:
/// lỗi trả về sớm (ví dụ bị từ chối quyền) vẫn được ném ra; nếu quá hạn (thường do
/// offline) thì coi như đã ghi vào bộ nhớ đệm cục bộ và việc đồng bộ tiếp tục ở
/// nền, mọi lỗi hay kết quả đến muộn được bỏ qua êm.
@visibleForTesting
Future<void> settleWrite(Future<void> write, Duration grace) {
  final completer = Completer<void>();
  final timer = Timer(grace, () {
    if (!completer.isCompleted) completer.complete();
  });
  write.then((_) {
    timer.cancel();
    if (!completer.isCompleted) completer.complete();
  }, onError: (Object error, StackTrace stackTrace) {
    timer.cancel();
    if (!completer.isCompleted) completer.completeError(error, stackTrace);
  });
  return completer.future;
}
