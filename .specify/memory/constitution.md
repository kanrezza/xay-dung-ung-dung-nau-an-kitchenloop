# KitchenLoop Constitution

KitchenLoop là ứng dụng Flutter + Firebase (Firestore, Auth, Storage) quản lý vòng nấu ăn
khép kín: tủ lạnh → gợi ý món → thực đơn tuần → danh sách đi chợ → chế độ nấu từng bước →
thống kê calo/chi tiêu.

## Core Principles

### I. Mô hình nguyên liệu có cấu trúc dùng chung
Nguyên liệu MUST được lưu dạng có cấu trúc `{name, quantity, unit, price, kcal}` và là
nguồn dữ liệu duy nhất cho công thức, tủ lạnh, danh sách đi chợ, đổi khẩu phần và thống kê.
Không được lưu nguyên liệu dưới dạng chuỗi tự do trong bất kỳ tính năng mới nào.
Lý do: mọi tính năng trong vòng nấu ăn đọc cùng một dữ liệu; chuỗi tự do làm hỏng việc
gộp, trừ kho và tính toán.

### II. Phạm vi theo giai đoạn
Công việc MUST đi theo thứ tự: GĐ1 công thức + chế độ nấu từng bước; GĐ2 thực đơn tuần +
danh sách đi chợ; GĐ3 tủ lạnh + gợi ý món; GĐ4 thống kê calo/chi tiêu. Không được bắt đầu
một giai đoạn khi giai đoạn trước chưa đạt tiêu chí hoàn thành trong spec của nó.
Lý do: tránh làm dở dang nhiều tính năng; xong GĐ1–2 đã là một app dùng được.

### III. Bảo mật dữ liệu (KHÔNG THƯƠNG LƯỢNG)
Firestore/Storage rules MUST theo nguyên tắc quyền tối thiểu: người dùng không được tự
nâng quyền (`role`), không sửa dữ liệu của người khác, chỉ thao tác trên UID của chính mình.
Mọi thay đổi rules MUST được kiểm thử trên Firebase emulator trước khi deploy. Khoá bí mật,
`google-services.json` và file cấu hình nhạy cảm MUST NOT được commit.
Quyền quản trị MUST chỉ được cấp bằng custom claim `admin` của Firebase Auth (đặt bằng
script chạy với khoá quản trị, ngoài ứng dụng); MUST NOT dựa vào trường do client ghi được
(như `users.role`). Quản trị viên MUST NOT đọc được công thức riêng của người dùng.
Lý do: bản app cũ từng có lỗ hổng tự nâng quyền admin và chiếm món ăn.

### IV. Kiến trúc tách lớp
Giao diện MUST NOT gọi `FirebaseFirestore`/`FirebaseAuth` trực tiếp; truy cập dữ liệu đi
qua service/repository, trạng thái quản lý bằng Provider. Mỗi màn hình MUST dưới khoảng 300
dòng; phần lớn hơn MUST được tách thành widget riêng.
Lý do: bản cũ có màn hình hơn 1000 dòng trộn UI với truy vấn, khó kiểm thử và sửa.

### V. Kiểm thử và chất lượng mã
Logic nghiệp vụ (gộp nguyên liệu, đổi khẩu phần, gợi ý món, tính calo/chi phí) MUST có
unit test. Model MUST có test chuyển đổi `toMap`/`fromMap`. `flutter analyze` MUST không
báo lỗi trước khi hoàn tất một tác vụ.
Lý do: các phép tính sai làm người dùng mua thiếu đồ hoặc tính sai dinh dưỡng.

### VI. Tiếng Việt trước, hoạt động offline cơ bản
Mọi chuỗi hiển thị MUST đi qua `easy_localization`; tiếng Việt là ngôn ngữ chính, tiếng
Anh là bản dịch. Các chức năng cốt lõi (xem công thức, chế độ nấu, danh sách đi chợ) MUST
dùng được khi mất mạng nhờ bộ nhớ đệm của Firestore.
Lý do: người dùng nấu ăn trong bếp, mạng thường không ổn định.

### VII. Đơn giản và đúng trọng tâm
Áp dụng YAGNI: không thêm tính năng ngoài spec đang làm. Phần mạng xã hội của app cũ
(follow, bình luận, cộng đồng) MUST NOT được đưa vào KitchenLoop trừ khi có spec và sửa đổi
constitution này cho phép. Phần quản trị chỉ ở mức tối thiểu (thống kê tài khoản, khoá/mở
khoá tài khoản) và MUST đi qua spec riêng.
Lý do: giữ app tập trung vào vòng nấu ăn và khác biệt rõ với bài tham khảo.

## Ràng buộc bổ sung

- Công nghệ: Flutter (Dart ≥ 3.2), Firebase (Auth, Firestore, Storage), Provider,
  easy_localization, fl_chart cho biểu đồ.
- Dữ liệu cũ của app trước đó MUST NOT bị ghi đè; nếu cần chuyển đổi, viết script chuyển
  dữ liệu riêng và có bước kiểm tra.
- Tài liệu (spec, plan, tasks, README) viết bằng tiếng Việt.

## Quy trình phát triển

- Mỗi tính năng đi theo chuỗi Spec Kit: specify → (clarify) → plan → tasks → implement.
- Commit MUST NOT chứa dòng `Co-Authored-By` nhắc tới Claude/Anthropic hoặc dòng
  "Generated with Claude Code" (xem `CLAUDE.md` và `GIT_PUSH_NOTES.md`).
- README MUST ghi rõ nguồn tham khảo ý tưởng (KitchenOwl, Mealie, bài của bạn cùng lớp)
  và việc có dùng công cụ AI hỗ trợ.
- Chỉ commit/push khi chủ dự án yêu cầu.

## Lịch sử sửa đổi

- **1.1.0** (2026-11-14, MINOR): cho phép phần quản trị tối thiểu (spec 002). Mở rộng
  nguyên tắc III (quyền admin chỉ qua custom claim, admin không đọc công thức riêng) và
  VII (phạm vi quản trị). Không ảnh hưởng spec 001.

## Governance

Constitution này có hiệu lực cao hơn các quy ước khác trong dự án. Sửa đổi MUST được ghi
lại (lý do, nội dung, ảnh hưởng đến spec/plan đang có) và tăng phiên bản theo ngữ nghĩa:
MAJOR khi bỏ hoặc định nghĩa lại nguyên tắc; MINOR khi thêm nguyên tắc hoặc mở rộng đáng
kể; PATCH khi chỉnh lời văn. Mọi plan và pull request MUST kiểm tra tuân thủ các nguyên
tắc trên; vi phạm phải được giải thích và chấp thuận rõ ràng. Hướng dẫn vận hành hằng
ngày cho Claude nằm ở `CLAUDE.md`.

**Version**: 1.1.0 | **Ratified**: 2026-11-12 | **Last Amended**: 2026-11-14
