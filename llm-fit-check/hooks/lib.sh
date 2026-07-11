#!/usr/bin/env bash
# Shared helpers for the llm-fit-check hook suite.
# Sourced by classify.sh / session-init.sh / track-model.sh / cleanup.sh.
# Sourcing has no side effects beyond defining functions + constants.

LFC_STATE_DIR="${LLM_FIT_CHECK_STATE_DIR:-$HOME/.claude/state/llm-fit-check}"
LFC_DEBUG_LOG="$LFC_STATE_DIR/debug.log"
# Max debug-log size before rotation (bytes); override with LLM_FIT_CHECK_LOG_MAX.
LFC_LOG_MAX="${LLM_FIT_CHECK_LOG_MAX:-262144}"

# --- logging -----------------------------------------------------------------
# Always appends to the debug log (best-effort); also echoes to stderr when
# LLM_FIT_CHECK_VERBOSE is set. Rotates once past LFC_LOG_MAX bytes (single
# .1 backup) so the log can't grow unbounded across sessions.
lfc_log() {
  mkdir -p "$LFC_STATE_DIR" 2>/dev/null || true
  if [ -f "$LFC_DEBUG_LOG" ]; then
    local sz
    sz="$(wc -c <"$LFC_DEBUG_LOG" 2>/dev/null | tr -d ' ')"
    if [ -n "$sz" ] && [ "$sz" -ge "$LFC_LOG_MAX" ] 2>/dev/null; then
      mv -f "$LFC_DEBUG_LOG" "$LFC_DEBUG_LOG.1" 2>/dev/null || true
    fi
  fi
  printf '%s %s\n' "$(date -u +%FT%TZ)" "$*" >>"$LFC_DEBUG_LOG" 2>/dev/null || true
  [ -n "${LLM_FIT_CHECK_VERBOSE:-}" ] && printf 'llm-fit-check: %s\n' "$*" >&2 || true
}

# --- model tier map ----------------------------------------------------------
# Echoes a numeric rank (1=haiku 2=sonnet 3=opus) for known families, or the
# literal "unknown" for anything else (e.g. fable, or a future model). To rank
# a new family, add one case line below.
lfc_model_tier() {
  local m
  m="$(printf '%s' "${1:-}" | tr '[:upper:]' '[:lower:]')"
  case "$m" in
    "")       echo unknown ;;
    *haiku*)  echo 1 ;;
    *sonnet*) echo 2 ;;
    *opus*)   echo 3 ;;
    *)        echo unknown ;;
  esac
}

lfc_tier_name() {
  case "${1:-}" in
    1) echo haiku ;;
    2) echo sonnet ;;
    3) echo opus ;;
    *) echo "" ;;
  esac
}

# --- effort ordering ---------------------------------------------------------
lfc_effort_rank() {
  case "$(printf '%s' "${1:-}" | tr '[:upper:]' '[:lower:]')" in
    low)    echo 1 ;;
    medium) echo 2 ;;
    high)   echo 3 ;;
    xhigh)  echo 4 ;;
    max)    echo 5 ;;
    *)      echo unknown ;;
  esac
}

lfc_effort_name() {
  case "${1:-}" in
    1) echo low ;;
    2) echo medium ;;
    3) echo high ;;
    4) echo xhigh ;;
    5) echo max ;;
    *) echo "" ;;
  esac
}

# --- sidecar state ("the session variable") ----------------------------------
lfc_sidecar_path() { printf '%s/%s.model' "$LFC_STATE_DIR" "${1:-unknown}"; }

# Merge-write: empty model/effort args mean "keep the existing value".
# args: session_id model effort
lfc_sidecar_update() {
  local sid="${1:-unknown}" model="${2:-}" effort="${3:-}"
  local p cur_m="" cur_e=""
  p="$(lfc_sidecar_path "$sid")"
  if [ -f "$p" ]; then
    cur_m="$(jq -r '.model // ""' "$p" 2>/dev/null)"
    cur_e="$(jq -r '.effort // ""' "$p" 2>/dev/null)"
  fi
  [ -z "$model" ]  && model="$cur_m"
  [ -z "$effort" ] && effort="$cur_e"
  mkdir -p "$LFC_STATE_DIR" 2>/dev/null || true
  jq -n --arg m "$model" --arg e "$effort" --arg u "$(date -u +%FT%TZ)" \
    '{model:$m, effort:$e, updated:$u}' >"$p" 2>/dev/null || true
}

lfc_sidecar_read_model() {
  local p; p="$(lfc_sidecar_path "${1:-}")"
  if [ -f "$p" ]; then jq -r '.model // ""' "$p" 2>/dev/null; else echo ""; fi
}
