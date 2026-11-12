---
description: "Danh sách task cho GĐ1 KitchenLoop: công thức có cấu trúc và chế độ nấu từng bước"
---

# Tasks: Công thức có cấu trúc và chế độ nấu từng bước

**Input**: Tài liệu thiết kế trong `specs/001-structured-recipe-cooking-mode/`

**Prerequisites**: [plan.md](plan.md), [spec.md](spec.md), [research.md](research.md), [data-model.md](data-model.md), [contracts/](contracts/), [quickstart.md](quickstart.md)

**Tests**: **Bắt buộc** cho logic nghiệp vụ, model, repository và rules (Constitution nguyên tắc III và V). Viết test trước, thấy test thất bại, rồi mới cài đặt.

**Organization**: Nhóm theo user story để làm và kiểm thử độc lập. Mọi đường dẫn tính từ thư mục gốc dự án; mã mới nằm trong `lib/features/recipes/`.

## Format: `[ID] [P?] [Story] Mô tả kèm đường dẫn file`

- **[P]**: có thể chạy song song (khác file, không phụ thuộc task chưa xong)
- **[Story]**: US1–US6 theo [spec.md](spec.md)
- Quy ước ghi chú: `data-model:` nghĩa là quy tắc trích nguyên văn từ [data-model.md](data-model.md)

---

## Phase 1: Setup (Hạ tầng dùng chung)

**Purpose**: Chuẩn bị phụ thuộc, cấu trúc thư mục và công cụ kiểm thử

- [x] T001 Thêm phụ thuộc vào `pubspec.yaml`: `wakelock_plus: ^1.7.0`, `flutter_local_notifications: ^22.3.3`, `timezone: ^0.11.2`, `cached_network_image: ^3.4.1`, `uuid: ^4.6.0`; dev: `fake_cloud_firestore: ^3.1.0`, `firebase_auth_mocks` (phiên bản mới nhất tương thích, kiểm tra bằng `flutter pub add --dry-run` trước); rồi chạy `flutter pub get` và `flutter analyze` (kỳ vọng không lỗi mới)
- [x] T002 [P] Tạo cấu trúc thư mục theo plan: `lib/features/recipes/{models,domain,data,providers,view/widgets}/`, `test/{unit,repository,widget}/` (mỗi thư mục trống thêm `.gitkeep`)
- [x] T003 [P] Cập nhật `.gitignore`: thêm `.claude/settings.local.json`, `android/app/google-services.json`, `ios/Runner/GoogleService-Info.plist`, `rules_test/node_modules/` (Constitution III: không commit khoá/cấu hình nhạy cảm)
- [x] T004 [P] Tạo `rules_test/package.json` (phụ thuộc `@firebase/rules-unit-testing@3`, `firebase@10`) và khung `rules_test/test.mjs` (khởi tạo test environment đọc `../firestore.rules`, hàm trợ giúp `t(name, promise)`, in tổng số đạt/trượt, thoát mã 1 nếu có lỗi)

---

## Phase 2: Foundational (Điều kiện chặn mọi user story)

**Purpose**: Model, kho dữ liệu, rules, khoá dịch và bộ nhớ đệm offline mà mọi story đều dùng

**⚠️ CRITICAL**: Không user story nào được bắt đầu khi phase này chưa xong

### Tests (viết trước, phải thất bại)

- [x] T005 [P] Viết test model trong `test/unit/models_test.dart`: `toMap`/`fromMap` hai chiều cho `Ingredient`, `RecipeStep`, `Recipe` (gồm `isPlaceholder`; thiếu trường thì mặc định `false`); kiểm tra các quy tắc hợp lệ ở T008–T010 (tên rỗng, 0 nguyên liệu, 0 bước, số âm, `durationSec` ≤ 0, `baseServings` ngoài 1–100)
- [x] T006 [P] Viết test `parseQuantity`/`formatQuantity` trong `test/unit/quantity_parser_test.dart`: "2"→2, "0,5"→0.5, "0.5"→0.5, "1/2"→0.5, "1 1/2"→1.5, "abc"→null, ""→null; `formatQuantity(2.0)`→"2", `formatQuantity(1.25)`→"1,25" (dấu thập phân theo ngôn ngữ), tối đa 2 chữ số thập phân; test đặt locale rõ ràng (`vi`/`en`) vì dấu thập phân phụ thuộc ngôn ngữ
- [x] T007 [P] Viết test rules `recipes` trong `rules_test/test.mjs` theo 8 tình huống ở [contracts/firestore-schema.md](contracts/firestore-schema.md) mục "Kiểm thử bắt buộc cho rules" (chủ sở hữu được; người khác bị từ chối đọc/sửa/xoá; tạo với `ownerId` của người khác; đổi `ownerId`; 0 nguyên liệu/0 bước/101 phần tử/tên rỗng/`baseServings` ≤ 0; truy vấn không lọc `ownerId`; chưa đăng nhập; không ghi được `users.role`). Thêm test: người dùng được ghi `users/{uid}.recipeMigratedAt` và đọc được `foods` của chính mình theo `authorId`; đọc (`get`) document `recipes` không tồn tại khi đã đăng nhập → không bị từ chối (trả về không tồn tại), còn đọc document của người khác vẫn bị từ chối

### Implementation

