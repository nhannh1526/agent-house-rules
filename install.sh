#!/usr/bin/env bash
# Install or uninstall agent-house-rules for Claude Code and/or Codex CLI (macOS, Linux, WSL, Git Bash).
#   bash install.sh [--only claude|codex] [--no-rtk] [--dry-run]
#   bash install.sh --uninstall <backup-dir>
# core/rules.md is the single source of the shared rules. Claude imports it; for tools that read
# AGENTS.md without import support (Codex) the installer writes
# AGENTS.md = [core/rtk.md] + core/rules.md + agents/specifics.md.
# Every target that already exists is copied into a fresh backup dir with a manifest; uninstall
# validates the whole manifest first, then restores those; current versions are kept, never deleted.
set -euo pipefail

SELF="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"
SRC="$(dirname "$SELF")"
CODEX_DIR="${CODEX_HOME:-$HOME/.codex}"
# Manifest paths must not depend on the directory uninstall runs from.
case "$CODEX_DIR" in /* | [A-Za-z]:*) ;; *) CODEX_DIR="$PWD/$CODEX_DIR" ;; esac
ONLY="" NO_RTK=0 DRY=0 UNINSTALL=""

while [ $# -gt 0 ]; do
  case "$1" in
    --only) ONLY="${2:?--only needs claude or codex}"; shift 2 ;;
    --no-rtk) NO_RTK=1; shift ;;
    --dry-run) DRY=1; shift ;;
    --uninstall) UNINSTALL="${2:?--uninstall needs a backup dir}"; shift 2 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
done
# Adding a tool: extend this list, add <TOOL>_TARGETS + gen_ functions, and a selection block below.
case "$ONLY" in ""|claude|codex) ;; *) echo "--only must be claude or codex" >&2; exit 2 ;; esac

run() { if [ "$DRY" = 1 ]; then echo "would: $*"; else "$@"; fi; }
exists() { [ -e "$1" ] || [ -L "$1" ]; }

# Targets: "<kind>:<source>|<destination>". kind=copy copies a file/dir; kind=gen runs gen_<source>.
# These destinations are the only paths this script ever writes or deletes.
CLAUDE_TARGETS=("gen:claude_md|$HOME/.claude/CLAUDE.md" "copy:core/rules.md|$HOME/.claude/house-rules.md" "copy:claude/skills/kickoff|$HOME/.claude/skills/kickoff")
CODEX_TARGETS=("gen:codex_agents|$CODEX_DIR/AGENTS.md" "copy:agents/skills/kickoff|$HOME/.agents/skills/kickoff")
allowed() { local t; for t in "${CLAUDE_TARGETS[@]}" "${CODEX_TARGETS[@]}"; do [ "${t#*|}" = "$1" ] && return 0; done; return 1; }

# RTK is optional: its line is included only when RTK.md sits next to the tool's global file.
use_rtk() { [ "$NO_RTK" = 0 ] && [ -f "$1/RTK.md" ]; }
# Every step returns its own status: these run under ||, where set -e does not apply.
gen_claude_md() {
  if use_rtk "$HOME/.claude"; then echo "@RTK.md" || return 1; fi
  cat "$SRC/claude/CLAUDE.md" || return 1
  # Personal rules live in their own file so reinstalls never drop them.
  if [ -f "$HOME/.claude/personal.md" ]; then printf '\n@personal.md\n'; fi
}
gen_agents_md() { # $1 = tool home that will hold AGENTS.md
  if use_rtk "$1"; then { cat "$SRC/core/rtk.md" && echo; } || return 1; fi
  cat "$SRC/core/rules.md" && echo && cat "$SRC/agents/specifics.md" || return 1
  if [ -f "$1/personal.md" ]; then echo && cat "$1/personal.md"; fi
}
gen_codex_agents() { gen_agents_md "$CODEX_DIR"; }

if [ -n "$UNINSTALL" ]; then
  manifest="$UNINSTALL/manifest.tsv"
  [ -f "$manifest" ] || { echo "no manifest at $manifest" >&2; exit 1; }
  [ -s "$manifest" ] && [ -z "$(tail -c 1 "$manifest")" ] || { echo "manifest is empty or truncated" >&2; exit 1; }
  # Validate every row before touching anything; apply exactly the validated rows.
  ids=() flags=() paths=() seen="|"
  while IFS=$'\t' read -r id existed target; do
    [[ "$id" =~ ^[0-9]+$ ]] || { echo "bad id in manifest: $id" >&2; exit 1; }
    [[ "$existed" =~ ^[01]$ ]] || { echo "bad flag in manifest: $existed" >&2; exit 1; }
    allowed "$target" || { echo "refusing: $target is not an agent-house-rules target" >&2; exit 1; }
    case "$seen" in *"|id:$id|"* | *"|$target|"*) echo "duplicate row in manifest: $id $target" >&2; exit 1 ;; esac
    seen="$seen""id:$id|$target|"
    if [ "$existed" = 1 ] && ! exists "$UNINSTALL/$id"; then echo "missing backup $UNINSTALL/$id" >&2; exit 1; fi
    ids+=("$id"); flags+=("$existed"); paths+=("$target")
  done < "$manifest"
  # Undo newest first: an older backup holds the files from before the newer install, so undoing
  # it first would let the newer undo bring the older install back.
  # ponytail: order = backup-dir name (timestamp first); two installs in the same second may misorder.
  kept="$UNINSTALL/uninstalled" self_name="$(basename "$UNINSTALL")" newer=""
  # A finished uninstall stays finished: re-running it must not resurrect files deleted since.
  if [ -e "$kept/.complete" ]; then echo "already undone: $UNINSTALL"; exit 0; fi
  for d in "$(dirname "$UNINSTALL")"/*; do
    if [ -f "$d/manifest.tsv" ] && [ ! -e "$d/uninstalled/.complete" ] && [[ "$(basename "$d")" > "$self_name" ]]; then newer="$d"; fi
  done
  if [ -n "$newer" ]; then
    echo "refusing: a newer install is still active; undo it first:" >&2
    printf '  bash %q --uninstall %q\n' "$SELF" "$newer" >&2
    exit 1
  fi
  # Nothing is deleted: the current version of each target (including any edits made after install)
  # moves to <backup-dir>/uninstalled/<id>; a restore is staged next to the target before it swaps in.
  # Rows already moved aside are skipped or finished, so a failed uninstall can simply be re-run.
  [ "$DRY" = 1 ] || mkdir -p "$kept"
  for n in "${!ids[@]}"; do
    id="${ids[$n]}" target="${paths[$n]}" moved=0
    if exists "$kept/$id"; then
      if [ "${flags[$n]}" = 0 ] || exists "$target"; then echo "already undone: $target"; continue; fi
      moved=1 # an earlier run moved the target aside but did not restore it
    fi
    if [ "$DRY" = 1 ]; then
      if [ "${flags[$n]}" = 1 ]; then echo "would: move $target to $kept/$id, then restore backup $id"; else echo "would: move $target to $kept/$id"; fi
      continue
    fi
    staged=""
    if [ "${flags[$n]}" = 1 ]; then
      mkdir -p "$(dirname "$target")"  # the folder may have been deleted since install
      staged=$(mktemp -d "$(dirname "$target")/.house-rules.XXXXXX")
      cp -RP "$UNINSTALL/$id" "$staged/item" || { rm -rf "$staged"; echo "failed to stage restore of $target" >&2; exit 1; }
    fi
    if [ "$moved" = 0 ] && exists "$target"; then
      mv "$target" "$kept/$id" || { [ -z "$staged" ] || rm -rf "$staged"; echo "failed to move $target aside; fix and re-run" >&2; exit 1; }
    fi
    if [ -n "$staged" ]; then mv "$staged/item" "$target"; rmdir "$staged"; echo "restored $target"; else echo "removed $target"; fi
  done
  [ "$DRY" = 1 ] || { : > "$kept/.complete"; echo "previous versions kept in $kept"; }
  exit 0
fi

want() { [ -z "$ONLY" ] || [ "$ONLY" = "$1" ]; }
targets=()
add_targets() { # skip destinations already listed (tools that read AGENTS.md can share ~/.agents/skills)
  local t u dup; for t in "$@"; do dup=0
    for u in ${targets[@]+"${targets[@]}"}; do [ "${u#*|}" = "${t#*|}" ] && dup=1; done
    [ "$dup" = 1 ] || targets+=("$t"); done; }
done_tools="" skipped=""
pick() { # $1 = tool, $2 = display name, $3 = command; rest = targets
  local tool="$1" name="$2" cmd="$3"; shift 3
  if ! want "$tool"; then skipped="$skipped  - $name: not selected (--only)\n"
  elif ! command -v "$cmd" >/dev/null 2>&1; then skipped="$skipped  - $name: '$cmd' command not found; install $name, then run this again\n"
  else add_targets "$@"; done_tools="$done_tools $name,"; fi
}
pick claude "Claude Code" claude "${CLAUDE_TARGETS[@]}"
pick codex "Codex" codex "${CODEX_TARGETS[@]}"
[ -z "$skipped" ] || printf 'skipping:\n%b' "$skipped"
[ ${#targets[@]} -gt 0 ] || { echo "nothing to install" >&2; exit 1; }
# A target inside another (e.g. CODEX_HOME pointing into a skill folder) would be overwritten twice.
for t in "${targets[@]}"; do for u in "${targets[@]}"; do
  case "${t#*|}" in "${u#*|}"/*) echo "refusing: ${t#*|} is inside ${u#*|}" >&2; exit 1 ;; esac
done; done

# Backup folders sort in install order (uninstall relies on it): a counter first, then the time.
broot="$HOME/.agent-house-rules-backup"
seq=$(( $(cat "$broot/.seq" 2>/dev/null || echo 0) + 1 ))
backup="$broot/$(printf '%06d' "$seq")-$(date +%Y%m%d%H%M%S)-$$"
if [ "$DRY" = 1 ]; then echo "would: create $backup"
else
  mkdir -p "$broot"; mkdir "$backup"; echo "$seq" > "$broot/.seq"
  # Recovery info comes before the first change, so a failed install can still be undone.
  echo "backup: $backup"
  # Uninstall only accepts targets it would install now, so a custom CODEX_HOME must come along.
  if [ -n "${CODEX_HOME:-}" ]; then printf 'undo:   CODEX_HOME=%q bash %q --uninstall %q\n' "$CODEX_DIR" "$SELF" "$backup"
  else printf 'undo:   bash %q --uninstall %q\n' "$SELF" "$backup"; fi
fi

i=0
for t in "${targets[@]}"; do
  spec="${t%%|*}" dst="${t#*|}"; kind="${spec%%:*}" src="${spec#*:}"; i=$((i + 1))
  if exists "$dst"; then run cp -RP "$dst" "$backup/$i"; existed=1; else existed=0; fi
  # Text in a file this replaces would silently stop applying: say so whenever the content changes.
  if [ -f "$dst" ] && [ "$kind" = gen ]; then
    preview=$(mktemp "${TMPDIR:-/tmp}/house-rules.XXXXXX")
    "gen_$src" > "$preview" || { rm -f "$preview"; echo "failed to generate $dst" >&2; exit 1; }
    if ! cmp -s "$preview" "$dst" && grep -vqE '^[[:space:]]*$|^@.*RTK\.md$' "$dst"; then
      if grep -qE '^(@house-rules\.md|# Agent Operating Rules)$' "$dst"; then why="was edited or comes from another version"
      else why="has your own instructions"; fi
      if [ "$DRY" = 1 ]; then what="would be replaced (a copy would be kept in the backup)"
      else what="is replaced (old copy: $backup/$i)"; fi
      echo "NOTE: $dst $why; it $what. Keep personal rules in $(dirname "$dst")/personal.md: the installer includes that file."
    fi
    rm -f "$preview"
  fi
  [ "$DRY" = 1 ] || printf '%s\t%s\t%s\n' "$i" "$existed" "$dst" >> "$backup/manifest.tsv"
  if [ "$DRY" = 1 ]; then echo "would: install $dst"; continue; fi
  mkdir -p "$(dirname "$dst")"
  # Build the new content next to the destination, then swap it in.
  tmp=$(mktemp -d "$(dirname "$dst")/.house-rules.XXXXXX")
  if [ "$kind" = gen ]; then
    "gen_$src" > "$tmp/new" || { rm -rf "$tmp"; echo "failed to generate $dst" >&2; exit 1; }
  else
    cp -R "$SRC/$src" "$tmp/new" || { rm -rf "$tmp"; echo "failed to copy $src" >&2; exit 1; }
  fi
  # A file renames atomically over a file; a symlink or directory at the destination is removed first
  # (rm on a symlink removes only the link) so mv never writes through it.
  if [ -L "$dst" ] || [ -d "$dst" ]; then rm -rf "$dst"; fi
  mv -f "$tmp/new" "$dst"
  rmdir "$tmp"
  echo "installed $dst"
done
if [ "$DRY" = 1 ]; then echo "dry run: would install for:${done_tools%,}"
else echo "done: installed for:${done_tools%,}. Undo with the command printed above."; fi
[ -z "$skipped" ] || printf 'not installed:\n%b' "$skipped"

# Optional add-ons: report only; this script never installs them (see README, "Optional add-ons").
yn() { if "$@"; then printf yes; else printf no; fi; }
# Codex plugin table in config.toml: yes, disabled, or no (either quote style).
cx_plugin() { awk -v p="$2" -v q="'" 'BEGIN { s = "no" }
  /^[[:space:]]*\[/ { inside = 0 }
  $0 ~ ("^[[:space:]]*\\[plugins\\.[\"" q "]" p "@") { inside = 1; s = "yes"; next }
  inside && /^[[:space:]]*enabled[[:space:]]*=[[:space:]]*false/ { s = "disabled" }
  END { print s }' "$1" 2>/dev/null || printf no; }
in_file() { [ -f "$1" ] && grep -q "$2" "$1"; }
cp_json="$HOME/.claude/plugins/installed_plugins.json" cx_toml="$CODEX_DIR/config.toml"
echo "optional add-ons (README > Optional add-ons):"
case "$done_tools" in *"Claude Code"*)
  echo "  Claude Code: superpowers $(yn in_file "$cp_json" '"superpowers@'), codex plugin $(yn in_file "$cp_json" '"codex@openai-codex"'), ponytail $(yn in_file "$cp_json" '"ponytail@'), caveman $(yn in_file "$cp_json" '"caveman@'), RTK $(yn test -f "$HOME/.claude/RTK.md")" ;; esac
case "$done_tools" in *Codex*)
  echo "  Codex: superpowers $(cx_plugin "$cx_toml" superpowers), ponytail $(cx_plugin "$cx_toml" ponytail), caveman $(yn test -f "$HOME/.agents/skills/caveman/SKILL.md"), RTK $(yn test -f "$CODEX_DIR/RTK.md")" ;; esac
