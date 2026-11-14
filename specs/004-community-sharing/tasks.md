# Tasks: Chia sẻ công thức lên cộng đồng

**Input**: [spec.md](spec.md), [plan.md](plan.md)

## Phase 1: Nền tảng

- [x] T001 Sửa constitution lên 1.2.0 trong .specify/memory/constitution.md
- [x] T002 [P] Quy tắc kiểm duyệt + từ cấm + test trong lib/features/community/domain/moderation.dart
- [x] T003 [P] Model `CommunityPost`, `PostReport` + test trong lib/features/community/models/
- [x] T004 Rules `communityPosts`, `reports`, `users.lastPostAt` + rules test (emulator)
- [x] T005 `CommunityRepository` + test trong lib/features/community/data/

## Phase 2: User Story 1 - Chia sẻ (P1)

- [x] T006 [US1] Nút "Chia sẻ lên cộng đồng" + kiểm tra trước + báo lý do trong màn chi tiết công thức

## Phase 3: User Story 2 - Xem, lưu, báo cáo (P1)

- [x] T007 [US2] `CommunityProvider` + test
- [x] T008 [US2] Tab Cộng đồng, chi tiết bài, lưu vào sổ, báo cáo, gỡ bài trong lib/features/community/view/

## Phase 4: User Story 3 - Quản trị (P2)

- [x] T009 [US3] Thống kê cộng đồng (thuần) + test trong lib/features/community/domain/community_stats.dart
- [x] T010 [US3] Mục Cộng đồng trong màn Quản trị: số liệu, biểu đồ 7 ngày, hàng chờ duyệt

## Phase 5: Hoàn thiện

- [x] T011 Khoá dịch vi/en; mở rộng các test chốt chặn; test từ cấm khớp giữa Dart và rules
- [x] T012 Ảnh giao diện, README; deploy rules (2026-11-14); nghiệm thu trên máy ảo: chia sẻ món, bài hiện ở Cộng đồng
