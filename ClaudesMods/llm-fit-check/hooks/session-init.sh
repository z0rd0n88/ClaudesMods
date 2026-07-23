#!/usr/bin/env bash
# SessionStart hook — seed the per-session model/effort sidecar with the
# configured defaults (best-effort; a `--model` launch override is not visible
# here and gets corrected by classify.sh's transcript refresh after turn 1).
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
. "$SCRIPT_DIR/lib.sh"

payload="$(cat)"
sid="$(printf '%s' "$payload" | jq -r '.session_id // ""' 2>/dev/null)"

settings="$HOME/.claude/settings.json"
model=""; effort=""
if [ -f "$settings" ]; then
  model="$(jq -r '.model // ""' "$settings" 2>/dev/null)"
  effort="$(jq -r '.effortLevel // ""' "$settings" 2>/dev/null)"
fi

lfc_sidecar_update "$sid" "$model" "$effort"
lfc_log "session-init sid=$sid model='${model}' effort='${effort}'"
exit 0