- [x] T008 [P] Tạo `lib/features/recipes/models/ingredient.dart`: `Ingredient {id, name, quantity?, unit?, price?, kcal?, isPlaceholder}`, `toMap`/`fromMap`/`copyWith`. data-model: `id` chuỗi uuid ổn định; `name` 1–100 ký tự; `quantity` số thực tuỳ chọn, `null` = "vừa đủ/tuỳ khẩu vị", nếu có thì ≥ 0; `unit` tuỳ chọn ≤ 20 ký tự; `price` tuỳ chọn ≥ 0 (VND); `kcal` tuỳ chọn ≥ 0, tính theo đúng lượng `quantity` của dòng đó; `isPlaceholder` boolean mặc định `false`, `true` chỉ cho dòng giữ chỗ do việc chuyển dữ liệu cũ tạo ra (giao diện hiển thị khoá `recipes.placeholder_ingredient` thay cho tên đã lưu)
- [x] T009 [P] Tạo `lib/features/recipes/models/recipe_step.dart`: `RecipeStep {id, order, text, imageUrl?, durationSec?, isPlaceholder}`. data-model: `order` số nguyên bắt đầu từ 1, liên tục, không trùng; `text` 1–1000 ký tự; `durationSec` tuỳ chọn, nếu có thì > 0 và ≤ 86400; `isPlaceholder` boolean mặc định `false` như ở `Ingredient` (hiển thị khoá `recipes.placeholder_step`)
- [x] T010 Tạo `lib/features/recipes/models/recipe.dart` (phụ thuộc T008, T009): `Recipe {id, ownerId, title, imageUrl, baseServings, ingredients, steps, tags, note, createdAt, updatedAt, legacy?, schemaVersion}` với `toMap`/`fromMap`/`copyWith` và `List<String> validate()` trả về các lỗi. data-model: `title` sau khi cắt khoảng trắng 1–120 ký tự; `baseServings` số nguyên 1–100; `ingredients` 1–100 phần tử; `steps` 1–100 phần tử; `tags` tối đa 20, mỗi thẻ 1–30 ký tự (việc loại trùng không dấu/không phân biệt hoa thường làm lúc nhập ở task tích hợp thẻ của US4, không nằm trong `validate()`); `note` ≤ 2000 ký tự; `ownerId` bất biến; `schemaVersion = 1`
- [x] T011 [P] Tạo `lib/features/recipes/domain/quantity_parser.dart` với `parseQuantity(String)` và `formatQuantity(double?)` theo T006 (hàm thuần, không phụ thuộc Flutter ngoài định dạng số)
- [x] T012 Tạo `lib/features/recipes/data/recipe_repository.dart` (phụ thuộc T010): giao diện `RecipeRepository` và cài đặt Firestore (nhận `FirebaseFirestore` và `FirebaseAuth` qua constructor để test được bằng `fake_cloud_firestore` + `firebase_auth_mocks`) theo [contracts/recipe-repository.md](contracts/recipe-repository.md): `watchMyRecipes()` (truy vấn `where('ownerId', isEqualTo: uid)`, sắp xếp `updatedAt` phía client), `watchRecipe(id)` (chuyển lỗi `permission-denied` thành `null`), `watchUserId()` (UID hiện tại, phát lại khi đăng nhập/đăng xuất), `create`, `update`, `delete`; định nghĩa `RecipeValidationException`, `RecipeNotFoundException`, `OfflineException`; `create`/`update`/`delete` không chờ xác nhận máy chủ khi offline; `createdAt`/`updatedAt` dùng `FieldValue.serverTimestamp()`
- [x] T013 [P] Viết test repository trong `test/repository/recipe_repository_test.dart` bằng `fake_cloud_firestore`: tạo/đọc/sửa/xoá, `ownerId` được đặt tự động và không đổi khi sửa, `RecipeValidationException` khi dữ liệu sai, chỉ trả công thức của người dùng hiện tại và khi đổi tài khoản không còn trả công thức của tài khoản trước (làm ngay sau T012; cần giao diện repository nên không viết trước được)
- [x] T014 [P] Thêm khối `match /recipes/{recipeId}` vào `firestore.rules` theo [contracts/firestore-schema.md](contracts/firestore-schema.md): `get` khi `resource == null || resource.data.ownerId == request.auth.uid` (để đọc document chưa tồn tại không báo lỗi quyền), `list` khi `resource.data.ownerId == request.auth.uid`; `create`/`update` kiểm tra `ownerId`, `title` không rỗng và ≤ 120, `ingredients.size()` 1–100, `steps.size()` 1–100, `baseServings` số nguyên 1–100; `update` giữ `ownerId` không đổi; `delete` chỉ chủ sở hữu; admin **không** có đặc quyền. Chạy emulator và làm T007 đạt hết
- [x] T015 [P] Thêm khoá dịch GĐ1 vào `assets/langs/vi.json` và `assets/langs/en.json` theo danh sách ở cuối [contracts/screens.md](contracts/screens.md), gồm cả `account.*`, `recipes.placeholder_*` và `recipes.original_content` (tiếng Việt là bản chính)
- [x] T016 Bật bộ nhớ đệm bền của Firestore trong `lib/main.dart`: sau `Firebase.initializeApp`, đặt `FirebaseFirestore.instance.settings = const Settings(persistenceEnabled: true, cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED)`

**Checkpoint**: Model, repository, rules, khoá dịch và cache offline sẵn sàng; T005, T006, T007, T013 đều đạt

---

## Phase 3: User Story 1 - Tạo và xem công thức có cấu trúc (Priority: P1) 🎯 MVP

**Goal**: Người dùng tạo, xem, sửa, xoá công thức với nguyên liệu và bước nấu có cấu trúc, riêng tư theo từng tài khoản.

**Independent Test**: Tạo công thức 3 nguyên liệu và 3 bước, lưu, đóng mở lại app, thấy đủ và đúng thứ tự; lưu khi thiếu tên hoặc nguyên liệu bị từ chối với thông báo rõ (kịch bản 1, 2 và 11 trong [quickstart.md](quickstart.md)).

### Tests for User Story 1

- [x] T017 [P] [US1] Viết test `RecipeEditorProvider` trong `test/unit/recipe_editor_provider_test.dart`: thêm/xoá/đổi thứ tự nguyên liệu và bước (cập nhật lại `order` liên tục từ 1), lưu thất bại và liệt kê trường lỗi khi tên trống / 0 nguyên liệu / 0 bước / `quantity` âm / `durationSec` ≤ 0, không mất dữ liệu nhập khi lưu lỗi, cờ "có thay đổi chưa lưu"
- [x] T018 [P] [US1] Viết widget test `AccountMenuScreen` trong `test/widget/account_menu_screen_test.dart`: hiện email; chọn English/Tiếng Việt đổi locale ngay; nút Đăng xuất có hộp thoại xác nhận và gọi `AccountActions.signOut()` (FR-020, FR-023)

