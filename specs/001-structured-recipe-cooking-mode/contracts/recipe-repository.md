# Contract: Giao diện lớp dữ liệu và logic nghiệp vụ (GĐ1)

Đây là hợp đồng giữa tầng giao diện (Provider/màn hình) và tầng dữ liệu. Giao diện MUST chỉ gọi qua các giao diện
này, không gọi Firebase trực tiếp (Constitution IV). Chữ ký dưới đây mô tả hành vi, không phải mã hoàn chỉnh.

## RecipeRepository

| Phương thức | Mô tả | Lỗi/biên |
|---|---|---|
| `Stream<List<Recipe>> watchMyRecipes()` | Danh sách công thức của người dùng hiện tại, mới sửa nhất trước. Lấy từ bộ nhớ đệm khi offline. | Chưa đăng nhập → luồng rỗng. |
| `Stream<Recipe?> watchRecipe(String id)` | Một công thức; `null` nếu không tồn tại hoặc không thuộc người dùng (lỗi `permission-denied` khi đọc document không tồn tại hoặc của người khác được chuyển thành `null`). | |
| `Stream<String?> watchUserId()` | UID người dùng hiện tại, phát lại khi đăng nhập/đăng xuất/đổi tài khoản; Provider dùng để huỷ luồng và xoá danh sách của tài khoản trước. | |
| `Future<String> create(Recipe draft)` | Tạo công thức, trả về `id`. Đặt `ownerId`, `createdAt`, `updatedAt`. | Dữ liệu không hợp lệ → `RecipeValidationException` (liệt kê trường lỗi). |
| `Future<void> update(Recipe recipe)` | Cập nhật; giữ `ownerId`/`createdAt`. | Như trên; không tồn tại → `RecipeNotFoundException`. |
| `Future<void> delete(String id)` | Xoá công thức. | |
| `Future<String> uploadImage(File file, {required String recipeId})` | Tải ảnh lên Storage, trả URL. | Offline → `OfflineException` (không làm mất dữ liệu đang nhập). |

Quy ước offline: `create`/`update`/`delete` **không chờ** xác nhận từ máy chủ khi không có mạng; ghi được xếp hàng và
phương thức hoàn tất ngay khi đã ghi vào bộ nhớ đệm cục bộ; Provider hiển thị trạng thái "đang đồng bộ" từ
`SnapshotMetadata.hasPendingWrites`.

## LegacyMigrationService

| Phương thức | Mô tả |
|---|---|
| `Future<MigrationResult> migrateIfNeeded()` | Nếu `users/{uid}.recipeMigratedAt` vắng mặt: đọc `foods` có `authorId == uid`, chuyển từng bản ghi thành `recipes/{foodId}` (idempotent), rồi đặt `recipeMigratedAt`. Trả về số bản ghi chuyển, số dòng nguyên liệu không phân tích được. |

Bảo đảm: không xoá/sửa `foods`; chạy lại an toàn; lỗi giữa chừng không đặt `recipeMigratedAt`; món cũ thiếu nguyên liệu/hướng dẫn hoặc có tên rỗng/quá dài vẫn được chuyển theo "Quy tắc bù" ở [../data-model.md](../data-model.md) và luôn có `legacy.title`.

Giao diện KHÔNG gọi service này trực tiếp mà qua `RecipeListProvider.runMigrationIfNeeded()`.

## Hàm thuần (domain) — phải có unit test

| Hàm | Hành vi |
|---|---|
| `scaleQuantity(q, baseServings, targetServings)` | `q == null` → `null`; `target ≤ 0` hoặc `base ≤ 0` → ném lỗi tham số; ngược lại `q * target / base`, làm tròn tối đa 2 chữ số thập phân. |
| `formatQuantity(q)` | Bỏ phần thập phân thừa ("2", "0,5", "1,25"); dấu thập phân theo ngôn ngữ giao diện. |
| `parseQuantity(String)` | Nhận "2", "0,5", "0.5", "1/2", "1 1/2"; không hợp lệ → `null`. |
| `parseLegacyIngredient(String)` | "200g thịt bò" → `{200, "g", "thịt bò"}`; "muối vừa đủ" → `{null, null, "muối vừa đủ"}` (nguyên văn). |
| `splitLegacyInstructions(String)` | Tách thành danh sách bước theo quy tắc ở [research.md](../research.md) R2; không bao giờ trả về rỗng nếu đầu vào có chữ. |
| `normalizeForSearch(String)` | Chữ thường, bỏ dấu tiếng Việt, `đ→d`, gộp khoảng trắng. |
| `filterRecipes(list, query, tags)` | Giao của khớp từ khoá (tên, nguyên liệu, thẻ) và có đủ các thẻ đã chọn. |

## CookingSessionStore

| Phương thức | Mô tả |
|---|---|
| `Future<CookingSession?> load(recipeId)` | Đọc phiên nấu dở dang. |
| `Future<void> save(CookingSession)` | Lưu mỗi khi đổi bước/khẩu phần/hẹn giờ. |
| `Future<void> clear(recipeId)` | Xoá khi hoàn thành hoặc bắt đầu lại. |

## TimerNotificationService

| Phương thức | Mô tả |
|---|---|
| `Future<bool> requestPermission()` | Xin quyền thông báo (và báo thức chính xác trên Android 12+). Trả `false` nếu bị từ chối. |
| `Future<int> schedule({required DateTime endAt, required String title, required String body})` | Đặt thông báo tại `endAt`; trả `notificationId`. Nếu không có quyền chính xác thì dùng lịch gần đúng. |
| `Future<void> cancel(int notificationId)` | Huỷ hẹn giờ khi người dùng **tạm dừng, đặt lại hoặc hoàn thành** bước. **Không** huỷ khi chỉ thoát chế độ nấu hoặc đưa app xuống nền (spec: hẹn giờ vẫn phải báo đúng lúc). |
| `Future<void> cancelAll()` | Huỷ mọi hẹn giờ đã lên lịch; chỉ dùng khi đăng xuất. |

## AccountActions

| Phương thức | Mô tả |
|---|---|
| `Future<void> signOut()` | Gọi `TimerNotificationService.cancelAll()`, rồi đăng xuất qua `AuthService.logout()` (đã có ở `lib/services/auth_service.dart`). Sau khi `watchUserId()` phát `null`, Provider xoá danh sách. |
| `Future<void> setLanguage(Locale locale)` | Đổi ngôn ngữ giao diện (`vi` hoặc `en`) và ghi nhớ lựa chọn. |
| `String? get email` | Email tài khoản đang đăng nhập để hiển thị. |
