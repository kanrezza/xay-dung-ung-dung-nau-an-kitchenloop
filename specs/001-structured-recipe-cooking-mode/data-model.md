# Data Model: Công thức có cấu trúc và chế độ nấu từng bước

Tên trường dùng đúng như lưu trong Firestore (camelCase). Xem định dạng lưu trữ chi tiết ở
[contracts/firestore-schema.md](contracts/firestore-schema.md).

## Recipe (Công thức)

| Trường | Kiểu | Bắt buộc | Quy tắc |
|---|---|---|---|
| `id` | chuỗi | có | ID document; với bản chuyển từ dữ liệu cũ = ID document `foods` gốc |
| `ownerId` | chuỗi | có | UID chủ sở hữu; **bất biến** sau khi tạo |
| `title` | chuỗi | có | sau khi cắt khoảng trắng: 1–120 ký tự |
| `imageUrl` | chuỗi | không | URL ảnh trên Storage; rỗng nếu không có |
| `baseServings` | số nguyên | có | 1–100 (FR-006: từ chối ≤ 0) |
| `ingredients` | mảng `Ingredient` | có | 1–100 phần tử |
| `steps` | mảng `RecipeStep` | có | 1–100 phần tử, thứ tự theo `order` |
| `tags` | mảng chuỗi | không | tối đa 20 thẻ; mỗi thẻ 1–30 ký tự, không trùng; việc loại trùng (không dấu, không phân biệt hoa thường) làm lúc nhập ở giao diện, còn `validate()` chỉ kiểm tra số lượng và độ dài |
| `note` | chuỗi | không | ≤ 2000 ký tự |
| `createdAt` | thời điểm | có | do máy chủ đặt khi tạo; bản chuyển từ dữ liệu cũ giữ `createdAt` của món cũ |
| `updatedAt` | thời điểm | có | do máy chủ đặt mỗi lần lưu (dùng cho "ghi sau cùng thắng") |
| `legacy` | bản đồ | không | chỉ có ở bản chuyển từ dữ liệu cũ; xem bên dưới |
| `schemaVersion` | số nguyên | có | `1` ở GĐ1 |

## Ingredient (Nguyên liệu) — mô hình dùng chung cho mọi giai đoạn

| Trường | Kiểu | Bắt buộc | Quy tắc |
|---|---|---|---|
| `id` | chuỗi (uuid) | có | ổn định giữa các lần sửa; dùng để đổi thứ tự/so sánh |
| `name` | chuỗi | có | 1–100 ký tự |
| `quantity` | số thực | không | `null` = "vừa đủ/tuỳ khẩu vị"; nếu có thì ≥ 0; **không bị nhân khi đổi khẩu phần nếu `null`** |
| `unit` | chuỗi | không | từ danh sách đơn vị chuẩn hoặc tự do, ≤ 20 ký tự |
| `price` | số thực | không | ≥ 0, đơn vị tiền VND; chưa dùng ở GĐ1 (để dành GĐ2/4) |
| `kcal` | số thực | không | ≥ 0, tính cho **lượng ghi trong `quantity`**; chưa dùng ở GĐ1 (để dành GĐ4) |
| `isPlaceholder` | boolean | không | mặc định `false`; `true` chỉ cho dòng giữ chỗ do việc chuyển dữ liệu cũ tạo ra |

Quy ước `price` và `kcal` tính theo đúng lượng `quantity` của dòng đó (không theo 100 g) để khỏi phải
quy đổi đơn vị ở GĐ1; nếu GĐ3–4 cần chuẩn hoá theo đơn vị thì sẽ tăng `schemaVersion` và có script chuyển.

## RecipeStep (Bước nấu)

| Trường | Kiểu | Bắt buộc | Quy tắc |
|---|---|---|---|
| `id` | chuỗi (uuid) | có | ổn định |
| `order` | số nguyên | có | bắt đầu từ 1, liên tục, không trùng |
| `text` | chuỗi | có | 1–1000 ký tự |
| `imageUrl` | chuỗi | không | ảnh minh hoạ bước |
| `durationSec` | số nguyên | không | nếu có thì > 0 và ≤ 86400 (24 giờ) |
| `isPlaceholder` | boolean | không | mặc định `false`; `true` chỉ cho bước giữ chỗ do việc chuyển dữ liệu cũ tạo ra |

## Legacy (chỉ trong bản chuyển)

| Trường | Kiểu | Ý nghĩa |
|---|---|---|
| `legacy.ingredients` | mảng chuỗi | nguyên văn danh sách nguyên liệu cũ |
| `legacy.instructions` | chuỗi | nguyên văn hướng dẫn cũ |
| `legacy.title` | chuỗi | nguyên văn tên món cũ (luôn lưu, kể cả khi tên mới bị cắt hoặc bù) |
| `legacy.sourceCollection` | chuỗi | luôn là `foods` |
| `legacy.migratedAt` | thời điểm | thời điểm chuyển |

