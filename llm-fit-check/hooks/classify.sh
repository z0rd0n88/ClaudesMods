#!/usr/bin/env bash
# UserPromptSubmit hook — classify the prompt's difficulty and compare it to the
# current model (sidecar) + effort (payload). Asymmetric action: block when
# under-powered on a heavy task, warn when over-powered, silent on a match.
# Fail-open everywhere: any error path exits 0 (never wedge the session).
set -uo pipefail

# Recursion guard: set when we shell out to `claude -p` so the child session's
# own UserPromptSubmit hook no-ops instead of recursing forever.
[ -n "${LLM_FIT_CHECK_GUARD:-}" ] && exit 0

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
. "$SCRIPT_DIR/lib.sh"
# shellcheck source=lfc_classify.sh
. "$SCRIPT_DIR/lfc_classify.sh"   # shared classification engine (single source of truth)

payload="$(cat)"
prompt="$(printf '%s' "$payload" | jq -r '.prompt // ""' 2>/dev/null)"
effort="$(printf '%s' "$payload" | jq -r '.effort.level // ""' 2>/dev/null)"
[ -z "$effort" ] && effort="${CLAUDE_EFFORT:-}"
sid="$(printf '%s' "$payload" | jq -r '.session_id // ""' 2>/dev/null)"
tpath="$(printf '%s' "$payload" | jq -r '.transcript_path // ""' 2>/dev/null)"

# Empty prompt (e.g. a slash-command pass-through) -> nothing to classify.
[ -z "${prompt// /}" ] && exit 0

# --- current model: sidecar, self-healed by a best-effort transcript read ----
model="$(lfc_sidecar_read_model "$sid")"
if [ -n "$tpath" ] && [ -f "$tpath" ]; then
  tmodel="$(grep -ho '"model"[[:space:]]*:[[:space:]]*"[^"]*"' "$tpath" 2>/dev/null \
            | tail -1 | sed -E 's/.*"([^"]*)"[[:space:]]*$/\1/')"
  [ -n "$tmodel" ] && model="$tmodel"
fi
lfc_sidecar_update "$sid" "$model" "$effort"   # keep the sidecar fresh

# --- heuristic band + desired config (shared engine) -------------------------
# The band regex, word-count thresholds, band→tier/effort map, and the optional
# borderline LLM escalation all live in lfc_classify.sh (single source of truth).
wc=$(printf '%s' "$prompt" | wc -w | tr -d ' ')
read -r band d_tier d_eff <<EOF
$(lfc_classify "$prompt" "$model" "$effort")
EOF
: "${band:=moderate}" "${d_tier:=2}" "${d_eff:=2}"   # fail-open defaults

cur_tier="$(lfc_model_tier "$model")"    # 1/2/3 or "unknown"
cur_eff="$(lfc_effort_rank "$effort")"   # 1..5 or "unknown"

lfc_log "classify sid=$sid band=$band wc=$wc model='${model}' cur_tier=$cur_tier effort='${effort}' cur_eff=$cur_eff d_tier=$d_tier d_eff=$d_eff"

# --- asymmetric decision -----------------------------------------------------
under_model=0; over_model=0
if [ "$cur_tier" != unknown ]; then
  [ "$cur_tier" -lt "$d_tier" ] && under_model=1
  [ "$cur_tier" -gt "$d_tier" ] && over_model=1
fi
under_eff=0; over_eff=0
if [ "$cur_eff" != unknown ]; then
  [ "$cur_eff" -lt "$d_eff" ] && under_eff=1
  [ "$cur_eff" -gt "$d_eff" ] && over_eff=1
fi

# Only heavy/risky tasks (desired opus or >=high effort) are eligible to BLOCK.
heavy_task=0
{ [ "$d_tier" -ge 3 ] || [ "$d_eff" -ge 3 ]; } && heavy_task=1

# BLOCK: under-powered on a heavy task. Model axis counts only if model known.
if [ "$heavy_task" = 1 ] && { [ "$under_model" = 1 ] || [ "$under_eff" = 1 ]; }; then
  recs=""
  [ "$under_model" = 1 ] && recs="/model $(lfc_tier_name "$d_tier")"
  if [ "$under_eff" = 1 ]; then
    [ -n "$recs" ] && recs="$recs && "
    recs="${recs}/effort $(lfc_effort_name "$d_eff")"
  fi
  reason="This looks like a ${band} task but the current setup is under-powered. Run: ${recs}, then resend."
  jq -n --arg r "$reason" '{decision:"block", reason:$r}'
  lfc_log "DECISION=block $reason"
  exit 0
fi

# WARN: over-powered (never blocks); only when not under-powered on either axis.
if [ "$under_model" = 0 ] && [ "$under_eff" = 0 ] && { [ "$over_model" = 1 ] || [ "$over_eff" = 1 ]; }; then
  sugg=""
  [ "$over_model" = 1 ] && sugg="/model $(lfc_tier_name "$d_tier")"
  if [ "$over_eff" = 1 ]; then
    [ -n "$sugg" ] && sugg="$sugg && "
    sugg="${sugg}/effort $(lfc_effort_name "$d_eff")"
  fi
  msg="llm-fit-check: ${band} task on a heavier setup — ${sugg} would save cost/latency."
  jq -n --arg m "$msg" '{systemMessage:$m}'
  lfc_log "DECISION=warn $msg"
  exit 0
fi

# Match, or only-unknown axes -> silent allow.
exit 0
