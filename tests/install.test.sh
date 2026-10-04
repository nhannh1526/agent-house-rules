#!/usr/bin/env bash
# Installer self-check: runs install.sh against throwaway HOMEs with stub `claude`/`codex` on PATH.
# Never touches the real HOME. Usage: bash tests/install.test.sh
set -u

REPO="$(cd "$(dirname "$0")/.." && pwd)"
ROOT="$(mktemp -d "${TMPDIR:-/tmp}/ahr-test.XXXXXX")"
trap 'chmod -R u+w "$ROOT" 2>/dev/null; rm -rf "$ROOT"' EXIT
STUB="$ROOT/stub"; mkdir -p "$STUB"
for t in claude codex; do printf '#!/bin/sh\nexit 0\n' > "$STUB/$t"; chmod +x "$STUB/$t"; done
PASS=0 FAIL=0

ok() { PASS=$((PASS + 1)); echo "ok   $1"; }
bad() { FAIL=$((FAIL + 1)); echo "FAIL $1"; }
check() { local name="$1"; shift; if "$@"; then ok "$name"; else bad "$name"
  # For remote debugging: show the tail of the file a failed grep looked at.
  local last="${!#}"; [ -f "$last" ] && tail -n 8 "$last" | sed 's/^/     | /'; fi; }
not() { ! "$@"; }
# chmod 555 only blocks writes on POSIX filesystems for non-root users (not on Windows/NTFS).
perms_enforced() { local d; d="$(mktemp -d "$ROOT/perm.XXXXXX")"; chmod 555 "$d"
  if touch "$d/probe" 2>/dev/null; then chmod 755 "$d"; return 1; fi; chmod 755 "$d"; return 0; }

# Fresh HOME per scenario; the space in the name exercises quoting.
new_home() { H="$ROOT/home $1"; mkdir -p "$H"; unset CODEX_HOME; }
# Run install.sh as the user would, with only the stub tools and the base system on PATH.
inst() { HOME="$H" PATH="$STUB:/usr/bin:/bin" bash "$REPO/install.sh" "$@"; }
# Tree snapshot (type, path, content checksum or link target), excluding our own backup folder.
snap() {
  (cd "$H" && find . -path ./.agent-house-rules-backup -prune -o -print | LC_ALL=C sort | while IFS= read -r p; do
    if [ -L "$p" ]; then echo "L $p -> $(readlink "$p")"
    elif [ -d "$p" ]; then echo "D $p"
    else echo "F $p $(cksum < "$p")"; fi
  done)
}
files_only() { grep -v '^D '; }
backup_of() { sed -n 's/^backup: //p' "$1"; }
first_line() { head -n 1 "$1"; }

seed_existing() { # a HOME that already has every target, a symlinked target, and RTK.md for both tools
  mkdir -p "$H/.claude/skills/kickoff" "$H/.codex" "$H/.agents/skills/kickoff" "$H/dotfiles"
  printf '@RTK.md\n# my personal rules\n' > "$H/.claude/CLAUDE.md"
  echo "rtk claude" > "$H/.claude/RTK.md"
  echo "my shared rules" > "$H/dotfiles/house-rules.md"
  ln -s "$H/dotfiles/house-rules.md" "$H/.claude/house-rules.md"
  echo "old kickoff" > "$H/.claude/skills/kickoff/SKILL.md"; echo "extra" > "$H/.claude/skills/kickoff/notes.md"
  printf '@%s/.codex/RTK.md\n' "$H" > "$H/.codex/AGENTS.md"
  echo "rtk codex" > "$H/.codex/RTK.md"
  echo "old codex kickoff" > "$H/.agents/skills/kickoff/SKILL.md"
}

echo "# 1. dry run writes nothing"
new_home dry; before="$(snap)"
inst --dry-run > "$ROOT/out" 2>&1
check "dry run exit 0" [ $? -eq 0 ]
check "dry run leaves HOME untouched" [ "$before" = "$(snap)" ]
check "dry run creates no backup dir" [ ! -e "$H/.agent-house-rules-backup" ]

