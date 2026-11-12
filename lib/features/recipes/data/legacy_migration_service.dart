import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../domain/legacy_converter.dart';
import 'firestore_codec.dart';
import 'migration_result.dart';

/// Chuyển công thức dạng cũ (`foods`, nguyên liệu là chuỗi tự do, hướng dẫn là một
/// đoạn) của người dùng hiện tại sang dạng có cấu trúc (`recipes`).
///
/// - Chạy một lần cho mỗi người dùng; xong thì đặt `users/{uid}.recipeMigratedAt`.
/// - Không bao giờ sửa hoặc xoá `foods`.
/// - ID đích là `recipes/{foodId}` nên chạy lại không tạo bản sao; công thức đã có
///   thì được bỏ qua (không ghi đè chỉnh sửa của người dùng).
/// - Đọc dữ liệu từ **máy chủ**, không từ bộ nhớ đệm: nếu đang offline mà đọc cache
///   thấy rỗng thì sẽ đánh dấu "đã chuyển" nhầm và dữ liệu cũ không bao giờ được
///   chuyển. Mất mạng thì ném lỗi để lần sau thử lại.
class LegacyMigrationService {
  LegacyMigrationService({
    required FirebaseFirestore firestore,
    required FirebaseAuth auth,
    DateTime Function()? now,
    this.batchSize = 400,
    this.commitTimeout = const Duration(seconds: 30),
  })  : _firestore = firestore,
        _auth = auth,
        _now = now ?? DateTime.now;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final DateTime Function() _now;

  /// Số công thức tối đa trong một lô ghi (Firestore giới hạn 500 thao tác mỗi lô).
  final int batchSize;

  /// Quá thời gian này mà máy chủ chưa xác nhận thì coi là mất mạng và thử lại sau.
  final Duration commitTimeout;

  static const GetOptions _server = GetOptions(source: Source.server);

  Future<MigrationResult> migrateIfNeeded() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return const MigrationResult();

    final userRef = _firestore.collection('users').doc(uid);
    final user = await userRef.get(_server);
    if (user.data()?['recipeMigratedAt'] != null) return const MigrationResult();

    final foods = await _firestore.collection('foods').where('authorId', isEqualTo: uid).get(_server);
    final recipes = _firestore.collection('recipes');
    final existing = (await recipes.where('ownerId', isEqualTo: uid).get(_server)).docs.map((d) => d.id).toSet();

    final migratedAt = _now();
    final pending = <_Pending>[];
    for (final doc in foods.docs) {
      if (existing.contains(doc.id)) continue; // đã chuyển ở lần trước, giữ nguyên chỉnh sửa
      final conversion = convertLegacyFood(
        foodId: doc.id,
        ownerId: uid,
        data: decodeFirestoreMap(doc.data()),
        migratedAt: migratedAt,
      );
      final data = conversion.recipe.toMap()..['updatedAt'] = FieldValue.serverTimestamp();
      pending.add(_Pending(doc.id, data, conversion.unparsedIngredientLines));
    }

    var migrated = 0;
    var unparsed = 0;
    for (var start = 0; start < pending.length; start += batchSize) {
      final chunk = pending.sublist(start, (start + batchSize).clamp(0, pending.length));
      final batch = _firestore.batch();
      for (final item in chunk) {
        batch.set(recipes.doc(item.id), item.data);
      }
      await batch.commit().timeout(commitTimeout);
      migrated += chunk.length;
      unparsed += chunk.fold<int>(0, (total, item) => total + item.unparsedLines);
    }

    // Chỉ đặt cờ khi mọi lô đã ghi xong; lỗi giữa chừng thì lần sau chạy tiếp.
    await userRef.set({'recipeMigratedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
    return MigrationResult(migrated: migrated, unparsedIngredientLines: unparsed);
  }
}

class _Pending {
  _Pending(this.id, this.data, this.unparsedLines);

  final String id;
  final Map<String, dynamic> data;
  final int unparsedLines;
}
