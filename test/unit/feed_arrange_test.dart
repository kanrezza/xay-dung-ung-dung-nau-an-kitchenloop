import 'package:btl_ltdd/features/community/domain/community_stats.dart';
import 'package:btl_ltdd/features/community/domain/feed_arrange.dart';
import 'package:btl_ltdd/features/community/models/community_post.dart';
import 'package:flutter_test/flutter_test.dart';

CommunityPost post(String id,
        {List<String> tags = const [], int likes = 0, bool featured = false, PostStatus status = PostStatus.visible, String title = ''}) =>
    CommunityPost(
      id: id,
      authorId: 'u_$id',
      authorName: 'Người $id',
      sourceRecipeId: id,
      title: title.isEmpty ? 'Món $id' : title,
      baseServings: 2,
      ingredients: const [],
      steps: const [],
      tags: tags,
      likedBy: [for (var i = 0; i < likes; i++) 'x$i'],
      featured: featured,
      status: status,
    );

void main() {
  // Danh sách từ repository: mới nhất trước.
  final feed = [
    post('a', tags: ['nhanh'], likes: 1, title: 'Phở gà'),
    post('b', tags: ['Món chay', 'nhanh'], likes: 5, featured: true),
    post('c', tags: ['món chay'], likes: 5),
    post('d', likes: 0, featured: true, status: PostStatus.hidden),
  ];

  test('mặc định giữ thứ tự mới nhất', () {
    expect(arrangeFeed(feed).map((p) => p.id), ['a', 'b', 'c', 'd']);
  });

  test('được thích nhiều: nhiều ♥ trước, bằng nhau thì bài mới hơn trước', () {
    expect(arrangeFeed(feed, sort: FeedSort.popular).map((p) => p.id), ['b', 'c', 'a', 'd']);
  });

  test('lọc theo thẻ không phân biệt dấu/hoa thường; kết hợp với từ khoá', () {
    expect(arrangeFeed(feed, tag: 'mon chay').map((p) => p.id), ['b', 'c']);
    expect(arrangeFeed(feed, tag: 'nhanh', query: 'pho').map((p) => p.id), ['a']);
  });

  test('bài nổi bật: chỉ bài đang hiện được ghim', () {
    expect(featuredPosts(feed).map((p) => p.id), ['b']);
  });

  test('thẻ phổ biến: đếm không phân biệt dấu, giữ cách viết đầu tiên, nhiều trước', () {
    expect(popularTags(feed), ['Món chay', 'nhanh']);
    expect(popularTags(feed, max: 1), ['Món chay']);
  });

  test('thống kê: tổng lượt thích, số bài nổi bật, bài hot (chỉ bài đang hiện)', () {
    final s = computeCommunityStats(feed, DateTime(2026, 11, 14));
    expect(s.totalLikes, 11);
    expect(s.featured, 1);
    expect(s.topPosts.map((p) => p.id), ['b', 'c', 'a']);
  });

  test('đọc từ Firestore: likedBy bỏ trùng, cờ mặc định false', () {
    final p = CommunityPost.fromMap('x', {
      'likedBy': ['a', 'a', 'b', 3],
      'featured': true
    });
    expect(p.likeCount, 2);
    expect(p.isLikedBy('a'), isTrue);
    expect(p.isLikedBy(null), isFalse);
    expect(p.featured, isTrue);
    expect(p.byAdmin, isFalse);
    expect(CommunityPost.fromMap('y', const {}).likedBy, isEmpty);
  });
}