echo "# 2. fresh install, then uninstall"
new_home fresh; before="$(snap | files_only)"
inst > "$ROOT/out" 2>&1; rc=$?
check "install exit 0" [ $rc -eq 0 ]
check "summary names both tools" grep -q "^done: installed for: Claude Code, Codex" "$ROOT/out"
check "no personal-file note on a fresh HOME" not grep -q "^NOTE:" "$ROOT/out"
check "add-on report shows missing superpowers for Claude" grep -q "^  Claude Code: superpowers no," "$ROOT/out"
check "add-on report covers Codex" grep -q "^  Codex: superpowers no, ponytail no, caveman no, RTK no" "$ROOT/out"
check "CLAUDE.md imports house-rules.md" [ "$(first_line "$H/.claude/CLAUDE.md")" = "@house-rules.md" ]
check "house-rules.md = core/rules.md" cmp -s "$H/.claude/house-rules.md" "$REPO/core/rules.md"
check "claude kickoff installed" cmp -s "$H/.claude/skills/kickoff/SKILL.md" "$REPO/claude/skills/kickoff/SKILL.md"
check "codex kickoff + openai.yaml installed" [ -f "$H/.agents/skills/kickoff/agents/openai.yaml" ]
check "AGENTS.md starts with the rules (no RTK)" [ "$(first_line "$H/.codex/AGENTS.md")" = "$(first_line "$REPO/core/rules.md")" ]
check "AGENTS.md contains specifics" grep -q "AGENTS.md tool specifics" "$H/.codex/AGENTS.md"
check "no temp dirs left" [ -z "$(find "$H" -name '.house-rules.*')" ]
b="$(backup_of "$ROOT/out")"
inst --uninstall "$b" > "$ROOT/out2" 2>&1
check "uninstall exit 0" [ $? -eq 0 ]
check "uninstall removes every installed file (empty parent dirs stay)" [ "$before" = "$(snap | files_only)" ]
check "installed files kept in uninstalled/" [ -f "$b/uninstalled/1" ]
cp "$b/uninstalled/1" "$ROOT/kept1"
inst --uninstall "$b" > "$ROOT/out3" 2>&1
check "second uninstall is a no-op" [ $? -eq 0 ]
check "second uninstall changes nothing" [ "$before" = "$(snap | files_only)" ]
check "kept versions not overwritten" cmp -s "$b/uninstalled/1" "$ROOT/kept1"

echo "# 3. existing files, symlink, RTK present"
new_home existing; seed_existing; before="$(snap)"
inst > "$ROOT/out" 2>&1
check "install exit 0" [ $? -eq 0 ]
check "add-on report sees RTK for Claude" grep -q "^  Claude Code: .*RTK yes$" "$ROOT/out"
check "add-on report sees RTK for Codex" grep -q "^  Codex: .*RTK yes$" "$ROOT/out"
check "note warns that personal CLAUDE.md content is replaced" grep -q "^NOTE: .*/.claude/CLAUDE.md has your own instructions" "$ROOT/out"
check "no note for an AGENTS.md that only held RTK's line" not grep -q "^NOTE: .*AGENTS.md" "$ROOT/out"
check "CLAUDE.md keeps @RTK.md first" [ "$(first_line "$H/.claude/CLAUDE.md")" = "@RTK.md" ]
check "CLAUDE.md imports house-rules.md" grep -qx "@house-rules.md" "$H/.claude/CLAUDE.md"
check "AGENTS.md starts with RTK instruction" [ "$(first_line "$H/.codex/AGENTS.md")" = "$(first_line "$REPO/core/rtk.md")" ]
check "RTK's @path line replaced" not grep -q "^@" "$H/.codex/AGENTS.md"
check "symlink replaced by a real file" [ ! -L "$H/.claude/house-rules.md" ]
check "symlink target untouched" [ "$(cat "$H/dotfiles/house-rules.md")" = "my shared rules" ]
check "old kickoff dir replaced (no stray files)" [ ! -e "$H/.claude/skills/kickoff/notes.md" ]
check "RTK.md files untouched" [ "$(cat "$H/.claude/RTK.md")$(cat "$H/.codex/RTK.md")" = "rtk claudertk codex" ]
inst --uninstall "$(backup_of "$ROOT/out")" > "$ROOT/out2" 2>&1
check "uninstall exit 0" [ $? -eq 0 ]
check "uninstall restores files, dirs and symlink exactly" [ "$before" = "$(snap)" ]

echo "# 4. install twice, uninstall newest then oldest"
new_home twice; seed_existing; before="$(snap)"
inst > "$ROOT/out1" 2>&1; mid="$(snap)"
inst > "$ROOT/out2" 2>&1
check "re-install does not warn about its own files" not grep -q "^NOTE:" "$ROOT/out2"
inst --uninstall "$(backup_of "$ROOT/out2")" > /dev/null 2>&1
check "undo 2nd install returns to 1st install" [ "$mid" = "$(snap)" ]
inst --uninstall "$(backup_of "$ROOT/out1")" > /dev/null 2>&1
check "undo 1st install returns to original" [ "$before" = "$(snap)" ]

