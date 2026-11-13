# Tasks: Thực đơn tuần, đi chợ và giao diện mới

**Input**: [spec.md](spec.md), [plan.md](plan.md)

## Phase 1: Nền tảng

- [x] T001 [P] Model `WeekPlan`, `MealEntry`, `ShoppingState` + test toMap/fromMap trong lib/features/planner/models/
- [x] T002 [P] Hàm tuần (thứ 2 của tuần, id tuần) + test trong lib/features/planner/domain/week.dart
- [x] T003 [P] Gộp nguyên liệu, quy đổi g/kg, ml/lít, làm tròn lên đơn vị đếm + test trong lib/features/planner/domain/shopping_builder.dart
- [x] T004 Rules `weekPlans`, `shoppingLists` + rules test trong firestore.rules, rules_test/test.mjs
- [x] T005 `PlannerRepository` + test trong lib/features/planner/data/planner_repository.dart

## Phase 2: User Story 1 - Giao diện mới (P1)

- [x] T006 [US1] Theme sáng/tối trong lib/app_theme.dart
- [x] T007 [US1] `RecipeCover` (ảnh minh hoạ theo từ khoá) + test trong lib/features/home/view/widgets/recipe_cover.dart
- [x] T008 [US1] Thẻ công thức dạng lưới trong lib/features/recipes/view/widgets/recipe_card.dart, recipe_list_screen.dart
- [x] T009 [US1] Chi tiết có ảnh bìa lớn, thông tin nhanh, nút thêm vào thực đơn trong lib/features/recipes/view/recipe_detail_screen.dart
- [x] T010 [US1] `AppShell` 4 tab, trang chủ trong lib/features/home/view/
- [x] T011 [US1] Phiên nấu dở cho trang chủ trong lib/features/recipes/data/cooking_session_store.dart

## Phase 3: User Story 2 - Thực đơn tuần (P1)

- [x] T012 [US2] `MealPlanProvider` + test trong lib/features/planner/providers/
- [x] T013 [US2] Màn Thực đơn tuần, chọn món, chọn bữa trong lib/features/planner/view/

## Phase 4: User Story 3 - Đi chợ (P1)

- [x] T014 [US3] `ShoppingProvider` + test trong lib/features/planner/providers/
- [x] T015 [US3] Màn Đi chợ (nhóm, tick, món lẻ, ẩn đã mua) trong lib/features/planner/view/

## Phase 5: Hoàn thiện

- [x] T016 Khoá dịch vi/en; mở rộng rà soát đa ngôn ngữ, tách lớp, mã chết
- [x] T017 Ảnh giao diện mới trong screenshots/; README
- [x] T018 Deploy rules (2026-11-14); nghiệm thu trên máy ảo Android: thêm món từ chi tiết, danh sách đi chợ, tick đã mua