### Implementation for User Story 1

- [x] T019 [P] [US1] Tạo `lib/features/recipes/providers/recipe_list_provider.dart`: bọc `watchMyRecipes()`, trạng thái tải/lỗi/danh sách, xoá công thức; lắng nghe `RecipeRepository.watchUserId()` để huỷ luồng và xoá danh sách khi đăng xuất/đổi tài khoản; có `runMigrationIfNeeded()` để giao diện không gọi service trực tiếp (Constitution IV)
- [x] T020 [US1] Tạo `lib/features/recipes/providers/recipe_editor_provider.dart` (làm T017 đạt): giữ bản nháp `Recipe`, thao tác thêm/xoá/đổi thứ tự, `validate()`, `save()` qua `RecipeRepository`, theo dõi thay đổi chưa lưu
- [x] T021 [P] [US1] Tạo `lib/features/recipes/view/widgets/ingredient_row.dart`: một dòng nguyên liệu {tên, số lượng, đơn vị, giá, kcal}; số lượng nhận "1/2", "0,5" qua `parseQuantity`; báo lỗi tại chỗ
- [x] T022 [P] [US1] Tạo `lib/features/recipes/view/widgets/step_editor.dart`: một dòng bước {nội dung, ảnh, thời gian tuỳ chọn phút/giây}; thời gian ≤ 0 bị từ chối
- [x] T023 [US1] Tạo `lib/features/recipes/view/recipe_editor_screen.dart` (phụ thuộc T020–T022, dưới ~300 dòng): tên, số người ăn gốc, ghi chú, danh sách nguyên liệu và bước kéo đổi thứ tự, thoát khi có thay đổi chưa lưu thì hỏi xác nhận
- [x] T024 [US1] Tạo `lib/features/recipes/data/account_actions.dart` (`signOut()` qua `AuthService.logout()` ở `lib/services/auth_service.dart`, `setLanguage(Locale)` bằng `context.setLocale`, `email`) và `lib/features/recipes/view/account_menu_screen.dart` (làm T018 đạt; dưới ~300 dòng) theo [contracts/screens.md](contracts/screens.md) mục 5 (các khoá dịch `account.*` đã có từ T015)
- [x] T025 [US1] Tạo `lib/features/recipes/view/recipe_list_screen.dart` (phụ thuộc T019 và T024): danh sách, trạng thái trống thân thiện với nút tạo công thức đầu tiên, nút thêm, xoá có xác nhận, biểu tượng mở `AccountMenuScreen` (T024)
- [x] T026 [US1] Tạo `lib/features/recipes/view/recipe_detail_screen.dart`: ảnh, tên, ghi chú, nguyên liệu (số lượng + đơn vị), các bước theo thứ tự; nút sửa/xoá; nếu công thức có `legacy` thì thêm mục thu gọn "Nội dung gốc" hiển thị nguyên văn nguyên liệu và hướng dẫn cũ (khoá `recipes.original_content`); nguyên liệu/bước có `isPlaceholder` hiển thị bằng khoá `recipes.placeholder_ingredient` / `recipes.placeholder_step` (cũng áp dụng cho `cooking_mode_screen.dart` và `recipe_editor_screen.dart`), tên món giữ chỗ bằng `recipes.placeholder_title` khi `legacy.title` rỗng
- [x] T027 [US1] Thêm `uploadImage(File, {required String recipeId})` vào `lib/features/recipes/data/recipe_repository.dart` (Firebase Storage) và nối vào `recipe_editor_screen.dart`/`step_editor.dart` bằng `image_picker`; offline ném `OfflineException`, giữ nguyên phần đang nhập
- [x] T028 [US1] Đăng ký `RecipeListProvider`/`RecipeEditorProvider` trong `MultiProvider` ở `lib/main.dart` và đổi đích sau đăng nhập trong `lib/view/auth/login_screen.dart` (mọi vai trò, kể cả admin) sang `RecipeListScreen`

**Checkpoint**: US1 chạy độc lập — đây là MVP, đã là một sổ công thức dùng được

---

## Phase 4: User Story 2 - Chế độ nấu từng bước (Priority: P1)

**Goal**: Nấu theo từng bước với chữ lớn, vuốt qua lại, màn hình luôn sáng và hẹn giờ chính xác kể cả khi chạy nền.

**Independent Test**: Công thức 4 bước (1 bước 2 phút): đi tới/lui, bật hẹn giờ, chuyển bước khác và khoá máy, hết giờ có báo (sai lệch ≤ 2 giây); để yên 5 phút màn hình không tắt (kịch bản 4–7).

### Tests for User Story 2

- [x] T029 [P] [US2] Viết test `CookingSession`/`CookingSessionStore` trong `test/unit/cooking_session_store_test.dart` (dùng `SharedPreferences.setMockInitialValues`): `save`/`load`/`clear`, khoá `cooking_session_<uid>_<recipeId>`, `timers` giữ `endAt` tuyệt đối
- [x] T030 [P] [US2] Viết test `CookingModeProvider` trong `test/unit/cooking_mode_provider_test.dart` (đồng hồ giả): `remaining = endAt - now` đúng khi "thời gian trôi qua" lúc app ở nền, tạm dừng/đặt lại huỷ thông báo, không lùi quá bước 1, bước cuối chuyển thành hoàn thành, hoàn thành xoá phiên; **thoát chế độ nấu hoặc đưa app xuống nền KHÔNG huỷ thông báo đã lên lịch** (chỉ tạm dừng/đặt lại/hoàn thành mới huỷ, theo [contracts/recipe-repository.md](contracts/recipe-repository.md)); dùng bản giả của `wakelock_plus` (`WakelockPlusPlatformInterface`) để kiểm tra bật khi vào chế độ nấu và tắt khi thoát/xuống nền (FR-010)
- [x] T031 [P] [US2] Viết widget test `test/widget/cooking_mode_screen_test.dart`: hiện "Bước X / Y", nút Trước bị vô hiệu ở bước 1, nút Tiếp thành "Hoàn thành" ở bước cuối, vuốt đổi bước, chip hẹn giờ chỉ hiện với bước có `durationSec`

