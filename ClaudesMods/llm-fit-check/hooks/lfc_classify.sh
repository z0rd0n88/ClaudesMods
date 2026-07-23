#!/usr/bin/env bash
# Shared classification engine for llm-fit-check — the SINGLE source of truth
# for prompt-difficulty classification. Sourced by classify.sh (the automatic
# UserPromptSubmit hook) and shelled out to by the /model-route command.
#
# Sourcing has NO side effects beyond defining functions + constants.
# Executing runs the CLI (see the tail of this file).
#
#   lfc_classify <prompt> [current_model] [current_effort]
#     echoes: "<band> <desired_tier> <desired_effort>"
#       band           : trivial | moderate | heavy   (borderline is resolved)
#       desired_tier   : 1=haiku 2=sonnet 3=opus
#       desired_effort : 1..5 (low..max)
#
# current_model / current_effort are accepted for context + forward-compat; the
# band is derived from the prompt alone. Fail-open: any internal error degrades
# to "moderate 2 2" and never wedges a session.
set -uo pipefail

LFC_CLASSIFY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Pull in lfc_log / tier + effort name helpers if not already sourced (e.g. when
# this file is executed directly or sourced standalone by /model-route).
if ! declare -F lfc_log >/dev/null 2>&1; then
  # shellcheck source=lib.sh
  . "$LFC_CLASSIFY_DIR/lib.sh"
fi

# --- classification constants: the single source of truth --------------------
# Keyword families + word-count thresholds. Tune HERE and both surfaces update.
LFC_HEAVY_RE='refactor|re-architect|architect|migrat|security|threat|vulnerab|concurren|race condition|deadlock|optimi[sz]e|distributed|algorithm|cryptograph|proof|prove |root cause|design a |design the |scal(e|ing)|performance regression'
LFC_TRIVIAL_RE='typo|rename|reword|reformat|format |bump |changelog|add a comment|spelling|lint|what is|list the|print |show me|readme'
# A trivial keyword only bands "trivial" under this word count; long prompts and
# very long prompts push toward "borderline".
LFC_TRIVIAL_WC_MAX="${LFC_TRIVIAL_WC_MAX:-25}"
LFC_BORDERLINE_WC_MIN="${LFC_BORDERLINE_WC_MIN:-80}"

# --- band -> desired tier/effort map -----------------------------------------
# The single place the band→config mapping lives. Echoes "<tier> <effort>".
lfc_band_to_config() {
  case "${1:-}" in
    trivial) echo "1 1" ;;
    heavy)   echo "3 3" ;;
    *)       echo "2 2" ;;   # moderate (and any unexpected band): balanced default
  esac
}

# --- optional LLM escalation for a borderline band ---------------------------
# Resolves a "borderline" band to trivial/moderate/heavy. With
# LLM_FIT_CHECK_USE_LLM set and `claude` available, asks a haiku rubric;
# otherwise (and on any failure) degrades conservatively to "moderate".
# Non-borderline bands pass through unchanged.
lfc_resolve_borderline() {
  local band="${1:-moderate}" prompt="${2:-}"
  [ "$band" != borderline ] && { printf '%s' "$band"; return 0; }
  if [ -n "${LLM_FIT_CHECK_USE_LLM:-}" ] && command -v claude >/dev/null 2>&1; then
    local rubric resp ltier
    rubric='Classify task difficulty. Reply ONLY compact JSON {"tier":"haiku|sonnet|opus","effort":"low|medium|high|xhigh","difficulty":1}. haiku/low=trivial mechanical; sonnet/medium=normal implementation; opus/high=architecture, security, concurrency, tricky debugging. TASK:'
    resp="$(LLM_FIT_CHECK_GUARD=1 timeout 15 claude -p --model haiku "$rubric $prompt" 2>/dev/null)"
    ltier="$(printf '%s' "$resp" | jq -r '.tier // ""' 2>/dev/null)"
    case "$ltier" in
      haiku)  band=trivial ;;
      sonnet) band=moderate ;;
      opus)   band=heavy ;;
      *)      band=moderate ;;   # fail-open: classifier failure never blocks
    esac
    lfc_log "llm-escalation tier='${ltier}' -> band=$band"
  else
    band=moderate   # no LLM available -> conservative, never block
  fi
  printf '%s' "$band"
}

# --- the engine --------------------------------------------------------------
# lfc_classify <prompt> [current_model] [current_effort]
lfc_classify() {
  local prompt="${1:-}"
  local _model="${2:-}" _effort="${3:-}"   # context only; band is prompt-derived
  local lc wc heavy=0 trivial=0 band cfg d_tier d_eff

  lc="$(printf '%s' "$prompt" | tr '[:upper:]' '[:lower:]' 2>/dev/null)" || lc=""
  wc="$(printf '%s' "$prompt" | wc -w 2>/dev/null | tr -d ' ')"
  case "$wc" in ''|*[!0-9]*) wc=0 ;; esac   # guard numeric compares (fail-open)

  printf '%s' "$lc" | grep -Eq "$LFC_HEAVY_RE"   2>/dev/null && heavy=1
  printf '%s' "$lc" | grep -Eq "$LFC_TRIVIAL_RE" 2>/dev/null && trivial=1

  if   [ "$heavy" = 1 ] && [ "$trivial" = 1 ]; then band=borderline
  elif [ "$heavy" = 1 ]; then band=heavy
  elif [ "$trivial" = 1 ] && [ "$wc" -lt "$LFC_TRIVIAL_WC_MAX" ]; then band=trivial
  elif [ "$wc" -ge "$LFC_BORDERLINE_WC_MIN" ]; then band=borderline
  else band=moderate
  fi

  band="$(lfc_resolve_borderline "$band" "$prompt")"
  [ -n "$band" ] || band=moderate

  cfg="$(lfc_band_to_config "$band")"
  d_tier="${cfg%% *}"; d_eff="${cfg##* }"
  printf '%s %s %s\n' "$band" "$d_tier" "$d_eff"
}

# --- CLI mode ----------------------------------------------------------------
# `lfc_classify.sh <prompt words...>` or a prompt on stdin. Prints a parseable
# block for /model-route to consume, including the ready-made hook-style
# "/model X && /effort Y" recommendation string.
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  if [ "$#" -gt 0 ]; then _prompt="$*"; else _prompt="$(cat 2>/dev/null || true)"; fi
  read -r _band _tier _eff <<EOF
$(lfc_classify "$_prompt")
EOF
  : "${_band:=moderate}" "${_tier:=2}" "${_eff:=2}"
  printf 'band=%s\n' "$_band"
  printf 'desired_tier=%s\n' "$_tier"
  printf 'desired_model=%s\n' "$(lfc_tier_name "$_tier")"
  printf 'desired_effort_rank=%s\n' "$_eff"
  printf 'desired_effort=%s\n' "$(lfc_effort_name "$_eff")"
  printf 'recommend=/model %s && /effort %s\n' "$(lfc_tier_name "$_tier")" "$(lfc_effort_name "$_eff")"
fi
