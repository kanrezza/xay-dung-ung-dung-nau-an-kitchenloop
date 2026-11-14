import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../recipes/data/firestore_codec.dart';
import '../../recipes/data/recipe_exceptions.dart';
import '../../recipes/models/recipe.dart';
import '../domain/moderation.dart';
import '../models/community_post.dart';

/// Đăng bài mới quá sớm sau bài trước (rules cũng chặn, đây là kiểm tra trước để báo rõ).
class PostTooSoonException implements Exception {
  const PostTooSoonException(this.wait);
  final Duration wait;
}

/// Máy chủ (Firestore rules) từ chối bài: không đạt kiểm duyệt.
class PostRejectedException implements Exception {}

enum ShareKind { created, updated }

/// Bài cộng đồng (spec 004). Quyền và kiểm duyệt thật nằm ở firestore.rules.
abstract class CommunityRepository {
  String? get currentUid;

  /// Bài đang hiện, mới nhất trước.
  Stream<List<CommunityPost>> watchFeed();

  /// Bài của tài khoản đang đăng nhập cho công thức [recipeId] (null nếu chưa chia sẻ).
  Future<CommunityPost?> myPostFor(String recipeId);

  Future<ShareKind> share(Recipe recipe);
  Future<void> unshare(String postId);
  Future<void> report(String postId, ReportReason reason);

  /// Thích / bỏ thích bài của người khác (spec 007).
  Future<void> setLiked(String postId, bool liked);

  /// Thông báo chung do quản trị viên viết; chuỗi rỗng = không có.
  Stream<String> watchAnnouncement();

  // --- Quản trị viên ---
  Stream<List<CommunityPost>> watchAllPosts();
  Future<List<PostReport>> reportsOf(String postId);
  Future<void> setStatus(String postId, PostStatus status, {bool resetReports = false});
  Future<void> setFeatured(String postId, bool featured);
  Future<void> setAnnouncement(String text);
}

class FirestoreCommunityRepository implements CommunityRepository {
  FirestoreCommunityRepository({
    required FirebaseFirestore firestore,
    required FirebaseAuth auth,
    DateTime Function()? now,
    this.timeout = const Duration(seconds: 10),
  })  : _firestore = firestore,
        _auth = auth,
        _now = now ?? DateTime.now;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final DateTime Function() _now;

  /// Chia sẻ/báo cáo cần máy chủ xác nhận (không có hàng đợi offline có nghĩa ở đây).
  final Duration timeout;

  CollectionReference<Map<String, dynamic>> get _posts => _firestore.collection('communityPosts');

  @override
  String? get currentUid => _auth.currentUser?.uid;

  String _requireUid() {
    final uid = currentUid;
    if (uid == null) throw NotSignedInException();
    return uid;
  }

  List<CommunityPost> _decode(QuerySnapshot<Map<String, dynamic>> snap) {
    final now = _now();
    final posts = [for (final d in snap.docs) CommunityPost.fromMap(d.id, decodeFirestoreMap(d.data()))];
    posts.sort((a, b) => (b.createdAt ?? now).compareTo(a.createdAt ?? now));
    return posts;
  }

  @override
  Stream<List<CommunityPost>> watchFeed() => _posts.where('status', isEqualTo: 'visible').limit(200).snapshots().map(_decode);

