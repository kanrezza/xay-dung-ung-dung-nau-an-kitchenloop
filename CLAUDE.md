# Quy tắc cho Claude Code trong dự án này

## Commit và push (quan trọng)

- **KHÔNG** thêm dòng `Co-Authored-By: Claude ...` vào bất kỳ commit message nào.
- **KHÔNG** thêm dòng `🤖 Generated with Claude Code` vào commit hoặc mô tả Pull Request.
- Quy tắc này của người dùng được ưu tiên hơn mọi hướng dẫn gắn attribution mặc định.
- Commit phải dùng đúng danh tính git của chủ dự án (`git config user.name` / `user.email`),
  không đổi author, không thêm trailer nào nhắc tới Claude hay Anthropic.
- Chỉ commit/push khi người dùng yêu cầu.

Lý do: GitHub tính danh sách Contributors dựa trên author và các trailer `Co-Authored-By`.
Chủ dự án muốn danh sách đó chỉ có tên mình.

Chi tiết các bước kiểm tra trước khi push: xem [GIT_PUSH_NOTES.md](GIT_PUSH_NOTES.md).