### Implementation for User Story 2

- [x] T032 [P] [US2] Tạo `lib/features/recipes/models/cooking_session.dart` và `lib/features/recipes/data/cooking_session_store.dart` bằng `shared_preferences` theo [data-model.md](data-model.md) mục CookingSession (làm T029 đạt)
- [x] T033 [P] [US2] Tạo `lib/features/recipes/data/timer_notification_service.dart` bằng `flutter_local_notifications` + `timezone`: `requestPermission()`, `schedule({endAt,title,body})` trả `notificationId`, `cancel(id)`, `cancelAll()` (dùng khi đăng xuất); nếu thiếu quyền báo thức chính xác thì dùng lịch gần đúng (research R5); lên lịch bằng `tz.TZDateTime.from(endAt, tz.UTC)` (thời điểm tuyệt đối, không cần gói múi giờ thiết bị)
- [x] T034 [P] [US2] Cấu hình Android trong `android/app/src/main/AndroidManifest.xml`: quyền `POST_NOTIFICATIONS`, `SCHEDULE_EXACT_ALARM` (hoặc `USE_EXACT_ALARM`), `VIBRATE`, `WAKE_LOCK`, receiver của `flutter_local_notifications`; kiểm tra `android/app/build.gradle.kts` đủ `minSdk` và bật core library desugaring nếu gói yêu cầu
- [x] T035 [P] [US2] Cấu hình iOS trong `ios/Runner/AppDelegate.swift` và `ios/Runner/Info.plist`: đặt delegate thông báo, giải thích xin quyền thông báo
- [x] T036 [US2] Tạo `lib/features/recipes/providers/cooking_mode_provider.dart` (phụ thuộc T032, T033; làm T030 đạt): chỉ số bước, điều hướng, hẹn giờ theo `endAt` (`Timer.periodic` mỗi giây chỉ để cập nhật giao diện), đặt thông báo (chỉ huỷ khi tạm dừng/đặt lại/hoàn thành; **không** huỷ khi thoát hoặc xuống nền), lưu phiên mỗi lần đổi, bật `WakelockPlus.enable()` khi vào và `disable()` khi thoát hoặc app vào nền (`WidgetsBindingObserver`), khôi phục hẹn giờ đang chạy khi quay lại
- [x] T037 [P] [US2] Tạo `lib/features/recipes/view/widgets/step_timer_chip.dart`: Bắt đầu/Tạm dừng/Đặt lại, hiển thị đếm ngược, trạng thái "hết giờ"
- [x] T038 [US2] Tạo `lib/features/recipes/view/cooking_mode_screen.dart` (phụ thuộc T036, T037; làm T031 đạt; dưới ~300 dòng): `PageView` vuốt qua lại, chữ lớn (≥ 24 sp, theo cỡ chữ hệ thống), "Bước X / Y" và thanh tiến độ, nút Trước/Tiếp/Hoàn thành, danh sách mọi hẹn giờ đang chạy, ngăn kéo nguyên liệu, hộp thoại "Tiếp tục từ bước N / Bắt đầu lại" khi có phiên dở
- [x] T039 [US2] Nối nút "Bắt đầu nấu" trong `lib/features/recipes/view/recipe_detail_screen.dart` mở `CookingModeScreen` (tối đa 2 chạm từ danh sách, SC-002) và xin quyền thông báo lần đầu cần dùng hẹn giờ; khi từ chối vẫn báo trong app; nối `TimerNotificationService.cancelAll()` vào `AccountActions.signOut()` (`lib/features/recipes/data/account_actions.dart`, T024)

**Checkpoint**: US1 và US2 cùng chạy độc lập; thử hẹn giờ nền trên thiết bị/giả lập thật

---

## Phase 5: User Story 3 - Đổi khẩu phần (Priority: P2)

**Goal**: Đổi số người ăn thì số lượng nguyên liệu quy đổi tức thì, cả khi xem và khi nấu.

**Independent Test**: Công thức 2 người có 200 g thịt: đổi 5 người → 500 g; đổi 1 người → 100 g; "muối vừa đủ" không đổi; công thức gốc không bị sửa (kịch bản 3).

### Tests for User Story 3

- [x] T040 [P] [US3] Viết test `scaleQuantity` trong `test/unit/serving_scaler_test.dart`: 200 g (2→5 người)=500, (2→1)=100, `null` giữ `null`, `target ≤ 0` hoặc `base ≤ 0` ném lỗi tham số, làm tròn tối đa 2 chữ số thập phân (ví dụ 1 quả 3→2 người = 0,67)
- [x] T041 [P] [US3] Viết widget test `ServingsStepper` trong `test/widget/servings_stepper_test.dart`: tăng/giảm, nhập số 0 hoặc âm bị từ chối và giữ giá trị cũ, giới hạn 1–100

### Implementation for User Story 3

- [x] T042 [P] [US3] Tạo `lib/features/recipes/domain/serving_scaler.dart` với `scaleQuantity(q, baseServings, targetServings)` (làm T040 đạt)
- [x] T043 [P] [US3] Tạo `lib/features/recipes/view/widgets/servings_stepper.dart` (nút −/+ và ô nhập số; làm T041 đạt)
- [x] T044 [US3] Tích hợp bộ chỉnh khẩu phần vào `lib/features/recipes/view/recipe_detail_screen.dart` (quy đổi chỉ để xem, không ghi vào công thức) và vào ngăn kéo nguyên liệu của `lib/features/recipes/view/cooking_mode_screen.dart`; lưu `servings` vào `CookingSession` ở `lib/features/recipes/providers/cooking_mode_provider.dart`; hiển thị số lượng bằng `formatQuantity`

