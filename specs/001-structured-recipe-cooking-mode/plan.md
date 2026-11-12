# Implementation Plan: Công thức có cấu trúc và chế độ nấu từng bước

**Branch**: `001-structured-recipe-cooking-mode` (thư mục spec; chưa dùng git) | **Date**: 2026-11-12 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/001-structured-recipe-cooking-mode/spec.md`

## Summary

Xây GĐ1 của KitchenLoop: công thức riêng tư theo từng người với nguyên liệu và bước nấu có cấu trúc,
đổi khẩu phần, chế độ nấu từng bước (giữ màn hình sáng, hẹn giờ chính xác kể cả khi chạy nền), gắn thẻ,
tìm/lọc không dấu, chuyển dữ liệu công thức cũ và dùng được khi mất mạng.

Hướng kỹ thuật (chi tiết ở [research.md](research.md)): collection Firestore mới `recipes` với mảng nhúng
nguyên liệu/bước; logic nghiệp vụ là hàm thuần dễ test (quy đổi, parser, chuẩn hoá tìm kiếm); hẹn giờ dựa
trên thời điểm kết thúc tuyệt đối + thông báo cục bộ; bộ nhớ đệm của Firestore cho offline; rules mới chỉ
cho chủ sở hữu truy cập, kiểm thử trên emulator.

## Technical Context

**Language/Version**: Dart (SDK `>=3.2.3 <4.0.0`), Flutter 3.41.6 stable

**Primary Dependencies**: giữ nguyên `firebase_core`, `firebase_auth`, `cloud_firestore`,
`firebase_storage`, `provider`, `easy_localization`, `shared_preferences`, `image_picker`.
Thêm mới: `wakelock_plus` (1.7.0), `flutter_local_notifications` (22.x) + `timezone`,
`cached_network_image` (3.4.1), `uuid` (4.x); dev: `fake_cloud_firestore` (3.1.0), `firebase_auth_mocks`.
Bỏ khỏi luồng chính: `video_player`, `fl_chart` (để dành GĐ4); chỉ gỡ khỏi `pubspec.yaml` sau khi mã cũ còn dùng chúng đã bị xoá hẳn.

**Storage**: Cloud Firestore (collection `recipes`, bộ nhớ đệm bền bật), Firebase Storage (ảnh),
`shared_preferences` (phiên nấu cục bộ).

**Testing**: `flutter_test` (unit + widget), `fake_cloud_firestore` + `firebase_auth_mocks` (repository),
`@firebase/rules-unit-testing` trên Firestore emulator (rules), `flutter analyze` sạch.

**Target Platform**: Android và iOS (điện thoại). Windows/macOS/Linux/web chỉ giữ để build, không là mục tiêu.

**Project Type**: mobile-app (Flutter + Firebase, không có backend riêng)

**Performance Goals**: đổi khẩu phần cập nhật tức thì (< 100 ms); tìm kiếm < 1 s với ≥ 200 công thức;
hẹn giờ sai lệch ≤ 2 s; chuyển bước trong chế độ nấu ≥ 60 fps.

**Constraints**: dùng được offline (xem công thức, chế độ nấu, hẹn giờ, đổi khẩu phần); mỗi màn hình
< ~300 dòng; UI không gọi Firebase trực tiếp; mọi chuỗi qua `easy_localization` (vi mặc định, en kèm theo).

**Scale/Scope**: một người dùng có tối đa vài trăm công thức; mỗi công thức ≤ 100 nguyên liệu và ≤ 100 bước;
5 màn hình mới (danh sách, chi tiết, soạn thảo, chế độ nấu, tài khoản); bộ lọc thẻ và thông báo chuyển dữ liệu là thành phần trong màn hình danh sách.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Nguyên tắc | Đánh giá | Cách đáp ứng |
|---|---|---|
| I. Nguyên liệu có cấu trúc dùng chung | ✅ Đạt | Model `Ingredient {id, name, quantity?, unit?, price?, kcal?}` trong [data-model.md](data-model.md), không dùng chuỗi tự do. |
| II. Phạm vi theo giai đoạn | ✅ Đạt | Chỉ GĐ1; thực đơn/đi chợ/tủ lạnh/thống kê nằm ngoài (đã ghi ở spec). |
| III. Bảo mật | ✅ Đạt | Rules `recipes` chỉ chủ sở hữu, `ownerId` bất biến, giới hạn kích thước; test trên emulator trước khi deploy. Không commit khoá. |
| IV. Kiến trúc tách lớp | ✅ Đạt (code mới) | `RecipeRepository` + Provider; widget nhỏ. Code cũ vi phạm sẽ bị gỡ khỏi điều hướng, không tái sử dụng. |
| V. Kiểm thử | ✅ Đạt | Unit test cho quy đổi, parser, chuẩn hoá, model `toMap/fromMap`; `flutter analyze` sạch. |
| VI. Tiếng Việt trước, offline | ✅ Đạt | Khoá dịch vi/en; cache bền Firestore + cache ảnh. |
| VII. Đơn giản | ✅ Đạt | Không tái dùng cộng đồng/follow/bình luận; không thêm tính năng ngoài spec. |

**Kết quả**: Không vi phạm; không cần mục Complexity Tracking.

**Re-check sau thiết kế (Phase 1)**: Vẫn đạt. Điểm cần theo dõi: thông báo hẹn giờ bổ sung quyền Android/iOS
(rủi ro đã ghi ở R5) và đây là phụ thuộc mới duy nhất có tác động nền tảng.

## Project Structure

### Documentation (this feature)

```text
specs/001-structured-recipe-cooking-mode/
├── plan.md              # File này
├── research.md          # Phase 0
├── data-model.md        # Phase 1
├── quickstart.md        # Phase 1
├── contracts/           # Phase 1
│   ├── recipe-repository.md
│   ├── firestore-schema.md
│   └── screens.md
├── checklists/requirements.md
└── tasks.md             # /speckit-tasks (chưa tạo)
```

### Source Code (repository root)

```text
lib/
├── main.dart                          # sửa: bật persistence, route về danh sách công thức
├── features/
│   └── recipes/
│       ├── models/                    # recipe.dart, ingredient.dart, recipe_step.dart, cooking_session.dart
│       ├── domain/                    # serving_scaler.dart, quantity_parser.dart,
│       │                              # legacy_converter.dart, text_normalizer.dart, recipe_filter.dart
│       ├── data/                      # recipe_repository.dart (Firestore), legacy_migration_service.dart,
│       │                              # cooking_session_store.dart (shared_preferences), account_actions.dart,
│       │                              # timer_notification_service.dart
│       ├── providers/                 # recipe_list_provider.dart, recipe_editor_provider.dart,
│       │                              # cooking_mode_provider.dart
│       └── view/
│           ├── recipe_list_screen.dart
│           ├── recipe_detail_screen.dart
│           ├── recipe_editor_screen.dart
│           ├── cooking_mode_screen.dart
│           ├── account_menu_screen.dart
│           └── widgets/               # ingredient_row, step_editor, tag_filter_bar, servings_stepper,
│                                      # step_timer_chip, ...
├── (code cũ: models/ providers/ services/ view/)   # không mở rộng; gỡ khỏi điều hướng cuối GĐ1
assets/langs/{vi,en}.json              # thêm khoá cho GĐ1
firestore.rules                        # thêm match /recipes/{recipeId}
rules_test/                            # Node + rules-unit-testing (mới)
test/
├── unit/                              # scaler, parser, normalizer, filter, model
├── repository/                        # RecipeRepository với fake_cloud_firestore
└── widget/                            # cooking_mode_screen, servings_stepper
android/app/src/main/AndroidManifest.xml   # quyền thông báo + báo thức chính xác
ios/Runner/Info.plist / AppDelegate.swift  # cấu hình thông báo cục bộ
```

**Structure Decision**: Giữ một dự án Flutter duy nhất. Mã tính năng mới gom theo thư mục `lib/features/recipes/`
(models / domain / data / providers / view) để tách rõ UI với truy cập dữ liệu theo Constitution IV, thay vì
thêm vào các thư mục `models/ services/ view/` phẳng cũ đã phình to. Mã cũ giữ nguyên cho tới khi gỡ.
