import 'ingredient.dart';
import 'recipe_step.dart';

const Object _unset = Object();

/// Thời gian trong dữ liệu đã được tầng `data/` đổi sang [DateTime] (xem firestore_codec.dart).
DateTime? _toDate(Object? value) => value is DateTime ? value : null;

/// Nội dung gốc của công thức cũ, giữ lại để đối chiếu sau khi chuyển dữ liệu.
class RecipeLegacy {
  const RecipeLegacy({
    required this.title,
    required this.ingredients,
    required this.instructions,
    this.sourceCollection = 'foods',
    this.migratedAt,
    this.extra = const {},
  });

  /// Nguyên văn tên món cũ (kể cả khi tên mới bị cắt hoặc bù).
  final String title;

  /// Nguyên văn danh sách nguyên liệu cũ.
  final List<String> ingredients;

  /// Nguyên văn hướng dẫn cũ.
  final String instructions;

  final String sourceCollection;
  final DateTime? migratedAt;

  /// Thông tin cũ không có chỗ trong mô hình mới, giữ lại để đối chiếu (ví dụ
  /// `time`, `difficulty`, `category`, `videoUrl`, `servings`, và `note` gốc nếu bị cắt).
  final Map<String, dynamic> extra;

  factory RecipeLegacy.fromMap(Map<String, dynamic> map) {
    return RecipeLegacy(
      title: (map['title'] as String?) ?? '',
      ingredients: List<String>.from((map['ingredients'] as List?) ?? const []),
      instructions: (map['instructions'] as String?) ?? '',
      sourceCollection: (map['sourceCollection'] as String?) ?? 'foods',
      migratedAt: _toDate(map['migratedAt']),
      extra: map['extra'] is Map ? Map<String, dynamic>.from(map['extra'] as Map) : const {},
    );
  }

  Map<String, dynamic> toMap() => {
        'title': title,
        'ingredients': ingredients,
        'instructions': instructions,
        'sourceCollection': sourceCollection,
        'migratedAt': migratedAt,
        if (extra.isNotEmpty) 'extra': extra,
      };
}

/// Video hướng dẫn nấu của công thức (spec 006). Nội dung nằm ở các mẩu
/// `recipes/{id}/videoChunks/{id}_NN`; ở đây chỉ là thông tin để tải và ghép lại.
class RecipeVideo {
  const RecipeVideo({required this.id, required this.chunkCount, required this.sizeBytes, this.durationMs, this.mime = 'video/mp4'});

  final String id;
  final int chunkCount;
  final int sizeBytes;
  final int? durationMs;
  final String mime;

  Map<String, dynamic> toMap() => {
        'id': id,
        'chunkCount': chunkCount,
        'sizeBytes': sizeBytes,
        'durationMs': durationMs,
        'mime': mime,
      };

  /// `null` nếu dữ liệu thiếu hoặc sai kiểu (coi như chưa có video).
  static RecipeVideo? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'], count = raw['chunkCount'], size = raw['sizeBytes'], duration = raw['durationMs'];
    if (id is! String || id.isEmpty || count is! int || count < 1 || size is! int || size < 1) return null;
    return RecipeVideo(
      id: id,
      chunkCount: count,
      sizeBytes: size,
      durationMs: duration is int ? duration : null,
      mime: raw['mime'] is String ? raw['mime'] as String : 'video/mp4',
    );
  }
}

/// Một công thức của một người dùng (riêng tư theo tài khoản).
class Recipe {
  Recipe({
    required this.id,
    required this.ownerId,
    required this.title,
    this.imageUrl = '',
    required this.baseServings,
    required this.ingredients,
    required this.steps,
    this.tags = const [],
    this.note = '',
    this.createdAt,
    this.updatedAt,
    this.legacy,
    this.schemaVersion = currentSchemaVersion,
    this.isSyncing = false,
    this.video,
  });

  static const int currentSchemaVersion = 1;
  static const int maxTitleLength = 120;
  static const int minServings = 1;
  static const int maxServings = 100;
  static const int maxIngredients = 100;
  static const int maxSteps = 100;
  static const int maxTags = 20;
  static const int maxTagLength = 30;
  static const int maxNoteLength = 2000;

  /// ID document; với bản chuyển từ dữ liệu cũ bằng ID document `foods` gốc.
  final String id;

  /// UID chủ sở hữu; bất biến sau khi tạo.
  final String ownerId;

  final String title;
  final String imageUrl;
  final int baseServings;
  final List<Ingredient> ingredients;
  final List<RecipeStep> steps;
  final List<String> tags;
  final String note;

  /// `null` khi đang chờ máy chủ đặt thời gian.
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// Chỉ có ở bản chuyển từ dữ liệu cũ.
  final RecipeLegacy? legacy;
  final int schemaVersion;

  /// Video hướng dẫn (spec 006). KHÔNG nằm trong [toMap]: chỉ VideoRepository ghi trường này,
  /// để việc sửa công thức không bao giờ ghi đè video.
  final RecipeVideo? video;

