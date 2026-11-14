# KitchenLoop

App nấu ăn viết bằng Flutter + Firebase, làm cho bài tập lớn môn Lập trình di động.

Ý tưởng đơn giản: lưu công thức của mình, xếp thực đơn cho cả tuần, app tự gom ra danh sách đi chợ,
rồi lúc đứng bếp thì mở chế độ nấu từng bước (chữ to, màn hình không tự tắt, có hẹn giờ). Ai muốn thì
chia sẻ món lên tab Cộng đồng cho người khác xem và lưu về.

App ban đầu sửa từ một app nấu ăn có sẵn (Repicea), sau đó mình viết lại gần hết. Phần code cũ không dùng
nữa đã được xoá khỏi repo.

## App làm được gì

**Công thức**
- Nguyên liệu nhập có cấu trúc (tên, số lượng, đơn vị, giá, kcal), các bước tách riêng, bước nào cũng gắn
  được thời gian.
- Đổi số người ăn thì số lượng nguyên liệu tự nhân/chia theo.
- Gắn thẻ kiểu "món sinh viên", "nhanh"; tìm kiếm gõ không dấu vẫn ra.
- Mỗi công thức gắn được một video hướng dẫn (quay hoặc chọn từ máy, tối đa 3 phút).
- Có nút thêm sẵn 12 món Việt (cơm rang dưa bò, bún chả, cá kho tộ, chè đậu xanh…) để có dữ liệu dùng thử.

**Nấu**
- Chế độ nấu: mỗi màn một bước, vuốt qua lại, màn hình luôn sáng.
- Hẹn giờ cho từng bước, chạy được nhiều cái cùng lúc, app ở nền vẫn báo.
- Đang nấu dở mà thoát ra thì lần sau vào nấu tiếp đúng bước đó.

**Thực đơn và đi chợ**
- Xếp món vào bữa sáng/trưa/tối cho 7 ngày, chọn số người ăn.
- Danh sách đi chợ tự gộp nguyên liệu của cả tuần (g với kg, ml với lít được cộng chung), tick món đã mua,
  thêm được món lẻ.

**Cộng đồng**
- Chia sẻ công thức, người khác bấm lưu về sổ của họ (thành bản riêng, sửa thoải mái).
- Thả tim, xếp bài theo mới nhất hoặc nhiều tim nhất, lọc theo thẻ.
- Bài đăng được kiểm duyệt tự động ngay ở Firestore rules: chặn bài quá sơ sài, gõ bừa, có link, có từ cấm,
  hoặc đăng liên tục. Bài nào bị 3 người báo cáo thì tự ẩn chờ duyệt.
- Không có theo dõi hay bình luận, cố ý để app không thành mạng xã hội.

**Quản trị**
- Tài khoản admin có bảng quản trị riêng: số liệu tài khoản và bài đăng, hàng chờ duyệt, khoá/mở khoá
  tài khoản, ghim bài nổi bật, đăng thông báo chung cho mọi người.
- Admin vẫn không đọc được công thức riêng của ai.

Ngoài ra: đăng nhập bằng email, tab Tài khoản (ảnh đại diện, tên, đổi mật khẩu), giao diện sáng/tối,
tiếng Việt và tiếng Anh, xem công thức và nấu được cả khi mất mạng.

## Chạy thử

Cần Flutter SDK và một project Firebase có bật Authentication và Firestore.

```bash
flutter pub get
flutter run
```

Repo đang trỏ tới project Firebase của mình (`lib/firebase_options.dart`). Nếu clone về chạy riêng thì
tạo project Firebase khác rồi chạy `flutterfire configure` để sinh lại file cấu hình, sau đó đẩy rules lên:

```bash
firebase deploy --only firestore:rules,storage --project <id-project>
```

Ảnh và video không để trên Cloud Storage (gói miễn phí không còn dùng được): ảnh đại diện lưu thẳng trong
hồ sơ Firestore, video được nén rồi cắt thành từng mẩu nhỏ dưới 750 KB để lưu trong Firestore.

## Cấp quyền admin

Quyền admin là custom claim của Firebase Auth, chỉ cấp được bằng script chạy trên máy, trong app không có
nút nào tự nâng quyền.

