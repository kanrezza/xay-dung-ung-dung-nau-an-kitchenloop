import 'dart:async';

import 'package:btl_ltdd/features/admin/data/admin_repository.dart';
import 'package:btl_ltdd/features/admin/models/admin_user.dart';
import 'package:btl_ltdd/features/community/data/community_repository.dart';
import 'package:btl_ltdd/features/community/domain/moderation.dart';
import 'package:btl_ltdd/features/community/models/community_post.dart';
import 'package:btl_ltdd/features/recipes/models/recipe.dart';

/// Repository cộng đồng giả trong bộ nhớ (không kiểm tra quyền; rules được test riêng trên emulator).
class FakeCommunityRepository implements CommunityRepository {
  FakeCommunityRepository({this.uid = 'alice', DateTime Function()? now}) : _now = now ?? DateTime.now;

  final String uid;
  final DateTime Function() _now;
  final posts = <String, CommunityPost>{};
  final reports = <String, List<PostReport>>{};
  final _changes = StreamController<void>.broadcast();
  bool reject = false;
  Duration? tooSoon;

  void _emit() => _changes.add(null);

  List<CommunityPost> _sorted(Iterable<CommunityPost> ps) =>
      ps.toList()..sort((a, b) => (b.createdAt ?? _now()).compareTo(a.createdAt ?? _now()));

  @override
  String? get currentUid => uid;

  @override
  Stream<List<CommunityPost>> watchFeed() async* {
    List<CommunityPost> feed() => _sorted(posts.values.where((p) => p.status == PostStatus.visible));
    yield feed();
    yield* _changes.stream.map((_) => feed());
  }

  @override
  Stream<List<CommunityPost>> watchAllPosts() async* {
    yield _sorted(posts.values);
    yield* _changes.stream.map((_) => _sorted(posts.values));
  }

  @override
  Future<CommunityPost?> myPostFor(String recipeId) async => posts[CommunityPost.idFor(uid, recipeId)];

  @override
  Future<ShareKind> share(Recipe recipe) async {
    if (reject) throw PostRejectedException();
    if (tooSoon != null) throw PostTooSoonException(tooSoon!);
    final post = CommunityPost.fromRecipe(recipe, authorName: 'An');
    final existed = posts.containsKey(post.id);
    final before = posts[post.id];
    posts[post.id] = CommunityPost.fromMap(post.id, {
      ...post.contentMap(),
      'status': 'visible',
      'reportCount': 0,
      'createdAt': before?.createdAt ?? _now(),
      'likedBy': before?.likedBy ?? const <String>[],
      'featured': before?.featured ?? false,
      'byAdmin': isAdmin,
    });
    _emit();
    return existed ? ShareKind.updated : ShareKind.created;
  }

  @override
  Future<void> unshare(String postId) async {
    posts.remove(postId);
    _emit();
  }

  @override
  Future<void> report(String postId, ReportReason reason) async {
    final p = posts[postId]!;
    final list = reports.putIfAbsent(postId, () => []);
    if (list.any((r) => r.reporterId == uid)) throw PostRejectedException();
    list.add(PostReport(reporterId: uid, reason: reason));
    final count = p.reportCount + 1;
    posts[postId] = p.copyWith(status: count >= reportsToHide ? PostStatus.hidden : p.status, reportCount: count);
    _emit();
  }

  @override
  Future<List<PostReport>> reportsOf(String postId) async => reports[postId] ?? const [];

  @override
  Future<void> setStatus(String postId, PostStatus status, {bool resetReports = false}) async {
    final p = posts[postId]!;
    posts[postId] = p.copyWith(status: status, reportCount: resetReports ? 0 : p.reportCount);
    _emit();
  }

  String announcement = '';
  bool isAdmin = false;

  @override
  Future<void> setLiked(String postId, bool liked) async {
    final p = posts[postId]!;
    if (reject || p.authorId == uid) throw PostRejectedException();
    final likes = {...p.likedBy};
    liked ? likes.add(uid) : likes.remove(uid);
    posts[postId] = p.copyWith(likedBy: likes.toList());
    _emit();
  }

  @override
  Future<void> setFeatured(String postId, bool featured) async {
    posts[postId] = posts[postId]!.copyWith(featured: featured);
    _emit();
  }

  @override
  Stream<String> watchAnnouncement() async* {
    yield announcement;
    yield* _changes.stream.map((_) => announcement);
  }

  @override
  Future<void> setAnnouncement(String text) async {
    if (reject) throw PostRejectedException();
    announcement = text.trim();
    _emit();
  }
}

/// AdminRepository tối giản cho các màn hình chỉ cần biết "có phải quản trị viên không".
class StubAdminRepository implements AdminRepository {
  StubAdminRepository({this.admin = false, this.users = const []});

  final bool admin;
  final List<AdminUser> users;

  @override
  String? get currentUid => 'boss';

  @override
  Future<bool> isCurrentUserAdmin() async => admin;

  @override
  Stream<bool> watchIsAdmin() => Stream.value(admin);

  @override
  Stream<List<AdminUser>> watchUsers() => Stream.value(users);

  @override
  Future<void> setLocked(String uid, bool locked) async {}
}
