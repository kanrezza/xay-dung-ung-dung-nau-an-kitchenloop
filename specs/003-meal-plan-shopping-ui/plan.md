# Implementation Plan: Thực đơn tuần, đi chợ và giao diện mới

**Branch**: `003-meal-plan-shopping-ui` | **Date**: 2026-11-14 | **Spec**: [spec.md](spec.md)

## Summary

Thêm `lib/features/home/` (khung 4 tab, trang chủ, ảnh bìa minh hoạ) và `lib/features/planner/`
(model tuần, gộp nguyên liệu, repository, provider, màn Thực đơn và Đi chợ). Làm mới thẻ công
thức (lưới) và màn chi tiết (ảnh bìa lớn, nút thêm vào thực đơn). Theme sáng/tối.

## Constitution Check (v1.1.0)

| Nguyên tắc | Đáp ứng |
|---|---|
| I Nguyên liệu có cấu trúc | Danh sách đi chợ tính từ `Ingredient` có cấu trúc; không lưu chuỗi tự do. |
| II Theo giai đoạn | Đây là GĐ2. GĐ1 đã nghiệm thu trên máy ảo Android; T059/T066 (máy thật) còn mở — xem Complexity Tracking. Không làm thống kê (GĐ4). |
| III Bảo mật | `weekPlans`, `shoppingLists`: chỉ chủ sở hữu, id gắn UID, chặn tài khoản khoá; test trên emulator. |
| IV Tách lớp | Chỉ `data/` import Firebase; màn hình < 300 dòng. |
| V Kiểm thử | Unit test gộp nguyên liệu, quy đổi đơn vị, tuần; repository test; widget test. |
| VI Đa ngôn ngữ, offline | Khoá `home.*`, `planner.*`, `shopping.*`; dữ liệu qua cache Firestore. |
| VII Đơn giản | Một tài liệu mỗi tuần; không chia sẻ, không đồng bộ nhiều người. |

## Complexity Tracking

| Ngoại lệ | Lý do | Phương án đơn giản hơn bị loại vì |
|---|---|---|
| Bắt đầu GĐ2 khi T059/T066 (máy thật) còn mở | Đã nghiệm thu GĐ1 trên máy ảo; chưa có máy thật; chủ dự án yêu cầu làm tiếp | Chờ máy thật làm trễ tiến độ môn học; rủi ro thấp vì GĐ2 không đổi GĐ1 |

## Thiết kế dữ liệu

- `weekPlans/{uid}_{yyyy-MM-dd}`: `{ownerId, weekStart, entries: [{id, day 0..6, slot breakfast|lunch|dinner, recipeId, title, servings}], updatedAt}`.
- `shoppingLists/{uid}_{yyyy-MM-dd}`: `{ownerId, weekStart, checked: [itemKey], extras: [{id, name, quantity?, unit?}], updatedAt}`.
- `itemKey` = tên chuẩn hoá (không dấu) + `|` + nhóm đơn vị, để trạng thái đã mua bền khi thực đơn đổi.

## Thiết kế giao diện

- `AppShell`: `NavigationBar` + `IndexedStack` (giữ trạng thái từng tab).
- `RecipeCover`: ảnh thật hoặc nền chuyển màu + biểu tượng món theo từ khoá tên.
- Trang chủ: lời chào theo giờ, bữa hôm nay, nấu tiếp, gợi ý ngang, số liệu nhanh.
