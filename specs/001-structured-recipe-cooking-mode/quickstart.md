# Quickstart: Kiểm tra GĐ1 từ đầu đến cuối

Hướng dẫn chạy và xác nhận tính năng hoạt động. Chi tiết dữ liệu: [data-model.md](data-model.md); hợp đồng:
[contracts/](contracts/).

## Điều kiện

- Flutter 3.41.x, Android emulator hoặc iOS simulator (hẹn giờ nền cần thử trên thiết bị/giả lập thật).
- Firebase CLI và JDK 21 trở lên (cho Firestore emulator). Trên máy này JDK 21 nằm ở
  `/Library/Java/JavaVirtualMachines/temurin-21.jdk/Contents/Home`.
- Đã đăng nhập Firebase cho project `my-food-app-b8f2d` (chỉ cần khi deploy rules).

## 1. Cài phụ thuộc và kiểm tra tĩnh

```bash
flutter pub get
flutter analyze
```

Kỳ vọng: không có lỗi.

## 2. Chạy kiểm thử tự động

```bash
flutter test
```

Kỳ vọng: toàn bộ test đạt, gồm quy đổi khẩu phần, parser nguyên liệu/hướng dẫn cũ, chuẩn hoá tìm kiếm,
chuyển đổi model và repository (với Firestore giả).

## 3. Kiểm thử rules trên emulator (bắt buộc trước khi deploy)

```bash
cd rules_test && npm install
export JAVA_HOME=/Library/Java/JavaVirtualMachines/temurin-21.jdk/Contents/Home
firebase emulators:exec --only firestore --project demo-rules "node test.mjs"
```

Kỳ vọng: tất cả tình huống ở mục "Kiểm thử bắt buộc cho rules" trong
[contracts/firestore-schema.md](contracts/firestore-schema.md) đạt.

## 4. Chạy app và duyệt các kịch bản

```bash
flutter run
```

| # | Kịch bản | Cách làm | Kết quả mong đợi |
|---|---|---|---|
| 1 | US1 – tạo/xem | Tạo "Trứng chiên" (2 người; 2 quả trứng, muối vừa đủ; 2 bước) và lưu | Xuất hiện trong danh sách; mở ra đúng nguyên liệu và thứ tự bước |
| 2 | US1 – kiểm tra dữ liệu | Lưu khi để trống tên / không nguyên liệu | Không lưu được, báo rõ trường thiếu |
| 3 | US3 – khẩu phần | Đổi 2 → 5 người | Trứng 2 → 5 quả; "muối vừa đủ" giữ nguyên; công thức gốc không đổi |
| 4 | US2 – chế độ nấu | Bắt đầu nấu, vuốt qua các bước | Chữ lớn, "Bước X / Y", bước đầu không lùi, bước cuối thành "Hoàn thành" |
| 5 | US2 – hẹn giờ | Bước có 2 phút: bật hẹn giờ, chuyển bước khác, khoá máy | Hết giờ có âm thanh/rung và thông báo, sai lệch ≤ 2 giây |
| 6 | US2 – màn hình sáng | Để yên ở chế độ nấu 5 phút | Màn hình không tắt; thoát ra thì trở lại bình thường |
| 7 | US2 – tiếp tục | Thoát giữa chừng rồi vào lại | Được hỏi tiếp tục từ bước dở hay bắt đầu lại |
| 8 | US4 – tìm/lọc | Gắn thẻ "món sinh viên" cho vài món; tìm "ga" | Lọc đúng; "ga" khớp món chứa "gà" |
| 9 | US5 – chuyển dữ liệu | Đăng nhập tài khoản có công thức cũ (gồm một món không có nguyên liệu và một món tên rất dài) | Thông báo "Đã chuyển N công thức…"; mọi món đều có mặt (món thiếu dữ liệu dùng dòng/bước giữ chỗ); mục "Nội dung gốc" hiển thị nguyên văn; chạy lại không tạo bản sao |
| 10 | US6 – offline | Mở danh sách khi có mạng, tắt mạng, mở công thức và nấu hết các bước | Không lỗi chặn; sửa khi offline được đồng bộ khi có mạng lại |
| 11 | Quyền riêng tư | Đăng nhập bằng tài khoản khác | Không thấy công thức của tài khoản kia |
| 12 | Tài khoản | Mở màn hình tài khoản: đổi sang English và về Tiếng Việt; bật hẹn giờ rồi đăng xuất | Giao diện đổi ngay; sau đăng xuất không còn thông báo hẹn giờ; đăng nhập lại tài khoản khác không thấy dữ liệu người trước |

## 5. Điều kiện hoàn thành GĐ1

- Các bước 1–3 đạt và 12 kịch bản ở mục 4 đạt.
- Các tiêu chí SC-001 đến SC-009 trong [spec.md](spec.md) được xác nhận (đo thủ công cho SC-001, SC-002, SC-004, SC-005).
- Rules `recipes` đã deploy sau khi qua emulator.