**Checkpoint**: US1, US2, US3 hoạt động độc lập

---

## Phase 6: User Story 4 - Gắn thẻ, tìm và lọc (Priority: P2)

**Goal**: Gắn nhiều thẻ, tìm theo tên món hoặc nguyên liệu không phân biệt dấu tiếng Việt, và lọc theo thẻ.

**Independent Test**: 10 công thức, 3 cái gắn "món sinh viên": lọc theo thẻ còn đúng 3; tìm "ga" ra các món chứa "gà"; kết hợp từ khoá và thẻ chỉ giữ món thoả cả hai (kịch bản 8).

### Tests for User Story 4

- [x] T045 [P] [US4] Viết test `normalizeForSearch` trong `test/unit/text_normalizer_test.dart`: chữ thường, bỏ dấu tiếng Việt, `đ→d`, gộp khoảng trắng, chuỗi rỗng, ký tự đặc biệt không gây lỗi
- [x] T046 [P] [US4] Viết test `filterRecipes` trong `test/unit/recipe_filter_test.dart`: khớp theo tên món, tên nguyên liệu, thẻ; kết hợp từ khoá + nhiều thẻ (phải có đủ các thẻ); không có kết quả; chuỗi rỗng trả toàn bộ; hiệu năng < 1 giây với 200 công thức (SC-006)

### Implementation for User Story 4

- [x] T047 [P] [US4] Tạo `lib/features/recipes/domain/text_normalizer.dart` với `normalizeForSearch(String)` (làm T045 đạt; thay cho hàm cục bộ trong `lib/view/home/blogger_home_screen.dart`)
- [x] T048 [US4] Tạo `lib/features/recipes/domain/recipe_filter.dart` với `filterRecipes(list, query, tags)` (phụ thuộc T047; làm T046 đạt) và hàm `collectTags(list)` đếm số công thức theo thẻ
- [x] T049 [P] [US4] Tạo `lib/features/recipes/view/widgets/tag_filter_bar.dart` (chọn nhiều thẻ, hiển thị số lượng)
- [x] T050 [US4] Tích hợp vào `lib/features/recipes/view/recipe_list_screen.dart`: ô tìm kiếm, `TagFilterBar`, trạng thái "không có kết quả" kèm nút xoá bộ lọc; thêm nhập/gợi ý thẻ vào `lib/features/recipes/view/recipe_editor_screen.dart` (tối đa 20 thẻ, mỗi thẻ 1–30 ký tự, loại trùng bằng `normalizeForSearch` từ US4: so khớp không dấu, không phân biệt hoa thường)

**Checkpoint**: US1–US4 hoạt động độc lập

---

## Phase 7: User Story 5 - Chuyển dữ liệu công thức cũ (Priority: P2)

**Goal**: Công thức từ bản cũ được chuyển sang dạng có cấu trúc, không mất dữ liệu, chạy lại an toàn.

**Independent Test**: Món cũ có "200g thịt bò", "2 quả trứng", "muối", hướng dẫn nhiều dòng: nguyên liệu tách đúng khi nhận diện được, dòng không nhận diện giữ nguyên văn, hướng dẫn thành các bước, chạy lại không tạo bản sao, `foods` gốc còn nguyên (kịch bản 9).

### Tests for User Story 5

- [x] T051 [P] [US5] Viết test `parseLegacyIngredient` và `splitLegacyInstructions` trong `test/unit/legacy_converter_test.dart`: "200g thịt bò"→{200,"g","thịt bò"}; "2 quả trứng"→{2,"quả","trứng"}; "1/2 củ hành"; "muối vừa đủ"→{null,null,"muối vừa đủ"}; dòng rỗng bị bỏ; hướng dẫn "1. ... 2. ..."/"Bước 1:" tách đúng và bỏ tiền tố; một dòng dài tách theo câu; không trả rỗng nếu có chữ; kèm bộ dữ liệu mẫu ≥ 20 dòng nguyên liệu cũ trong `test/unit/fixtures/legacy_ingredients.json` (số + đơn vị + tên, phân số, hỗn số, dấu phẩy thập phân, dòng tự do) và khẳng định ≥ 90% dòng dạng "số + đơn vị + tên" được tách đúng (SC-007)
- [x] T052 [P] [US5] Viết test `LegacyMigrationService` trong `test/repository/legacy_migration_service_test.dart` (fake Firestore): ghi `recipes/{foodId}` với `legacy` giữ nguyên văn; chạy lần 2 không tạo bản sao; `foods` không bị sửa/xoá; lỗi giữa chừng thì chưa đặt `recipeMigratedAt`; tài khoản không có dữ liệu cũ thì chỉ đặt cờ; chỉ chuyển món có `authorId == uid`; món cũ không có nguyên liệu → đúng 1 dòng nguyên liệu giữ chỗ; hướng dẫn trống → đúng 1 bước giữ chỗ; các dòng/bước giữ chỗ có `isPlaceholder == true`, dòng/bước thường là `false`; bản chuyển giữ `createdAt` của món cũ; tên rỗng hoặc dài hơn 120 ký tự → tên được bù/cắt cho hợp lệ và tên gốc nằm ở `legacy.title`; mọi bản chuyển đều qua `Recipe.validate()` không lỗi (FR-022)

### Implementation for User Story 5

