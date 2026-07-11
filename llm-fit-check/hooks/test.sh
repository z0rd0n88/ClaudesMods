#!/usr/bin/env bash
# Path-coverage tests for the llm-fit-check hook suite.
#
# Exercises every path: classify.sh (all five bands, all three decisions,
# both block sub-paths, guard/empty short-circuits, transcript override),
# lib.sh unit helpers, session-init.sh, cleanup.sh, track-model.sh, and
# lfc_log rotation. Every check folds into the pass/fail totals and the
# exit code (0 = all pass, 1 = any fail), so this is CI-safe.
#
# Usage: hooks/llm-fit-check/test.sh
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export LLM_FIT_CHECK_STATE_DIR="$(mktemp -d)"
STATE="$LLM_FIT_CHECK_STATE_DIR"
pass=0; fail=0

hr(){ printf '%s\n' "----------------------------------------------------------------------"; }
ok(){ pass=$((pass+1)); printf '  [PASS] %s\n' "$1"; }
no(){ fail=$((fail+1)); printf '  [FAIL] %s\n' "$1"; }
seed(){ mkdir -p "$STATE"; printf '{"model":"%s","effort":"%s","updated":"x"}' "$2" "$3" > "$STATE/$1.model"; }

# run_classify: sid prompt effort transcript_path [guard] -> "<exit>\t<stdout>"
run_classify(){
  local sid="$1" prompt="$2" eff="$3" tp="${4:-}" guard="${5:-}" payload out rc
  payload="$(jq -n --arg s "$sid" --arg p "$prompt" --arg e "$eff" --arg t "$tp" \
    '{session_id:$s, prompt:$p, effort:{level:$e}, transcript_path:$t}')"
  if [ -n "$guard" ]; then
    out="$(printf '%s' "$payload" | LLM_FIT_CHECK_GUARD=1 bash "$HERE/classify.sh" 2>/dev/null)"; rc=$?
  else
    out="$(printf '%s' "$payload" | bash "$HERE/classify.sh" 2>/dev/null)"; rc=$?
  fi
  printf '%s\t%s' "$rc" "$out"
}

# assert_case: name expected(block|warn|silent) expect_substr tab_output
assert_case(){
  local name="$1" expect="$2" substr="$3" res="$4"
  local rc="${res%%$'\t'*}" out="${res#*$'\t'}" kind="silent" good=1
  printf '%s' "$out" | grep -q '"decision"[[:space:]]*:[[:space:]]*"block"' && kind="block"
  printf '%s' "$out" | grep -q '"systemMessage"' && kind="warn"
  [ "$kind" = "$expect" ] || good=0
  [ -n "$substr" ] && { printf '%s' "$out" | grep -qF "$substr" || good=0; }
  [ "$rc" = "0" ] || good=0   # fail-open: every path must exit 0
  if [ "$good" = 1 ]; then ok "$name"; else
    no "$name (kind=$kind rc=$rc want=$expect substr=\"$substr\")"
    printf '         output: %s\n' "${out:-<empty>}"
  fi
}
# eq: got want name
eq(){ if [ "$1" = "$2" ]; then ok "$3=$1"; else no "$3 got=$1 want=$2"; fi; }

echo "SUT=$HERE"; echo "STATE=$STATE"
hr; echo "== A. short-circuit paths =="
seed grd claude-haiku-4-5 low
assert_case "recursion guard -> silent" silent "" \
  "$(run_classify grd 'refactor the distributed lock race condition' low '' guard)"
assert_case "empty prompt -> silent" silent "" "$(run_classify grd '   ' low '')"

hr; echo "== B. BLOCK paths (heavy task, under-powered) =="
seed b1 claude-haiku-4-5 low
assert_case "heavy haiku/low -> block model+effort" block "/model opus && /effort high" \
  "$(run_classify b1 'refactor and re-architect the auth module for a race condition' low '')"
seed b2 claude-opus-4-8 low
assert_case "heavy opus/low -> block effort-only" block "/effort high" \
  "$(run_classify b2 'optimize the distributed algorithm and prove correctness' low '')"
seed b3 claude-haiku-4-5 high
assert_case "heavy haiku/high -> block model-only" block "/model opus" \
  "$(run_classify b3 'security threat model for the cryptography module' high '')"
printf '{"model":"","effort":""}' > "$STATE/b4.model"
assert_case "heavy unknown-model/low -> block effort-only (no /model)" block "/effort high" \
  "$(run_classify b4 'design the concurrency control to avoid deadlock' low '')"

