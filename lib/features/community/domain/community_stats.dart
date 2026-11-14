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
  return CommunityStats(
    total: posts.length,
    visible: posts.where((p) => p.status == PostStatus.visible).length,
    hidden: posts.where((p) => p.status == PostStatus.hidden).length,
    removed: posts.where((p) => p.status == PostStatus.removed).length,
    totalReports: posts.fold(0, (sum, p) => sum + p.reportCount),
    perDay: perDay,
    authors: posts.map((p) => p.authorId).toSet().length,
  );
}
