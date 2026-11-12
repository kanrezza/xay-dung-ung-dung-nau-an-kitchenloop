# Contract: Màn hình và hành vi giao diện (GĐ1)

Tất cả chuỗi hiển thị dùng khoá `easy_localization` (vi mặc định, en kèm theo). Mỗi màn hình MUST dưới ~300 dòng;
phần lớn hơn tách thành widget trong `view/widgets/`.

## 1. Danh sách công thức (`RecipeListScreen`) — trang chủ sau đăng nhập

- Ô tìm kiếm (không dấu) + hàng thẻ lọc (chọn nhiều thẻ = phải có đủ các thẻ).
- Mỗi mục: ảnh nhỏ, tên, số nguyên liệu/bước, thẻ, biểu tượng "đang đồng bộ" nếu có thay đổi chưa gửi.
- Nút thêm công thức; vuốt/menu để xoá (có xác nhận).
- Trạng thái trống: lời nhắn thân thiện + nút tạo công thức đầu tiên; kết quả lọc trống: gợi ý xoá bộ lọc.
- Khi mở app lần đầu sau nâng cấp: chạy `migrateIfNeeded()` và hiện thông báo kết quả
  ("Đã chuyển N công thức; M dòng nguyên liệu được giữ nguyên văn").
- Liên quan: FR-001, FR-013, FR-014, FR-017, US1, US4, US5.

## 2. Chi tiết công thức (`RecipeDetailScreen`)

- Ảnh, tên, thẻ, ghi chú; **bộ chỉnh khẩu phần** (− / +, nhập số); danh sách nguyên liệu đã quy đổi; danh sách các bước.
- Nút lớn "Bắt đầu nấu" (tối đa 2 chạm từ danh sách, SC-002); nút sửa, xoá.
- Với công thức chuyển từ dữ liệu cũ (có `legacy`): mục thu gọn "Nội dung gốc" hiển thị nguyên văn nguyên liệu và hướng dẫn cũ (khoá `recipes.original_content`).
- Đổi khẩu phần ở đây chỉ để xem, không ghi vào công thức (US3 #3).
- Liên quan: FR-006, FR-007, US1, US3.

## 3. Soạn thảo công thức (`RecipeEditorScreen`) — dùng cho tạo và sửa

- Trường: tên, ảnh (chọn từ máy), số người ăn gốc, ghi chú, thẻ (nhập, gợi ý từ thẻ có sẵn).
- Nguyên liệu: danh sách dòng {tên, số lượng, đơn vị, giá, kcal}; thêm/xoá/kéo đổi thứ tự; số lượng nhận "1/2", "0,5".
- Bước nấu: danh sách {nội dung, ảnh, thời gian tuỳ chọn}; thêm/xoá/kéo đổi thứ tự.
- Kiểm tra khi lưu: nêu rõ trường lỗi (tên trống, 0 nguyên liệu/bước, số âm, thời gian ≤ 0); không mất dữ liệu đang nhập.
- Thoát khi có thay đổi chưa lưu: hỏi xác nhận.
- Mất mạng: lưu bình thường (xếp hàng); thêm ảnh báo "cần có mạng".
- Liên quan: FR-002–FR-005, FR-021, US1.

## 4. Chế độ nấu (`CookingModeScreen`)

- Mỗi lúc một bước, chữ lớn (cỡ ≥ 24 sp, tăng theo cài đặt cỡ chữ hệ thống), chỉ báo "Bước X / Y" và thanh tiến độ.
- Điều hướng: vuốt trái/phải và nút Trước/Tiếp; ở bước 1 vô hiệu "Trước"; ở bước cuối "Tiếp" thành "Hoàn thành".
- Giữ màn hình sáng từ lúc vào đến lúc thoát (và khi ứng dụng quay lại từ nền).
- Bước có `durationSec`: chip hẹn giờ {Bắt đầu / Tạm dừng / Đặt lại}; hết giờ → âm thanh/rung + thông báo (cả khi ở nền
  hoặc đã chuyển bước); hiển thị tất cả hẹn giờ đang chạy.
- Thoát chế độ nấu hoặc đưa app xuống nền **không** huỷ các hẹn giờ đang chạy; chỉ tạm dừng/đặt lại/hoàn thành mới huỷ.
- Nút xem nhanh nguyên liệu (đã quy đổi theo khẩu phần đang chọn) dưới dạng ngăn kéo.
- Vào lại công thức có phiên dở: hỏi "Tiếp tục từ bước N" hoặc "Bắt đầu lại".
- Liên quan: FR-008–FR-012, US2, US6.

## 5. Tài khoản (`AccountMenuScreen`)

- Mở từ biểu tượng ở `RecipeListScreen`.
- Hiển thị email đang đăng nhập; chọn ngôn ngữ Tiếng Việt / English (đổi ngay, ghi nhớ).
- Nút Đăng xuất có hộp thoại xác nhận; đăng xuất huỷ mọi hẹn giờ và quay về màn hình đăng nhập.
- Liên quan: FR-020, FR-023.

## Điều hướng

```
Đăng nhập (giữ như cũ) → RecipeListScreen
RecipeListScreen → RecipeDetailScreen → CookingModeScreen
RecipeListScreen / RecipeDetailScreen → RecipeEditorScreen
RecipeListScreen → AccountMenuScreen → (đăng xuất) → Đăng nhập
```

Các màn hình cộng đồng, theo dõi, bình luận, đánh giá, khám phá và quản trị cũ không còn trong điều hướng.

## Khoá dịch tối thiểu cần thêm (vi / en)

`recipes.title`, `recipes.search_hint`, `recipes.empty`, `recipes.empty_filtered`, `recipes.add`,
`recipes.ingredients`, `recipes.steps`, `recipes.servings`, `recipes.start_cooking`, `recipes.continue_cooking`,
`recipes.restart`, `recipes.step_of`, `recipes.timer_start`, `recipes.timer_done`, `recipes.migrated_summary`,
`recipes.err_title_required`, `recipes.err_no_ingredient`, `recipes.err_no_step`, `recipes.err_offline_image`,
`recipes.syncing`, `recipes.original_content`, `recipes.placeholder_ingredient`, `recipes.placeholder_step`,
`recipes.placeholder_title`, `account.title`, `account.language`, `account.logout`, `account.logout_confirm`, `common.save`, `common.cancel`, `common.delete_confirm`.
