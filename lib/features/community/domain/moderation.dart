/// Kiểm duyệt tự động bài chia sẻ (spec 004). Bộ quy tắc này được dùng ở HAI nơi:
/// - ở ứng dụng, để báo lý do bằng lời dễ hiểu trước khi gửi;
/// - ở `firestore.rules` (cùng các mẫu regex dưới đây), để chặn thật cả khi ứng dụng bị sửa.
/// `test/unit/moderation_test.dart` kiểm tra hai nơi luôn khớp nhau.
library;

const titleMin = 3;
const titleMax = 80;
const noteMax = 1000;
const authorNameMax = 60;
const minIngredients = 2;
const maxIngredients = 50;
const minSteps = 2;
const maxSteps = 50;
const stepTextMin = 8;
const ingredientNameMin = 2;
const maxTags = 10;

/// Số báo cáo để bài tự ẩn chờ quản trị viên.
const reportsToHide = 3;

/// Khoảng cách tối thiểu giữa hai bài mới của cùng một tài khoản.
const postCooldown = Duration(minutes: 2);

/// Từ/cụm cấm (so khớp trên chữ thường). Cẩn thận với từ trùng một phần từ thường dùng trong
/// nấu ăn: "lồn" chặn nhưng không chặn "lồng" (lồng đèn, chim lồng).
const bannedPattern =
    '(địt|lồn([^g]|\$)|cặc|buồi|đéo|vãi l|vcl|fuck|shit|bitch|porn|sex|xxx|18[+]|casino|cá độ|cá cược|lô đề|vay tiền|kiếm tiền online|bitcoin|zalo:|inbox)';

/// Liên kết, tên miền (spam quảng cáo).
const linkPattern = '(https?://|www[.]|[.](com|net|org|vn|io|xyz|info|ly)([/ ]|\$))';

/// Một chữ cái hoặc chữ số lặp 5 lần liền ("aaaaa", "11111"). Firestore rules dùng RE2 (không có
/// tham chiếu ngược) nên mẫu được liệt kê từng ký tự.
final repeatPattern = '(${[for (final c in 'abcdefghijklmnopqrstuvwxyz0123456789'.split('')) c * 5].join('|')})';

/// Ít nhất 2 chữ cái (Latin, kể cả tiếng Việt có dấu).
const lettersPattern = '[a-zA-ZÀ-ỹ].*[a-zA-ZÀ-ỹ]';

enum ModerationIssue {
  titleTooShort,
  titleTooLong,
  titleNoLetters,
  repeatedChars,
  link,
  bannedWord,
  noteTooLong,
  tooFewIngredients,
  tooManyIngredients,
  ingredientTooShort,
  tooFewSteps,
  tooManySteps,
  stepTooShort,
  tooManyTags,
}

bool _has(String pattern, String text) => RegExp(pattern, dotAll: true).hasMatch(text.toLowerCase());

/// Kiểm tra một đoạn chữ: link, từ cấm, ký tự lặp.
Set<ModerationIssue> checkText(String text) => {
      if (_has(linkPattern, text)) ModerationIssue.link,
      if (_has(bannedPattern, text)) ModerationIssue.bannedWord,
      if (_has(repeatPattern, text)) ModerationIssue.repeatedChars,
    };

/// Kiểm tra toàn bộ bài. Danh sách rỗng = đạt. Ứng dụng kiểm tra MỌI nguyên liệu và bước
/// (rules chỉ kiểm tra kỹ 2 nguyên liệu và 2 bước đầu vì không có vòng lặp).
List<ModerationIssue> checkPost({
  required String title,
  required String note,
  required List<String> ingredientNames,
  required List<String> stepTexts,
  List<String> tags = const [],
}) {
  final issues = <ModerationIssue>{};
  final t = title.trim();
  if (t.length < titleMin) issues.add(ModerationIssue.titleTooShort);
  if (t.length > titleMax) issues.add(ModerationIssue.titleTooLong);
  if (!RegExp(lettersPattern, dotAll: true).hasMatch(t)) issues.add(ModerationIssue.titleNoLetters);
  issues.addAll(checkText(t));
  if (note.length > noteMax) issues.add(ModerationIssue.noteTooLong);
  issues.addAll(checkText(note));
  if (ingredientNames.length < minIngredients) issues.add(ModerationIssue.tooFewIngredients);
  if (ingredientNames.length > maxIngredients) issues.add(ModerationIssue.tooManyIngredients);
  for (final name in ingredientNames) {
    if (name.trim().length < ingredientNameMin) issues.add(ModerationIssue.ingredientTooShort);
    issues.addAll(checkText(name));
  }
  if (stepTexts.length < minSteps) issues.add(ModerationIssue.tooFewSteps);
  if (stepTexts.length > maxSteps) issues.add(ModerationIssue.tooManySteps);
  for (final text in stepTexts) {
    if (text.trim().length < stepTextMin) issues.add(ModerationIssue.stepTooShort);
    issues.addAll(checkText(text));
  }
  if (tags.length > maxTags) issues.add(ModerationIssue.tooManyTags);
  for (final tag in tags) {
    issues.addAll(checkText(tag));
  }
  return ModerationIssue.values.where(issues.contains).toList();
}
