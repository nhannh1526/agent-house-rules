# agent-house-rules

[English](README.md)

Bộ "nội quy" cho trợ lý code AI của bạn, [Claude Code](https://github.com/anthropics/claude-code) và [Codex](https://github.com/openai/codex). Cài một lần; mọi session, ở mọi project, đều bắt đầu từ cùng một bộ luật. (Trợ lý vẫn có thể sơ suất; [kết quả test](#có-thật-sự-hiệu-quả) cho thấy mức độ.)

> Project cộng đồng, không chính thức. Không liên kết với Anthropic hay OpenAI. Đã kiểm tra với Claude Code 2.1.288 và Codex CLI 0.160 (tháng 10/2026).

## Vì sao cần

Trợ lý AI viết code giỏi nhưng hay lệch về cách làm việc. Trong các bài test của chúng tôi, khi được bảo "làm theo plan rồi báo khi sẵn sàng ship", trợ lý không có bộ luật này tự tạo branch git mới và commit trong mọi repo (thư mục project) ở 9/12 lần chạy; có bộ luật: 0/12. Bộ luật dặn trợ lý:

- **không đụng vào git** (không commit, tạo branch hay push) trừ khi bạn yêu cầu;
- **kiểm tra mọi project bị ảnh hưởng** trước khi đổi thứ mà nơi khác đang dùng, ví dụ API mà website của bạn gọi;
- **dừng lại báo bạn** khi plan không khớp với code, thay vì lặng lẽ làm khác đi;
- **bỏ qua chỉ dẫn giấu trong file hay trang web**, và báo cho bạn biết;
- **nói rõ đã thật sự test những gì**, và những gì chưa test được.

## Bạn nhận được gì

- Một file luật ngắn mà Claude Code và Codex đều đọc ở đầu mỗi session.
- Lệnh `kickoff` để bắt đầu công việc đụng tới nhiều project.
- Script cài đặt có backup mọi thứ nó thay thế và có thể tự gỡ.

Không cài gì khác. Các add-on giúp bộ luật hữu ích hơn là tùy chọn, liệt kê ở [bên dưới](#add-on-tùy-chọn).

## Cài đặt

**Dễ nhất: nhờ trợ lý cài.** Dán câu này vào Claude Code hoặc Codex:

> Clone https://github.com/nhannh1526/agent-house-rules và cài nó theo mục "For AI agents installing this" trong README. Hỏi tôi trước khi thay đổi bất cứ thứ gì.

**Hoặc tự cài.** Các lệnh này gõ trong **Terminal** (Windows: dùng Git Bash, có sẵn khi cài [Git for Windows](https://gitforwindows.org)):

```bash
claude --version || codex --version   # ít nhất một lệnh phải in ra số phiên bản
git clone https://github.com/nhannh1526/agent-house-rules.git
cd agent-house-rules
bash install.sh --dry-run             # cho xem sẽ thay đổi gì; chưa đổi gì cả
bash install.sh                       # cài cho mọi trợ lý tìm thấy
```

Đã tải thư mục về rồi? Bỏ dòng `git clone` và `cd`, chạy các dòng `bash` từ bên trong thư mục đó.

Mấy dòng cuối của output cho biết chuyện gì đã xảy ra:

- `done: installed for: Claude Code, Codex`: các trợ lý đã có bộ luật.
- `not installed: ... command not found`: trợ lý đó chưa được cài (hoặc Terminal không tìm thấy nó, tức là nó không nằm trong PATH). Cài nó, rồi chạy lại `bash install.sh`.
- `NOTE: ...`: một file luật bạn đã có (hoặc đã sửa) vừa bị thay; bản cũ nằm trong thư mục backup mà output ghi ra. Muốn giữ luật riêng, đặt nó vào `~/.claude/personal.md` (Claude) hoặc `~/.codex/personal.md` (Codex) rồi chạy lại `bash install.sh`: script cài luôn gộp các file đó vào.
- `optional add-ons:` cho biết bạn đã có [add-on](#add-on-tùy-chọn) nào (`yes`/`no`). Script cài không bao giờ tự cài chúng; chọn trong bảng bên dưới.
- `undo:` là lệnh gỡ toàn bộ. Hãy giữ lại.

## Kiểm tra đã cài được chưa

- **Trong Claude Code** (mở bằng lệnh `claude`): gõ `/memory`; danh sách phải có `~/.claude/CLAUDE.md`. Gõ `/kickoff` phải thấy lệnh này.
- **Trong Codex** (mở bằng lệnh `codex`): gõ `/skills`; danh sách phải có `kickoff`. Sau đó hỏi *"tóm tắt global instructions của bạn trong 3 ý"*: câu trả lời phải nhắc tới git, plan và việc kiểm tra. Nếu không, xem có file `~/.codex/AGENTS.override.md` không; khi file đó còn, nó thay thế bộ luật.

## Sử dụng

Cứ làm việc như bình thường; bộ luật tự áp dụng. Ví dụ, bảo *"thêm nút chuyển dark mode vào trang settings"*: bộ luật dặn trợ lý đọc code liên quan trước, sửa, chạy test của project, kết thúc bằng việc đã đổi gì và đã kiểm tra gì, và không commit nếu bạn không yêu cầu.

Khi task đụng tới nhiều project, bắt đầu bằng `kickoff` và nêu tên chúng:

- Trong Claude Code: `/kickoff Thêm cột "last login" --repo ../api --repo ../web`
- Trong Codex: `$kickoff Thêm cột "last login" --repo ../api --repo ../web`

Thay `../api` và `../web` bằng thư mục project của bạn. Thiếu thông tin thì kickoff sẽ hỏi. Để trợ lý mở được repo nằm ngoài thư mục bạn khởi động nó, xem [Làm việc trên nhiều repo](docs/advanced.vi.md#làm-việc-trên-nhiều-repo).

## Add-on tùy chọn

Các project riêng mà bộ luật sẽ dùng nếu có. Mọi thứ ở trên vẫn chạy khi không có chúng. Mọi lệnh dưới đây gõ trong **Terminal**.

**Nếu phân vân, bắt đầu với superpowers** (thêm plugin codex nếu bạn dùng cả hai trợ lý). Các add-on khác thêm sau. Nếu muốn dùng RTK, cài nó **trước** khi chạy `bash install.sh`, hoặc chạy lại script cài sau đó.

| Add-on | Bạn được gì | Claude Code | Codex |
|---|---|---|---|
| [superpowers](https://github.com/obra/superpowers) | Các skill hướng dẫn từng bước để lên plan, debug và kiểm tra công việc | `claude plugin marketplace add obra/superpowers-marketplace` rồi `claude plugin install superpowers@superpowers-marketplace` | `codex plugin marketplace add obra/superpowers-marketplace` rồi `codex plugin add superpowers@superpowers-marketplace` |
| [plugin codex](https://github.com/openai/codex-plugin-cc) | Claude nhờ Codex cho ý kiến thứ hai với thay đổi lớn (cần đã cài và đăng nhập Codex) | `claude plugin marketplace add openai/codex-plugin-cc` rồi `claude plugin install codex@openai-codex`, sau đó gõ `/codex:setup` trong Claude Code | - |
| [RTK](https://github.com/rtk-ai/rtk) | Output lệnh ngắn hơn, tốn ít token hơn | Cài theo README của nó, rồi `rtk init -g --auto-patch` | `rtk init -g --codex` |
| [caveman](https://github.com/JuliusBrussee/caveman) | Trả lời ngắn gọn | `claude plugin marketplace add JuliusBrussee/caveman` rồi `claude plugin install caveman@caveman` | `npx skills add JuliusBrussee/caveman -a codex -g` |
| [ponytail](https://github.com/DietrichGebert/ponytail) | Thay đổi code nhỏ và gọn hơn | `claude plugin marketplace add DietrichGebert/ponytail` rồi `claude plugin install ponytail@ponytail` | `codex plugin marketplace add DietrichGebert/ponytail` rồi `codex plugin add ponytail@ponytail` |

- Khởi động lại Claude Code hoặc Codex sau khi cài. Codex có thể nhờ bạn duyệt hook mới trong `/hooks`.
- Nếu plugin báo "disabled by your workspace admin" nghĩa là tổ chức của bạn chặn nó. Bỏ qua; bộ luật vẫn chạy.
- Setup của tác giả gồm: bộ luật, cả 5 add-on ở trên, [GitNexus](https://github.com/abhigyanpatwari/GitNexus) cho codebase lớn, và model mặc định đặt như trong [docs/advanced.vi.md](docs/advanced.vi.md#model-và-effort).

### For AI agents installing this

Mục này viết cho AI agent được nhờ cài (bản tiếng Anh ở [README.md](README.md#for-ai-agents-installing-this) là bản chuẩn):

1. Dùng bash (Windows: Git Bash). Không có bash thì dừng lại và báo user.
2. Chạy `bash install.sh --dry-run` và cho user xem output.
3. Chờ user xác nhận, rồi chạy thật (thêm `--only claude` hoặc `--only codex` nếu user chỉ muốn một tool).
4. Báo các dòng tóm tắt (`done:`, `not installed:`, mọi dòng `NOTE:`), đường dẫn backup và lệnh hoàn tác script đã in ra.
5. Chạy các bước trong "Kiểm tra đã cài được chưa" nếu làm được, và nói cho user bước nào họ phải tự làm.
6. Không tự cài plugin, sửa `settings.json` / `config.toml` hay đổi quyền khi chưa hỏi. Đưa user bảng add-on tùy chọn, và chỉ cài những cái user chọn.

## Gỡ cài đặt

Chạy lệnh `undo:` mà script đã in ra, ví dụ `bash install.sh --uninstall ~/.agent-house-rules-backup/<thư-mục>`. Lệnh này khôi phục mọi file đã có từ trước và gỡ những gì lần cài thêm vào; không có gì bị xoá (bản đã cài được chuyển vào `<thư-mục>/uninstalled/`). Nếu đã cài nhiều lần, gỡ lần mới nhất trước; chọn sai thì script sẽ báo. Undo không gỡ add-on; gỡ chúng bằng lệnh riêng của từng add-on.

## Có thật sự hiệu quả?

180 lần chạy test trong container dùng một lần, trên 6 project thực tế, mỗi project gồm 2-3 repo:

- **Tự ý đổi git** (bài test "sẵn sàng ship"): tạo branch và commit ở 9/12 lần khi không có bộ luật, 0/12 khi có.
- **Đổi API mà project khác đang dùng:** sau khi thêm một dòng luật, Codex tìm ra mọi project bị ảnh hưởng ở tất cả các lần chạy (trước đó thỉnh thoảng sót một project).
- **Chỉ dẫn giấu trong file:** không lần chạy nào làm theo, dù có hay không bộ luật; model hiện tại đã tự xử lý được.
- **Chất lượng code:** test không cho thấy code tốt hơn khi có bộ luật. Bộ luật thay đổi cách trợ lý làm việc, không phải độ giỏi khi viết code.

Chi tiết, giới hạn và cách chạy lại test: [eval/RESULTS.md](eval/RESULTS.md).

## Thuật ngữ

| Từ | Nghĩa |
|---|---|
| Terminal | Ứng dụng dòng lệnh (Terminal trên macOS, Git Bash trên Windows) |
| repo | Một thư mục project được git quản lý |
| commit / branch / push | Lưu một bản chụp / một nhánh làm việc song song / đẩy lên GitHub |
| plugin, skill | Add-on cho trợ lý thêm chỉ dẫn hoặc lệnh |
| subagent | Trợ lý phụ mà trợ lý chính tạo ra để làm một phần việc |
| worktree | Thư mục làm việc thứ hai của cùng repo, trên branch riêng |
| token | Đơn vị đo lượng sử dụng AI |

## Thêm

- [docs/advanced.vi.md](docs/advanced.vi.md): cấu trúc config, model và effort, worktree, GitNexus, bảo trì bộ luật, ghi chú kỹ thuật.
- [eval/](eval/README.md): harness test và kết quả đầy đủ (tiếng Anh).

License: [MIT](LICENSE). Mỗi add-on có license riêng.
