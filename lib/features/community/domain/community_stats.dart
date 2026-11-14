import '../models/community_post.dart';

/// Số liệu cộng đồng cho quản trị viên (spec 004, US3).
class CommunityStats {
  const CommunityStats({
    required this.total,
    required this.visible,
    required this.hidden,
    required this.removed,
    required this.totalReports,
    required this.perDay,
    required this.authors,
    this.totalLikes = 0,
    this.featured = 0,
    this.topPosts = const [],
  });

  final int total;
  final int visible;

  /// Bị ẩn do đủ báo cáo, đang chờ duyệt.
  final int hidden;
  final int removed;

  /// Tổng số báo cáo trên các bài.
  final int totalReports;

  /// Số bài đăng mỗi ngày trong 7 ngày gần nhất, từ cũ tới hôm nay.
  final List<int> perDay;

  /// Số người đã đăng bài.
  final int authors;

  /// Tổng lượt thích trên các bài đang hiện (spec 007).
  final int totalLikes;

  /// Số bài đang được ghim nổi bật.
  final int featured;

  /// Tối đa 3 bài đang hiện được thích nhiều nhất (ít nhất 1 lượt thích).
  final List<CommunityPost> topPosts;
}

CommunityStats computeCommunityStats(List<CommunityPost> posts, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final perDay = List<int>.filled(7, 0);
  for (final p in posts) {
    final c = p.createdAt;
    if (c == null) continue;
    final day = DateTime(c.year, c.month, c.day);
    final diff = (today.difference(day).inHours / 24).round();
    if (diff >= 0 && diff < 7) perDay[6 - diff]++;
  }
  final visible = posts.where((p) => p.status == PostStatus.visible).toList();
  return CommunityStats(
    total: posts.length,
    visible: posts.where((p) => p.status == PostStatus.visible).length,
    hidden: posts.where((p) => p.status == PostStatus.hidden).length,
    removed: posts.where((p) => p.status == PostStatus.removed).length,
    totalReports: posts.fold(0, (sum, p) => sum + p.reportCount),
    perDay: perDay,
    authors: posts.map((p) => p.authorId).toSet().length,
    totalLikes: visible.fold(0, (sum, p) => sum + p.likeCount),
    featured: visible.where((p) => p.featured).length,
    topPosts: (visible.where((p) => p.likeCount > 0).toList()..sort((a, b) => b.likeCount.compareTo(a.likeCount))).take(3).toList(),
  );
}