echo "# 5. --only and --no-rtk"
new_home only; inst --only claude > "$ROOT/out" 2>&1
check "--only claude: summary lists Codex as not selected" grep -q "Codex: not selected" "$ROOT/out"
check "--only claude: Claude installed" [ -f "$H/.claude/CLAUDE.md" ]
check "--only claude: Codex untouched" [ ! -e "$H/.codex" -a ! -e "$H/.agents" ]
new_home nortk; seed_existing; inst --no-rtk > /dev/null 2>&1
check "--no-rtk: no @RTK.md in CLAUDE.md" not grep -q "@RTK.md" "$H/.claude/CLAUDE.md"
check "--no-rtk: no RTK line in AGENTS.md" not grep -qF "$(cat "$REPO/core/rtk.md")" "$H/.codex/AGENTS.md"
new_home badopt; inst --only gemini > /dev/null 2>&1
check "--only with unknown tool rejected" [ $? -eq 2 ]

echo "# 6. no tools on PATH"
new_home notools; before="$(snap)"
HOME="$H" PATH="/usr/bin:/bin" bash "$REPO/install.sh" > /dev/null 2>&1
check "nothing to install exits non-zero" [ $? -ne 0 ]
check "nothing written" [ "$before" = "$(snap)" ]

echo "# 7. custom CODEX_HOME"
new_home codexhome; before="$(snap | files_only)"
CODEX_HOME="$H/custom codex" inst > "$ROOT/out" 2>&1
check "AGENTS.md written to CODEX_HOME" [ -f "$H/custom codex/AGENTS.md" -a ! -e "$H/.codex" ]
undo="$(sed -n 's/^undo: *//p' "$ROOT/out")"
( export HOME="$H" PATH="$STUB:/usr/bin:/bin"; eval "$undo" ) > /dev/null 2>&1
check "printed undo carries CODEX_HOME and restores" [ "$before" = "$(snap | files_only)" ]

echo "# 8. tampered manifest"
new_home tamper; inst > "$ROOT/out" 2>&1; b="$(backup_of "$ROOT/out")"; after="$(snap)"
cp "$b/manifest.tsv" "$ROOT/manifest.ok"
printf '99\t0\t%s\n' "$H/.ssh/id_rsa" >> "$b/manifest.tsv"
inst --uninstall "$b" > /dev/null 2>&1
check "foreign path in manifest refused" [ $? -ne 0 ]
check "refused uninstall changes nothing" [ "$after" = "$(snap)" ]
head -c 20 "$ROOT/manifest.ok" > "$b/manifest.tsv"
inst --uninstall "$b" > /dev/null 2>&1
check "truncated manifest refused" [ $? -ne 0 ]
check "truncated manifest changes nothing" [ "$after" = "$(snap)" ]

echo "# 9. install fails midway, undo still restores"
if ! perms_enforced; then echo "skip (this filesystem or user ignores read-only folders, e.g. root or Windows)"; else
  new_home partial; seed_existing; before="$(snap)"
  chmod 555 "$H/.agents/skills"
  inst > "$ROOT/out" 2>&1
  check "failed install exits non-zero" [ $? -ne 0 ]
  chmod 755 "$H/.agents/skills"
  inst --uninstall "$(backup_of "$ROOT/out")" > /dev/null 2>&1
  check "undo after failed install restores original" [ "$before" = "$(snap)" ]
fi

echo "# 10. uninstall fails midway, rerun finishes it"
if ! perms_enforced; then echo "skip (this filesystem or user ignores read-only folders, e.g. root or Windows)"; else
  new_home resume; seed_existing; before="$(snap)"
  inst > "$ROOT/out" 2>&1; b="$(backup_of "$ROOT/out")"
  chmod 555 "$H/.codex"
  inst --uninstall "$b" > /dev/null 2>&1
  check "blocked uninstall exits non-zero" [ $? -ne 0 ]
  chmod 755 "$H/.codex"
  inst --uninstall "$b" > /dev/null 2>&1
  check "rerun uninstall exits 0" [ $? -eq 0 ]
  check "rerun uninstall restores original" [ "$before" = "$(snap)" ]
fi

echo "# 11. out-of-order uninstall is refused"
new_home order; seed_existing; before="$(snap)"
inst > "$ROOT/out1" 2>&1; inst > "$ROOT/out2" 2>&1; latest="$(snap)"
inst --uninstall "$(backup_of "$ROOT/out1")" > "$ROOT/out3" 2>&1
check "undoing an older install first is refused" [ $? -ne 0 ]
check "refusal names the newer undo" grep -qF "$(basename "$(backup_of "$ROOT/out2")")" "$ROOT/out3"
check "refusal changes nothing" [ "$latest" = "$(snap)" ]
inst --uninstall "$(backup_of "$ROOT/out2")" > /dev/null 2>&1
inst --uninstall "$(backup_of "$ROOT/out1")" > /dev/null 2>&1
check "newest-first undo returns to original" [ "$before" = "$(snap)" ]

