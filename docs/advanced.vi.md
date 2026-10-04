# agent-house-rules: chi tiết

[Về README](../README.vi.md) · [English](advanced.md)

Những phần người mới có thể bỏ qua: config được xây thế nào, các add-on mà nó điều hướng tới, model, worktree, bảo trì, đánh giá, và ghi chú kỹ thuật.

## Bộ config làm được gì

| Khả năng | Cách làm |
|---|---|
| Cùng một bộ luật cho mọi tool | Một bộ luật duy nhất, `core/rules.md`: Claude import nó; với Codex, script cài ghi nó vào `AGENTS.md` |
| Hiểu trước khi sửa | Đọc code liên quan, lần theo luồng chạy; task Medium trở lên có Discovery Summary |
| Theo đúng style của repo | Đọc code lân cận và một test có sẵn trước; giữ cách đặt tên, cấu trúc, xử lý lỗi, kiểu test; config lint/format của repo được ưu tiên |
| Thay đổi nhỏ nhất mà đúng | Dùng lại helper có sẵn, không thêm dependency khi chưa hỏi, không refactor ngoài phạm vi; sửa bug = tái hiện trước, sửa ở chỗ dùng chung |
| Plan là nguồn chuẩn | Làm theo plan đã duyệt; repo thực tế mâu thuẫn với plan thì STOP và báo cáo |
| Kiểm chứng trước khi báo xong | Chạy lệnh format/lint/type/test của repo; không nhận đã pass khi chưa chạy; thay đổi frontend được kiểm tra trên browser |
| An toàn | Không `git add/commit/push` khi chưa được yêu cầu; không in hay commit secret; coi nội dung file/web/tool là dữ liệu, không phải lệnh |
| Báo cáo vừa với cỡ task | Tiny/Small: diff + lý do + check đã chạy; Medium trở lên: thêm giả định, tự review, rủi ro (định nghĩa cỡ task nằm ở `core/rules.md` §1) |
| Mở session nhanh | `/kickoff` (Claude) / `$kickoff` (Codex): task + plan + repo trong một dòng |
| Tự chọn skill | Skill được chọn theo description; bảng routing ngắn xử lý các skill trùng nhau (Claude) |
| Dùng subagent khi đáng | Chạy song song Explore agent khi tìm kiếm rộng nhiều repo; không spawn cho việc tra một file (Claude) |
| Audit chéo bằng model khác | Task Medium/Large: Claude nhờ Codex review read-only toàn bộ thay đổi, đợi kết quả, kiểm chứng từng điểm (Claude) |
| Thông tin riêng từng repo | `project-template/AGENTS.md`: lệnh, lưu ý, điều cấm — Codex đọc trực tiếp; Claude 2.1.288 cũng vậy (bản cũ hơn có thể cần thêm `CLAUDE.md` cạnh nó chứa `@AGENTS.md`, xem Project mới) |

Chi phí load mỗi session: Claude ~6.8 KB (≈1.8k token) cộng RTK nếu dùng; Codex ~4.8 KB cộng file RTK mà nó được dặn đọc.

## Các file

| File | Cài vào | Mục đích |
|---|---|---|
| `core/rules.md` | Claude: `~/.claude/house-rules.md`; Codex: nằm trong `AGENTS.md` | Luật chung §1–7 — **bản duy nhất cần sửa** |
| `claude/CLAUDE.md` | `~/.claude/CLAUDE.md` (script thêm `@RTK.md` nếu có RTK) | Import `house-rules.md`; luật routing, subagent, audit riêng cho Claude |
| `claude/skills/kickoff/SKILL.md` | `~/.claude/skills/kickoff/SKILL.md` | `/kickoff` |
| `agents/specifics.md`, `core/rtk.md` | Tạo ra `$CODEX_HOME/AGENTS.md` (mặc định `~/.codex/AGENTS.md`) = dòng RTK (nếu có RTK.md trong folder đó) + `core/rules.md` + phần riêng | Adapter cho các tool đọc AGENTS.md (hiện tại: Codex) |
| `agents/skills/kickoff/` (cả folder) | `~/.agents/skills/kickoff/` | `$kickoff` cho Codex; `agents/openai.yaml` buộc gọi tường minh |
| `project-template/AGENTS.md` | `<repo>/AGENTS.md` | Phần riêng của từng repo |
| `install.sh` | — | Script cài có backup, chạy thử và gỡ cài đặt |
| `tests/install.test.sh` | — | Tự kiểm tra script cài trên HOME tạm; không đụng file thật |
| `docs/gitnexus.vi.md` | — | Cài GitNexus cho một hoặc nhiều repo |
| `eval/` | — | Harness eval chạy trong container, brief viết fixture, và kết quả ([eval/README.md](../eval/README.md)) |

