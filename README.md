# KitchenLoop

Ứng dụng di động (Flutter + Firebase) giúp **quản lý công thức nấu ăn của riêng bạn** và **nấu theo
từng bước** ngay trong bếp: chữ lớn, vuốt qua lại, màn hình luôn sáng, hẹn giờ báo đúng lúc.

KitchenLoop được phát triển từ một ứng dụng nấu ăn có sẵn (Repicea) nhưng đã đổi hướng: bỏ phần mạng
xã hội (cộng đồng, theo dõi, bình luận, khám phá, quản trị), tập trung vào vòng nấu ăn hằng ngày của
**một người**. Mã của phiên bản cũ đã được gỡ khỏi dự án.

> **Trạng thái:** xong giai đoạn 1 (công thức + chế độ nấu) và giai đoạn 2 (thực đơn tuần + danh sách đi
> chợ). Tủ lạnh và thống kê chưa làm — xem [tầm nhìn](#tầm-nhìn).

## Tính năng

| Tính năng | Mô tả |
|---|---|
| **Công thức có cấu trúc** | Nguyên liệu gồm tên, số lượng, đơn vị, giá, kcal; các bước nấu tách riêng, mỗi bước có thể kèm ảnh và thời gian. |
| **Chế độ nấu từng bước** | Mỗi lần một bước bằng chữ lớn; vuốt hoặc bấm để chuyển bước; giữ màn hình sáng; nhớ bước đang nấu dở. |
| **Hẹn giờ chính xác** | Hẹn giờ cho từng bước, chạy song song nhiều bước; báo bằng thông báo cục bộ kể cả khi app ở nền hoặc đã thoát. |
| **Đổi khẩu phần** | Đổi số người ăn, số lượng nguyên liệu quy đổi tức thì (chỉ để xem, không ghi vào công thức). |
| **Thẻ, tìm, lọc** | Gắn thẻ ("món sinh viên", "nhanh"...), tìm theo tên món/nguyên liệu/thẻ **không phân biệt dấu tiếng Việt**, lọc nhiều thẻ. |
| **Chuyển dữ liệu cũ** | Công thức của bản cũ được chuyển sang dạng có cấu trúc, không mất dữ liệu, giữ nguyên văn để đối chiếu. |
| **Dùng khi mất mạng** | Xem công thức, nấu, hẹn giờ khi offline; thay đổi được đồng bộ khi có mạng lại (hiện nhãn "Đang đồng bộ"). |
| **Riêng tư theo tài khoản** | Mỗi người chỉ thấy và sửa công thức của mình. |
| **Trang chủ** | Lời chào, số liệu nhanh, món của hôm nay, món đang nấu dở (nấu tiếp), gợi ý món. |
| **Thực đơn tuần** | Xếp món vào bữa sáng/trưa/tối từ thứ 2 tới chủ nhật, chọn số người ăn, chuyển tuần ([spec 003](specs/003-meal-plan-shopping-ui/spec.md)). |
| **Danh sách đi chợ tự động** | Gộp nguyên liệu của cả tuần theo số người ăn (g/kg, ml/lít được quy đổi, quả/tép làm tròn lên), tick đã mua, thêm món lẻ. |
| **Giao diện** | 4 tab, lưới công thức có ảnh bìa (ảnh minh hoạ theo loại món khi chưa có ảnh), chế độ sáng/tối theo máy. |
| **Tài khoản** | Tab riêng: ảnh đại diện (thư viện/máy ảnh), tên hiển thị, số liệu cá nhân, ngôn ngữ, giao diện Theo máy/Sáng/Tối (được nhớ), đổi mật khẩu qua email, quản trị, đăng xuất ([spec 005](specs/005-account-tab/spec.md)). |
| **Hai ngôn ngữ** | Tiếng Việt (mặc định) và tiếng Anh. |
| **Cộng đồng** | Chia sẻ công thức; **kiểm duyệt tự động ở Firestore rules** (chặn bài thiếu nội dung, chữ vô nghĩa, link, từ cấm, đăng dồn dập); lưu bài của người khác vào sổ; báo cáo, đủ 3 báo cáo thì bài tự ẩn chờ duyệt ([spec 004](specs/004-community-sharing/spec.md)). Không có follow, bình luận. |
| **Công thức mẫu** | Một nút thêm 12 món Việt quen thuộc (cơm rang dưa bò, bún chả, cá kho tộ, chè đậu xanh…) có sẵn nguyên liệu, giá, kcal và hẹn giờ từng bước; món trùng tên với món đã có được bỏ qua. |
| **Video hướng dẫn** | Mỗi công thức có một video nấu (chọn từ thư viện hoặc quay, tối đa 3 phút); video được nén rồi cắt thành các mẩu ≤ 750 KB lưu trong Firestore (không cần Cloud Storage trả phí); trình phát có tua, video đã xem được lưu trên máy để xem lại khi offline ([spec 006](specs/006-recipe-video/spec.md)). |
| **Quản trị tối thiểu** | Tài khoản quản trị: số tài khoản, khoá/mở khoá; thống kê cộng đồng, biểu đồ bài đăng 7 ngày, hàng chờ duyệt (khôi phục/gỡ bài). Không xem được công thức riêng của ai ([spec 002](specs/002-admin-minimal/spec.md), [spec 004](specs/004-community-sharing/spec.md)). |

## Công nghệ

- **Flutter** (Dart ≥ 3.2), Android và iOS là mục tiêu chính
- **Firebase**: Authentication, Cloud Firestore (bộ nhớ đệm bền để chạy offline), Storage
- `provider` (quản lý trạng thái), `easy_localization` (đa ngôn ngữ), `wakelock_plus` (giữ màn hình sáng),
  `flutter_local_notifications` (báo hết giờ), `cached_network_image` (ảnh có cache),
  `video_player` + `video_compress` (video hướng dẫn)
- Kiểm thử: `flutter_test`, `fake_cloud_firestore`, `firebase_auth_mocks`, Firebase Emulator cho rules

## Cấu trúc mã

```text
lib/
├── main.dart                     # khởi tạo Firebase, đăng ký provider
├── features/recipes/             # toàn bộ tính năng KitchenLoop
│   ├── models/                   # Recipe, Ingredient, RecipeStep, CookingSession (không phụ thuộc Firebase)
│   ├── domain/                   # logic thuần: quy đổi khẩu phần, tìm/lọc, chuẩn hoá chữ, chuyển dữ liệu cũ
│   ├── data/                     # nơi DUY NHẤT nói chuyện với Firebase: repository, migration, thông báo
│   ├── providers/                # trạng thái giao diện (danh sách, soạn thảo, chế độ nấu)
│   └── view/                     # màn hình và widget
├── features/home/                # khung 4 tab, trang chủ, ảnh bìa minh hoạ (spec 003)
├── features/planner/             # thực đơn tuần, danh sách đi chợ (spec 003)
├── features/account/             # tab Tài khoản: hồ sơ, ảnh đại diện, cài đặt (spec 005)
├── features/community/           # chia sẻ công thức, kiểm duyệt, báo cáo (spec 004)
├── features/admin/               # quản trị tối thiểu (spec 002)
├── view/auth/                    # đăng nhập, đăng ký, quên mật khẩu
└── models/ providers/ services/  # chỉ phần phục vụ đăng nhập: UserModel, UserProvider, AuthService
firestore.rules                   # quy tắc bảo mật (chỉ chủ sở hữu đọc/ghi công thức)
rules_test/                       # kiểm thử rules trên Firebase Emulator
tool/admin_tool/                  # script cấp quyền quản trị và tạo dữ liệu demo (chạy trên máy)
specs/001-structured-recipe-cooking-mode/   # đặc tả, kế hoạch, danh sách task (Spec Kit)
```

Nguyên tắc kiến trúc (xem [constitution](.specify/memory/constitution.md)): giao diện không gọi Firebase
trực tiếp; mỗi màn hình dưới ~300 dòng; logic nghiệp vụ có unit test.

## Chạy ứng dụng

Yêu cầu: Flutter SDK, một project Firebase đã cấu hình (Auth, Firestore, Storage).

```bash
flutter pub get
flutter run
```

Dự án đang trỏ tới project Firebase của tác giả (`lib/firebase_options.dart`,
`android/app/google-services.json`). Nếu bạn clone để dùng riêng, hãy tạo project Firebase của bạn và chạy
`flutterfire configure` để sinh lại các file cấu hình này; **đừng dùng chung khoá của người khác**.

Triển khai quy tắc bảo mật lên Firebase:

```bash
firebase deploy --only firestore:rules,storage --project <id-project-cua-ban>
```

Đăng nhập bằng **email** và mật khẩu (Firebase Auth tự giữ phiên, mở lại app không cần đăng nhập lại).
Ứng dụng không lưu mật khẩu ở bất kỳ đâu; hồ sơ người dùng chỉ chủ tài khoản đọc được.

## Quản trị và tài khoản demo

Quyền quản trị là **custom claim** `admin` của Firebase Auth, chỉ cấp được bằng script với khoá
quản trị (không có nút nào trong app tự cấp quyền được).

1. Firebase Console → Project settings → Service accounts → **Generate new private key**, lưu
   thành `tool/admin_tool/service-account.json` (đã có trong `.gitignore`, **không commit**).
2. Đăng ký tài khoản trong app như người dùng bình thường.
3. Chạy:

```bash
cd tool/admin_tool && npm install
node index.mjs grant <email>        # cấp quyền quản trị
node index.mjs seed-demo <email>    # thêm 6 công thức mẫu cho tài khoản demo
node index.mjs list                 # xem ai đang là quản trị viên
node index.mjs revoke <email>       # thu quyền
```

Mở lại màn hình Tài khoản trong app sẽ thấy mục **Quản trị**.

## Kiểm thử

```bash
flutter analyze
flutter test
```

Kiểm thử quy tắc bảo mật Firestore và Storage trên emulator (cần JDK 21 trở lên và Firebase CLI):

```bash
cd rules_test && npm install
npm test
```

Một số kiểm tra **chỉ làm được trên thiết bị thật** (hẹn giờ báo ở nền, quyền thông báo, chế độ máy bay,
iOS); danh sách nằm trong mục Ghi chú của
[tasks.md](specs/001-structured-recipe-cooking-mode/tasks.md) và
[quickstart.md](specs/001-structured-recipe-cooking-mode/quickstart.md).

## Tầm nhìn

Vòng nấu ăn khép kín mà dự án hướng tới:

```text
Tủ lạnh → Gợi ý món → Thực đơn tuần → Danh sách đi chợ → Chế độ nấu → Thống kê calo/chi tiêu
```

Mô hình nguyên liệu có cấu trúc (`{tên, số lượng, đơn vị, giá, kcal}`) được thiết kế để dùng chung cho cả
vòng này. Giai đoạn 1 chỉ làm **công thức + chế độ nấu**.

## Quy trình phát triển

Dự án dùng [Spec Kit](https://github.com/github/spec-kit): `constitution` → `specify` → `plan` →
`tasks` → `implement`. Toàn bộ tài liệu nằm trong [`specs/`](specs/001-structured-recipe-cooking-mode/)
và `.specify/`.

## Nguồn tham khảo và ghi nhận

- Ý tưởng tính năng tham khảo từ các dự án mã nguồn mở
  [KitchenOwl](https://github.com/TomBursch/kitchenowl) (danh sách đi chợ, thực đơn) và
  [Mealie](https://docs.mealie.io/) (quy đổi khẩu phần, quản lý công thức). KitchenLoop **không sao chép mã
  nguồn** của các dự án này.
- Dự án bắt đầu từ một ứng dụng nấu ăn có sẵn (Repicea), sau đó được tái cấu trúc và viết lại phần lớn.
  <!-- TODO(tác giả): ghi tên người bạn cùng lớp có bài làm được tham khảo và xác nhận đã được người đó đồng ý
       trước khi đưa repo lên công khai. Nếu giảng viên có quy định về việc tham khảo bài khác, hãy làm theo. -->
- **Công cụ AI:** một phần mã nguồn, kiểm thử và tài liệu của dự án được viết với sự hỗ trợ của công cụ AI.
  Tác giả đã đọc, kiểm thử và chịu trách nhiệm về toàn bộ nội dung. Nếu giảng viên có quy định riêng về việc
  sử dụng công cụ AI, hãy làm theo quy định đó.