- [x] T053 [P] [US5] Tạo `lib/features/recipes/domain/legacy_converter.dart` với `parseLegacyIngredient` và `splitLegacyInstructions` theo [research.md](research.md) R2 (làm T051 đạt; dùng lại `parseQuantity` ở T011) và hàm bù theo mục "Quy tắc bù khi chuyển dữ liệu cũ" trong [data-model.md](data-model.md), đặt `isPlaceholder = true` cho mọi dòng/bước giữ chỗ
- [x] T054 [US5] Tạo `lib/features/recipes/data/legacy_migration_service.dart` (phụ thuộc T012, T053; làm T052 đạt): `migrateIfNeeded()` đọc `foods` có `authorId == uid`, `set` vào `recipes/{foodId}` (ID xác định), điền `legacy {ingredients, instructions, sourceCollection: "foods", migratedAt}`, `ownerId = uid`, `createdAt` giữ nguyên của món cũ (thiếu thì dùng thời điểm chuyển), `updatedAt = serverTimestamp`, `baseServings` suy ra từ `servings` cũ (mặc định 2 nếu không đọc được), ảnh/thẻ/ghi chú giữ nguyên (thẻ giới hạn 20 thẻ, mỗi thẻ ≤ 30 ký tự); áp dụng quy tắc bù (dòng/bước giữ chỗ đặt `isPlaceholder = true`) để mọi bản chuyển hợp lệ với rules; luôn ghi `legacy.title`; xong tất cả mới đặt `users/{uid}.recipeMigratedAt`; trả `MigrationResult {migrated, unparsedIngredientLines}`
- [x] T055 [US5] Gọi `RecipeListProvider.runMigrationIfNeeded()` (bọc `migrateIfNeeded()`) khi `RecipeListScreen` mở lần đầu trong `lib/features/recipes/view/recipe_list_screen.dart` và hiện thông báo kết quả bằng khoá `recipes.migrated_summary`; lỗi mạng thì để lần sau thử lại, không chặn người dùng

**Checkpoint**: US1–US5 hoạt động độc lập; công thức cũ xuất hiện trong danh sách mới

---

## Phase 8: User Story 6 - Dùng khi mất mạng (Priority: P3)

**Goal**: Xem công thức đã tải và dùng chế độ nấu đầy đủ khi không có mạng; chỉnh sửa được đồng bộ khi có mạng lại.

**Independent Test**: Mở danh sách khi có mạng, tắt mạng, mở công thức và nấu hết các bước; sửa khi offline rồi bật mạng, thay đổi được đồng bộ (kịch bản 10).

### Implementation for User Story 6

- [x] T056 [P] [US6] Thay `Image.network` bằng `CachedNetworkImage` (có placeholder và biểu tượng lỗi) trong `lib/features/recipes/view/recipe_list_screen.dart`, `lib/features/recipes/view/recipe_detail_screen.dart`, `lib/features/recipes/view/widgets/step_editor.dart`, `lib/features/recipes/view/cooking_mode_screen.dart`
- [x] T057 [US6] Dùng `snapshots(includeMetadataChanges: true)` trong `lib/features/recipes/data/recipe_repository.dart` để lộ `hasPendingWrites`; thêm trường `isSyncing` vào mô hình hiển thị và biểu tượng/nhãn `recipes.syncing` ở `lib/features/recipes/view/recipe_list_screen.dart`
- [x] T058 [US6] Rà soát hành vi offline: `create`/`update`/`delete` không treo giao diện chờ máy chủ; `OfflineException` khi tải ảnh được bắt và hiện thông báo `recipes.err_offline_image` mà không mất dữ liệu đang nhập (`lib/features/recipes/providers/recipe_editor_provider.dart`, `lib/features/recipes/view/recipe_editor_screen.dart`); hẹn giờ và quy đổi khẩu phần không phụ thuộc mạng
- [ ] T059 [US6] Kiểm thử thủ công kịch bản 10 trong [quickstart.md](quickstart.md) bằng chế độ máy bay trên thiết bị/giả lập và ghi kết quả vào mục "Ghi chú" ở cuối file này

**Checkpoint**: Cả 6 user story hoạt động độc lập

---

## Phase 9: Polish & Cross-Cutting Concerns

**Purpose**: Hoàn thiện, dọn mã cũ và nghiệm thu

- [x] T060 Gỡ các màn hình mạng xã hội cũ khỏi điều hướng (cộng đồng, theo dõi, bình luận, đánh giá, khám phá, quản trị) bằng cách bỏ mọi liên kết tới `lib/view/community/`, `lib/view/discover_screen.dart`, `lib/view/widgets/blogger_navigator_screen.dart`, `lib/view/profile/follow_list_screen.dart`, `lib/view/admin/`; **chưa xoá file** cho tới khi `flutter analyze` sạch và người dùng đồng ý (Constitution VII); chỉ sau khi xoá hẳn mã cũ mới gỡ `video_player` và `fl_chart` khỏi `pubspec.yaml`
- [x] T061 [P] Rà soát chuỗi cứng: mọi văn bản hiển thị trong `lib/features/recipes/` phải qua `.tr()`; bổ sung khoá còn thiếu vào `assets/langs/vi.json` và `assets/langs/en.json`
- [x] T062 [P] Kiểm tra kích thước: mỗi file màn hình trong `lib/features/recipes/view/` dưới ~300 dòng; tách thêm widget vào `lib/features/recipes/view/widgets/` nếu vượt (Constitution IV); xác nhận không file nào trong `lib/features/recipes/` import `cloud_firestore`/`firebase_auth` ngoài thư mục `data/`
- [x] T063 Chạy `flutter analyze` (không lỗi) và `flutter test` (đạt hết) từ thư mục gốc; sửa mọi vấn đề
- [x] T064 Chạy kiểm thử rules trên emulator (JDK 21): `firebase emulators:exec --only firestore --project demo-rules "node rules_test/test.mjs"`; mọi tình huống phải đạt trước khi deploy
- [x] T065 Deploy rules: `firebase deploy --only firestore:rules --project my-food-app-b8f2d` — **chỉ sau khi T064 đạt và người dùng xác nhận**
- [ ] T066 Chạy toàn bộ 12 kịch bản trong [quickstart.md](quickstart.md) và xác nhận SC-001 đến SC-009 ở [spec.md](spec.md) (đo thủ công SC-001, SC-002, SC-004, SC-005 trên thiết bị thật); thử công thức 50 nguyên liệu + 50 bước cuộn mượt; thử đăng xuất rồi đăng nhập tài khoản khác không thấy công thức/hẹn giờ của người trước
- [x] T067 [P] Cập nhật `README.md`: giới thiệu KitchenLoop, nguồn tham khảo ý tưởng (KitchenOwl, Mealie, bài của bạn cùng lớp đã được đồng ý), ghi rõ có dùng công cụ AI hỗ trợ (Constitution, mục Quy trình phát triển)
- [x] T068 [P] Dọn `.specify/memory/constitution.md`: xoá khối chú thích "Sync Impact Report" ở đầu file; chạy kiểm tra `git log` theo `GIT_PUSH_NOTES.md` để chắc commit không có dòng `Co-Authored-By` nhắc tới Claude/Anthropic trước khi push

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: bắt đầu ngay
- **Foundational (Phase 2)**: phụ thuộc Phase 1; **chặn mọi user story**
- **US1 (Phase 3)**: phụ thuộc Phase 2; MVP
- **US2 (Phase 4)**: phụ thuộc Phase 2; cần `RecipeDetailScreen` (T026) ở T039, nên làm sau US1
- **US3 (Phase 5)**: phụ thuộc Phase 2 để làm hàm thuần; T044 cần màn hình chi tiết (T026) và chế độ nấu (T038)
- **US4 (Phase 6)**: hàm thuần chỉ cần Phase 2; T050 cần `RecipeListScreen` (T025) và editor (T023)
- **US5 (Phase 7)**: phụ thuộc T011, T012; T055 cần `RecipeListScreen` (T025)
- **US6 (Phase 8)**: phụ thuộc US1 và US2 (đã có màn hình để rà soát)
- **Polish (Phase 9)**: sau khi các story mong muốn đã xong

