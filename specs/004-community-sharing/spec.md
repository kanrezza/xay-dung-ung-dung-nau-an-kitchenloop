# Feature Specification: Chia sẻ công thức lên cộng đồng, kiểm duyệt tự động

**Feature Branch**: `004-community-sharing`

**Created**: 2026-11-14

**Status**: Implemented

**Input**: "Chia sẻ công thức cho cộng đồng; kiểm duyệt bài đăng tự động để không có bài linh
tinh; admin xem được thống kê." Phương án đã chốt: kiểm duyệt bằng Firestore rules + báo cáo
của cộng đồng (gói Spark, không Cloud Functions).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Chia sẻ công thức (Priority: P1)

Từ màn chi tiết công thức, người dùng bấm "Chia sẻ lên cộng đồng". Ứng dụng kiểm tra trước và
báo rõ lý do nếu bài chưa đạt (tên quá ngắn, ít nguyên liệu/bước, có link, từ cấm...). Bài đạt
thì xuất hiện ngay ở tab Cộng đồng. Chia sẻ lại cùng công thức thì cập nhật bài cũ.

**Acceptance Scenarios**:

1. **Given** công thức có tên rõ ràng, ≥ 2 nguyên liệu, ≥ 2 bước, **When** chia sẻ, **Then** bài hiện ở Cộng đồng.
2. **Given** tên "aaaaaa" hoặc có link "http://...", **When** chia sẻ, **Then** bị từ chối và báo lý do.
3. **Given** ứng dụng bị sửa để bỏ qua kiểm tra, **When** gửi bài linh tinh thẳng lên Firestore, **Then** rules vẫn từ chối.
4. **Given** vừa đăng một bài, **When** đăng bài khác trong vòng 2 phút, **Then** bị từ chối (chống spam).

### User Story 2 - Xem, lưu và báo cáo bài (Priority: P1)

Người dùng xem bài cộng đồng (mới nhất trước, tìm theo tên), xem chi tiết, "Lưu vào sổ của tôi"
để có bản sao riêng (nấu, đổi khẩu phần, thêm vào thực đơn), hoặc báo cáo bài kèm lý do. Mỗi
người báo cáo một bài một lần; bài đủ 3 báo cáo tự ẩn chờ quản trị viên.

**Acceptance Scenarios**:

1. **Given** bài của người khác, **When** "Lưu vào sổ của tôi", **Then** công thức xuất hiện trong tab Công thức.
2. **Given** bài có 2 báo cáo, **When** người thứ 3 báo cáo, **Then** bài biến mất khỏi Cộng đồng.
3. **Given** đã báo cáo một bài, **When** báo cáo lần nữa, **Then** bị từ chối.
4. **Given** bài của mình, **Then** không có nút báo cáo, có nút gỡ bài.

### User Story 3 - Quản trị viên: thống kê và duyệt bài (Priority: P2)

Trong màn Quản trị có mục Cộng đồng: số bài đang hiện / đang chờ duyệt / đã gỡ, tổng báo cáo,
số bài đăng 7 ngày qua theo ngày, và hàng chờ duyệt (bài bị ẩn kèm lý do báo cáo) với nút
Khôi phục hoặc Gỡ bài.

**Acceptance Scenarios**:

1. **Given** quản trị viên, **When** mở Quản trị → Cộng đồng, **Then** thấy số liệu đúng.
2. **Given** bài trong hàng chờ, **When** Khôi phục, **Then** bài hiện lại và số báo cáo về 0.
3. **Given** người thường, **Then** không đổi được trạng thái bài và không đọc được báo cáo.

## Requirements *(mandatory)*

- **FR-001**: Kiểm duyệt MUST chạy ở Firestore rules: tên 3–80 ký tự, có chữ, không lặp một ký tự
  ≥ 5 lần liền, không link, không từ cấm; 2–50 nguyên liệu, 2–50 bước; nội dung 2 nguyên liệu
  và 2 bước đầu có nghĩa; ghi chú ≤ 1000 ký tự.
- **FR-002**: Ứng dụng MUST kiểm tra trước cùng bộ quy tắc và báo lý do bằng lời dễ hiểu.
- **FR-003**: Giới hạn 1 bài mới mỗi 2 phút mỗi tài khoản (rules, dùng `users.lastPostAt`).
- **FR-004**: Báo cáo: mỗi người một lần mỗi bài; bộ đếm chỉ tăng đúng 1 trong cùng lần ghi; đủ 3 thì bài ẩn.
- **FR-005**: Chỉ quản trị viên (custom claim) đổi trạng thái bài, đọc báo cáo, xem bài bị ẩn/gỡ của người khác.
- **FR-006**: Bài đăng chỉ chứa tên hiển thị của tác giả, không chứa email.
- **FR-007**: Tài khoản bị khoá không đăng, không báo cáo, không đọc cộng đồng.
- **FR-008**: Không có follow, bình luận, nhắn tin (Constitution VII).

## Success Criteria *(mandatory)*

- **SC-001**: 100% kịch bản kiểm duyệt (hợp lệ / linh tinh / spam / báo cáo / quản trị) đạt trên emulator.
- **SC-002**: Danh sách từ cấm trong ứng dụng và trong rules luôn khớp (có test).

## Assumptions

- Không có AI duyệt nội dung (cần gói Blaze); rules không hiểu ngữ nghĩa, nên báo cáo của cộng
  đồng bù cho phần đó.
- Rules không duyệt được mọi phần tử trong danh sách (không có vòng lặp); chỉ kiểm tra kỹ 2 nguyên
  liệu và 2 bước đầu, các phần tử khác kiểm tra ở ứng dụng và qua báo cáo.
- Ảnh công thức không được chia sẻ ở bản này (ảnh nằm trong Storage riêng của tác giả).