hr; echo "== C. WARN paths (over-powered, never blocks) =="
seed w1 claude-opus-4-8 high
assert_case "trivial opus/high -> warn" warn "/model haiku && /effort low" \
  "$(run_classify w1 'fix a typo in the readme' high '')"
seed w2 claude-opus-4-8 high
assert_case "moderate opus/high -> warn" warn "/model sonnet && /effort medium" \
  "$(run_classify w2 'add a new endpoint that returns the user list from the service' high '')"

hr; echo "== D. SILENT / match paths =="
seed s1 claude-opus-4-8 high
assert_case "heavy opus/high -> silent" silent "" \
  "$(run_classify s1 'refactor the concurrency model to remove the deadlock' high '')"
seed s2 claude-haiku-4-5 low
assert_case "trivial haiku/low -> silent" silent "" "$(run_classify s2 'rename the variable' low '')"
seed s3 claude-sonnet-5 medium
assert_case "moderate sonnet/medium -> silent" silent "" \
  "$(run_classify s3 'add a new endpoint that returns the user list from the service' medium '')"
seed s4 claude-haiku-4-5 low
assert_case "moderate under-powered (non-heavy) -> silent" silent "" \
  "$(run_classify s4 'add a new endpoint that returns the user list from the service' low '')"

hr; echo "== E. band edges =="
seed e1 claude-sonnet-5 medium
assert_case "borderline (heavy+trivial kw) -> moderate/silent" silent "" \
  "$(run_classify e1 'refactor and fix a typo' medium '')"
LONG="$(for i in $(seq 1 90); do printf 'word%d ' "$i"; done)"
seed e2 claude-sonnet-5 medium
assert_case "borderline (wc>=80) -> moderate/silent" silent "" \
  "$(run_classify e2 "$LONG" medium '')"

hr; echo "== F. transcript overrides sidecar model =="
seed f1 claude-opus-4-8 high
TP="$(mktemp)"; printf '{"type":"assistant","message":{"model":"claude-haiku-4-5"}}\n' > "$TP"
assert_case "transcript(haiku) overrides sidecar(opus) -> block /model opus" block "/model opus" \
  "$(run_classify f1 'security threat model with cryptography proof' high "$TP")"
rm -f "$TP"

hr; echo "== G. lib.sh unit helpers =="
# Source in a subshell but fold results into totals via a temp count file.
CNT="$STATE/.gcounts"; : > "$CNT"
(
  . "$HERE/lib.sh"
  g_eq(){ if [ "$1" = "$2" ]; then echo "P $3=$1"; else echo "F $3 got=$1 want=$2"; fi; }
  g_eq "$(lfc_model_tier claude-haiku-4-5)" 1 "tier(haiku)"
  g_eq "$(lfc_model_tier claude-sonnet-5)"  2 "tier(sonnet)"
  g_eq "$(lfc_model_tier claude-opus-4-8)"  3 "tier(opus)"
  g_eq "$(lfc_model_tier claude-fable-5)"   unknown "tier(fable)"
  g_eq "$(lfc_model_tier '')"               unknown "tier(empty)"
  g_eq "$(lfc_effort_rank low)"    1 "eff(low)"
  g_eq "$(lfc_effort_rank medium)" 2 "eff(medium)"
  g_eq "$(lfc_effort_rank high)"   3 "eff(high)"
  g_eq "$(lfc_effort_rank xhigh)"  4 "eff(xhigh)"
  g_eq "$(lfc_effort_rank max)"    5 "eff(max)"
  g_eq "$(lfc_effort_rank bogus)"  unknown "eff(bogus)"
  lfc_sidecar_update mrg claude-opus-4-8 high
  lfc_sidecar_update mrg "" ""
  g_eq "$(lfc_sidecar_read_model mrg)" claude-opus-4-8 "sidecar merge keeps model"
  lfc_sidecar_update mrg claude-haiku-4-5 ""
  g_eq "$(lfc_sidecar_read_model mrg)" claude-haiku-4-5 "sidecar updates model"
  g_eq "$(jq -r .effort "$STATE/mrg.model")" high "sidecar kept effort"
) > "$CNT"
while read -r verdict rest; do
  case "$verdict" in P) ok "$rest" ;; F) no "$rest" ;; esac
done < "$CNT"

