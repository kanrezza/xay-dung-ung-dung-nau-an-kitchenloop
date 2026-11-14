import 'package:btl_ltdd/features/community/data/community_repository.dart';
import 'package:btl_ltdd/features/community/models/community_post.dart';
import 'package:btl_ltdd/features/recipes/models/ingredient.dart';
import 'package:btl_ltdd/features/recipes/models/recipe.dart';
import 'package:btl_ltdd/features/recipes/models/recipe_step.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeFirebaseFirestore db;
  var now = DateTime(2026, 11, 14, 10);

  FirestoreCommunityRepository repo(String uid) => FirestoreCommunityRepository(
        firestore: db,
        auth: MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: uid)),
        now: () => now,
      );

  final recipe = Recipe(
    id: 'r1',
    ownerId: 'an',
    title: 'Thịt kho trứng',
    baseServings: 4,
    ingredients: const [Ingredient(id: 'a', name: 'thịt ba chỉ', quantity: 500, unit: 'g'), Ingredient(id: 'b', name: 'trứng vịt', quantity: 6, unit: 'quả')],
    steps: const [RecipeStep(id: 's1', order: 1, text: 'Luộc trứng 10 phút.'), RecipeStep(id: 's2', order: 2, text: 'Kho thịt 45 phút.')],
  );

  setUp(() async {
    db = FakeFirebaseFirestore();
    now = DateTime(2026, 11, 14, 10);
    await db.collection('users').doc('an').set({'name': 'An Nguyễn', 'email': 'an@example.com'});
  });

  test('chia sẻ lần đầu: tạo bài đang hiện, tên hiển thị (không email), đặt lastPostAt', () async {
    expect(await repo('an').share(recipe), ShareKind.created);
    final doc = await db.collection('communityPosts').doc('an_r1').get();
    expect(doc.data()!['status'], 'visible');
    expect(doc.data()!['reportCount'], 0);
    expect(doc.data()!['authorName'], 'An Nguyễn');
    expect(doc.data().toString(), isNot(contains('an@example.com')));
    expect((await db.collection('users').doc('an').get()).data()!['lastPostAt'], isNotNull);
  });

  test('chia sẻ lại cùng công thức: cập nhật bài cũ, không tính là bài mới', () async {
    await repo('an').share(recipe);
    expect(await repo('an').share(recipe.copyWith(title: 'Thịt kho trứng vịt')), ShareKind.updated);
    expect((await db.collection('communityPosts').doc('an_r1').get()).data()!['title'], 'Thịt kho trứng vịt');
  });

  test('bài mới thứ 2 trong vòng 2 phút: báo phải chờ', () async {
    await db.collection('users').doc('an').set({'lastPostAt': Timestamp.fromDate(now.subtract(const Duration(seconds: 30)))}, SetOptions(merge: true));
    await expectLater(repo('an').share(recipe), throwsA(isA<PostTooSoonException>()));
    now = now.add(const Duration(minutes: 3));
    expect(await repo('an').share(recipe), ShareKind.created);
  });

  test('danh sách cộng đồng chỉ gồm bài đang hiện, mới nhất trước', () async {
    Future<void> post(String id, String status, DateTime at) => db.collection('communityPosts').doc(id).set({
          'authorId': 'x', 'title': id, 'status': status, 'reportCount': 0, 'createdAt': Timestamp.fromDate(at),
        });
    await post('cu', 'visible', DateTime(2026, 11, 1));
    await post('moi', 'visible', DateTime(2026, 11, 10));
    await post('an-di', 'hidden', DateTime(2026, 11, 12));
    final feed = await repo('binh').watchFeed().first;
    expect(feed.map((p) => p.id), ['moi', 'cu']);
  });

  test('báo cáo: ghi báo cáo, tăng bộ đếm; đủ 3 thì bài bị ẩn', () async {
    await repo('an').share(recipe);
    await repo('b1').report('an_r1', ReportReason.spam);
    await repo('b2').report('an_r1', ReportReason.notRecipe);
    var data = (await db.collection('communityPosts').doc('an_r1').get()).data()!;
    expect([data['reportCount'], data['status']], [2, 'visible']);
    await repo('b3').report('an_r1', ReportReason.offensive);
    data = (await db.collection('communityPosts').doc('an_r1').get()).data()!;
    expect([data['reportCount'], data['status']], [3, 'hidden']);
    final reports = await repo('admin').reportsOf('an_r1');
    expect(reports.map((r) => r.reason).toSet(), {ReportReason.spam, ReportReason.notRecipe, ReportReason.offensive});
  });

  test('quản trị viên khôi phục bài và đặt lại số báo cáo; gỡ bài', () async {
    await repo('an').share(recipe);
    await repo('admin').setStatus('an_r1', PostStatus.hidden);
    await repo('admin').setStatus('an_r1', PostStatus.visible, resetReports: true);
    var data = (await db.collection('communityPosts').doc('an_r1').get()).data()!;
    expect([data['status'], data['reportCount']], ['visible', 0]);
    await repo('admin').setStatus('an_r1', PostStatus.removed);
    data = (await db.collection('communityPosts').doc('an_r1').get()).data()!;
    expect(data['status'], 'removed');
    expect((await repo('admin').watchAllPosts().first).single.status, PostStatus.removed);
  });

  test('tác giả gỡ bài; tìm lại bài của mình theo công thức', () async {
    await repo('an').share(recipe);
    expect((await repo('an').myPostFor('r1'))!.title, 'Thịt kho trứng');
    await repo('an').unshare('an_r1');
    expect(await repo('an').myPostFor('r1'), isNull);
  });
}