echo "# 12. relative CODEX_HOME, undo from another directory"
new_home relcodex; mkdir -p "$H/proj" "$H/elsewhere"; before="$(snap | files_only)"
(cd "$H/proj" && CODEX_HOME="rel codex" inst > "$ROOT/out" 2>&1)
check "relative CODEX_HOME resolved against cwd" [ -f "$H/proj/rel codex/AGENTS.md" ]
undo="$(sed -n 's/^undo: *//p' "$ROOT/out")"
(cd "$H/elsewhere" && export HOME="$H" PATH="$STUB:/usr/bin:/bin" && eval "$undo") > /dev/null 2>&1
check "undo from another directory restores original" [ "$before" = "$(snap | files_only)" ]

echo "# 13. CODEX_HOME overlapping another target is refused"
new_home overlap; before="$(snap)"
CODEX_HOME="$H/.agents/skills/kickoff" inst > /dev/null 2>&1
check "overlapping CODEX_HOME refused" [ $? -ne 0 ]
check "overlap refusal writes nothing" [ "$before" = "$(snap)" ]

echo "# 14. finished uninstall stays finished; restore recreates a deleted parent folder"
new_home again; seed_existing; inst > "$ROOT/out" 2>&1; b="$(backup_of "$ROOT/out")"
inst --uninstall "$b" > /dev/null 2>&1
rm "$H/.claude/CLAUDE.md"; after="$(snap)"
inst --uninstall "$b" > /dev/null 2>&1
check "re-running a finished uninstall exits 0" [ $? -eq 0 ]
check "re-running a finished uninstall changes nothing" [ "$after" = "$(snap)" ]
new_home parent; seed_existing; before="$(snap)"; inst > "$ROOT/out" 2>&1
rm -rf "$H/.codex"
inst --uninstall "$(backup_of "$ROOT/out")" > /dev/null 2>&1
check "undo after the target's folder was deleted exits 0" [ $? -eq 0 ]
check "restored AGENTS.md matches the original" [ "$(cat "$H/.codex/AGENTS.md" 2>/dev/null)" = "@$H/.codex/RTK.md" ]

echo "# 15. personal.md is included and survives reinstalls; hand edits are reported"
new_home personal; mkdir -p "$H/.claude" "$H/.codex"
echo "Always answer in Vietnamese." > "$H/.claude/personal.md"; echo "Prefer pnpm." > "$H/.codex/personal.md"
inst > /dev/null 2>&1
check "CLAUDE.md imports personal.md" grep -qx "@personal.md" "$H/.claude/CLAUDE.md"
check "AGENTS.md includes Codex personal.md" grep -qx "Prefer pnpm." "$H/.codex/AGENTS.md"
echo "my hand edit" >> "$H/.claude/CLAUDE.md"
inst --dry-run > "$ROOT/out" 2>&1
check "dry run warns about a hand-edited CLAUDE.md, in conditional words" grep -q "^NOTE: .*CLAUDE.md was edited or comes from another version; it would be replaced" "$ROOT/out"
inst > "$ROOT/out" 2>&1
check "install warns about the hand edit and names the backup" grep -q "^NOTE: .*CLAUDE.md was edited or comes from another version; it is replaced (old copy: " "$ROOT/out"
check "personal.md still applies after reinstall" grep -qx "@personal.md" "$H/.claude/CLAUDE.md"

echo "# 16. add-on report: quote styles, disabled plugins, per tool"
new_home addons; mkdir -p "$H/.claude/plugins" "$H/.codex" "$H/.agents/skills/caveman"
printf '{"plugins":{"superpowers@superpowers-marketplace":[],"codex@openai-codex":[]}}\n' > "$H/.claude/plugins/installed_plugins.json"
printf "[plugins.'superpowers@superpowers-marketplace']\nenabled = true\n\n[plugins.\"ponytail@ponytail\"]\nenabled = false\n" > "$H/.codex/config.toml"
echo "rtk" > "$H/.codex/RTK.md"
inst > "$ROOT/out" 2>&1
check "Claude report sees installed plugins" grep -q "^  Claude Code: superpowers yes, codex plugin yes, ponytail no, caveman no, RTK no$" "$ROOT/out"
check "Codex report: single quotes, disabled, empty caveman folder, RTK" grep -q "^  Codex: superpowers yes, ponytail disabled, caveman no, RTK yes$" "$ROOT/out"

echo "# 17. backup folders sort in install order"
new_home order2; inst > "$ROOT/o1" 2>&1; inst > "$ROOT/o2" 2>&1
b1="$(basename "$(backup_of "$ROOT/o1")")"; b2="$(basename "$(backup_of "$ROOT/o2")")"
check "second backup sorts after the first" [ "$b2" \> "$b1" ]
check "backup names start with a counter" [ "${b1%%-*}" = "000001" -a "${b2%%-*}" = "000002" ]

echo
echo "bash $BASH_VERSION: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
