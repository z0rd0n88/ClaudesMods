#!/usr/bin/env bash
# ConfigChange hook — update the sidecar when the model/effort changes.
# The ConfigChange payload shape is not yet documented, so extraction is
# tolerant and the raw payload is logged (build-time: inspect debug.log to
# confirm the real field names, then tighten this).
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
. "$SCRIPT_DIR/lib.sh"

payload="$(cat)"
sid="$(printf '%s' "$payload" | jq -r '.session_id // ""' 2>/dev/null)"

# Any string field anywhere that looks like a model id.
model="$(printf '%s' "$payload" | jq -r '
  [ .. | strings | select(test("claude-(haiku|sonnet|opus|fable)|^(haiku|sonnet|opus|fable)$";"i")) ] | last // ""
' 2>/dev/null)"
# Any effort-shaped field (.effortLevel, .effort.level, or a bare .effort string).
effort="$(printf '%s' "$payload" | jq -r '
  [ .. | objects | (.effortLevel? // .effort?.level? // (.effort? | select(type=="string"))) ]
  | map(select(type=="string")) | last // ""
' 2>/dev/null)"

lfc_log "config-change sid=$sid model='${model}' effort='${effort}' raw=$(printf '%s' "$payload" | tr -d '\n' | cut -c1-400)"

if [ -n "$model" ] || [ -n "$effort" ]; then
  lfc_sidecar_update "$sid" "$model" "$effort"
fi
exit 0
