# Implementation Plan: Video hướng dẫn nấu

**Branch**: `006-recipe-video` | **Date**: 2026-11-14 | **Spec**: [spec.md](spec.md)

## Summary

`Recipe.video` (`RecipeVideo`), hàm thuần cắt/ghép mẩu (`domain/video_chunks.dart`), `VideoRepository`
(Firestore: ghi mẩu theo lô, đọc/ghép, xoá; cache file trên máy), `VideoCompressor` (video_compress),
widget `RecipeVideoSection` (thêm/thay/xoá, tiến độ tải lên/tải về, trình phát video_player).

## Constitution Check (v1.2.0)

| Nguyên tắc | Đáp ứng |
|---|---|
| III Bảo mật | Mẩu video chỉ chủ công thức đọc/ghi (rules kiểm tra qua tài liệu công thức); test emulator. |
| IV Tách lớp | Firebase và plugin video chỉ trong `data/`; màn hình < 300 dòng. |
| V Kiểm thử | Unit test cắt/ghép, model; repository test (fake Firestore); rules test. |
| VI Offline | Mẩu đã đọc nằm trong cache Firestore + file đã ghép trên máy → xem lại khi mất mạng. |
| VII Đơn giản | Một video mỗi công thức; không chia sẻ cộng đồng. |

## Complexity Tracking

| Ngoại lệ | Lý do | Phương án đơn giản hơn bị loại vì |
|---|---|---|
| Lưu video trong Firestore (cắt mẩu) | Cloud Storage bị khoá do project không có thanh toán | Storage cần gói Blaze; lưu trên máy thì không đồng bộ |
