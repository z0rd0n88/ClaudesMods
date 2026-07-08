#!/usr/bin/env bash
# edit-agents — toggle Claude Code agents between enabled and disabled.
#
# Layout assumed:
#   <root>/<agent>.md            # enabled (loaded into the session)
#   <root>-parked/<agent>.md     # parked (NOT loaded — sibling outside <root>)
#
# NOTE: Claude Code scans <root> RECURSIVELY, so a <root>/disabled/ subfolder is
# still loaded into the roster. Parked agents must live OUTSIDE the agents/ tree.
#
# Default <root>: ./.claude/agents if it exists, else ~/.claude/agents.
# Override with --scope project|user, or --dir <path>.

set -euo pipefail

# ---------- categories ----------
# Edit these lists as the agent set evolves.
declare -A CATEGORIES=(
  [review]="architect-review code-explorer code-reviewer commit-guardian critical-thinking demonstrate-understanding"
  [security]="crypto-security-reviewer compliance-auditor penetration-tester security-engineer smart-contract-auditor"
  [impl]="backend-developer kotlin-specialist kotlin-mcp-expert blockchain-developer smart-contract-specialist web3-integration-specialist"
  [api]="api-architect api-designer api-reviewer"
  [docs]="api-documenter documentation-expert technical-writer diagram-architect code-tour specification"
  [ops]="debug error-detective database-optimization unused-code-cleaner"
  [research]="research-orchestrator competitive-analyst knowledge-synthesizer market-researcher search-specialist"
  [ai]="llm-architect model-evaluator"
  [meta]="agent-installer agent-organizer agent-overview context-manager command-expert prompt-builder"
  [product]="product-strategist legal-advisor simple-app-idea-generator communication-excellence-coach"
)

# ---------- arg parse ----------
SCOPE=""
DIR=""
while [[ $# -gt 0 && "$1" == --* ]]; do
  case "$1" in
    --scope) SCOPE="$2"; shift 2 ;;
    --dir)   DIR="$2";   shift 2 ;;
    --help|-h)
      cat <<'EOF'
edit-agents — toggle Claude Code agents between enabled and disabled.

Layout assumed:
  <root>/<agent>.md            (enabled — loaded into the session)
  <root>-parked/<agent>.md     (parked — NOT loaded; sibling outside <root>)

Default <root>: ./.claude/agents if it exists, else ~/.claude/agents.
Override with --scope project|user, or --dir <path>.
EOF
      cat <<'EOF'

Commands:
  list [enabled|disabled|all]              Show agents (default: all)
  enable <agent>...                        Move agents from disabled/ → enabled
  disable <agent>...                       Move agents from enabled → disabled/
  enable-category <category>               Enable every agent in a category
  disable-category <category>              Disable every agent in a category
  categories                               List defined categories + members

Examples:
  edit-agents list
  edit-agents enable kotlin-specialist crypto-security-reviewer
  edit-agents disable-category research
  edit-agents --scope user list
EOF
      exit 0 ;;
    *) echo "Unknown flag: $1" >&2; exit 2 ;;
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
# Park OUTSIDE the agents/ tree: Claude Code scans <root> recursively, so a
# <root>/disabled/ subfolder would still be loaded. Use a sibling dir instead.
DISABLED="${ROOT}-parked"
mkdir -p "$DISABLED"

# ---------- helpers ----------
list_dir() { # $1=dir, $2=label
  local d="$1" label="$2"
  if compgen -G "$d/*.md" >/dev/null; then
    printf "  [%s] %s\n" "$label" "$(cd "$d" && ls *.md 2>/dev/null | sed 's/\.md$//' | tr '\n' ' ')"
  else
    printf "  [%s] (none)\n" "$label"
  fi
}

enable_one() {
  local name="$1"
  local src="$DISABLED/$name.md" dst="$ROOT/$name.md"
  if [[ -f "$dst" ]]; then echo "already enabled: $name"; return 0; fi
  if [[ ! -f "$src" ]]; then echo "not found in disabled/: $name" >&2; return 1; fi
  mv "$src" "$dst"
  echo "enabled: $name"
}

disable_one() {
  local name="$1"
  local src="$ROOT/$name.md" dst="$DISABLED/$name.md"
  if [[ -f "$dst" ]]; then echo "already disabled: $name"; return 0; fi
  if [[ ! -f "$src" ]]; then echo "not found in enabled: $name" >&2; return 1; fi
  mv "$src" "$dst"
  echo "disabled: $name"
}

# ---------- dispatch ----------
CMD="${1:-list}"; shift || true

case "$CMD" in
  list)
    MODE="${1:-all}"
    echo "scope: ${SCOPE:-explicit-dir}   root: $ROOT"
    [[ "$MODE" == "enabled"  || "$MODE" == "all" ]] && list_dir "$ROOT"     "enabled " || :
    [[ "$MODE" == "disabled" || "$MODE" == "all" ]] && list_dir "$DISABLED" "disabled" || :
    ;;
  enable)
    [[ $# -gt 0 ]] || { echo "usage: edit-agents enable <agent>..." >&2; exit 2; }
    rc=0; for a in "$@"; do enable_one "$a" || rc=$?; done; exit $rc ;;
  disable)
    [[ $# -gt 0 ]] || { echo "usage: edit-agents disable <agent>..." >&2; exit 2; }
    rc=0; for a in "$@"; do disable_one "$a" || rc=$?; done; exit $rc ;;
  enable-category)
    cat="${1:?category required}"
    members="${CATEGORIES[$cat]:-}"
    [[ -n "$members" ]] || { echo "unknown category: $cat" >&2; exit 2; }
    rc=0; for a in $members; do enable_one "$a" || rc=$?; done; exit $rc ;;
  disable-category)
    cat="${1:?category required}"
    members="${CATEGORIES[$cat]:-}"
    [[ -n "$members" ]] || { echo "unknown category: $cat" >&2; exit 2; }
    rc=0; for a in $members; do disable_one "$a" || rc=$?; done; exit $rc ;;
  categories)
    for k in "${!CATEGORIES[@]}"; do
      printf "  %-10s %s\n" "$k" "${CATEGORIES[$k]}"
    done | sort
    ;;
  *) echo "unknown command: $CMD (try --help)" >&2; exit 2 ;;
esac
