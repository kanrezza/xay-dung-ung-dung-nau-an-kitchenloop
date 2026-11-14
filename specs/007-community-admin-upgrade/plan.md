# Kế hoạch: Nâng cấp Cộng đồng và Quản trị

## Dữ liệu

| Nơi lưu | Trường | Ghi chú |
|---|---|---|
| `communityPosts/{id}` | `likedBy` (list uid), `featured` (bool), `byAdmin` (bool) | bài cũ thiếu trường → đọc mặc định |
| `appConfig/announcement` | `text`, `updatedAt` | `text` rỗng = không có thông báo |

## Rules

- `validLikeChange()`: chỉ đổi `likedBy`, thêm hoặc bớt đúng uid của người ghi (so sánh tập hợp trước/sau).
  Chọn cách này thay vì subcollection `likes/` vì app biết ngay mình đã thích bài nào mà không phải đọc thêm.
- Nhánh quản trị viên của update cho thêm `featured`.
- Create: `get('featured', false) == false`, `get('likedBy', []).size() == 0`, `get('byAdmin', false) == isAdmin()`.
- Tác giả update: không đổi `likedBy`, `featured`; `byAdmin` phải bằng `isAdmin()`.
- `match /appConfig/announcement`.

## Mã

- `community/data`: `like/unlike`, `watchMyLikes`, `setFeatured`, `watchAnnouncement`, `setAnnouncement`.
- `community/domain/feed_arrange.dart`: xếp, lọc thẻ, bài nổi bật (thuần, có test).
- `community/view`: nút ♥ trên thẻ và màn xem bài, chip xếp/lọc, dải nổi bật, thanh công cụ quản trị,
  `AnnouncementBanner` (dùng ở Trang chủ và Cộng đồng).
- `admin/view`: tab Tổng quan (số liệu, bài hot, soạn thông báo); thẻ Bảng quản trị ở Trang chủ;
  huy hiệu ở tab Tài khoản.

## Kiểm thử

Unit cho xếp/lọc/thống kê; repository với fake Firestore; widget cho thích, thanh công cụ quản trị,
banner; rules emulator cho thích, featured, byAdmin, announcement.
