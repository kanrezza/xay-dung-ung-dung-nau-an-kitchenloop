# Research: Công thức có cấu trúc và chế độ nấu từng bước

Mọi mục "cần làm rõ" trong Technical Context đã được giải quyết bên dưới.

## R1. Nơi lưu công thức mới

- **Decision**: Collection Firestore mới `recipes/{recipeId}`; nguyên liệu và bước nấu là **mảng nhúng** trong document.
- **Rationale**: Một công thức có tối đa vài chục nguyên liệu/bước, đọc một lần là có đủ dữ liệu
  (nhanh, rẻ, và dễ dùng offline vì chỉ cần cache một document). Không cần truy vấn riêng lẻ từng
  nguyên liệu ở GĐ1. Dùng collection mới giúp không đụng tới `foods` cũ (an toàn khi chuyển dữ liệu).
- **Alternatives considered**: (a) sub-collection `ingredients`/`steps` — nhiều lần đọc, khó đồng bộ
  offline, quá phức tạp cho quy mô này; (b) sửa trực tiếp collection `foods` — dễ làm hỏng dữ liệu cũ
  và còn lẫn các trường mạng xã hội.

## R2. Chuyển dữ liệu công thức cũ

- **Decision**: Chuyển từ `foods` (lọc `authorId == uid`) sang `recipes` bằng **ID xác định**
  (`recipes/{foodId}`) và lưu `legacy: {ingredients: [...], instructions: "..."}` để đối chiếu.
  Chạy một lần mỗi người dùng khi mở app, ghi cờ `users/{uid}.recipeMigratedAt`. Không sửa/xoá `foods`.
- **Rationale**: ID xác định làm cho việc chạy lại an toàn (ghi đè cùng một document, không tạo bản
  sao) — đáp ứng FR-018. Giữ nguyên bản gốc đáp ứng yêu cầu "không mất dữ liệu".
- **Parser nguyên liệu**: biểu thức chính quy `^\s*(số|phân số|hỗn số)\s*(đơn vị)?\s*(.+)$`; nhận dấu
  `,` và `.` thập phân, "1/2", "1 1/2". Không khớp → `name = nguyên văn`, `quantity = null`.
- **Parser hướng dẫn**: tách theo dòng; bỏ tiền tố đánh số ("1.", "1)", "Bước 1:"); bỏ dòng rỗng. Nếu chỉ
  còn một dòng dài thì tách theo câu kết thúc bằng dấu chấm.
- **Alternatives considered**: Cloud Function chuyển hàng loạt — cần gói trả phí Blaze và triển khai
  riêng; chuyển phía client theo từng người dùng đơn giản hơn, đủ cho đồ án.

## R3. Quy đổi khẩu phần

- **Decision**: Hàm thuần (không phụ thuộc Flutter): `scale(quantity, baseServings, targetServings)`;
  `null` giữ nguyên. Làm tròn tối đa 2 chữ số thập phân, bỏ số 0 thừa; hiển thị phân số thân thiện
  (½, ¼) là cải tiến sau.
- **Rationale**: Dễ unit test (Constitution V), dùng lại cho danh sách đi chợ ở GĐ2.
- **Alternatives considered**: Lưu sẵn số lượng cho từng khẩu phần — thừa dữ liệu, dễ lệch.

## R4. Giữ màn hình sáng

- **Decision**: gói `wakelock_plus` (1.7.0 resolve được). Bật khi vào chế độ nấu, tắt khi thoát
  hoặc khi app vào nền (theo `WidgetsBindingObserver`).
- **Rationale**: Gói phổ biến, hỗ trợ cả Android/iOS, API đơn giản (`WakelockPlus.enable/disable`).
- **Alternatives considered**: `screen_brightness`/tự giữ bằng timer — không đúng mục đích.

## R5. Hẹn giờ chính xác kể cả khi chạy nền

- **Decision**: Lưu **thời điểm kết thúc tuyệt đối** (`endAt`), không đếm lùi bằng biến. Giao diện cập
  nhật mỗi giây bằng `Timer.periodic` nhưng tính `remaining = endAt - now`. Đồng thời đặt thông báo
  cục bộ hẹn giờ tại `endAt` bằng `flutter_local_notifications` (+ `timezone`) để báo khi app ở nền. Thời điểm lên lịch dùng `TZDateTime` theo UTC (thời điểm tuyệt đối) nên không cần xác định múi giờ của thiết bị.
