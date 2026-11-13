# Feature Specification: Quản trị tối thiểu

**Feature Branch**: `002-admin-minimal`

**Created**: 2026-11-14

**Status**: Implemented

**Input**: "Thêm một phần quản trị nhỏ và an toàn: thống kê tài khoản, khoá/mở khoá tài khoản;
quyền admin cấp bằng custom claim, admin không đọc được công thức riêng của người dùng."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Xem thống kê và danh sách tài khoản (Priority: P1)

Quản trị viên mở mục "Quản trị" trong màn hình Tài khoản, thấy số tài khoản, số tài khoản
đang bị khoá, số tài khoản mới trong 7 ngày, và danh sách tài khoản (tên, email, ngày tạo,
trạng thái). Có thể tìm theo tên hoặc email.

**Independent Test**: Cấp quyền admin cho một tài khoản, đăng nhập, mở Tài khoản → Quản trị,
thấy đúng số tài khoản như trong Firebase Console.

**Acceptance Scenarios**:

1. **Given** tài khoản có quyền admin, **When** mở màn hình Tài khoản, **Then** thấy mục "Quản trị".
2. **Given** tài khoản thường, **When** mở màn hình Tài khoản, **Then** KHÔNG thấy mục "Quản trị";
   gọi thẳng vào dữ liệu `users` cũng bị rules từ chối.
3. **Given** quản trị viên, **When** xem màn hình quản trị, **Then** KHÔNG thấy nội dung hay số
   lượng công thức của ai (quyền riêng tư).

### User Story 2 - Khoá và mở khoá tài khoản (Priority: P1)

Quản trị viên khoá một tài khoản vi phạm (có xác nhận). Tài khoản bị khoá không đăng nhập
được, phiên đang mở bị đăng xuất khi mở lại app, và không đọc/ghi được công thức. Mở khoá thì
dùng lại bình thường. Quản trị viên không tự khoá chính mình.

**Acceptance Scenarios**:

1. **Given** tài khoản B đang hoạt động, **When** admin khoá B, **Then** B không đăng nhập được
   và không đọc/ghi được `recipes`.
2. **Given** B đang bị khoá, **When** admin mở khoá, **Then** B dùng lại bình thường, dữ liệu còn nguyên.
3. **Given** admin, **When** xem dòng của chính mình, **Then** không có nút khoá.

### Edge Cases

- Người dùng tự ghi `role: 'admin'` hoặc `isLocked: false` vào hồ sơ: không có tác dụng.
- Admin chỉ được đổi trường `isLocked` (và `lockedAt`), không sửa được tên, email của người khác.
- Hồ sơ cũ thiếu `createdAt` hoặc `name`: vẫn hiện được trong danh sách.

## Requirements *(mandatory)*

- **FR-001**: Quyền admin MUST đến từ custom claim `admin == true` của Firebase Auth, đặt bằng
  script ngoài ứng dụng (khoá quản trị không nằm trong app hay repo).
- **FR-002**: Chỉ admin MUST đọc/liệt kê được `users`; người thường chỉ đọc hồ sơ của mình.
- **FR-003**: Admin MUST chỉ đổi được `isLocked`/`lockedAt` của người khác, không phải của mình.
- **FR-004**: Tài khoản bị khoá MUST bị từ chối đọc/ghi `recipes` ở tầng rules.
- **FR-005**: Tài khoản bị khoá MUST bị đăng xuất khi đăng nhập hoặc khi mở lại app.
- **FR-006**: Admin MUST NOT đọc được `recipes` của người khác (giữ nguyên spec 001).
- **FR-007**: Mọi chuỗi hiển thị MUST đi qua easy_localization (vi, en).

## Success Criteria *(mandatory)*

- **SC-001**: 100% kịch bản rules (admin, người thường, tài khoản khoá) đạt trên emulator.
- **SC-002**: Khoá một tài khoản có hiệu lực ngay ở lần đọc/ghi kế tiếp của tài khoản đó.

## Assumptions

- Không có Cloud Functions; thống kê được tính trên máy admin từ danh sách `users`.
- Số lượng tài khoản nhỏ (bài tập lớn), tải toàn bộ `users` là chấp nhận được.
- Ngoài phạm vi: xoá tài khoản, sửa hồ sơ người khác, thống kê công thức.
