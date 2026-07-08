#!/usr/bin/env bash
# edit-agents — toggle Claude Code agents between enabled and parked.
#
# Layout assumed:
#   <root>/<agent>.md            enabled (loaded by Claude Code at session start)
#   <root>-parked/<agent>.md     parked  (NOT loaded — sibling dir outside <root>)
#
# WHY a sibling: Claude Code scans <root> RECURSIVELY. A <root>/disabled/
# subfolder would still be loaded into the roster. Parked agents must live
# OUTSIDE the agents/ tree.
#
# Default <root>: $PWD/.claude/agents if it exists, else $HOME/.claude/agents.
# Override with `--scope project|user` or `--dir <path>`.
#
# Categories are OPTIONAL and user-configured. If a config exists (see below),
# `enable-category`/`disable-category`/`categories` operate on it; otherwise
# they print a helpful message. `list`/`enable`/`disable` never require it.

set -euo pipefail

# Requires bash 4+ for associative arrays (`declare -A`).
# macOS ships bash 3.2 as /bin/bash — install `bash` via Homebrew and put it
# earlier on $PATH, or invoke this script explicitly with a newer bash.
if [[ "${BASH_VERSINFO[0]:-0}" -lt 4 ]]; then
  echo "edit-agents: requires bash 4+ (found ${BASH_VERSION:-unknown})" >&2
  echo "  macOS: brew install bash, then rerun." >&2
  exit 1
fi

# ---------- resolve categories config ----------
#
# Search order:
#   1. $CLAUDE_EDIT_AGENTS_CATEGORIES  (env override — absolute path)
#   2. $XDG_CONFIG_HOME/edit-agents/categories  (or ~/.config/... if unset)
#
# File format (one category per line, blank/`#` lines ignored):
#
#   review:   architect-review code-explorer commit-guardian
#   security: crypto-security-reviewer penetration-tester
#
# Names must match agent file basenames (without `.md`).

CATEGORIES_FILE="${CLAUDE_EDIT_AGENTS_CATEGORIES:-${XDG_CONFIG_HOME:-$HOME/.config}/edit-agents/categories}"

declare -A CATEGORIES=()
if [[ -f "$CATEGORIES_FILE" ]]; then
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%%#*}"                    # strip trailing comments
    line="${line#"${line%%[![:space:]]*}"}"  # ltrim
    [[ -z "$line" ]] && continue
    [[ "$line" != *:* ]] && continue
    key="${line%%:*}"
    val="${line#*:}"
    key="${key%"${key##*[![:space:]]}"}"  # rtrim key
    val="${val#"${val%%[![:space:]]*}"}"  # ltrim val
    val="${val%"${val##*[![:space:]]}"}"  # rtrim val
    [[ -z "$key" || -z "$val" ]] && continue
    CATEGORIES["$key"]="$val"
  done < "$CATEGORIES_FILE"
fi

# ---------- arg parse ----------
SCOPE=""
DIR=""
while [[ $# -gt 0 && "$1" == --* ]]; do
  case "$1" in
    --scope) SCOPE="$2"; shift 2 ;;
    --dir)   DIR="$2";   shift 2 ;;
    --help|-h)
      cat <<'EOF'
edit-agents — toggle Claude Code agents between enabled and parked.

Layout:
  <root>/<agent>.md          enabled (loaded at session start)
  <root>-parked/<agent>.md   parked  (sibling outside <root>; NOT loaded)

Default <root>: ./.claude/agents if present, else ~/.claude/agents.
Override with --scope project|user, or --dir <path>.

Commands:
  list [enabled|parked|all]           Show agents (default: all)
  enable <agent>...                   Move from parked → enabled
  disable <agent>...                  Move from enabled → parked
  enable-category <category>          Enable every agent in a category *
  disable-category <category>         Disable every agent in a category *
  categories                          List configured categories *

  * Requires a categories config file. See:
      $CLAUDE_EDIT_AGENTS_CATEGORIES  (env override)
      $XDG_CONFIG_HOME/edit-agents/categories  (default)

Examples:
  edit-agents list
  edit-agents enable kotlin-specialist crypto-security-reviewer
  edit-agents --scope user disable-category research
EOF
      exit 0 ;;
    *) echo "unknown flag: $1" >&2; exit 2 ;;
  esac
done

# ---------- resolve root ----------
if [[ -n "$DIR" ]]; then
  ROOT="$DIR"
elif [[ "$SCOPE" == "project" ]]; then
  ROOT="$PWD/.claude/agents"
elif [[ "$SCOPE" == "user" ]]; then
  ROOT="$HOME/.claude/agents"
