# Đặc tả: Nâng cấp Cộng đồng và Quản trị

**Thư mục**: `specs/007-community-admin-upgrade` · **Ngày**: 2026-11-14 · **Trạng thái**: Đang làm

## Bối cảnh

Tab Cộng đồng (spec 004) mới chỉ có danh sách bài mới nhất và ô tìm kiếm; người đọc không có cách
nào cho biết bài nào hay. Quản trị viên (spec 002, 004) dùng app gần như người thường: chỉ có một mục
"Quản trị" ẩn trong tab Tài khoản. Bản này làm cộng đồng sống động hơn và cho quản trị viên công cụ
điều hành thật sự, vẫn giữ nguyên tắc VII của constitution: **không follow, không bình luận**.

## User story

### US1 — Thích bài và xem bài được yêu thích (P1)

Người dùng bấm ♥ để thích/bỏ thích bài của người khác; mỗi bài hiện số lượt thích. Danh sách có thể
xếp theo **Mới nhất** hoặc **Được thích nhiều**, và lọc theo thẻ (chip) lấy từ các bài đang hiện.

**Chấp nhận**
1. Thích một bài → số lượt thích tăng 1 ngay; bấm lần nữa → giảm 1. Mỗi người tối đa một lượt mỗi bài.
2. Không thích được bài của chính mình (nút ẩn, máy chủ cũng chặn).
3. Chọn "Được thích nhiều" → bài nhiều ♥ nhất lên đầu; chọn thẻ "nhanh" → chỉ còn bài có thẻ đó.

### US2 — Bài nổi bật do quản trị viên chọn (P1)

Quản trị viên ghim bài hay thành **Nổi bật**; đầu tab Cộng đồng có dải bài nổi bật cuộn ngang.

**Chấp nhận**
1. Ở màn xem bài, quản trị viên có thanh công cụ: Ghim nổi bật/Bỏ ghim, Ẩn bài, Gỡ bài.
2. Người thường không thấy thanh công cụ; máy chủ chặn người thường đặt `featured`.
3. Bài nổi bật bị ẩn/gỡ thì không còn trong dải nổi bật.

### US3 — Thông báo chung (P2)

Quản trị viên viết một thông báo ngắn (tối đa 200 ký tự) hiện ở đầu Trang chủ và tab Cộng đồng cho mọi
người; người dùng có thể tắt (ẩn) thông báo trên máy mình cho tới khi có thông báo mới.

**Chấp nhận**
1. Quản trị viên lưu thông báo → người khác thấy ngay; xoá thông báo → biến mất.
2. Thông báo chứa link/từ cấm bị chặn bởi cùng bộ kiểm duyệt với bài đăng.
3. Người thường không ghi được thông báo.

### US4 — Không gian làm việc cho quản trị viên (P1)

Quản trị viên được nhận diện rõ và có lối tắt tới việc cần làm.

**Chấp nhận**
1. Tab Tài khoản hiện huy hiệu "Quản trị viên" dưới tên.
2. Trang chủ của quản trị viên có thẻ "Bảng quản trị": số bài chờ duyệt, số tài khoản, lối vào nhanh.
3. Màn Quản trị có mục **Tổng quan** mới: các ô số liệu (tài khoản, mới 7 ngày, bị khoá, bài đang hiện,
   chờ duyệt, tổng lượt thích), bài được thích nhiều nhất, và soạn thông báo chung.
4. Bài do quản trị viên đăng mang huy hiệu "Quản trị viên" (máy chủ kiểm: chỉ tài khoản có quyền mới
   đặt được cờ này).

## Yêu cầu chức năng

- **FR-001** Lượt thích lưu trong bài, trường `likedBy` (danh sách uid); mỗi lần ghi chỉ được thêm hoặc bớt
  đúng uid của người ghi; rules chặn thích bài của mình, thích hai lần, sửa lượt thích của người khác.
- **FR-002** Tác giả sửa bài (chia sẻ lại) không đổi được `likedBy`, `featured`; `byAdmin` luôn phải khớp quyền thật.
- **FR-003** Chỉ quản trị viên (custom claim) đổi được `featured`; bài tạo mới có `featured == false`.
- **FR-004** `byAdmin` khi tạo/sửa phải bằng quyền thật của người ghi.
- **FR-005** `appConfig/announcement`: mọi người đã đăng nhập (không bị khoá) đọc; chỉ quản trị viên
  ghi; nội dung 1–200 ký tự, qua `cleanText`.
- **FR-006** Xếp theo lượt thích, lọc theo thẻ chạy trên máy (danh sách bài đã tải).
- **FR-007** Mọi chuỗi mới có tiếng Việt và tiếng Anh.

## Ngoài phạm vi

Bình luận, theo dõi người dùng, thông báo đẩy, quản trị viên đọc công thức riêng (vẫn cấm).