Bản ghi `foods` gốc **không bị sửa hay xoá**.

### Quy tắc bù khi chuyển dữ liệu cũ

Để mọi bản chuyển đều hợp lệ với rules và `validate()` mà vẫn không mất dữ liệu:

| Tình huống ở bản ghi `foods` | Cách bù ở bản `recipes` |
|---|---|
| Không có nguyên liệu nào | Thêm đúng 1 nguyên liệu giữ chỗ `name = "(Chưa có nguyên liệu)"`, không số lượng |
| Hướng dẫn rỗng | Thêm đúng 1 bước giữ chỗ `text = "(Chưa có hướng dẫn)"` |
| Tên rỗng | `title = "(Món chưa đặt tên)"` |
| Tên dài hơn 120 ký tự | Cắt còn 120 ký tự; tên đầy đủ nằm ở `legacy.title` |
| Dòng nguyên liệu dài hơn 100 ký tự | Cắt tên còn 100 ký tự; nguyên văn nằm ở `legacy.ingredients` |
| Bước dài hơn 1000 ký tự | Tách thành nhiều bước hoặc cắt còn 1000 ký tự; nguyên văn nằm ở `legacy.instructions` |
| Hơn 100 nguyên liệu hoặc hơn 100 bước | Giữ 100 mục đầu; phần còn lại nằm trong `legacy` |
| Có hơn 20 thẻ hoặc thẻ dài hơn 30 ký tự | Giữ 20 thẻ đầu, cắt thẻ còn 30 ký tự |

Dòng/bước giữ chỗ được đánh dấu `isPlaceholder = true`; giao diện hiển thị khoá dịch `recipes.placeholder_ingredient` / `recipes.placeholder_step` thay cho chuỗi đã lưu để đúng ngôn ngữ đang chọn. Chuỗi tiếng Việt ở bảng trên chỉ là giá trị dự phòng lưu trong dữ liệu (để qua `validate()` và rules). Khi người dùng sửa một dòng/bước giữ chỗ, cờ `isPlaceholder` được đặt lại `false`.

Tên món giữ chỗ không có cờ riêng: giao diện hiển thị khoá `recipes.placeholder_title` khi công thức có `legacy` và `legacy.title` rỗng.

## CookingSession (Phiên nấu — chỉ lưu cục bộ trên máy)

| Trường | Kiểu | Ý nghĩa |
|---|---|---|
| `recipeId` | chuỗi | công thức đang nấu |
| `stepIndex` | số nguyên | chỉ số bước hiện tại (bắt đầu từ 0) |
| `servings` | số nguyên | số người ăn đang chọn khi nấu |
| `timers` | mảng `{stepId, endAt, notificationId}` | các hẹn giờ đang chạy; `endAt` là thời điểm tuyệt đối |
| `startedAt` | thời điểm | thời điểm bắt đầu |

Khoá lưu: `cooking_session_<uid>_<recipeId>`; xoá khi hoàn thành hoặc người dùng chọn "bắt đầu lại".

## Tag (Thẻ)

Không phải document riêng. Là chuỗi trong `Recipe.tags`; danh sách thẻ để lọc được tính từ tập công thức
của người dùng (hợp các `tags`, đếm số công thức).

## Quan hệ

```
User (1) ──< Recipe (n) ──< Ingredient (nhúng, n)
                       └──< RecipeStep  (nhúng, n)
                       └──  Tag         (nhúng dạng chuỗi)
Recipe (1) ── CookingSession (0..1, cục bộ)
foods (cũ) ──chuyển một lần──▶ Recipe (legacy)
```

## Chuyển trạng thái

- **Tạo**: `Recipe` mới → `createdAt = updatedAt = serverTimestamp`.
- **Sửa**: giữ nguyên `id`, `ownerId`, `createdAt`; cập nhật `updatedAt`.
- **Chuyển dữ liệu cũ** (idempotent): với mỗi `foods/{foodId}` của người dùng, ghi `recipes/{foodId}`
  (`set`, không `add`); xong tất cả thì ghi `users/{uid}.recipeMigratedAt`. Chạy lại chỉ ghi đè cùng document. Bản chuyển giữ `createdAt` của món cũ (thiếu thì dùng thời điểm chuyển) và đặt `updatedAt = serverTimestamp`.
- **Phiên nấu**: `không có` → `đang nấu` (lưu mỗi lần đổi bước/hẹn giờ) → `hoàn thành/bắt đầu lại` (xoá).

## Quy tắc kiểm tra dữ liệu (gom từ yêu cầu)

- Công thức hợp lệ khi: tên không rỗng, `baseServings ≥ 1`, có ≥ 1 nguyên liệu và ≥ 1 bước (FR-002).
- `quantity`, `price`, `kcal` không âm; `durationSec` > 0 (FR-003, FR-004).
- Đổi khẩu phần: số người ăn đích phải nguyên dương, ngược lại giữ giá trị cũ (spec, US3 #4).
