# Contract: Lược đồ Firestore và quy tắc truy cập (GĐ1)

## Document `recipes/{recipeId}`

```json
{
  "ownerId": "uid",
  "title": "Thịt kho trứng",
  "imageUrl": "https://firebasestorage.googleapis.com/...",
  "baseServings": 4,
  "ingredients": [
    { "id": "uuid", "name": "thịt ba chỉ", "quantity": 500, "unit": "g", "price": 90000, "kcal": 1800 },
    { "id": "uuid", "name": "muối", "quantity": null, "unit": null, "price": null, "kcal": null }
  ],
  "steps": [
    { "id": "uuid", "order": 1, "text": "Luộc trứng 10 phút.", "imageUrl": null, "durationSec": 600 },
    { "id": "uuid", "order": 2, "text": "Kho thịt với nước dừa.", "imageUrl": null, "durationSec": null }
  ],
  "tags": ["món sinh viên", "nhanh"],
  "note": "",
  "createdAt": "<serverTimestamp>",
  "updatedAt": "<serverTimestamp>",
  "schemaVersion": 1,
  "legacy": {
    "ingredients": ["500g thịt ba chỉ", "muối vừa đủ"],
    "instructions": "1. Luộc trứng...\n2. Kho thịt...",
    "sourceCollection": "foods",
    "migratedAt": "<timestamp>"
  }
}
```

`legacy` chỉ có ở bản chuyển từ dữ liệu cũ. Kiểu và ràng buộc từng trường: xem [../data-model.md](../data-model.md).

## Trường mới trên `users/{uid}`

| Trường | Kiểu | Ý nghĩa |
|---|---|---|
| `recipeMigratedAt` | thời điểm | đã chuyển dữ liệu công thức cũ; vắng mặt = chưa chuyển |

Chủ tài khoản được ghi trường này theo rules `users` hiện có (rules đã chặn đổi `role`, `isLocked`).

## Quy tắc truy cập `recipes` (sẽ thêm vào `firestore.rules`)

| Thao tác | Điều kiện |
|---|---|
| `get` | đã đăng nhập **và** (`resource == null` **hoặc** `resource.data.ownerId == request.auth.uid`). Cho phép `resource == null` để đọc document chưa tồn tại trả về "không tồn tại" thay vì lỗi quyền. |
| `list` | đã đăng nhập **và** `resource.data.ownerId == request.auth.uid`. Truy vấn danh sách MUST có `where('ownerId', isEqualTo: uid)`. |
| `create` | `request.resource.data.ownerId == request.auth.uid`; `title` không rỗng và ≤ 120 ký tự; `ingredients.size()` trong 1–100; `steps.size()` trong 1–100; `baseServings` là số nguyên 1–100. |
| `update` | chủ sở hữu hiện tại; `ownerId` **không đổi**; cùng các ràng buộc kích thước như `create`. |
| `delete` | chủ sở hữu. |

Admin **không** có quyền đọc công thức riêng tư của người dùng ở GĐ1 (khác với các collection cũ); quyết định này
bảo vệ quyền riêng tư theo spec (FR-015, SC-009) và có thể xem xét lại ở giai đoạn sau.

## Chỉ mục

Truy vấn `where('ownerId', ==, uid)` dùng chỉ mục một trường tự động; sắp xếp theo `updatedAt` được làm **phía client**
để tránh cần chỉ mục tổng hợp. `firestore.indexes.json` không cần thay đổi.

## Kiểm thử bắt buộc cho rules (rules_test/)

1. Người A đọc/ghi công thức của chính mình → cho phép.
2. Người B đọc, sửa, xoá công thức của A → từ chối.
3. Tạo công thức với `ownerId` của người khác → từ chối.
4. Sửa `ownerId` → từ chối.
5. Tạo với 0 nguyên liệu, 0 bước, 101 phần tử, tên rỗng hoặc `baseServings` ≤ 0 → từ chối.
6. Truy vấn danh sách không lọc theo `ownerId` → từ chối.
7. Chưa đăng nhập → từ chối mọi thao tác.
8. Không thể ghi trực tiếp `users.role` (kiểm tra lại rules cũ không bị phá).
9. Đọc (`get`) document `recipes` không tồn tại khi đã đăng nhập → không bị từ chối (trả về không tồn tại); đọc document của người khác vẫn bị từ chối.