elif [[ -d "$PWD/.claude/agents" ]]; then
  ROOT="$PWD/.claude/agents"
  SCOPE="project"
else
  ROOT="$HOME/.claude/agents"
  SCOPE="user"
fi

[[ -d "$ROOT" ]] || { echo "no agents directory at: $ROOT" >&2; exit 1; }
PARKED="${ROOT}-parked"
# Note: PARKED is created lazily by enable/disable ops, not by read-only `list`.

# ---------- helpers ----------
list_dir() { # $1=dir, $2=label
  local d="$1" label="$2"
  if compgen -G "$d/*.md" >/dev/null; then
    printf "  [%s] %s\n" "$label" "$(cd "$d" && ls *.md 2>/dev/null | sed 's/\.md$//' | tr '\n' ' ')"
  else
    printf "  [%s] (none)\n" "$label"
  fi
}

reject_bad_name() {
  local name="$1"
  # Reject path separators / traversal / empty / dotfile-only names.
  if [[ -z "$name" || "$name" == *"/"* || "$name" == "."* ]]; then
    echo "invalid agent name: $name" >&2
    return 1
  fi
}

enable_one() {
  local name="$1"
  reject_bad_name "$name" || return 1
  mkdir -p "$PARKED"
  local src="$PARKED/$name.md" dst="$ROOT/$name.md"
  if [[ -f "$dst" ]]; then echo "already enabled: $name"; return 0; fi
  if [[ ! -f "$src" ]]; then echo "not found in parked: $name" >&2; return 1; fi
  mv "$src" "$dst"
  echo "enabled: $name"
}

disable_one() {
  local name="$1"
  reject_bad_name "$name" || return 1
  mkdir -p "$PARKED"
  local src="$ROOT/$name.md" dst="$PARKED/$name.md"
  if [[ -f "$dst" ]]; then echo "already parked: $name"; return 0; fi
  if [[ ! -f "$src" ]]; then echo "not found in enabled: $name" >&2; return 1; fi
  mv "$src" "$dst"
  echo "parked: $name"
}

require_categories() {
  if (( ${#CATEGORIES[@]} == 0 )); then
    cat >&2 <<EOF
no categories configured.

Create $CATEGORIES_FILE with lines like:

  review:   architect-review code-explorer
  security: penetration-tester crypto-security-reviewer

Or set \$CLAUDE_EDIT_AGENTS_CATEGORIES to another file path.
EOF
    exit 2
  fi
}

# ---------- dispatch ----------
CMD="${1:-list}"; shift || true

case "$CMD" in
  list)
    MODE="${1:-all}"
    echo "scope: ${SCOPE:-explicit-dir}   root: $ROOT"
    if [[ "$MODE" == "enabled" || "$MODE" == "all" ]]; then
      list_dir "$ROOT" "enabled"
    fi
    if [[ "$MODE" == "parked" || "$MODE" == "disabled" || "$MODE" == "all" ]]; then
      list_dir "$PARKED" "parked "
    fi
    ;;
  enable)
    [[ $# -gt 0 ]] || { echo "usage: edit-agents enable <agent>..." >&2; exit 2; }
    rc=0; for a in "$@"; do enable_one "$a" || rc=$?; done; exit $rc ;;
  disable)
    [[ $# -gt 0 ]] || { echo "usage: edit-agents disable <agent>..." >&2; exit 2; }
    rc=0; for a in "$@"; do disable_one "$a" || rc=$?; done; exit $rc ;;
  enable-category)
    require_categories
    cat_name="${1:?category required}"
    members="${CATEGORIES[$cat_name]:-}"
    [[ -n "$members" ]] || { echo "unknown category: $cat_name" >&2; exit 2; }
    read -ra members_arr <<< "$members"
    rc=0; for a in "${members_arr[@]}"; do enable_one "$a" || rc=$?; done; exit $rc ;;
  disable-category)
    require_categories
    cat_name="${1:?category required}"
    members="${CATEGORIES[$cat_name]:-}"
    [[ -n "$members" ]] || { echo "unknown category: $cat_name" >&2; exit 2; }
    read -ra members_arr <<< "$members"
    rc=0; for a in "${members_arr[@]}"; do disable_one "$a" || rc=$?; done; exit $rc ;;
  categories)
    require_categories
    for k in "${!CATEGORIES[@]}"; do
      printf "  %-12s %s\n" "$k" "${CATEGORIES[$k]}"
    done | sort
    ;;
  *) echo "unknown command: $CMD (try --help)" >&2; exit 2 ;;
esac
