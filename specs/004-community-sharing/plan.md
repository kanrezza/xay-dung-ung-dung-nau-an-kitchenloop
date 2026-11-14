# Implementation Plan: Chia sẻ công thức lên cộng đồng

**Branch**: `004-community-sharing` | **Date**: 2026-11-14 | **Spec**: [spec.md](spec.md)

## Summary

Feature `lib/features/community/`: quy tắc kiểm duyệt dùng chung (Dart + rules), repository,
provider, tab Cộng đồng (danh sách, chi tiết bài, lưu, báo cáo, gỡ), nút chia sẻ ở màn chi tiết
công thức, mục Cộng đồng trong màn Quản trị (thống kê + hàng chờ duyệt).

## Constitution Check (v1.2.0)

| Nguyên tắc | Đáp ứng |
|---|---|
| I | Bài đăng chép nguyên liệu có cấu trúc; "Lưu vào sổ" tạo `Recipe` có cấu trúc. |
| III | Kiểm duyệt ở rules; admin chỉ qua custom claim; không lộ email; test trên emulator. |
| IV | Chỉ `data/` import Firebase; màn hình < 300 dòng. |
| V | Unit test kiểm duyệt, thống kê; repository test; widget test; test đồng bộ từ cấm. |
| VII | Chỉ chia sẻ công thức + báo cáo; không follow/bình luận. |

## Thiết kế dữ liệu

- `communityPosts/{uid}_{recipeId}`: `{authorId, authorName, sourceRecipeId, title, note,
  baseServings, ingredients, steps, tags, status: visible|hidden|removed, reportCount,
  createdAt, updatedAt}`.
- `communityPosts/{id}/reports/{reporterUid}`: `{reason, createdAt}`.
- `users/{uid}.lastPostAt`: thời điểm đăng bài mới gần nhất (rules ép bằng `request.time`).
- Báo cáo = 1 batch: tạo `reports/{uid}` + tăng `reportCount` đúng 1 (+ `status: hidden` khi đủ 3).
