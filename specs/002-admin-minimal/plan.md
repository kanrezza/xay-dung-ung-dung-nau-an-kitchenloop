# Implementation Plan: Quản trị tối thiểu

**Branch**: `002-admin-minimal` | **Date**: 2026-11-14 | **Spec**: [spec.md](spec.md)

## Summary

Thêm feature `lib/features/admin/` (model, domain thống kê, repository, màn hình), quyền admin
qua custom claim, rules mới cho `users` và kiểm tra khoá trong `recipes`, script Node
`tool/admin_tool/` (firebase-admin) để cấp/thu quyền và tạo dữ liệu demo.

## Technical Context

- Flutter 3.41, Firebase Auth/Firestore; Provider; easy_localization.
- Kiểm thử: fake_cloud_firestore, widget test, rules test trên emulator (custom claim qua
  `authenticatedContext(uid, { admin: true })`).

## Constitution Check (v1.1.0)

| Nguyên tắc | Đáp ứng |
|---|---|
| III Bảo mật | Quyền admin chỉ qua custom claim; admin không đọc `recipes`; khoá service account bị `.gitignore`. |
| IV Tách lớp | Chỉ `features/admin/data/` import Firebase; màn hình < 300 dòng. |
| V Kiểm thử | Unit test thống kê, model; repository test; widget test; rules test. |
| VI Đa ngôn ngữ | Khoá `admin.*` ở vi và en. |
| VII Đơn giản | Chỉ thống kê và khoá/mở; không xoá, không sửa hồ sơ người khác. |

## Thiết kế

- **Rules**: `isAdmin()` = `request.auth.token.admin == true`. `users`: get nếu chủ hoặc admin;
  list chỉ admin; admin update chỉ `isLocked`/`lockedAt`, không phải hồ sơ của mình.
  `recipes`: thêm `notLocked()` (đọc `users/{uid}.isLocked`).
- **App**: `AdminRepository` (`isCurrentUserAdmin`, `watchUsers`, `setLocked`);
  `computeAdminStats` thuần; `AdminScreen` (thẻ thống kê + danh sách + tìm kiếm + khoá/mở có
  xác nhận); mục "Quản trị" trong `AccountMenuScreen` khi là admin; `main.dart` đăng xuất tài
  khoản bị khoá khi khôi phục phiên.
- **Script**: `node tool/admin_tool/index.mjs grant|revoke|list|seed-demo <email>`.