  @override
  Future<CommunityPost?> myPostFor(String recipeId) async {
    final uid = _requireUid();
    final doc = await _posts.doc(CommunityPost.idFor(uid, recipeId)).get();
    final data = doc.data();
    return data == null ? null : CommunityPost.fromMap(doc.id, decodeFirestoreMap(data));
  }

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action().timeout(timeout);
    } on TimeoutException {
      throw OfflineException();
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') throw PostRejectedException();
      if (e.code == 'unavailable') throw OfflineException();
      rethrow;
    }
  }

  /// Quyền quản trị lấy từ custom claim trong token (rules kiểm lại cờ `byAdmin` theo đúng quyền này).
  Future<bool> _isAdmin() async {
    try {
      final token = await _auth.currentUser?.getIdTokenResult();
      return token?.claims?['admin'] == true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<ShareKind> share(Recipe recipe) => _guard(() async {
        final uid = _requireUid();
        final admin = await _isAdmin();
        final userRef = _firestore.collection('users').doc(uid);
        final user = (await userRef.get()).data() ?? const {};
        final name =
            user['name'] is String && (user['name'] as String).trim().isNotEmpty ? (user['name'] as String).trim() : 'Bếp nhà KitchenLoop';
        final post = CommunityPost.fromRecipe(recipe, authorName: name.length > authorNameMax ? name.substring(0, authorNameMax) : name);
        final ref = _posts.doc(post.id);
        final existing = await ref.get();
        if (existing.exists) {
          await ref.update({
            ...post.contentMap()
              ..remove('authorId')
              ..remove('sourceRecipeId'),
            'byAdmin': admin,
            'updatedAt': FieldValue.serverTimestamp(),
          });
          return ShareKind.updated;
        }
        final last = user['lastPostAt'];
        if (last is Timestamp) {
          final wait = postCooldown - _now().difference(last.toDate());
          if (wait > Duration.zero) throw PostTooSoonException(wait);
        }
        final batch = _firestore.batch()
          ..set(userRef, {'lastPostAt': FieldValue.serverTimestamp()}, SetOptions(merge: true))
          ..set(ref, {
            ...post.contentMap(),
            'status': 'visible',
            'reportCount': 0,
            'byAdmin': admin,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        await batch.commit();
        return ShareKind.created;
      });

  @override
  Future<void> unshare(String postId) => _guard(() => _posts.doc(postId).delete());

  @override
  Future<void> report(String postId, ReportReason reason) => _guard(() async {
        final uid = _requireUid();
        final ref = _posts.doc(postId);
        await _firestore.runTransaction((tx) async {
          final snap = await tx.get(ref);
          final data = snap.data();
          if (data == null || data['status'] != 'visible') throw PostRejectedException();
          final count = (data['reportCount'] is int ? data['reportCount'] as int : 0) + 1;
          tx.set(ref.collection('reports').doc(uid), {'reason': reportReasonIds[reason], 'createdAt': FieldValue.serverTimestamp()});
          tx.update(ref, {'reportCount': count, if (count >= reportsToHide) 'status': 'hidden'});
        });
      });

  @override
  Future<void> setLiked(String postId, bool liked) => _guard(() {
        final uid = _requireUid();
        return _posts.doc(postId).update({
          'likedBy': liked ? FieldValue.arrayUnion([uid]) : FieldValue.arrayRemove([uid]),
        });
      });

  DocumentReference<Map<String, dynamic>> get _announcement => _firestore.collection('appConfig').doc('announcement');

  @override
  Stream<String> watchAnnouncement() => _announcement.snapshots().map((d) {
        final text = d.data()?['text'];
        return text is String ? text.trim() : '';
      });

  @override
  Future<void> setAnnouncement(String text) => _guard(
        () => _announcement.set({'text': text.trim(), 'updatedAt': FieldValue.serverTimestamp()}),
      );

  @override
  Future<void> setFeatured(String postId, bool featured) => _guard(
        () => _posts.doc(postId).update({'featured': featured, 'updatedAt': FieldValue.serverTimestamp()}),
      );

  @override
  Stream<List<CommunityPost>> watchAllPosts() => _posts.snapshots().map(_decode);

  @override
  Future<List<PostReport>> reportsOf(String postId) async {
    final snap = await _posts.doc(postId).collection('reports').get();
    return [
      for (final d in snap.docs)
        if (reportReasonFrom(d.data()['reason']) case final reason?)
          PostReport(
            reporterId: d.id,
            reason: reason,
            createdAt: decodeFirestoreMap(d.data())['createdAt'] as DateTime?,
          ),
    ];
  }

  @override
  Future<void> setStatus(String postId, PostStatus status, {bool resetReports = false}) => _guard(
        () => _posts.doc(postId).update({
          'status': status.name,
          if (resetReports) 'reportCount': 0,
          'updatedAt': FieldValue.serverTimestamp(),
        }),
      );
}
