# Implementation Plan: Tab Tài khoản và hồ sơ cá nhân

**Branch**: `005-account-tab` | **Date**: 2026-11-14 | **Spec**: [spec.md](spec.md)

## Summary

Feature `lib/features/account/`: `ProfileRepository` (hồ sơ `users/{uid}`, ảnh ở Storage, email đặt
lại mật khẩu), `ProfileProvider`, `ThemeModeProvider` (lưu trên máy), màn `AccountScreen` (thay
`AccountMenuScreen`), `UserAvatar` dùng chung (tab Tài khoản, trang chủ). `PlanScreen` gộp
`MealPlanScreen` + `ShoppingListScreen` (chế độ nhúng). `AppShell` còn 5 tab.

## Constitution Check (v1.2.0)

| Nguyên tắc | Đáp ứng |
|---|---|
| III Bảo mật | Storage chỉ chủ tài khoản ghi `avatars/{uid}`; `avatarUrl` chỉ nhận link Storage; test emulator. |
| IV Tách lớp | Firebase chỉ trong `account/data/`; màn hình < 300 dòng. |
| V Kiểm thử | Repository test (fake Firestore), provider test, widget test, rules test. |
| VI Đa ngôn ngữ | Khoá `account.*`, `plan.*`. |
| VII Đơn giản | Không thêm mạng xã hội; ảnh chỉ dùng trong app của chính mình. |
