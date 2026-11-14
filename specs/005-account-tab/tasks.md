# Tasks: Tab Tài khoản và hồ sơ cá nhân

**Input**: [spec.md](spec.md), [plan.md](plan.md)

- [x] T001 Rules: Storage `avatars/{uid}`, Firestore `users.name`/`avatarUrl` + test emulator
- [x] T002 [P] `ProfileRepository` (hồ sơ, ảnh, đặt lại mật khẩu) + test trong lib/features/account/data/
- [x] T003 [P] `ProfileProvider`, `ThemeModeProvider` + test trong lib/features/account/providers/
- [x] T004 [US1] `UserAvatar`, hồ sơ, đổi ảnh, đổi tên trong lib/features/account/view/
- [x] T005 [US2] Cài đặt: ngôn ngữ, giao diện, đổi mật khẩu, quản trị, đăng xuất
- [x] T006 [US3] `PlanScreen` (Thực đơn | Đi chợ), `AppShell` 5 tab, lối tắt trang chủ
- [x] T007 Khoá dịch vi/en; cập nhật test; ảnh giao diện; README
- [x] T008 Deploy rules (2026-11-14); chạy trên máy ảo: 5 tab, hồ sơ thật, đổi tên đạt
  - Cloud Storage của project bị khoá (tài khoản thanh toán đã đóng, HTTP 402) nên ảnh đại diện được
    chuyển sang lưu thẳng trong hồ sơ `users/{uid}.avatarData` (ảnh 256 px, base64, ≤ 150 000 ký tự,
    rules kiểm tra). Đã thử trên máy ảo: chụp ảnh → hiện ở tab Tài khoản và trang chủ.
  - Ảnh công thức vẫn dùng Storage nên vẫn lỗi tới khi bật lại thanh toán.
