#!/usr/bin/env bash
# SessionEnd hook — remove this session's sidecar file.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
. "$SCRIPT_DIR/lib.sh"

payload="$(cat)"
sid="$(printf '%s' "$payload" | jq -r '.session_id // ""' 2>/dev/null)"
[ -n "$sid" ] && rm -f "$(lfc_sidecar_path "$sid")" 2>/dev/null
lfc_log "cleanup sid=$sid"
exit 0