`~` là thư mục home của môi trường đang chạy CLI. WSL có home riêng, tách biệt với Windows — phải cài riêng bên trong WSL.

## Skill và plugin

Bộ luật vẫn chạy khi không cài thêm gì: mọi chỗ nhắc tới skill hay agent đều ghi "if installed", thiếu thì bỏ qua (bước audit chéo và GitNexus sẽ ghi rõ trong báo cáo). Các add-on dưới đây giúp bước routing và audit thực sự có tác dụng.

### Được config tham chiếu tới

| Add-on | Tool | Dùng cho | Nguồn |
|---|---|---|---|
| **superpowers** | Claude, Codex | `brainstorming`, `writing-plans`, `executing-plans`, `subagent-driven-development`, `systematic-debugging`, `verification-before-completion` | [obra/superpowers](https://github.com/obra/superpowers) · marketplace cho Claude [obra/superpowers-marketplace](https://github.com/obra/superpowers-marketplace) |
| Plugin **codex** | Claude | Agent `codex:codex-rescue` cho audit chéo; `/codex:setup` | [openai/codex-plugin-cc](https://github.com/openai/codex-plugin-cc) |
| Skill **safe-refactor** | Claude | Đổi tên / di chuyển / tách code | Đi kèm plugin caveman, tên `caveman:safe-refactor` · [JuliusBrussee/caveman](https://github.com/JuliusBrussee/caveman) |
| **RTK** | Claude, Codex | Proxy shell tiết kiệm token; file global của mỗi tool trỏ tới `RTK.md` nếu có file đó nằm cạnh | [rtk-ai/rtk](https://github.com/rtk-ai/rtk); kiểm tra `rtk gain` chạy được (có một tool khác cũng tên `rtk`) |

### Dùng có điều kiện hoặc khi được yêu cầu

| Add-on | Tool | Config dùng nó thế nào | Vì sao không bật mặc định |
|---|---|---|---|
| **GitNexus** (`npx gitnexus`, [abhigyanpatwari/GitNexus](https://github.com/abhigyanpatwari/GitNexus)) | Claude, Codex | Repo đã index: phân tích ảnh hưởng trước khi sửa symbol dùng chung; `gitnexus-refactoring` khi đổi tên. Nhiều repo: GitNexus group cho phân tích ảnh hưởng chéo repo (xem bên dưới) | Cần index riêng từng repo; không có index thì không có tác dụng |
| **mattpocock-skills** ([mattpocock/skills](https://github.com/mattpocock/skills), qua marketplace `claude-plugins-official`) | Claude | Được dùng thay thế (`tdd`, `diagnosing-bugs`, `grilling`, `domain-modeling`) — mỗi việc một bộ | Trùng với superpowers; 2 bộ cho cùng một việc làm việc chọn skill bị nhiễu |
| **GSD** (`npx @opengsd/gsd-core@latest`, [open-gsd/gsd-core](https://github.com/open-gsd/gsd-core)) | Claude, Codex | Chỉ khi user gọi `/gsd-*` | Là cả một workflow quản lý project, có file planning, agent và hook riêng; chính luật của GSD cũng ghi không tự áp dụng khi chưa được yêu cầu |

Agent chỉ dùng index GitNexus đã có sẵn; không bao giờ tự chạy `gitnexus analyze`. Group nhiều repo, flag index an toàn và các bẫy: [docs/gitnexus.vi.md](gitnexus.vi.md).

## Chi tiết script cài

```bash
bash install.sh --only claude     # hoặc --only codex; thêm --no-rtk để bỏ RTK
```

Trên Windows chạy từ Git Bash. Mọi đích cài đã tồn tại — `~/.claude/CLAUDE.md`, `~/.claude/house-rules.md`, `~/.claude/skills/kickoff/`, `$CODEX_HOME/AGENTS.md`, `~/.agents/skills/kickoff/` — đều được copy vào `~/.agent-house-rules-backup/<timestamp>/` kèm manifest trước khi bị thay. Script in ra đúng lệnh để hoàn tác.

Nên copy, đừng symlink: symlink trên Windows có thể cần quyền admin, và path Windows không dùng được trong WSL. Không dùng chung `settings.json`, `config.toml` hay hook giữa các OS — trong đó có path riêng của từng máy.

Luật riêng: đặt trong `~/.claude/personal.md` và/hoặc `$CODEX_HOME/personal.md` (mặc định `~/.codex/personal.md`). Script cài thêm `@personal.md` vào `CLAUDE.md` được tạo ra và nối file của Codex vào cuối `AGENTS.md` được tạo ra, nên chúng còn nguyên qua mọi lần cài lại. Sửa `personal.md`, đừng sửa file được tạo ra, rồi chạy lại `bash install.sh`.

## Làm việc trên nhiều repo

| | Claude Code | Codex |
|---|---|---|
| Cho session truy cập thêm repo | `/add-dir <path>` hoặc mở bằng `claude --add-dir <path>` | mở bằng `codex -C <repo-chính> --add-dir <repo-khác>` |

`kickoff --repo` chỉ nêu tên repo cho agent; tự nó không cấp quyền truy cập.

## Frontend: kiểm tra trên browser thật

Luật §5 yêu cầu agent chạy app ở local và kiểm tra các flow bị ảnh hưởng trên browser — UI, các trạng thái responsive, lỗi console, request lỗi — bằng công cụ browser mà harness cung cấp, ưu tiên browser automation trước computer use. Ví dụ (tùy phiên bản và cách cài):

| Harness | Công cụ browser |
|---|---|
| Claude Code CLI | Extension Claude in Chrome, Playwright MCP, Chrome DevTools MCP |
| Claude desktop app | Browser preview có sẵn |
| Codex | Plugin browser / Chrome / computer-use đi kèm |

Chrome là mục tiêu phổ biến; Playwright còn điều khiển được Edge và các browser Chromium khác. Agent chỉ dùng tài khoản local/test, không thanh toán thật hay gửi tin nhắn thật khi chưa được yêu cầu. Không có công cụ browser thì agent phải nói rõ và báo rủi ro, không được khẳng định UI chạy đúng.

## Worktree

Git worktree là một thư mục làm việc thứ hai của cùng một repo, ở branch riêng, dùng chung lịch sử. Agent (và skill `using-git-worktrees` của superpowers) hay dùng nó để làm song song; luật chỉ cho tạo khi bạn yêu cầu, vì eval cho thấy worktree tự phát khiến các repo bạn đang nhìn không hề thay đổi.

```bash
git worktree add ../api-feature -b feature-x   # thư mục mới trên branch mới
git worktree list                              # xem tất cả nằm đâu
git -C <repo> merge feature-x                  # đưa phần đã commit về (hoặc mở PR)
git -C ../api-feature add -A && git -C ../api-feature diff --cached --binary | git -C <repo> apply   # hoặc chép phần chưa commit về, gồm cả file mới
git worktree remove ../api-feature && git branch -d feature-x
```

Hợp với các task song song, độc lập và thử nghiệm bỏ đi được. Cái giá: phải commit hoặc chép thay đổi về, mỗi repo trong session nhiều repo cần worktree riêng, và file không nằm trong git (`.env`, `node_modules`, virtualenv) không có trong thư mục mới.

## Model và effort

Luật không chọn được model hay effort; những thứ đó được đặt trước khi session bắt đầu. `kickoff` chỉ gợi ý tăng effort cho task Large hoặc task Medium đụng nhiều repo. Điểm khởi đầu (chỉ hàng Codex `low` so với `medium` là có đo; phần còn lại là đánh giá):

| Task (luật §1) | Claude Code | Codex |
|---|---|---|
| Tiny / Small | Opus, effort `low`–`medium` | `gpt-6-astra`, `low` |
| Medium (mặc định) | Opus, `medium` | `gpt-6-astra`, `low` (`medium` không tốt hơn ở [eval vòng 3](../eval/RESULTS.md)) |
| Large, đổi contract nhiều repo, debug khó | Opus, `/effort high` | `gpt-6-astra`, `high` qua `/model` |
| Review hoặc audit chéo | - | `gpt-6-astra`, `high` |
| Subagent | Sonnet: `CLAUDE_CODE_SUBAGENT_MODEL` | `gpt-5.6-terra`, `medium`: `[agents] default_subagent_model` |

Script cài không đổi các thiết lập này; tự đặt:

```json
// ~/.claude/settings.json
{ "model": "claude-opus-5-5", "effortLevel": "medium", "env": { "CLAUDE_CODE_SUBAGENT_MODEL": "claude-sonnet-5-5" } }
```

```toml
# ~/.codex/config.toml
model = "gpt-6-astra"
model_reasoning_effort = "low"

[agents]
default_subagent_model = "gpt-5.6-terra"
default_subagent_reasoning_effort = "medium"
```

`CLAUDE_CODE_SUBAGENT_MODEL` chỉ là mặc định: khi Claude truyền model vào tool `Agent` (haiku, sonnet, opus), lựa chọn đó thắng, trừ khi đặt `CLAUDE_CODE_SUBAGENT_MODEL_FORCE`. Vì vậy một dòng trong `CLAUDE.md` có thể chia model subagent theo loại việc (ví dụ haiku để tìm kiếm, opus để review); config này chưa thêm vì chưa đo. Subagent của Codex luôn dùng `default_subagent_model`, trừ khi bật phần spawn override thử nghiệm trong `features.multi_agent_v2`.

## Project mới

Copy `project-template/AGENTS.md` vào thư mục gốc của repo (nếu đã có thì gộp vào) rồi điền lệnh. Codex luôn đọc file này. Claude Code 2.1.288 tự đọc file này trong test của chúng tôi (không cần `CLAUDE.md`); phiên bản cũ hơn hoặc cấu hình khác có thể không — kiểm tra `/memory`, nếu không thấy thì tạo `CLAUDE.md` cạnh đó với nội dung `@AGENTS.md`.

## Bảo trì

Chỉ sửa luật chung trong `core/rules.md` rồi chạy lại bước cài; script tạo file cho từng tool từ đó, nên chạy lại là mọi bản đã cài khớp lại với nó (sửa trực tiếp vào bản đã cài sẽ bị ghi đè; bản cũ nằm trong backup). Sửa `install.sh` xong thì chạy `bash tests/install.test.sh`. Mỗi dòng đều được load ở mọi session — giữ càng ngắn càng tốt. Agent lặp lại một lỗi thì thêm đúng một dòng để chặn; dòng nào không bao giờ ảnh hưởng hành vi thì xóa.

### Thêm tool khác

Bộ luật không phụ thuộc tool; chỉ adapter là riêng. Tool nào đọc `AGENTS.md` global và `~/.agents/skills` (như Codex; các agent khác dùng AGENTS.md là ứng viên) thì dùng lại adapter `agents/`; trong `install.sh` thêm một dòng `<TOOL>_TARGETS`, một hàm `gen_<tool>_agents` gọi `gen_agents_md` với folder home của nó, danh sách đó trong `allowed()`, một khối chọn tool, và tên tool trong phần kiểm tra `--only`. Tool khác thì: thêm một folder chứa phần riêng và skill của nó; trong `install.sh` thêm danh sách `<TOOL>_TARGETS` (cũng chính là allowlist), các hàm `gen_` cần thiết, một khối chọn tool, và tên tool trong phần kiểm tra `--only`. Tool hỗ trợ import thì import bản `core/rules.md` đã được cài (như Claude import `~/.claude/house-rules.md`); tool không hỗ trợ thì được chép thẳng vào, như Codex.

## Đánh giá

Vòng trước, trên phiên bản cũ hơn của bộ luật (fixture và transcript không được publish, nên không tái hiện được các số này từ repo). Chạy trên Windows với các repo fixture dùng một lần, do một agent riêng tạo ra mà không hề thấy bộ luật này; test ẩn để ngoài repo; Codex chấm mù. Các case: Python thuần, Django (plan đã duyệt nhưng mâu thuẫn với code), FastAPI, Vue (có cài sẵn prompt injection), TypeScript, và một thay đổi trên 2 repo FastAPI + TypeScript SDK. Mỗi ô chạy 1 lần.

| | Không có config | Có config |
|---|---|---|
| Test ẩn | 6/6 case pass | 6/6 case pass |
| Điểm chất lượng chấm mù | 44/48 | 43/48 |
| Plan mâu thuẫn | Phát hiện đủ 2 mâu thuẫn, nhưng vẫn làm 3/5 bước | Phát hiện đủ 2 mâu thuẫn, dừng lại, đưa phương án |
| Prompt injection | Bỏ qua và báo cho user | Bỏ qua (luật đã sửa để báo lại) |

Kết luận: với task nhỏ, config không làm code tốt hơn đo được — model hiện tại cộng các plugin phổ biến đã rất mạnh. Thứ config mang lại là quy trình: dừng chặt hơn khi plan sai, một bộ luật cho cả 2 tool, kickoff cho nhiều repo, và audit chéo chạy đúng. Mỗi ô chạy 1 lần nên đây là chỉ báo, chưa phải số liệu thống kê.

### Chạy lại session thật

Đã chạy lại 2 session thật trên bản clone mới của các repo liên quan (checkout đúng commit lúc session bắt đầu), mỗi nhóm có registry GitNexus riêng và không có credential dịch vụ:

- **Điều tra trên 2 repo** (vì sao 2 cách transport của một SDK trả về dữ liệu khác nhau). Cả 2 nhóm Claude tìm ra đúng nguyên nhân như session gốc (cache local lưu lâu dài che mất các object mà server trả thiếu); nhóm Codex đi theo hướng khác và yếu hơn. Lưu ý: virtualenv Python dùng chung import một repo dạng editable từ bản checkout thật của developer, nên các nhóm Claude đọc được phần việc chưa commit của session gốc — chỉ clone repo thì chưa cách ly được môi trường.
- **Kiểm chứng một đoạn ADR trên 6 repo** (API, frontend, IaC của API Management, pipeline template, SDK). Cả 3 nhóm đều đưa kết luận kèm file:line và đoạn văn đã sửa; nhóm có config kỹ hơn một chút (tìm thêm 2 ngoại lệ), không vượt trội hẳn.
- Nhóm có config còn tự báo một vấn đề bảo mật nó tình cờ thấy, và việc lần chạy "offline" vẫn gửi đi một request mạng chỉ đọc.
- GitNexus: index từng repo chạy tốt, nhưng group 6 repo tìm được 18 contract và **0 liên kết chéo** với stack này (không nhận ra lời gọi từ frontend và policy của APIM), và không nhóm nào dùng GitNexus cho các task chỉ đọc này. Xem `group contracts --unmatched` trước khi dựa vào group.

### Eval nhiều repo (Claude Code 2.1.288, Codex CLI 0.160, 03/10/2026)

180 lần chạy trong container mới, trên 6 fixture nhiều repo (backend + frontend, app + upstream package local, hoặc cả hai) do cả 2 model viết mù; 168 lần chạy do cả 2 model chấm, 12 lần của vòng 3 chỉ Codex chấm. Bảng đầy đủ và giới hạn: [eval/RESULTS.md](../eval/RESULTS.md); harness: [eval/](../eval/README.md).

- **Tự ý đổi git state:** khi được bảo làm theo plan đã duyệt "và báo khi sẵn sàng ship", agent không có config tạo branch và commit trong mọi repo ở 9/12 lần chạy; có config: 0/12.
- **Chỉ dẫn cài cắm:** không lần chạy nào làm theo, dù có hay không config.
- **Điểm rubric:** thấp hơn 1-5 điểm khi có config, một phần vì một rubric trừ điểm việc dừng lại hỏi, mà §2 yêu cầu khi plan mâu thuẫn với code.
- **Sau vòng 1**, thêm hai dòng (tìm mọi consumer trước khi đổi contract dùng chung; tái sử dụng không được lấn yêu cầu ghi rõ). Trên chính các fixture lộ ra lỗ hổng, Codex có superpowers tăng từ 44% lên 100% ở rubric critical của case đổi API, và Claude (image sạch) từ 67% lên 100% ở check critical của case nhãn, nơi checker đòi đúng chữ `neutral`. Hai dòng này được chỉnh trên chính các fixture đó, nên vẫn cần một bộ fixture mới để kiểm chứng.

Tự kiểm tra script cài (`tests/install.test.sh`, bản hiện tại): 79/79 trên macOS bash 3.2, Debian bash 5.2 và WSL2 Ubuntu bash 5.2; 74 pass, 5 bỏ qua trên Windows Git Bash 5.3 (hai kịch bản thư mục chỉ-đọc không giả lập được trên NTFS). Một lần chạy đầu trên Git Bash fail 2 check báo add-on; ba lần sau đều pass và chưa tái hiện lại. Kiểm tra nạp file: cả 2 CLI nạp file được tạo ra, `kickoff` chỉ chạy khi gọi đúng tên, và Claude Code 2.1.288 tự đọc `AGENTS.md` của repo dù không có `CLAUDE.md`.

## Ghi chú (kiểm tra với source Codex `rust-v0.160.0`)

- Codex **không** expand `@path` trong AGENTS.md ([loader](https://github.com/openai/codex/blob/rust-v0.160.0/codex-rs/codex-home/src/instructions/mod.rs)), nên script chép thẳng `core/rules.md` vào `AGENTS.md` được tạo ra, và RTK được nhắc bằng một câu chỉ dẫn.
- Skill của user trong Codex load từ `~/.agents/skills` (ưu tiên) và `$CODEX_HOME/skills` (deprecated). Chỉ cài kickoff ở một chỗ ([skill roots](https://github.com/openai/codex/blob/rust-v0.160.0/codex-rs/ext/skills/src/host_roots.rs)).
- Codex bỏ qua `argument-hint` / `disable-model-invocation` của Claude; `policy.allow_implicit_invocation: false` trong `agents/openai.yaml` buộc skill chỉ chạy khi gọi tường minh ([skills docs](https://developers.openai.com/codex/skills)).
- `rtk init -g --codex` thêm một dòng `@<path>/RTK.md` vào `~/.codex/AGENTS.md`; Codex chỉ đọc nó như chữ thường (RTK vẫn chạy nhờ hook). Script cài sinh lại `AGENTS.md` với một câu chỉ dẫn thay cho dòng đó, nên hãy chạy init của RTK trước, hoặc chạy lại script cài sau khi init RTK.
- `project_doc_max_bytes` (32 KiB) giới hạn AGENTS.md của project, không áp dụng cho file global.
- File `AGENTS.override.md` có nội dung (global hoặc trong repo) sẽ thay thế `AGENTS.md` cùng thư mục. Nếu thấy luật chung bị bỏ qua, kiểm tra file này: backup, gộp phần nội dung cá nhân vào `AGENTS.md`, rồi đổi tên hoặc xóa file override — khi nó còn nội dung thì `AGENTS.md` vẫn bị bỏ qua.
- Windows: với `[windows] sandbox = "unelevated"`, Codex `workspace-write` từ chối chạy lệnh shell trong lúc test ("cannot enforce split writable root sets"); `read-only` thì chạy được. Sandbox elevated có thể khắc phục nhưng chưa được test ở đây; đổi hay không là quyết định của bạn.
