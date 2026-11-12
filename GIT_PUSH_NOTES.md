# Ghi chú push lên GitHub (không hiện Claude Code trong Contributors)

## Vì sao Claude có thể hiện trong Contributors?

GitHub tính Contributors từ **author của commit** và từ các dòng trailer
`Co-Authored-By: ...` ở cuối commit message. Claude Code mặc định có thể thêm dòng
`Co-Authored-By: Claude ... <noreply@anthropic.com>`, nên cần chặn dòng này.

## Việc cần làm một lần

1. **Đã có `CLAUDE.md`** ở gốc dự án: dặn Claude không thêm attribution khi commit/PR.
2. **Tắt attribution trong cài đặt Claude Code** (chắc chắn nhất). Thêm vào
   `.claude/settings.json` của dự án:

   ```json
   {
     "attribution": { "commit": "", "pr": "" },
     "includeCoAuthoredBy": false
   }
   ```

3. **Kiểm tra danh tính git của bạn:**

   ```bash
   git config user.name
   git config user.email   # nên là email đã gắn với tài khoản GitHub của bạn
   ```

## Kiểm tra trước mỗi lần push

```bash
# Tìm commit nào còn nhắc tới Claude / Anthropic
git log --format='%h %an <%ae>%n%b' | grep -iE "claude|anthropic|co-authored"
```

Không có kết quả là sạch. Nếu có, xem mục dưới.

## Nếu lỡ có commit chứa Co-Authored-By

Chỉ làm khi **chưa push** (hoặc repo chỉ mình bạn dùng, chấp nhận force-push):

```bash
# Sửa commit gần nhất
git commit --amend            # xoá dòng Co-Authored-By trong editor

# Sửa nhiều commit: viết lại toàn bộ message, bỏ các dòng đó
git filter-branch -f --msg-filter "grep -viE '^Co-Authored-By:.*(Claude|Anthropic)|Generated with .*Claude'" HEAD
git push --force-with-lease   # chỉ nếu đã push trước đó
```

Lưu ý: Contributors trên GitHub có thể mất một lúc mới cập nhật sau khi lịch sử đã sạch.

## Ghi nguồn tham khảo (nên làm)

Không ghi Claude vào Contributors không có nghĩa là giấu nguồn tham khảo. Trong README
nên có một mục ngắn, ví dụ:

> Dự án tham khảo ý tưởng từ: KitchenOwl, Mealie, và bài của [tên bạn cùng lớp] (đã được đồng ý).
> Một số đoạn được hỗ trợ bởi công cụ AI; toàn bộ mã đã được tác giả đọc và chịu trách nhiệm.

Nếu giảng viên có quy định về dùng công cụ AI, hãy làm theo quy định đó.

## Tạo repo mới sạch

```bash
git init
git add .
git commit -m "Khởi tạo KitchenLoop"
git branch -M main
git remote add origin <url-repo-cua-ban>
git push -u origin main
```

Nhớ kiểm tra `.gitignore` đã loại `android/app/google-services.json` và các khoá
nhạy cảm trước khi push repo công khai.
