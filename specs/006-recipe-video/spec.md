# Feature Specification: Video hướng dẫn nấu cho công thức

**Feature Branch**: `006-recipe-video`

**Created**: 2026-11-14

**Status**: Implemented

**Input**: "Phải có cái để thêm video hướng dẫn nấu; lấy video tôi gửi để cho vào." Đã chốt: vì Cloud
Storage của project bị khoá (không có tài khoản thanh toán), video được nén rồi cắt thành nhiều mẩu
lưu trong Firestore.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Thêm video cho công thức (Priority: P1)

Ở màn chi tiết công thức, người dùng bấm "Thêm video hướng dẫn", chọn video từ thư viện hoặc quay
mới. Ứng dụng nén video, tải lên kèm thanh tiến độ, rồi hiện trình phát ngay trong màn chi tiết. Có
thể thay video khác hoặc xoá video.

**Acceptance Scenarios**:

1. **Given** công thức chưa có video, **When** chọn một video ngắn, **Then** video được tải lên và phát được.
2. **Given** video quá lớn sau khi nén (> 20 MB), **Then** bị từ chối và báo rõ giới hạn.
3. **Given** công thức có video, **When** xoá video hoặc xoá cả công thức, **Then** mọi mẩu video cũng bị xoá.

### User Story 2 - Xem video (Priority: P1)

Bấm phát: ứng dụng tải các mẩu (có tiến độ), ghép lại, phát có nút dừng/tiếp, thanh tua. Đã xem
một lần thì lần sau phát ngay, kể cả khi mất mạng.

## Requirements *(mandatory)*

- **FR-001**: Video lưu ở `recipes/{id}/videoChunks/{videoId}_{i}` (mỗi mẩu ≤ 750 000 byte, kiểu bytes),
  thông tin video ở trường `video` của công thức (`id`, `chunkCount`, `sizeBytes`, `durationMs`, `mime`).
- **FR-002**: Chỉ chủ công thức đọc/ghi các mẩu (rules); tối đa 28 mẩu (~20 MB) mỗi video.
- **FR-003**: Ghi các mẩu TRƯỚC, cập nhật `video` SAU; thay video thì xoá mẩu cũ sau khi video mới đã ghi xong.
- **FR-004**: Video được nén (chất lượng trung bình) trước khi tải; tối đa 3 phút.
- **FR-005**: Mọi chuỗi qua easy_localization (vi, en).

## Success Criteria *(mandatory)*

- **SC-001**: Video 2 phút quay bằng điện thoại thêm được trong ≤ 4 chạm.
- **SC-002**: 100% kịch bản rules mới đạt trên emulator.

## Assumptions

- Đây là cách lưu thay thế khi chưa có Cloud Storage; khi bật lại thanh toán nên chuyển video sang Storage.
- Video không được chia sẻ lên cộng đồng ở bản này.