1. Firebase Console → Project settings → Service accounts → Generate new private key, lưu thành
   `tool/admin_tool/service-account.json` (file này đã nằm trong `.gitignore`, đừng commit).
2. Đăng ký tài khoản trong app như bình thường.
3. Chạy:

```bash
cd tool/admin_tool && npm install
node index.mjs grant <email>       # cấp quyền admin
node index.mjs revoke <email>      # thu quyền
node index.mjs list                # xem ai đang là admin
node index.mjs seed-demo <email>   # thêm vài công thức mẫu cho tài khoản demo
```

Đăng nhập lại bằng tài khoản đó là thấy bảng quản trị ở Trang chủ.

## Kiểm thử

```bash
flutter analyze
flutter test
```

Rules được test riêng trên Firebase Emulator (cần JDK 21 và Firebase CLI):

```bash
cd rules_test && npm install
npm test
```

Mấy thứ như hẹn giờ báo khi app ở nền hay chạy trên iOS thì phải thử bằng máy thật, danh sách nằm trong
[quickstart của spec 001](specs/001-structured-recipe-cooking-mode/quickstart.md).

## Code nằm ở đâu

```text
lib/
├── main.dart              khởi tạo Firebase, đăng ký provider
├── features/
│   ├── recipes/           công thức, chế độ nấu, hẹn giờ, video
│   ├── planner/           thực đơn tuần, danh sách đi chợ
│   ├── community/         chia sẻ, kiểm duyệt, thả tim, thông báo chung
│   ├── admin/             bảng quản trị
│   ├── account/           tab Tài khoản
│   └── home/              trang chủ và khung 5 tab
└── view/auth/             đăng nhập, đăng ký, quên mật khẩu
firestore.rules            phân quyền và kiểm duyệt
rules_test/                test rules trên emulator
tool/admin_tool/           script cấp quyền admin
specs/                     tài liệu từng tính năng
```

Mỗi tính năng chia thành `models`, `domain` (logic thuần, có unit test), `data` (chỗ duy nhất gọi
Firebase), `providers` và `view`. Màn hình cố giữ dưới khoảng 300 dòng.

## Cách làm

Mình làm theo quy trình [Spec Kit](https://github.com/github/spec-kit): viết spec → lên plan → chia task →
code. Mỗi tính năng có một thư mục trong `specs/`:

| Spec | Nội dung |
|---|---|
| [001](specs/001-structured-recipe-cooking-mode/spec.md) | Công thức có cấu trúc, chế độ nấu từng bước |
| [002](specs/002-admin-minimal/spec.md) | Quản trị cơ bản: khoá/mở khoá tài khoản |
| [003](specs/003-meal-plan-shopping-ui/spec.md) | Thực đơn tuần, danh sách đi chợ, giao diện mới |
| [004](specs/004-community-sharing/spec.md) | Chia sẻ công thức, kiểm duyệt tự động, báo cáo |
| [005](specs/005-account-tab/spec.md) | Tab Tài khoản, ảnh đại diện |
| [006](specs/006-recipe-video/spec.md) | Video hướng dẫn nấu |
| [007](specs/007-community-admin-upgrade/spec.md) | Thả tim, bài nổi bật, thông báo chung, bảng quản trị |

Còn muốn làm thêm: tủ lạnh (nhập đồ đang có để gợi ý món) và thống kê calo, chi tiêu theo tuần.

## Tham khảo

- Ý tưởng danh sách đi chợ và thực đơn lấy từ [KitchenOwl](https://github.com/TomBursch/kitchenowl), phần đổi
  khẩu phần lấy ý từ [Mealie](https://docs.mealie.io/). Chỉ tham khảo cách làm, không chép code.
- Có dùng công cụ AI hỗ trợ khi viết code, test và tài liệu; mình đã đọc lại và chạy thử toàn bộ.
  <!-- TODO(tác giả): ghi tên người bạn cùng lớp có bài làm được tham khảo và xác nhận đã được người đó đồng ý
       trước khi đưa repo lên công khai. Nếu giảng viên có quy định về việc tham khảo bài khác, hãy làm theo. -->