  /// Có thay đổi chưa được máy chủ xác nhận (đang chờ đồng bộ, thường do offline).
  /// Chỉ để hiển thị: lấy từ siêu dữ liệu của Firestore, KHÔNG lưu vào dữ liệu.
  final bool isSyncing;

  factory Recipe.fromMap(Map<String, dynamic> map, String id, {bool isSyncing = false}) {
    List<Map<String, dynamic>> maps(Object? raw) => ((raw as List?) ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    final legacyRaw = map['legacy'];
    return Recipe(
      id: id,
      ownerId: (map['ownerId'] as String?) ?? '',
      title: (map['title'] as String?) ?? '',
      imageUrl: (map['imageUrl'] as String?) ?? '',
      baseServings: (map['baseServings'] as num?)?.toInt() ?? 0,
      ingredients: maps(map['ingredients']).map(Ingredient.fromMap).toList(),
      steps: maps(map['steps']).map(RecipeStep.fromMap).toList(),
      tags: List<String>.from((map['tags'] as List?) ?? const []),
      note: (map['note'] as String?) ?? '',
      createdAt: _toDate(map['createdAt']),
      updatedAt: _toDate(map['updatedAt']),
      legacy: legacyRaw is Map ? RecipeLegacy.fromMap(Map<String, dynamic>.from(legacyRaw)) : null,
      schemaVersion: (map['schemaVersion'] as num?)?.toInt() ?? currentSchemaVersion,
      isSyncing: isSyncing,
      video: RecipeVideo.fromMap(map['video']),
    );
  }

  /// Không chứa `id` (là tên document). Repository ghi đè `ownerId`,
  /// `createdAt` và `updatedAt` khi lưu.
  Map<String, dynamic> toMap() => {
        'ownerId': ownerId,
        'title': title,
        'imageUrl': imageUrl,
        'baseServings': baseServings,
        'ingredients': ingredients.map((e) => e.toMap()).toList(),
        'steps': steps.map((e) => e.toMap()).toList(),
        'tags': tags,
        'note': note,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
        'schemaVersion': schemaVersion,
        if (legacy != null) 'legacy': legacy!.toMap(),
      };

  Recipe copyWith({
    String? id,
    String? ownerId,
    String? title,
    String? imageUrl,
    int? baseServings,
    List<Ingredient>? ingredients,
    List<RecipeStep>? steps,
    List<String>? tags,
    String? note,
    Object? createdAt = _unset,
    Object? updatedAt = _unset,
    Object? legacy = _unset,
    int? schemaVersion,
    bool? isSyncing,
    Object? video = _unset,
  }) {
    return Recipe(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      title: title ?? this.title,
      imageUrl: imageUrl ?? this.imageUrl,
      baseServings: baseServings ?? this.baseServings,
      ingredients: ingredients ?? this.ingredients,
      steps: steps ?? this.steps,
      tags: tags ?? this.tags,
      note: note ?? this.note,
      createdAt: identical(createdAt, _unset) ? this.createdAt : createdAt as DateTime?,
      updatedAt: identical(updatedAt, _unset) ? this.updatedAt : updatedAt as DateTime?,
      legacy: identical(legacy, _unset) ? this.legacy : legacy as RecipeLegacy?,
      schemaVersion: schemaVersion ?? this.schemaVersion,
      isSyncing: isSyncing ?? this.isSyncing,
      video: identical(video, _unset) ? this.video : video as RecipeVideo?,
    );
  }

  /// Trả về danh sách mã lỗi; rỗng nghĩa là hợp lệ.
  ///
  /// Lỗi của nguyên liệu/bước có dạng `ingredients[2].name_invalid`.
  /// Việc loại thẻ trùng (không dấu, không phân biệt hoa thường) làm lúc nhập
  /// ở giao diện, không nằm ở đây.
  List<String> validate() {
    final errors = <String>[];

    final t = title.trim();
    if (t.isEmpty) {
      errors.add('title_required');
    } else if (t.length > maxTitleLength) {
      errors.add('title_too_long');
    }

    if (baseServings < minServings || baseServings > maxServings) {
      errors.add('servings_invalid');
    }

    if (ingredients.isEmpty) {
      errors.add('ingredients_required');
    } else if (ingredients.length > maxIngredients) {
      errors.add('ingredients_too_many');
    }
    for (var i = 0; i < ingredients.length; i++) {
      for (final e in ingredients[i].validate()) {
        errors.add('ingredients[$i].$e');
      }
    }

    if (steps.isEmpty) {
      errors.add('steps_required');
    } else if (steps.length > maxSteps) {
      errors.add('steps_too_many');
    }
    var orderOk = true;
    for (var i = 0; i < steps.length; i++) {
      for (final e in steps[i].validate()) {
        errors.add('steps[$i].$e');
      }
      if (steps[i].order != i + 1) orderOk = false;
    }
    if (!orderOk) errors.add('steps_order_invalid');

    if (tags.length > maxTags) errors.add('tags_too_many');
    if (tags.any((tag) {
      final n = tag.trim().length;
      return n < 1 || n > maxTagLength;
    })) {
      errors.add('tag_invalid');
    }

    if (note.length > maxNoteLength) errors.add('note_too_long');

    return errors;
  }
}
