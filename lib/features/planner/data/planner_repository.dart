import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../recipes/data/recipe_exceptions.dart';
import '../../recipes/data/recipe_repository.dart' show settleWrite;
import '../../recipes/data/stream_utils.dart';
import '../domain/week.dart';
import '../models/shopping_state.dart';
import '../models/week_plan.dart';

/// Thực đơn tuần và trạng thái đi chợ (spec 003). Mỗi tuần một tài liệu, id = `{uid}_{thứ 2}`,
/// chỉ chủ sở hữu đọc/ghi (xem firestore.rules).
abstract class PlannerRepository {
  Stream<WeekPlan> watchWeek(DateTime weekStart);
  Future<void> saveWeek(WeekPlan plan);
  Stream<ShoppingState> watchShopping(DateTime weekStart);
  Future<void> saveShopping(DateTime weekStart, ShoppingState state);
}

class FirestorePlannerRepository implements PlannerRepository {
  FirestorePlannerRepository({
    required FirebaseFirestore firestore,
    required FirebaseAuth auth,
    this.offlineGrace = const Duration(seconds: 2),
  })  : _firestore = firestore,
        _auth = auth;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  /// Khi mất mạng, lần ghi nằm trong hàng đợi cục bộ; không chờ máy chủ quá lâu (xem settleWrite).
  final Duration offlineGrace;

  static String docId(String uid, DateTime weekStart) => '${uid}_${weekKey(weekStart)}';

  /// Phát ngay UID hiện tại rồi theo dõi thay đổi đăng nhập.
  Stream<String?> _userIds() async* {
    yield _auth.currentUser?.uid;
    yield* _auth.authStateChanges().map((user) => user?.uid);
  }

  String _requireUid() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw NotSignedInException();
    return uid;
  }

  Stream<T> _watchDoc<T>(String collection, DateTime weekStart, T Function(Map<String, dynamic>?, bool pending) map) {
    return switchMapStream<String?, T>(_userIds().distinct(), (uid) {
      if (uid == null) return Stream.value(map(null, false));
      return _firestore
          .collection(collection)
          .doc(docId(uid, weekStart))
          .snapshots(includeMetadataChanges: true)
          .map((snap) => map(snap.data(), snap.metadata.hasPendingWrites));
    });
  }

  @override
  Stream<WeekPlan> watchWeek(DateTime weekStart) => _watchDoc(
        'weekPlans',
        weekStart,
        (data, pending) => WeekPlan.fromMap(weekStart, data, isSyncing: pending),
      );

  @override
  Future<void> saveWeek(WeekPlan plan) async {
    final uid = _requireUid();
    final data = plan.toMap(ownerId: uid, weekKey: weekKey(plan.weekStart))
      ..['updatedAt'] = FieldValue.serverTimestamp();
    await settleWrite(_firestore.collection('weekPlans').doc(docId(uid, plan.weekStart)).set(data), offlineGrace);
  }

  @override
  Stream<ShoppingState> watchShopping(DateTime weekStart) =>
      _watchDoc('shoppingLists', weekStart, (data, _) => ShoppingState.fromMap(data));

  @override
  Future<void> saveShopping(DateTime weekStart, ShoppingState state) async {
    final uid = _requireUid();
    final data = state.toMap(ownerId: uid, weekKey: weekKey(weekStart))..['updatedAt'] = FieldValue.serverTimestamp();
    await settleWrite(_firestore.collection('shoppingLists').doc(docId(uid, weekStart)).set(data), offlineGrace);
  }
}
