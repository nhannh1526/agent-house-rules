# agent-house-rules

[Tiếng Việt](README.vi.md)

House rules for your AI coding assistants, [Claude Code](https://github.com/anthropics/claude-code) and [Codex](https://github.com/openai/codex). Install once; every session, in every project, starts from the same rules. (Assistants can still slip; [the tests](#does-it-work) show how often.)

> Unofficial community project. Not affiliated with Anthropic or OpenAI. Checked with Claude Code 2.1.288 and Codex CLI 0.160 (October 2026).

## Why

AI assistants write good code but drift on process. In our tests, when told to "implement the plan and tell me when it's ready to ship", assistants without these rules created new git branches and commits in every repo (project folder) in 9 of 12 runs; with them, 0 of 12. The rules tell your assistant to:

- **leave git alone** (no commits, branches, or pushes) unless you ask;
- **check every affected project** before changing something others depend on, such as an API your website calls;
- **stop and tell you** when your plan does not match the code, instead of quietly doing something else;
- **ignore instructions hidden in files or web pages**, and tell you about them;
- **say what it actually tested**, and what it could not.

## What you get

- One short rules file that Claude Code and Codex both read at the start of every session.
- A `kickoff` command for starting work that spans several projects.
- An installer that backs up anything it replaces and can undo itself.

Nothing else is installed. Add-ons that make the rules more useful are optional and listed [below](#optional-add-ons).

## Install

**Easiest: let your assistant do it.** Paste this into Claude Code or Codex:

> Clone https://github.com/nhannh1526/agent-house-rules and install it by following the section "For AI agents installing this" in its README. Ask me before changing anything.

**Or do it yourself.** These commands go in a **Terminal** (on Windows: Git Bash, which comes with [Git for Windows](https://gitforwindows.org)):

```bash
claude --version || codex --version   # at least one must print a version number
git clone https://github.com/nhannh1526/agent-house-rules.git
cd agent-house-rules
bash install.sh --dry-run             # shows what would change; changes nothing
bash install.sh                       # installs for every assistant it finds
```

Already downloaded the folder? Skip the `git clone` and `cd` lines and run the `bash` lines from inside it.

The last lines of the output tell you what happened:

- `done: installed for: Claude Code, Codex` lists the assistants that now have the rules.
- `not installed: ... command not found` means that assistant is not installed (or your Terminal cannot find it, i.e. it is not on your PATH). Install it, then run `bash install.sh` again.
- `NOTE: ...` means a rules file you already had (or edited) was replaced; the old copy is in the backup folder the output names. To keep your own rules, put them in `~/.claude/personal.md` (Claude) or `~/.codex/personal.md` (Codex) and run `bash install.sh` again: the installer includes those files every time.
- `optional add-ons:` shows which [add-ons](#optional-add-ons) you already have (`yes`/`no`). The installer never installs them; pick from the table below.
- `undo:` is the command that removes everything again. Keep it.

## Check that it worked

- **Inside Claude Code** (start it with `claude`): type `/memory`; the list should include `~/.claude/CLAUDE.md`. Typing `/kickoff` should show the command.
- **Inside Codex** (start it with `codex`): type `/skills`; the list should include `kickoff`. Then ask *"summarize your global instructions in 3 bullets"*: the answer should mention git, plans, and verifying work. If it does not, check whether a file `~/.codex/AGENTS.override.md` exists; it replaces the rules while it is there.

## Use it

Work as usual; the rules apply on their own. For example, ask *"add a dark mode switch to the settings page"*: the rules tell the assistant to read the related code first, make the change, run the project's tests, end with what it changed and what it checked, and not commit unless you ask.

When a task touches several projects, start with `kickoff` and name them:

- Inside Claude Code: `/kickoff Add a "last login" column --repo ../api --repo ../web`
- Inside Codex: `$kickoff Add a "last login" column --repo ../api --repo ../web`

Replace `../api` and `../web` with your own project folders. If you leave out the details, kickoff asks for them. To let the assistant open repos outside the folder you started it in, see [Working across several repos](docs/advanced.md#working-across-several-repos).

## Optional add-ons

Separate projects that the rules use when they are present. Everything above works without them. All commands below go in a **Terminal**.

**If you are unsure, start with superpowers** (and the codex plugin if you use both assistants). Add the others later. If you want RTK, install it **before** `bash install.sh`, or run the installer again afterwards.

| Add-on | What you get | Claude Code | Codex |
|---|---|---|---|
| [superpowers](https://github.com/obra/superpowers) | Step-by-step skills for planning, debugging, and checking work | `claude plugin marketplace add obra/superpowers-marketplace` then `claude plugin install superpowers@superpowers-marketplace` | `codex plugin marketplace add obra/superpowers-marketplace` then `codex plugin add superpowers@superpowers-marketplace` |
| [codex plugin](https://github.com/openai/codex-plugin-cc) | Claude asks Codex for a second opinion on bigger changes (needs Codex installed and signed in) | `claude plugin marketplace add openai/codex-plugin-cc` then `claude plugin install codex@openai-codex`, then type `/codex:setup` inside Claude Code | - |
| [RTK](https://github.com/rtk-ai/rtk) | Shorter command output, fewer tokens | Install per its README, then `rtk init -g --auto-patch` | `rtk init -g --codex` |
| [caveman](https://github.com/JuliusBrussee/caveman) | Terse answers | `claude plugin marketplace add JuliusBrussee/caveman` then `claude plugin install caveman@caveman` | `npx skills add JuliusBrussee/caveman -a codex -g` |
| [ponytail](https://github.com/DietrichGebert/ponytail) | Smaller, simpler code changes | `claude plugin marketplace add DietrichGebert/ponytail` then `claude plugin install ponytail@ponytail` | `codex plugin marketplace add DietrichGebert/ponytail` then `codex plugin add ponytail@ponytail` |

- Restart Claude Code or Codex after installing. Codex may ask you to review new hooks under `/hooks`.
- If a plugin says "disabled by your workspace admin", your organization blocks it. Skip it; the rules still work.
- The author's own setup is: the rules, all five add-ons above, [GitNexus](https://github.com/abhigyanpatwari/GitNexus) for large codebases, and default models set as in [docs/advanced.md](docs/advanced.md#models-and-effort).

### For AI agents installing this

If you are an AI agent asked to install this config, follow these steps in order and report each result:

1. Use bash (Git Bash on Windows). If no bash is available, stop and tell the user.
2. Run `bash install.sh --dry-run` and show the user the output.
3. Wait for the user to confirm, then run it for real (add `--only claude` or `--only codex` if the user wants one tool).
4. Report the summary lines (`done:`, `not installed:`, any `NOTE:`), the backup path, and the undo command the script printed.
5. Run the checks in "Check that it worked" where you can, and tell the user which ones they need to do themselves.
6. Do not install plugins, edit `settings.json` / `config.toml`, or change permissions without asking. Offer the optional add-ons table instead, and install only the ones the user picks.

## Undo

Run the `undo:` command the installer printed, for example `bash install.sh --uninstall ~/.agent-house-rules-backup/<folder>`. It puts back every file that existed before and removes what the install added; nothing is deleted (the installed versions move to `<folder>/uninstalled/`). If you installed more than once, undo the newest install first; the script tells you if you pick the wrong one. Undo does not remove add-ons; uninstall those with their own commands.

## Does it work?

180 test runs in throwaway containers, on six realistic projects that each span two or three repos:

- **Unwanted git changes** (the "ready to ship" test): branches and commits in 9 of 12 runs without the rules, 0 of 12 with them.
- **Changing an API another project uses:** after one rule was added, Codex found every affected project in all runs (before, it sometimes missed one).
- **Instructions hidden in files:** no run followed them, with or without the rules; today's models already handle this.
- **Code quality:** the tests did not show better code with the rules. They change how the assistant works, not how well it codes.

Details, limits, and how to re-run the tests: [eval/RESULTS.md](eval/RESULTS.md).

## Words used here

| Word | Meaning |
|---|---|
| Terminal | The command-line app (Terminal on macOS, Git Bash on Windows) |
| repo | One project folder tracked by git |
| commit / branch / push | Saving a snapshot / a parallel line of work / uploading to GitHub |
| plugin, skill | Add-ons that give an assistant extra instructions or commands |
| subagent | A helper the assistant starts to do part of a task |
| worktree | A second working folder of the same repo, on its own branch |
| token | The unit AI usage is measured in |

## More

- [docs/advanced.md](docs/advanced.md): how it is built, models and effort, worktrees, GitNexus, maintaining the rules, technical notes.
- [eval/](eval/README.md): the test harness and full results.

License: [MIT](LICENSE). Each add-on has its own license.