### User Story Dependencies

- **US1 (P1)**: không phụ thuộc story khác
- **US2 (P1)**: nối vào màn hình chi tiết của US1 nhưng logic hẹn giờ/phiên nấu kiểm thử độc lập
- **US3 (P2)**: hàm quy đổi độc lập; giao diện nối vào US1/US2
- **US4 (P2)**: logic lọc độc lập; giao diện nối vào US1
- **US5 (P2)**: bộ chuyển đổi độc lập; giao diện thông báo nối vào US1
- **US6 (P3)**: rà soát lại US1 và US2

### Within Each User Story

- Test trước, phải thất bại, rồi mới cài đặt
- Model → hàm thuần/service → provider → widget → màn hình → nối điều hướng
- Hoàn thành story rồi mới chuyển sang story ưu tiên thấp hơn (Constitution II không ảnh hưởng vì mọi story đều thuộc GĐ1)

### Parallel Opportunities

- Setup: T002, T003, T004 chạy song song
- Foundational: T005, T006, T007 (test) song song; T008, T009, T011, T014, T015 song song (khác file)
- Sau Phase 2: các hàm thuần của US3 (T042), US4 (T047, T048), US5 (T053) có thể làm song song với US1 vì không chạm file giao diện
- Trong một story: các test `[P]` chạy cùng lúc; các widget `[P]` làm cùng lúc

---

## Parallel Example: Phase 2 và User Story 1

```bash
# Phase 2: viết test trước (song song)
Task: "T005 test model trong test/unit/models_test.dart"
Task: "T006 test parseQuantity trong test/unit/quantity_parser_test.dart"
Task: "T007 test rules recipes trong rules_test/test.mjs"

# Phase 2: các model và rules (song song)
Task: "T008 Ingredient trong lib/features/recipes/models/ingredient.dart"
Task: "T009 RecipeStep trong lib/features/recipes/models/recipe_step.dart"
Task: "T014 rules recipes trong firestore.rules"

# User Story 1: widget song song
Task: "T021 ingredient_row.dart"
Task: "T022 step_editor.dart"
```

---

## Implementation Strategy

### MVP First (US1)

1. Phase 1 → Phase 2 (kiểm tra checkpoint)
2. Phase 3 (US1) → **dừng và kiểm chứng** theo kịch bản 1, 2, 11
3. Có thể demo ngay: sổ công thức riêng tư có cấu trúc

### Incremental Delivery

1. Setup + Foundational → nền sẵn sàng
2. US1 → MVP
3. US2 → thêm chế độ nấu (điểm khác biệt chính); thử trên thiết bị thật vì có hẹn giờ nền
4. US3 và US4 → tiện dụng
5. US5 → giữ dữ liệu cũ (nên làm trước khi cho người dùng cũ dùng bản mới)
6. US6 → rà soát offline
7. Polish → dọn mã cũ, nghiệm thu, deploy rules

### Gợi ý phạm vi tối thiểu để nộp bài

Phase 1 + 2 + US1 + US2 (T001–T039) đã là app hoàn chỉnh với chế độ nấu; US3–US6 bổ sung dần.

---

## Notes

