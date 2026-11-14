# Feature Specification: Tab Tài khoản và hồ sơ cá nhân

**Feature Branch**: `005-account-tab`

**Created**: 2026-11-14

**Status**: Implemented

**Input**: "Làm riêng một tab Tài khoản, thiết kế lại, thay được ảnh đại diện…". Đã chốt: giữ 5 tab
bằng cách gộp Thực đơn + Đi chợ thành tab "Kế hoạch" (2 tab con).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Hồ sơ cá nhân (Priority: P1)

Ở tab Tài khoản, người dùng thấy ảnh đại diện, tên hiển thị, email và vài con số của mình (số
công thức, món trong tuần, bài đã chia sẻ). Bấm vào ảnh để chọn ảnh từ thư viện, chụp ảnh mới
hoặc xoá ảnh; bấm biểu tượng bút để đổi tên hiển thị (tên này hiện trên bài cộng đồng).

**Acceptance Scenarios**:

1. **Given** chưa có ảnh, **Then** hiện chữ cái đầu của tên trên nền màu.
2. **Given** chọn một ảnh, **Then** ảnh được tải lên và hiện ngay ở tab Tài khoản và trang chủ.
3. **Given** đổi tên thành tên hợp lệ, **Then** tên mới hiện ngay; tên rỗng, quá 40 ký tự hoặc chứa link/từ cấm thì bị từ chối kèm lý do.

### User Story 2 - Cài đặt (Priority: P1)

Đổi ngôn ngữ (Tiếng Việt/English), giao diện (Theo máy/Sáng/Tối, được nhớ sau khi mở lại app),
đổi mật khẩu (gửi email đặt lại tới email của tài khoản), mục Quản trị (nếu là admin), đăng xuất có xác nhận.

### User Story 3 - Điều hướng 5 tab (Priority: P1)

Thanh dưới có 5 tab: Trang chủ, Công thức, Kế hoạch (Thực đơn | Đi chợ), Cộng đồng, Tài khoản.
Các lối tắt trên trang chủ mở đúng tab và tab con.

## Requirements *(mandatory)*

- **FR-001**: Ảnh đại diện lưu trong hồ sơ `users/{uid}.avatarData` (data URI jpeg/png/webp, ≤ 150 000 ký tự),
  vì Cloud Storage cần gói trả phí; chỉ chủ tài khoản ghi. (Thư mục Storage `avatars/{uid}` vẫn có rules, dùng khi bật lại thanh toán.)
- **FR-002**: `users/{uid}.avatarUrl` chỉ nhận link Firebase Storage hoặc rỗng (không nhận link tuỳ ý); `name` ≤ 40 ký tự.
- **FR-003**: Ảnh được thu nhỏ trước khi lưu (tối đa 256 px, chất lượng 75).
- **FR-004**: Chế độ giao diện lưu trên máy (SharedPreferences), áp dụng ngay.
- **FR-005**: Mọi chuỗi qua easy_localization (vi, en).

## Success Criteria *(mandatory)*

- **SC-001**: Đổi ảnh đại diện trong ≤ 3 chạm từ tab Tài khoản.
- **SC-002**: 100% kịch bản rules mới (avatar, hồ sơ) đạt trên emulator.

## Assumptions

- Ảnh đại diện chưa hiện trên bài cộng đồng ở bản này (bài chỉ có tên hiển thị).
- Xoá tài khoản không thuộc phạm vi.
