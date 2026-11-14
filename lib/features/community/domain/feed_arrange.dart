import '../../recipes/domain/text_normalizer.dart';
import '../models/community_post.dart';

/// Cách xếp danh sách cộng đồng (spec 007).
enum FeedSort { newest, popular }

/// Lọc theo từ khoá (tên món, người đăng, thẻ) và thẻ đang chọn rồi xếp.
/// [posts] đã xếp mới nhất trước (từ repository); "Được thích nhiều" giữ thứ tự đó khi bằng lượt thích.
List<CommunityPost> arrangeFeed(
  List<CommunityPost> posts, {
  String query = '',
  String? tag,
  FeedSort sort = FeedSort.newest,
}) {
  final q = normalizeForSearch(query);
  final t = tag == null ? '' : normalizeForSearch(tag);
  final result = [
    for (final p in posts)
      if ((q.isEmpty || normalizeForSearch('${p.title} ${p.authorName} ${p.tags.join(' ')}').contains(q)) &&
          (t.isEmpty || p.tags.any((x) => normalizeForSearch(x) == t)))
        p,
  ];
  if (sort == FeedSort.popular) {
    final order = {for (final (i, p) in result.indexed) p.id: i};
    result.sort((a, b) {
      final byLikes = b.likeCount.compareTo(a.likeCount);
      return byLikes != 0 ? byLikes : order[a.id]!.compareTo(order[b.id]!);
    });
  }
  return result;
}

/// Bài được quản trị viên ghim, mới nhất trước.
List<CommunityPost> featuredPosts(List<CommunityPost> posts) => [
      for (final p in posts)
        if (p.featured && p.status == PostStatus.visible) p
    ];

/// Các thẻ phổ biến nhất trong các bài (dùng làm chip lọc), giữ cách viết của lần xuất hiện đầu.
List<String> popularTags(List<CommunityPost> posts, {int max = 8}) {
  final counts = <String, int>{};
  final label = <String, String>{};
  for (final p in posts) {
    for (final tag in p.tags.toSet()) {
      final key = normalizeForSearch(tag);
      if (key.isEmpty) continue;
      label.putIfAbsent(key, () => tag.trim());
      counts[key] = (counts[key] ?? 0) + 1;
    }
  }
  final keys = counts.keys.toList()
    ..sort((a, b) {
      final c = counts[b]!.compareTo(counts[a]!);
      return c != 0 ? c : a.compareTo(b);
    });
  return [for (final k in keys.take(max)) label[k]!];
}