- **Rationale**: Bộ đếm Dart bị hệ điều hành đóng băng khi app ở nền; dùng `endAt` + thông báo đã lên
  lịch giúp sai lệch ≤ 2 giây (SC-005) và vẫn đúng sau khi quay lại app.
- **Rủi ro**: Android 12+ cần quyền báo thức chính xác (`SCHEDULE_EXACT_ALARM`) và Android 13+ cần
  `POST_NOTIFICATIONS`; iOS cần xin quyền thông báo. Nếu bị từ chối: dùng lịch không chính xác và vẫn
  báo trong app khi đang mở (đã ghi ở Assumptions của spec).
- **Alternatives considered**: Foreground service — nặng cho nhu cầu này; `android_alarm_manager_plus` —
  chỉ Android.

## R6. Lưu phiên nấu để tiếp tục

- **Decision**: `shared_preferences` (đã có sẵn trong dự án): lưu `recipeId`, `stepIndex`, `servings`,
  danh sách `endAt` đang chạy. Xoá khi hoàn thành hoặc người dùng chọn bắt đầu lại.
- **Rationale**: Dữ liệu nhỏ, chỉ cục bộ trên máy, không cần đồng bộ.

## R7. Hoạt động offline

- **Decision**: Bật bộ nhớ đệm bền của Firestore (`Settings(persistenceEnabled: true)`); danh sách và
  chi tiết công thức đọc qua `snapshots()` nên tự lấy từ cache khi mất mạng. Ghi khi offline được xếp
  hàng và đồng bộ khi có mạng; **không `await` chờ server xác nhận** ở nơi cần phản hồi tức thì (dùng
  trạng thái "đang đồng bộ"). Ảnh dùng `cached_network_image` (3.4.1 resolve được).
- **Rationale**: Đáp ứng FR-019, SC-008 với ít mã nhất. Xung đột chỉnh sửa hai thiết bị: ghi sau cùng
  thắng (last-write-wins) theo `updatedAt` của máy chủ.
- **Alternatives considered**: CSDL cục bộ riêng (Drift/Isar) — trùng việc với cache của Firestore.

## R8. Tìm kiếm không dấu

- **Decision**: Lọc **phía client** trên danh sách công thức của chính người dùng (đã có trong bộ nhớ):
  chuẩn hoá chuỗi (hạ chữ thường, bỏ dấu tiếng Việt, `đ→d`) rồi so khớp tên món, tên nguyên liệu và thẻ.
  Hàm chuẩn hoá dùng chung (đã có bản trong `blogger_home_screen.dart`, sẽ chuyển thành tiện ích có test).
- **Rationale**: Quy mô ≤ vài trăm công thức mỗi người; Firestore không hỗ trợ tìm văn bản con; client-side
  nhanh (< 1 giây, SC-006) và chạy cả khi offline.
- **Alternatives considered**: Trường `searchKeywords` + `arrayContains`, Algolia — cần thiết khi tìm
  trong dữ liệu chung rất lớn, thừa ở GĐ1 vì công thức riêng tư.

## R9. Bảo mật

- **Decision**: Rules mới cho `recipes`: chỉ chủ sở hữu đọc/ghi (`resource.data.ownerId == request.auth.uid`),
  `ownerId` bất biến, giới hạn kích thước mảng (nguyên liệu ≤ 100, bước ≤ 100), tên không rỗng.
  Bộ kiểm thử rules đặt trong repo (`rules_test/`) chạy trên Firestore emulator (Constitution III).
- **Rationale**: Công thức riêng tư theo spec (FR-015, SC-009).

## R10. Kiểm thử

- **Decision**: `flutter_test` cho logic thuần (quy đổi, parser, chuẩn hoá tìm kiếm, model);
  `fake_cloud_firestore` 3.1.0 và `firebase_auth_mocks` cho repository (repository nhận Firestore/Auth qua constructor để thay được bằng bản giả); widget test cho màn hình chế độ nấu; kiểm thử rules bằng
  Node + `@firebase/rules-unit-testing` trên emulator.
- **Rationale**: Bám Constitution V; công cụ đã dùng thử thành công khi vá rules trước đó.

## R11. Xử lý code mạng xã hội cũ

- **Decision**: Không tái sử dụng màn hình cộng đồng, follow, bình luận, đánh giá. Màn hình công thức mới
  nằm ở thư mục mới; code cũ bị gỡ khỏi điều hướng ở cuối GĐ1 (Constitution VII), việc xoá file hẳn do
  một task riêng.