hr; echo "== H. session-init seeds a sidecar =="
printf '{"session_id":"si1"}' | bash "$HERE/session-init.sh" >/dev/null 2>&1
[ -f "$STATE/si1.model" ] && ok "session-init created sidecar" || no "session-init created no sidecar"

echo "== I. cleanup removes the sidecar =="
seed cl1 claude-opus-4-8 high
printf '{"session_id":"cl1"}' | bash "$HERE/cleanup.sh" >/dev/null 2>&1
[ ! -f "$STATE/cl1.model" ] && ok "cleanup removed sidecar" || no "cleanup left sidecar"

echo "== J. track-model extracts model/effort =="
printf '{"session_id":"tm1","model":"claude-opus-4-8","effortLevel":"xhigh"}' \
  | bash "$HERE/track-model.sh" >/dev/null 2>&1
tm="$(jq -r .model "$STATE/tm1.model" 2>/dev/null):$(jq -r .effort "$STATE/tm1.model" 2>/dev/null)"
eq "$tm" "claude-opus-4-8:xhigh" "track-model wrote model:effort"

hr; echo "== L. lfc_classify engine (shared source of truth) =="
# Source the engine in a subshell; fold results into totals via a count file.
LCNT="$STATE/.lcounts"; : > "$LCNT"
(
  . "$HERE/lfc_classify.sh"
  g_eq(){ if [ "$1" = "$2" ]; then echo "P $3=$1"; else echo "F $3 got=$1 want=$2"; fi; }
  # each classify echoes "<band> <tier> <effort>"
  g_eq "$(lfc_classify 'refactor and re-architect the auth module for a race condition')" \
       "heavy 3 3" "classify(heavy)"
  g_eq "$(lfc_classify 'fix a typo in the readme')"        "trivial 1 1" "classify(trivial)"
  g_eq "$(lfc_classify 'add a new endpoint returning the user list')" \
       "moderate 2 2" "classify(moderate)"
  # borderline (heavy+trivial keywords) resolves conservatively to moderate w/o LLM
  g_eq "$(lfc_classify 'refactor and fix a typo')"         "moderate 2 2" "classify(borderline-kw->moderate)"
  # borderline (long prompt, no keywords) resolves to moderate
  LONGP="$(for i in $(seq 1 90); do printf 'word%d ' "$i"; done)"
  g_eq "$(lfc_classify "$LONGP")"                          "moderate 2 2" "classify(borderline-wc->moderate)"
  # band->config map is the single mapping source
  g_eq "$(lfc_band_to_config trivial)" "1 1" "map(trivial)"
  g_eq "$(lfc_band_to_config heavy)"   "3 3" "map(heavy)"
  g_eq "$(lfc_band_to_config moderate)" "2 2" "map(moderate)"
) > "$LCNT"
while read -r verdict rest; do
  case "$verdict" in P) ok "$rest" ;; F) no "$rest" ;; esac
done < "$LCNT"

hr; echo "== M. model-route --why data path (debug.log decisions) =="
# --why greps the session's classify/DECISION lines out of debug.log. Produce a
# real block decision, then assert the exact lines --why reads are retrievable.
seed why1 claude-haiku-4-5 low
run_classify why1 'security threat model with a cryptography proof' low '' >/dev/null
WHY="$(grep -E 'classify |DECISION=' "$STATE/debug.log" 2>/dev/null | tail -20)"
printf '%s' "$WHY" | grep -q 'sid=why1' && ok "--why finds session classify line" \
  || no "--why missing classify line for sid=why1"
printf '%s' "$WHY" | grep -q 'DECISION=block' && ok "--why finds the block decision" \
  || no "--why missing DECISION=block"

hr; echo "== K. lfc_log rotation at threshold =="
if (
  export LLM_FIT_CHECK_STATE_DIR="$(mktemp -d)" LLM_FIT_CHECK_LOG_MAX=200
  . "$HERE/lib.sh"
  for i in $(seq 1 25); do lfc_log "rotation test line $i padding padding padding"; done
  st=1; [ -f "$LLM_FIT_CHECK_STATE_DIR/debug.log.1" ] && st=0
  rm -rf "$LLM_FIT_CHECK_STATE_DIR"; exit $st
); then ok "rotation produced .1 backup past LFC_LOG_MAX"; else no "rotation did not occur"; fi

hr
echo "SUMMARY: PASS=$pass FAIL=$fail"
rm -rf "$STATE"
[ "$fail" = 0 ]
