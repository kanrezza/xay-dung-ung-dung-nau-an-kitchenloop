# Tasks: Quản trị tối thiểu

**Input**: [spec.md](spec.md), [plan.md](plan.md)

## Phase 1: Nền tảng

- [x] T001 Sửa constitution lên 1.1.0 (quyền admin qua custom claim, phạm vi quản trị) trong .specify/memory/constitution.md
- [x] T002 Rules: `isAdmin()`, `users` cho admin, `notLocked()` cho `recipes` trong firestore.rules
- [x] T003 Rules test cho admin, người thường, tài khoản bị khoá trong rules_test/test.mjs

## Phase 2: User Story 1 - Thống kê và danh sách (P1)

- [x] T004 [P] [US1] Model `AdminUser` (fromMap chịu được hồ sơ cũ) trong lib/features/admin/models/admin_user.dart
- [x] T005 [P] [US1] `computeAdminStats` + unit test trong lib/features/admin/domain/admin_stats.dart
- [x] T006 [US1] `AdminRepository` + test với fake_cloud_firestore trong lib/features/admin/data/admin_repository.dart
- [x] T007 [US1] `AdminScreen` (thẻ thống kê, tìm kiếm, danh sách) trong lib/features/admin/view/admin_screen.dart
- [x] T008 [US1] Mục "Quản trị" trong lib/features/recipes/view/account_menu_screen.dart khi là admin

## Phase 3: User Story 2 - Khoá/mở khoá (P1)

- [x] T009 [US2] Nút khoá/mở có xác nhận, ẩn ở dòng của chính mình trong lib/features/admin/view/admin_screen.dart
- [x] T010 [US2] Đăng xuất tài khoản bị khoá khi khôi phục phiên trong lib/main.dart và lib/services/auth_service.dart
- [x] T011 [US2] Widget test màn hình quản trị trong test/widget/admin_screen_test.dart

## Phase 4: Công cụ và hoàn thiện

- [x] T012 Script cấp/thu quyền, tạo dữ liệu demo trong tool/admin_tool/index.mjs
- [x] T013 Khoá dịch `admin.*` (vi, en); mở rộng rà soát đa ngôn ngữ và tách lớp sang lib/features/admin
- [x] T014 Deploy rules lên Firebase (đã deploy 2026-11-14)
- [ ] T015 Nghiệm thu trên máy ảo: tài khoản demo thường + tài khoản admin
