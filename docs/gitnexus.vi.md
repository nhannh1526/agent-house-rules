# GitNexus với agent-house-rules

[Quay lại README](../README.vi.md)

## GitNexus khi làm nhiều repo

Với backend + frontend, hoặc một repo downstream dùng một hay nhiều repo upstream: index từng repo, rồi gom chúng vào một group để GitNexus nối các contract giữa các repo (đối chiếu với help của GitNexus CLI 1.6.12):

```bash
# mỗi repo một lần; --index-only để GitNexus không sửa AGENTS.md / CLAUDE.md / skill trong repo
npx gitnexus analyze --index-only ../api-service
npx gitnexus analyze --index-only ../web-client

npx gitnexus group create shop                     # tạo file group.yaml mẫu
npx gitnexus group add shop shop/backend api-service   # <groupPath> <tên trong 'gitnexus list'>
npx gitnexus group add shop shop/frontend web-client
npx gitnexus group sync shop                       # trích contract, tạo liên kết chéo repo

npx gitnexus group status shop                     # index có bị cũ không?
npx gitnexus group contracts shop --unmatched      # contract GitNexus chưa nối được
npx gitnexus group impact shop --repo shop/backend --target ProjectOut --direction upstream
```

- `--direction upstream` = ai đang phụ thuộc vào chỗ này (các consumer phía sau); `downstream` = chỗ này phụ thuộc vào gì.
- Giữ index luôn mới (`analyze --index-only --watch`, hoặc chạy lại `analyze --index-only` + `group sync` sau mỗi lần pull); group cũ cho kết quả cũ.
- Không có `--index-only` thì `analyze` sẽ thêm một mục GitNexus vào `AGENTS.md` / `CLAUDE.md` của repo và cài skill vào `.claude/skills` / `.agents/skills` — không nên với repo dùng chung của team.
- Đừng commit thư mục index `.gitnexus/` (thêm vào `.gitignore` hoặc `.git/info/exclude`).
- Liên kết chéo chỉ tốt bằng khả năng nhận diện contract của GitNexus với stack của bạn; xem `group contracts --unmatched` trước khi tin một kết quả impact rỗng.
