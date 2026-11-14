import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../recipes/data/recipe_repository.dart';
import '../../recipes/models/recipe.dart';
import '../data/community_repository.dart';
import '../domain/feed_arrange.dart';
import '../domain/moderation.dart';
import '../models/community_post.dart';

/// Kết quả chia sẻ để giao diện báo cho người dùng.
class ShareOutcome {
  const ShareOutcome._({this.kind, this.issues = const [], this.wait, this.rejected = false, this.offline = false});

  const ShareOutcome.done(ShareKind kind) : this._(kind: kind);
  const ShareOutcome.issues(List<ModerationIssue> issues) : this._(issues: issues);
  const ShareOutcome.tooSoon(Duration wait) : this._(wait: wait);
  const ShareOutcome.rejected() : this._(rejected: true);
  const ShareOutcome.offline() : this._(offline: true);

  final ShareKind? kind;
  final List<ModerationIssue> issues;
  final Duration? wait;
  final bool rejected;
  final bool offline;

  bool get ok => kind != null;
}

/// Trạng thái tab Cộng đồng: danh sách bài, tìm kiếm, chia sẻ, báo cáo, lưu vào sổ.
class CommunityProvider extends ChangeNotifier {
  CommunityProvider({required CommunityRepository repository, required RecipeRepository recipes})
      : _repository = repository,
        _recipes = recipes;

  final CommunityRepository _repository;
  final RecipeRepository _recipes;
  StreamSubscription<List<CommunityPost>>? _sub;
  List<CommunityPost> _posts = const [];
  bool _loading = false;
  Object? _error;
  String _query = '';

  String? get currentUid => _repository.currentUid;
  bool get isLoading => _loading;
  Object? get error => _error;
  String get query => _query;

  /// Bắt đầu nghe danh sách bài (gọi khi mở tab lần đầu, để không tải khi không dùng).
  void ensureListening() {
    if (_sub != null) return;
    _loading = true;
    _sub = _repository.watchFeed().listen((posts) {
      _posts = posts;
      _loading = false;
      _error = null;
      notifyListeners();
    }, onError: (Object e) {
      _loading = false;
      _error = e;
      notifyListeners();
    });
  }

  FeedSort _sort = FeedSort.newest;
  String? _tag;

  FeedSort get sort => _sort;

  /// Thẻ đang lọc (null = tất cả).
  String? get tag => _tag;

  /// Bài sau khi lọc theo từ khoá, thẻ và xếp theo [sort].
  List<CommunityPost> get posts => arrangeFeed(_posts, query: _query, tag: _tag, sort: _sort);

  /// Tất cả bài đang hiện, chưa lọc.
  List<CommunityPost> get allPosts => _posts;

  /// Bài quản trị viên ghim nổi bật.
  List<CommunityPost> get featured => featuredPosts(_posts);

  /// Thẻ phổ biến để làm chip lọc.
  List<String> get tags => popularTags(_posts);

  void setQuery(String value) {
    _query = value;
    notifyListeners();
  }

  void setSort(FeedSort value) {
    if (value == _sort) return;
    _sort = value;
    notifyListeners();
  }

  /// Chọn lại thẻ đang chọn = bỏ lọc.
  void toggleTag(String value) {
    _tag = _tag == value ? null : value;
    notifyListeners();
  }

  /// Bản mới nhất của bài (sau khi thích/ghim, màn xem bài cần bản mới).
  CommunityPost? postById(String id) {
    for (final p in _posts) {
      if (p.id == id) return p;
    }
    return null;
  }

  /// Thích/bỏ thích; `true` nếu thành công.
  Future<bool> toggleLike(CommunityPost post) => _attempt(() => _repository.setLiked(post.id, !post.isLikedBy(currentUid)));

  // --- Quản trị viên (rules chặn người thường) ---

  Future<bool> setFeatured(CommunityPost post, bool featured) => _attempt(() => _repository.setFeatured(post.id, featured));

  Future<bool> setStatus(CommunityPost post, PostStatus status) =>
      _attempt(() => _repository.setStatus(post.id, status, resetReports: status == PostStatus.visible));

  Future<bool> _attempt(Future<void> Function() action) async {
    try {
      await action();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Kiểm tra trước bằng cùng bộ quy tắc với firestore.rules, rồi mới gửi.
  Future<ShareOutcome> share(Recipe recipe) async {
    final issues = checkPost(
      title: recipe.title,
      note: recipe.note,
      ingredientNames: [
        for (final i in recipe.ingredients)
          if (!i.isPlaceholder) i.name
      ],
      stepTexts: [
        for (final s in recipe.steps)
          if (!s.isPlaceholder) s.text
      ],
      tags: recipe.tags,
    );
    if (issues.isNotEmpty) return ShareOutcome.issues(issues);
    try {
      return ShareOutcome.done(await _repository.share(recipe));
    } on PostTooSoonException catch (e) {
      return ShareOutcome.tooSoon(e.wait);
    } on PostRejectedException {
      return const ShareOutcome.rejected();
    } on OfflineException {
      return const ShareOutcome.offline();
    }
  }

  Future<CommunityPost?> myPostFor(String recipeId) async {
    try {
      return await _repository.myPostFor(recipeId);
    } catch (_) {
      return null;
    }
  }

  /// `true` nếu thành công.
  Future<bool> report(String postId, ReportReason reason) async {
    try {
      await _repository.report(postId, reason);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> unshare(String postId) async {
    try {
      await _repository.unshare(postId);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Chép bài vào sổ công thức của người đọc (bản riêng, sửa thoải mái). Trả về id mới.
  Future<String?> saveToMine(CommunityPost post) async {
    final uid = currentUid;
    if (uid == null) return null;
    try {
      return await _recipes.create(post.toRecipe(id: '', ownerId: uid));
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
