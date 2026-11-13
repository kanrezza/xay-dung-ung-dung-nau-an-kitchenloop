# Feature Specification: Giai đoạn 2 — Thực đơn tuần, danh sách đi chợ và giao diện mới

**Feature Branch**: `003-meal-plan-shopping-ui`

**Created**: 2026-11-14

**Status**: Implemented

**Input**: "Làm lại giao diện (điều hướng 4 tab, trang chủ, thẻ công thức có ảnh bìa, chi tiết có
ảnh lớn, chế độ tối) và giai đoạn 2: thực đơn tuần + danh sách đi chợ tự gộp nguyên liệu."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Giao diện mới, dễ dùng (Priority: P1)

Sau đăng nhập, người dùng thấy trang chủ (lời chào, món của hôm nay, món đang nấu dở, gợi ý)
và thanh điều hướng 4 tab: Trang chủ, Công thức, Thực đơn, Đi chợ. Công thức hiện dạng lưới
có ảnh bìa (ảnh thật hoặc ảnh minh hoạ theo loại món), tổng thời gian và khẩu phần. Màn chi
tiết có ảnh bìa lớn. Giao diện theo chế độ sáng/tối của máy.

**Acceptance Scenarios**:

1. **Given** đã đăng nhập, **When** mở app, **Then** thấy trang chủ và 4 tab, chuyển tab giữ nguyên trạng thái.
2. **Given** công thức không có ảnh, **When** xem lưới, **Then** thấy ảnh minh hoạ phù hợp (gà, cá, phở, trứng...).
3. **Given** có món đang nấu dở, **When** mở trang chủ, **Then** thấy thẻ "Nấu tiếp" mở đúng bước.

### User Story 2 - Thực đơn tuần (Priority: P1)

Người dùng xem tuần hiện tại (thứ 2 → chủ nhật), mỗi ngày có 3 bữa sáng/trưa/tối, thêm món từ
công thức của mình vào bữa (chọn số người ăn), xoá món, chuyển tuần trước/sau. Từ màn chi
tiết công thức có nút "Thêm vào thực đơn".

**Acceptance Scenarios**:

1. **Given** tuần trống, **When** thêm "Thịt kho trứng" cho 4 người vào bữa tối thứ 3, **Then** món hiện đúng ô và còn sau khi mở lại app.
2. **Given** một món trong thực đơn, **When** xoá, **Then** món biến mất.
3. **Given** đang ở tuần này, **When** bấm tuần sau, **Then** thấy tuần sau (trống nếu chưa lên kế hoạch).

### User Story 3 - Danh sách đi chợ tự động (Priority: P1)

Danh sách đi chợ của tuần được tạo tự động từ thực đơn: nguyên liệu được quy đổi theo số người
ăn của từng bữa và gộp lại (cùng tên, cùng loại đơn vị; g với kg, ml với lít được quy đổi).
Đơn vị đếm (quả, tép...) được làm tròn lên. Người dùng tick "đã mua", thêm món lẻ ngoài thực
đơn, ẩn các món đã mua. Dùng được khi mất mạng.

**Acceptance Scenarios**:

1. **Given** 2 bữa cùng dùng trứng (3 quả và 4 quả), **Then** danh sách có 1 dòng "7 quả trứng" ghi rõ dùng cho món nào.
2. **Given** 500 g thịt và 1 kg thịt, **Then** gộp thành "1,5 kg thịt".
3. **Given** đã tick một dòng, **When** thực đơn thay đổi nhưng dòng đó vẫn còn, **Then** dòng vẫn được tick.

### Edge Cases

- Món trong thực đơn bị xoá khỏi sổ công thức: vẫn hiện tên (lưu kèm), không đóng góp nguyên liệu, có ghi chú.
- Nguyên liệu không có số lượng ("tiêu vừa đủ"): một dòng không số lượng, không cộng dồn.
- Tuần có hơn 63 mục (9 món/bữa): từ chối thêm, báo rõ.

## Requirements *(mandatory)*

- **FR-001**: Thanh điều hướng 4 tab; trang chủ là tab đầu sau đăng nhập.
- **FR-002**: Ảnh bìa minh hoạ được chọn theo từ khoá tên món khi không có ảnh.
- **FR-003**: Thực đơn lưu theo tuần (`weekPlans/{uid}_{thứ 2 của tuần}`), chỉ chủ sở hữu đọc/ghi.
- **FR-004**: Danh sách đi chợ tính từ thực đơn + sổ công thức; trạng thái đã mua và món lẻ lưu ở
  `shoppingLists/{uid}_{thứ 2 của tuần}`; chỉ chủ sở hữu đọc/ghi.
- **FR-005**: Gộp nguyên liệu MUST có unit test (Constitution V).
- **FR-006**: Tài khoản bị khoá không đọc/ghi được thực đơn và danh sách đi chợ.
- **FR-007**: Mọi chuỗi qua easy_localization (vi, en); chế độ sáng/tối theo hệ thống.

## Success Criteria *(mandatory)*

- **SC-001**: Từ trang chủ tới thêm một món vào thực đơn trong ≤ 4 chạm.
- **SC-002**: Danh sách đi chợ cập nhật ngay khi thực đơn đổi, không cần tải lại.
- **SC-003**: 100% kịch bản rules mới đạt trên emulator.

## Assumptions

- Thống kê calo/chi tiêu theo tuần thuộc giai đoạn 4, không làm ở đây.
- Tuần bắt đầu thứ 2 (thói quen Việt Nam).