- `[P]` = khác file, không phụ thuộc task chưa xong
- Mỗi task nên commit riêng (commit **không** có dòng `Co-Authored-By` nhắc tới Claude/Anthropic; xem `CLAUDE.md`) — chỉ commit khi chủ dự án yêu cầu
- Dừng ở mỗi checkpoint để kiểm chứng story
- Rủi ro cần theo dõi: quyền báo thức chính xác trên Android 12+ (T033, T034) và thông báo trên iOS (T035) chỉ kiểm chứng được trên thiết bị/giả lập thật
- Admin không còn đọc được công thức riêng tư ở GĐ1 (xem [contracts/firestore-schema.md](contracts/firestore-schema.md)); các màn hình quản trị cũ bị gỡ khỏi điều hướng ở T060
- Ghi chú T060 (gỡ mã cũ): **đã xong.** Từ `lib/main.dart` không còn đường import nào tới mã cộng đồng, khám phá, quản trị, hồ sơ, món ăn cũ (test chốt chặn `test/unit/legacy_isolation_test.dart`). Đã sửa liên kết còn sót: sau **đăng ký** trước đây vào `BloggerHomeScreen`, nay vào `RecipeListScreen`; đã bỏ các provider quản trị/khám phá khỏi `main.dart`. Sau khi người dùng đồng ý (2026-11-12): **đã xoá 43 file Dart (~10.500 dòng)** không còn được dùng, dọn thư mục rỗng và gỡ `video_player`, `fl_chart` khỏi `pubspec.yaml`. Giữ lại 6 file phục vụ đăng nhập/đăng ký (`UserModel`, `UserProvider`, `AuthService`, 3 màn hình `view/auth/`). **Bản sao lưu** nằm ngoài dự án: `../sao_luu_ma_cu_20261112/` (43 file đã đối chiếu mã băm SHA-256, kèm `pubspec.yaml`/`pubspec.lock` cũ, `MUC_LUC.txt` và `DOC_TOI_TRUOC.txt`). Sau khi xoá: `flutter analyze` toàn dự án không còn vấn đề nào (trước đó 59 gợi ý, đều ở mã cũ).
- Ghi chú T065 (deploy rules): `firestore.rules` không đổi kể từ lần deploy gần nhất (đã được người dùng xác nhận); kiểm thử emulator 60/60 đạt, nên không cần deploy lại. Chỉ deploy lại khi sửa rules.
- Ghi chú T068: đã xoá khối "Sync Impact Report" khỏi constitution. Thư mục này **chưa phải git repo** nên chưa chạy được `git log`; khi `git init`, chạy kiểm tra trong `GIT_PUSH_NOTES.md` trước khi push. Đã quét toàn bộ mã nguồn: không có chuỗi `Co-Authored-By` nào.
- Ghi chú T066 (nghiệm thu) — **chưa hoàn thành**: cần thử trên thiết bị thật. Bằng chứng hiện có cho từng tiêu chí ở [spec.md](spec.md):

  | Tiêu chí | Bằng chứng tự động | Còn phải thử trên máy thật |
  |---|---|---|
  | SC-001 tạo công thức < 3 phút | luồng tạo công thức đầy đủ có test | bấm giờ người dùng thật |
  | SC-002 ≤ 2 chạm vào chế độ nấu | `recipe_flow_test.dart` (chọn món, bấm "Bắt đầu nấu") | — |
  | SC-003 đổi khẩu phần tức thì, chính xác | `serving_scaler_test.dart`, phép tính đồng bộ không chờ mạng | — |
  | SC-004 màn hình không tắt 30 phút | bật/tắt wakelock đúng lúc (bản giả) | để yên 30 phút ở chế độ nấu |
  | SC-005 hẹn giờ sai lệch ≤ 2 giây, kể cả nền | `endAt` tuyệt đối, thoát/xuống nền không huỷ thông báo | đo độ chính xác thông báo thật (Android 12+/iOS) |
  | SC-006 tìm < 1 giây với 200 công thức | `recipe_filter_test.dart` (đo thời gian) | — |
  | SC-007 chuyển 100% không mất, ≥ 90% tách đúng | 50/50 dòng mẫu, `legacy_migration_service_test.dart` | thử với dữ liệu Firebase thật |
  | SC-008 offline xem và nấu | không import mạng, cache bền bật, `settleWrite` | chế độ máy bay (T059) |
  | SC-009 không xem/sửa được công thức người khác | rules 60/60 và test theo từng tài khoản | — |

  Công thức 50 nguyên liệu + 50 bước: render, cuộn, đổi khẩu phần, mở màn hình sửa và đi hết 50 bước chế độ nấu đều chạy không lỗi trong test; độ mượt (khung hình) thì chỉ đo được trên máy thật. Đăng xuất rồi đăng nhập tài khoản khác không thấy dữ liệu người trước: có test ở cấp repository/provider; hẹn giờ của người trước được huỷ qua `AccountActions.signOut` (test), cần thử lại trên máy thật.
- Ghi chú kiểm thử offline (T059): **chưa kiểm thử thủ công** — cần chạy trên thiết bị hoặc giả lập thật bằng chế độ máy bay (môi trường phát triển hiện tại không làm được). Phần đã được kiểm chứng tự động: `settleWrite` không treo khi lần ghi không hoàn tất (`test/repository/settle_write_test.dart`), nhãn đang đồng bộ (`test/widget/recipe_card_test.dart`), ảnh có cache và khung lỗi (`test/widget/recipe_image_test.dart`), tải ảnh lỗi offline giữ nguyên dữ liệu đang nhập (`test/unit/recipe_editor_provider_test.dart`), và hẹn giờ/quy đổi khẩu phần/chế độ nấu không import thư viện mạng (`test/unit/offline_independence_test.dart`). Checklist thử tay (ghi kết quả vào đây sau khi làm):
  1. Có mạng: mở danh sách, mở ít nhất một công thức có ảnh, vào chế độ nấu một lần → ☐ ảnh và dữ liệu được tải.
  2. Bật chế độ máy bay → ☐ danh sách vẫn hiện đủ công thức; ☐ mở công thức đã xem vẫn thấy nội dung và ảnh đã tải; ☐ chế độ nấu chạy hết các bước; ☐ hẹn giờ chạy và báo hết giờ (kể cả khi khoá máy); ☐ đổi khẩu phần quy đổi đúng.
  3. Vẫn ở chế độ máy bay: ☐ sửa một công thức rồi lưu → thoát màn hình trong vòng ~2 giây, thẻ công thức hiện nhãn "Đang đồng bộ"; ☐ tạo công thức mới → xuất hiện trong danh sách kèm nhãn "Đang đồng bộ"; ☐ thêm ảnh → báo "Cần có mạng để tải ảnh lên" và các phần đã nhập còn nguyên.
  4. Tắt chế độ máy bay → ☐ nhãn "Đang đồng bộ" biến mất; ☐ thay đổi xuất hiện đúng trên Firestore (không mất, không nhân đôi).
  5. Đăng nhập tài khoản có món cũ khi đang offline → ☐ không bị đánh dấu "đã chuyển" nhầm; bật mạng rồi mở lại app → ☐ món cũ được chuyển.
  Kết quả: *(chưa kiểm thử)*
