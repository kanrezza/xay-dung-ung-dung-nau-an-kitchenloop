import '../../recipes/models/ingredient.dart';
import '../../recipes/models/recipe.dart';
import '../../recipes/models/recipe_step.dart';

enum PostStatus { visible, hidden, removed }

PostStatus postStatusFrom(Object? raw) =>
    PostStatus.values.firstWhere((s) => s.name == raw, orElse: () => PostStatus.hidden);

/// Lý do báo cáo (khớp danh sách trong firestore.rules).
enum ReportReason { spam, offensive, notRecipe, other }

const reportReasonIds = {
  ReportReason.spam: 'spam',
  ReportReason.offensive: 'offensive',
  ReportReason.notRecipe: 'not_recipe',
  ReportReason.other: 'other',
};

ReportReason? reportReasonFrom(Object? raw) {
  for (final e in reportReasonIds.entries) {
    if (e.value == raw) return e.key;
  }
  return null;
}

/// Một bài chia sẻ công thức. Id = `{authorId}_{sourceRecipeId}` nên mỗi công thức chỉ có một
/// bài; chia sẻ lại thì cập nhật bài cũ. Không chứa email tác giả, chỉ tên hiển thị.
class CommunityPost {
  const CommunityPost({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.sourceRecipeId,
    required this.title,
    required this.baseServings,
    required this.ingredients,
    required this.steps,
    this.note = '',
    this.tags = const [],
    this.status = PostStatus.visible,
    this.reportCount = 0,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String authorId;
  final String authorName;
  final String sourceRecipeId;
  final String title;
  final int baseServings;
  final List<Ingredient> ingredients;
  final List<RecipeStep> steps;
  final String note;
  final List<String> tags;
  final PostStatus status;
  final int reportCount;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  static String idFor(String authorId, String recipeId) => '${authorId}_$recipeId';

  /// Bài từ một công thức của tác giả (ảnh không được chia sẻ ở bản này).
  factory CommunityPost.fromRecipe(Recipe r, {required String authorName}) => CommunityPost(
        id: idFor(r.ownerId, r.id),
        authorId: r.ownerId,
        authorName: authorName,
        sourceRecipeId: r.id,
        title: r.title.trim(),
        baseServings: r.baseServings,
        ingredients: r.ingredients.where((i) => !i.isPlaceholder).toList(),
        steps: r.steps.where((s) => !s.isPlaceholder).map((s) => s.copyWith(imageUrl: null)).toList(),
        note: r.note.trim(),
        tags: r.tags,
      );

  /// Nội dung để ghi (không gồm status/reportCount/thời gian: repository tự thêm).
  Map<String, dynamic> contentMap() => {
        'authorId': authorId,
        'authorName': authorName,
        'sourceRecipeId': sourceRecipeId,
        'title': title,
        'note': note,
        'baseServings': baseServings,
        'ingredients': ingredients.map((e) => e.toMap()..remove('isPlaceholder')).toList(),
        'steps': steps.map((e) => e.toMap()..remove('isPlaceholder')..remove('imageUrl')).toList(),
        'tags': tags,
      };

  factory CommunityPost.fromMap(String id, Map<String, dynamic> d) {
    List<Map<String, dynamic>> maps(Object? raw) =>
        raw is List ? raw.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList() : const [];
    final servings = d['baseServings'];
    final count = d['reportCount'];
    return CommunityPost(
      id: id,
      authorId: d['authorId'] is String ? d['authorId'] as String : '',
      authorName: d['authorName'] is String ? d['authorName'] as String : '',
      sourceRecipeId: d['sourceRecipeId'] is String ? d['sourceRecipeId'] as String : '',
      title: d['title'] is String ? d['title'] as String : '',
      note: d['note'] is String ? d['note'] as String : '',
      baseServings: servings is int && servings > 0 ? servings : 1,
      ingredients: maps(d['ingredients']).map(Ingredient.fromMap).toList(),
      steps: maps(d['steps']).map(RecipeStep.fromMap).toList(),
      tags: d['tags'] is List ? (d['tags'] as List).whereType<String>().toList() : const [],
      status: postStatusFrom(d['status']),
      reportCount: count is int ? count : 0,
      createdAt: d['createdAt'] is DateTime ? d['createdAt'] as DateTime : null,
      updatedAt: d['updatedAt'] is DateTime ? d['updatedAt'] as DateTime : null,
    );
  }

  /// Dạng `Recipe` để dùng lại các widget xem nguyên liệu/bước, hoặc lưu vào sổ của người đọc.
  Recipe toRecipe({String id = '', String ownerId = ''}) => Recipe(
        id: id.isEmpty ? this.id : id,
        ownerId: ownerId.isEmpty ? authorId : ownerId,
        title: title,
        baseServings: baseServings,
        ingredients: ingredients,
        steps: steps,
        note: note,
        tags: tags,
      );
}

/// Một báo cáo (chỉ quản trị viên đọc được).
class PostReport {
  const PostReport({required this.reporterId, required this.reason, this.createdAt});

  final String reporterId;
  final ReportReason reason;
  final DateTime? createdAt;
}
