# baton-runner-multi-agent — Reference

Operational detail for [SKILL.md](SKILL.md). The manager follows this; each
unit receives only the slice it needs (its prompt template). The manager
never opens diffs, batons, gate logs, or xmad synthesis reports — it threads
*paths*.

`baton-runner-multi-agent` is a fork of `baton-runner` whose work-unit delegates
to `/multi-agent-developer` instead of running `tdd` in a single
subagent. Everything else (review-unit, fix-unit, stacked PRs, gate
discipline, run log) is the same. Only the work-unit prompt and a few
state fields differ.

## Worktree & branches

**One run worktree for the whole run** (the workflow is strictly sequential,
so a single worktree has no contention). Pick a short `<run-id>` (e.g.
`brma-<date>-<slug>`):

```bash
git -C <repo-root> fetch origin --prune
git -C <repo-root> worktree add <repo-root>/.worktrees/<run-id> \
  -b feat/<run-id>/phase-1 origin/main
```

Worktree location is `<repo-root>/.worktrees/<run-id>` to match the
repo-wide convention in the root `CLAUDE.md` (not `.claude/worktrees/`).

All units operate inside that run worktree. Phases share one linear,
accumulating history — phase N's agent sees phase N-1's code because the
files are physically there. "Stacked branches" are just labels on that
history:

| Phase | Branch (created in the SAME run worktree) | Draft PR base |
|---|---|---|
| 1 | `feat/<run-id>/phase-1` | `main` |
| N | `feat/<run-id>/phase-N` (`git switch -c` from phase-(N-1) tip) | `feat/<run-id>/phase-(N-1)` |

**The manager opens draft PRs and merges nothing.** Push the phase branch,
then `gh pr create --draft --base <prev-branch> --head feat/<run-id>/phase-N
--body-file <tmp>`. The body states: "machine-gated (`scripts/gate.sh`) +
agent-reviewed (`multi-agent-review`); **work synthesised by
`/multi-agent-developer`**; **not yet human-reviewed**", plus
`Refs #<issue>` when the phase maps to one. The user merges the stack **in
order** afterward. A `gh` failure is a fatal pause. Note in the final
summary: post-run edits to an early PR require rebasing the downstream
stack.

Write all commit messages and PR bodies to a temp file and use `-F` /
`--body-file` — WSL arg-mangling silently drops text after a `:`
otherwise.

### xmad sub-worktrees (transient, owned by the work-unit)

During each phase's WORK step, the work-unit invokes xmad, which creates a
**sub-worktree** at `<run-worktree>/.worktrees/feat/<xmad-slug>` branched
from `origin/main`. This sub-worktree is transient — the work-unit ports
xmad's delta-against-`main` into the run worktree (via whole-file copy,
not patch apply — see "Work unit" step 3) and then `git worktree remove`s
the sub-worktree before returning.

Why the sub-worktree branches from `main` instead of the previous phase's
tip: xmad has no concept of stacked phases, and overriding its worktree
creation would require modifying the user-scope
`multi-agent-developer` skill (out of scope for project-scoped
baton-runner-multi-agent). The whole-file copy in step 3 is what stitches xmad's
per-phase output back onto the run worktree's stacked chain.

Consequence: xmad's in-sub-worktree test run verifies the phase in
isolation, not on top of the prior phases. The work-unit re-runs tests in
the run worktree (step 4) as a first cross-phase signal, and the
review-unit's `scripts/gate.sh` is the authoritative gate after the
manager commits.

If the work-unit returns with the xmad sub-worktree still present (failed
removal, FATAL return, etc.), the **manager** must surface that as part
of the pause state — never auto-`--force` remove. A leftover sub-worktree
inside the run worktree shadows the phase chain and corrupts the next
phase's `git worktree add`.

## Run log & state

Directory `baton-runner/<run-id>/` (committed as the run's audit trail —
the directory name stays `baton-runner/` even for `baton-runner-multi-agent`
runs, so all runs land in one consistent place regardless of fork).

`STATE.md` — single source of truth for resume; keep current after every
transition:

```markdown
# baton-runner-multi-agent run <run-id>
status: RUNNING | PAUSED | DONE | FAILED
worktree: <abs path>
phase: <N of TOTAL>  unit: WORK|REVIEW|FIX  review_iter: <k of 3>
current_baton: <path>          # last baton produced
units_used: <n>                # against global ceiling
pause_reason: <text or ->
budgets: { global_ceiling: 75, phase_thrash: 20, bail_calls: 50, bail_files: 10 }
phases:
  - id: phase-1  spec: <issue#|file|inline>  readiness: READY|THIN|BLOCKED
    xmad_agents: ecc-tdd-guide,kotlin-specialist,crypto-security-reviewer,ecc-kotlin-reviewer
      # user-approved dev specialist team passed to xmad's --agents flag
    xmar_reviewers: numeric-precision-reviewer,crypto-security-reviewer,ecc-kotlin-reviewer,code-reviewer
      # user-approved reviewer roster passed to xmar's --reviewers flag
      # (review-unit may override to migration-aware roster at invocation
      # time if the actual diff touches db/migration/ or an Exposed Table)
    synthesis_report: baton-runner/<run-id>/synthesis-phase-1.md  # xmad --write-report destination
    review_report:    baton-runner/<run-id>/review-phase-1-iter-1.md  # xmar --write-to destination (iter k)
    phase_branch: feat/<run-id>/phase-1   # the actual branch name used in this worktree
    pr: <url|->  digest: baton-runner/<run-id>/digest-phase-1.md
    units: <n>  state: DONE
  - id: phase-2  spec: ...  state: RUNNING ...
```

`log.md` — append-only, one UTC-stamped line per action (spawn, return
status, baton path, VERDICT, commit SHA, PR URL, budget counter,
pause/resume). Progress line format:
`phase 3/6 · FIX iter2 · VERDICT ISSUES · units 17/75`.

## The objective gate — `scripts/gate.sh`

A committed, deterministic runner so verification is fixed and
reproducible, not improvised per spawn. The **review unit** runs it
first; the manager never does.

```
scripts/gate.sh baton-runner/<run-id>/gate-phase-<N>-iter-<k>/
```

It runs `./gradlew build -x test`, `./gradlew test`, and
`./gradlew ktlintCheck` (if available), tees each to the log dir,
prints `GATE: PASS|FAIL`, and exits non-zero if any check fails. A green
self-report with a red gate exit means the unit is not done.

## Unit prompt templates

Every spawn: `model: opus` (forced — overrides the agent's own default).
Work, review, and fix units all use `general-purpose` as `subagent_type`
(work units need the `Skill` tool to invoke `/multi-agent-developer`
and the full `*` tool set to copy files between worktrees + remove xmad's
sub-worktree). Fill the `<...>`.

### Containment contract (append to EVERY unit prompt)

```
CONTAINMENT — you may read the repo but WRITE only inside this worktree: <path>.
Never touch ~/.claude, other worktrees outside this run, the main checkout, or
system paths. Do NOT run any mutating git command, push, or gh — the manager
owns all git and remote actions. You may run read-only git (diff/log/status)
and tests/lint. If you need a new dependency, DECLARE it in your baton; never
add it silently. If you need anything outside this contract, return STATUS:
NEEDS_USER and stop.

EXCEPTION (work units only): you MAY create + remove xmad's sub-worktree at
<this-worktree>/.worktrees/feat/<xmad-slug> as part of invoking
/multi-agent-developer. xmad creates it via its own `git worktree add`,
and you remove it with `cd <run-worktree-path> && git worktree remove .worktrees/feat/<xmad-slug>` at
step 5 of the work-unit flow. Any other mutating git remains forbidden.
```

### Return contract (append to EVERY unit prompt)

```
RETURN CONTRACT — your final message MUST be exactly these lines:
  STATUS: COMPLETE | INCOMPLETE | NEEDS_USER | FATAL
  BATON: <path to the baton-pass file you wrote/updated>
  NOTES: <=3 lines: done / remaining / blocking question
Write/update the baton via the baton-pass skill BEFORE returning. Update it
incrementally — after each acceptance criterion and at least every ~10 tool
calls — so it is always a current resumable checkpoint. If you exceed ~50 tool
calls OR ~10 files touched (checked only at a stable point, never mid-edit), OR
cannot finish well, STOP and return INCOMPLETE with precise remaining-work
notes. Never sacrifice correctness to "finish".

For work units: the ~50/~10 bail budget counts THIS WRAPPER's tool calls (the
xmad invocation, the file copies, the worktree-remove, the baton write) — NOT
xmad's internal tool calls. xmad meters itself.
```

### Work unit

The work-unit is a **thin wrapper around `/multi-agent-developer`
(xmad)**. It does not write product code itself — it invokes xmad with the
phase's pre-resolved team, auto-approves xmad's Phase 5 gate, ports xmad's
delta into the run worktree, and removes xmad's sub-worktree.

```
You wrap ONE work-unit. Run worktree: <run-worktree-path>.
Scope (your ONLY scope): <inline spec | `gh issue view <n>` | file path>.
Acceptance criteria (the bar xmad's team will be held to): <criteria list>.
Continuity (what already exists in the worktree — honor it, don't duplicate
or contradict): <accumulated phase-exit digest paths, or "none — phase 1">.
xmad team (user-approved at pre-flight; pass verbatim to --agents):
  <comma-separated slugs, e.g.
   ecc-tdd-guide,kotlin-specialist,crypto-security-reviewer,ecc-kotlin-reviewer>
xmad synthesis report destination:
  <run-worktree-relative-path>, e.g.
   baton-runner/<run-id>/synthesis-phase-<N>.md
[If continuation:] Resume context (your full prior state): <work-unit baton path>.
  xmad does NOT resume across invocations — xmad on this continuation
  invocation starts from scratch on a new sub-worktree; your baton is
  context FOR YOU to pass as an inline `Continuity:` block in the xmad
  invocation spec, not a state file xmad resumes from. Concretely: rewrite
  the phase spec with already-completed criteria marked [DONE] and remaining
  criteria listed first, then invoke xmad with that rewritten spec path.
  Your baton summarises what xmad already produced (files written, criteria
  covered, RED evidence captured) so this invocation can pick up cleanly.

STEPS:

1. Verify framework agents are activated in the run worktree:
     ls <run-worktree-path>/.claude/agents/ecc-code-explorer.md
     ls <run-worktree-path>/.claude/agents/ecc-code-architect.md
   If either is missing, RETURN STATUS: FATAL (the baton-runner-multi-agent
   pre-flight should have caught this — do not run setup yourself; the
   manager owns that).

2. Invoke xmad from the run worktree:
     cd <run-worktree-path>
     /multi-agent-developer file <spec-path-relative-to-worktree> \
       --agents <comma-separated-slugs> \
       --write-report <synthesis-report-path>

   When xmad reaches its Phase 5 approval gate it will ask for team approval.
   Reply `y` IMMEDIATELY — the team is pre-approved at the baton-runner-multi-agent
   level, and stalling here would block the manager indefinitely. If xmad
   asks anything else (activation halt, disagreement escalation, branch-slug
   collision), STOP and RETURN STATUS: NEEDS_USER with the question in
   NOTES — that is a real user decision, not a gate auto-approve.

   xmad will create a SUB-WORKTREE at
   <run-worktree-path>/.worktrees/feat/<xmad-slug> branched from
   origin/main, run RED→GREEN→REFACTOR rounds, synthesise via
   ecc-code-architect, apply files to that sub-worktree, run the project's
   test command in that sub-worktree, and (unless --no-retry) do one
   GREEN-redux on test failure. Capture xmad's final report — it lists the
   files written + verify status (PASS|FAIL|SKIPPED).

3. Port xmad's delta into the run worktree. xmad's sub-worktree branched
   from origin/main, so its diff against main is exactly the phase's intent
   (and excludes the prior phases' code, which already lives in the run
   worktree from earlier phases in this run):

     xmad_wt=<run-worktree-path>/.worktrees/feat/<xmad-slug>
     # Capture the changed file list into your baton as the "files copied" list.
     while IFS= read -r f; do
       mkdir -p "<run-worktree-path>/$(dirname "$f")"
       cp -a "$xmad_wt/$f" "<run-worktree-path>/$f"
     done < <(git -C "$xmad_wt" diff main..HEAD --name-only)

   (Use the whole-file copy loop above — NOT `git apply` of an xmad-vs-main
   patch — because xmad's worktree is freshly branched from main and never
   sees the prior phases, so the patch context lines would mismatch when
   applied onto the run worktree's phase chain. Whole-file copy is the
   safe option.)

4. Run the project's test command in the RUN worktree (NOT xmad's
   sub-worktree) — this is the first signal that xmad's code composes
   correctly with the prior phases. Capture the output in your baton.
   Return COMPLETE regardless of this test outcome — the review-unit's
   `scripts/gate.sh` is the authoritative gate. A green run here is a
   positive signal; a red run must be recorded verbatim in your baton so
   the review-unit sees it immediately.

5. Remove xmad's sub-worktree (the synthesis report at
   <synthesis-report-path> already preserves what was done):
     cd <run-worktree-path>
     git worktree remove .worktrees/feat/<xmad-slug>
   If the remove fails (uncommitted state, locked), RETURN STATUS: FATAL
   with the error — do NOT --force, do NOT delete by hand. The
   baton-runner-multi-agent manager owns cleanup decisions.

6. Write your baton via the `baton-pass` skill. It MUST include:
   - The xmad synthesis report path (<synthesis-report-path>).
   - The file list copied in step 3.
   - The run-worktree test output from step 4.
   - For each acceptance criterion: a one-line
     "covered by <test-file>:<line>" pointing into the files xmad
     created/modified, and the RED evidence captured by xmad in the
     synthesis report.

DO NOT edit product code yourself. xmad's team owns the code; you own the
orchestration glue. If xmad fails to satisfy a criterion, RETURN
INCOMPLETE — do not patch it inline. Honor the repo CLAUDE.md (BigDecimal
rules, Prime Directive §1) when deciding whether xmad's output is
acceptable; xmad's team should already honor these (they're in the repo
CLAUDE.md xmad's agents read), but you are the last gate before commit.

<CONTAINMENT CONTRACT>
<RETURN CONTRACT>
```

### Review unit (independent of the implementer)

The review-unit is a **thin wrapper around `/multi-agent-review` (xmar)**,
symmetric to the work-unit's xmad wrapper. It runs the objective gate first,
then invokes xmar with the phase's pre-resolved reviewer roster, threads the
synthesized report's path back to the manager, and emits `VERDICT`. It does
not read xmar's report contents to make the decision — `CLEAN` iff xmar's
top-line counts (CRITICAL / HIGH) are both zero AND the gate passed AND
intent is met per the acceptance criteria.

```
You wrap ONE review-unit. Run worktree: <run-worktree-path>. Do NOT change
product code.
Work baton (what was claimed + the xmad synthesis report path + files-copied
list + RED evidence reference): <baton path>.
Acceptance criteria / intent to verify against: <criteria / spec ref>.
Phase base branch (for diff): <base-branch>.
xmar reviewer roster (user-approved at pre-flight; pass verbatim to
--reviewers, possibly overridden — see step 2): <comma-separated slugs, e.g.
 numeric-precision-reviewer,crypto-security-reviewer,ecc-kotlin-reviewer,code-reviewer>
xmar review report destination:
  baton-runner/<run-id>/review-phase-<N>-iter-<k>.md

STEPS:

1. Run: scripts/gate.sh baton-runner/<run-id>/gate-phase-<N>-iter-<k>/
   If it exits non-zero, VERDICT is ISSUES — record the failures as findings;
   no deep review needed on broken code. Skip step 2; do not invoke xmar
   on broken code (no point burning the credits, and reviewer agents have
   nothing useful to say about a code base that doesn't compile).

2. If gate is green: identify the files changed in this phase:
     git diff <base-branch>...HEAD --name-only

   Decide the actual reviewer roster:
   - DEFAULT: use the pre-resolved <xmar reviewer roster> verbatim.
   - OVERRIDE: if the diff touches `db/migration/` or any Exposed `Table`
     object under `<your-project>.db` (example: a Kotlin/Exposed project), REPLACE (not append) the roster
     with the migration-aware roster:
       ecc-kotlin-reviewer,crypto-security-reviewer,numeric-precision-reviewer,critical-thinking,flyway-exposed-parity-reviewer
     `--reviewers` REPLACES the default — it does not add. Note that
     `code-reviewer` is deliberately excluded from the migration override:
     migration parity is structural, `flyway-exposed-parity-reviewer`
     covers that lane, and the general-quality lens is dropped to keep
     the roster focused. Record the override in your baton ("xmar roster
     upgraded from <original> to migration-aware: diff touches
     <file-path>") so it's auditable post-run.

   Invoke xmar in a SINGLE call that yields ONE synthesized report (the
   VERDICT must be single-valued):
   - Multiple changed files: multi-agent-review spec <path1> [<path2> ...]
     --reviewers <roster> --write-to <review report destination>
     (one invocation, all paths)
   - Or, if changes are confined to one directory and there are many of
     them: multi-agent-review dir <that-subdir>
     --reviewers <roster> --write-to <review report destination>
   Do NOT issue N separate `multi-agent-review file <path>` calls — that
   produces N unmerged reports with no single VERDICT to act on.

   Capture xmar's top-line totals from its return summary (CRITICAL count,
   HIGH count). Do NOT open the report file to count manually — xmar prints
   the totals to the chat output before persisting the file. Write the
   review report path + totals to your baton.

3. Verify each acceptance criterion is genuinely met AND its tests are real
   (would fail if the implementation were reverted/mutated — not tautological).
   The work-unit's baton cites <test-file>:<line> for each criterion and
   points to xmad's synthesis report for RED evidence; cross-check those
   pointers without opening xmad's (already-removed) sub-worktree — the
   synthesis report file on disk is enough.
   Flag any criterion lacking RED evidence in the baton.

4. Flag every newly added dependency for the user's visibility. xmad's
   team should have declared new deps in its synthesis report's
   "Architectural Decisions" or "Open Questions" sections; if a dep
   appears in the diff but not in those sections, flag it as a finding
   ("silent dependency add — violates xmad declared-deps contract").

VERDICT = CLEAN iff: gate exits 0 AND the xmar synthesized report contains
zero CRITICAL findings AND zero HIGH findings AND intent is met (every
acceptance criterion has real test coverage AND no silent dep add).
ON CLEAN, also write the phase-exit digest to
  baton-runner/<run-id>/digest-phase-<N>.md
(<=40 lines: public surface added — modules + key signatures — and decisions/
conventions the next phase must honor).
RETURN: STATUS line, then `VERDICT: CLEAN | ISSUES`, then BATON + NOTES.
NOTES should include xmar's CRITICAL/HIGH counts (e.g.
`progress=xmar CRITICAL 0; HIGH 2; criteria 4/5`).
<CONTAINMENT CONTRACT (no product-code edits)>
```

### Fix unit

Fix units use plain `tdd` — they do NOT re-invoke xmad. The multi-agent
debate already happened in the work-unit; review findings are targeted
enough that a single TDD specialist can address them.

```
You implement the findings from a review. Worktree: <run-worktree-path>.
Review baton (your scope — fix exactly these, nothing more): <review baton path>.
Use the `tdd` skill: add/adjust tests proving each finding is resolved
(capture RED first), then fix. Write a baton summarizing what was fixed
and anything deliberately deferred + why.
<CONTAINMENT CONTRACT>
<RETURN CONTRACT>
```

## Spec readiness (pre-flight)

A spec is buildable only with (1) a clear outcome, (2) **testable
acceptance criteria**, (3) explicit scope/non-goals. Classify each phase:

- **READY** → proceed.
- **THIN** (goal clear, criteria missing/weak) → manager drafts proposed
  acceptance criteria and gets the user to confirm them at signoff. Never
  invent silently.
- **BLOCKED** (fundamental ambiguity/contradiction) → raise as an open
  question; the phase cannot start until resolved.

## xmad team (per phase) — replaces "Work-unit agent"

The work-unit subagent itself is **always `general-purpose`** — it needs
the `Skill` tool to invoke `/multi-agent-developer` and the full `*`
tool set to copy files between worktrees and call `git worktree remove`.
What the user nominates per phase is xmad's **dev specialist team**,
passed verbatim via `--agents`. This is the only way to keep xmad's
Phase 5 approval gate non-blocking under autonomous control: the team
must be user-approved before the work-unit invokes xmad, so the subagent
can reply `y` at xmad's prompt without consulting anyone.

At signoff, propose 4 specialists per phase using xmad's own Phase 3
heuristics (domain match, layer match, security baseline, TDD
discipline; prefer ECC-flavoured agents for code-quality lanes; prefer
specialists over generalists). Example: for a Kotlin trading-pipeline project, phases that touch the order pipeline might default to the `crypto-security-reviewer` + `numeric-precision-reviewer` pair plus a Kotlin implementer (`kotlin-specialist` or `ecc-tdd-guide`) plus `ecc-kotlin-reviewer`. Substitute the equivalent specialists for your domain. Let the user swap/add/drop before approving.

Per-phase signoff line example:

```
phase-1: Pacifica connector
  xmad team: ecc-tdd-guide, kotlin-specialist, crypto-security-reviewer, ecc-kotlin-reviewer
```

Record on each phase in `STATE.md` as `xmad_agents: <csv>`.

**Constraints on the team:**

- **All slugs must validate against xmad's catalog union** at invocation
  time (`<repo>/.claude/agents/` ∪ `~/.claude/agents-parked/CATALOG.md`
  ∪ the user-disabled-skills section). If a parked slug is picked, the
  user must run `git mv` to activate it before the work-unit invokes
  xmad — surface this at signoff, do not defer to xmad's runtime
  activation halt (which would block the autonomous loop).
- **Framework agents (`ecc-code-explorer`, `ecc-code-architect`) are
  NEVER in this list** — xmad treats them as bootstrap deps, not dev
  specialists. Listing them in `--agents` will likely cause xmad to
  hard-fail validation.
- **`--max-agents` defaults to 4**, xmad's hard ceiling. If a phase
  genuinely needs more lanes, split the phase.

**Scope of nomination.** This applies to xmad's team for work-units only.
Review-units have their own pre-resolved roster (see "xmar roster" below);
fix-units stay `general-purpose` and invoke `tdd` directly, NOT xmad,
because the multi-agent debate already happened in the work-unit.

**Model.** Work-unit and continuation spawns still force `model: opus`
regardless of `general-purpose`'s default — and xmad internally forces
`model: opus` for every dev specialist it spawns, so the chain is Opus
end-to-end.

## xmar roster (per phase) — review-unit's reviewer team

Mirrors the xmad-team pattern for the review side. The review-unit
subagent itself is always `general-purpose`; what the user nominates per
phase is the **reviewer roster** that the review-unit passes to xmar's
`--reviewers` flag. Recorded as `xmar_reviewers` on each phase in
`STATE.md`.

Unlike xmad, xmar has **no interactive approval gate** — it just runs the
roster and synthesises via `knowledge-synthesizer`. So pre-resolution
here isn't about unblocking; it's about making the per-phase review lens
explicit, auditable, and stable across iterations of the review→fix
loop. (Without pre-resolution, every review iteration would re-pick a
roster, which would make iter-2's CRITICAL/HIGH counts incomparable to
iter-1's. With pre-resolution, the roster only changes when the diff
crosses a threshold the review-unit checks at invocation time.)

**Default proposals at signoff:**

| Phase shape | Proposed roster |
|---|---|
| **Plain** (no migration, no Exposed table) | `numeric-precision-reviewer, crypto-security-reviewer, ecc-kotlin-reviewer, code-reviewer` (the project default) |
| **Migration-touching** (the phase will create/edit `db/migration/V<N>__*.sql` or any `<your-project>.db.Table` (example: a Kotlin/Exposed project) object) | `ecc-kotlin-reviewer, crypto-security-reviewer, numeric-precision-reviewer, critical-thinking, flyway-exposed-parity-reviewer` (note: `code-reviewer` deliberately dropped — `flyway-exposed-parity-reviewer` covers the structural lane the general lens would otherwise duplicate) |

(Verify `critical-thinking.md` is present in `.claude/agents/` before using the migration-aware roster; if absent, substitute `code-reviewer` or remove it from the roster.)

For phases whose shape is uncertain at pre-flight (could end up touching
migrations once xmad's team gets in there), default to the **plain** roster
and rely on the review-unit's invocation-time override to upgrade if the
actual diff crosses the threshold. Always cheaper to upgrade than to
review with the wrong lens.

**Constraints on the roster:**

- **All slugs must resolve in `<repo>/.claude/agents/`** at invocation
  time. xmar does not consult the user-parked catalog (unlike xmad's
  team selection), so any reviewer listed here must already be active
  in the project. Most domain-specific review lanes (in this example) are project-scoped
  already (`crypto-security-reviewer`, `numeric-precision-reviewer`,
  `ecc-kotlin-reviewer`, `flyway-exposed-parity-reviewer`,
  `code-reviewer`); verify the slug exists in
  `<repo>/.claude/agents/` at signoff time.
- **`code-reviewer` is the catch-all "everything else" lens.** Keep it
  in the plain roster unless you have a specific reason to drop it; the
  migration-aware roster is the documented exception.
- **No upper limit on roster size**, but every extra reviewer is a
  separate Opus invocation per iteration — 4–5 reviewers is the sweet
  spot. xmar's synthesizer (`knowledge-synthesizer`) handles arbitrary
  N, but the cost scales linearly.

**Override authority at invocation time.** The review-unit MAY upgrade
the roster from "plain" to "migration-aware" if the actual diff touches
`db/migration/` or any `<your-project>.db` (example: a Kotlin/Exposed project) `Table` object. This is the
only roster mutation allowed mid-loop; any other change (e.g., a desire
to add `critical-thinking` to a plain phase) requires the user to pause
the run and re-resolve at signoff. The override is logged in the
review-unit's baton ("xmar roster upgraded from <original> to
migration-aware: diff touches <file-path>") so it is auditable post-run.

**Iteration stability.** The roster captured at pre-flight (or the
override committed in iter-1) is reused verbatim across iterations 2
and 3 of the review→fix loop. This is intentional — comparing
CRITICAL/HIGH counts across iterations is the manager's "is the fix
landing?" signal, and that comparison only works if the lens is fixed.

## Heuristic context split & resilience

The manager can't meter a subagent's context, so resilience comes from
right-sizing (pre-flight) + incremental baton checkpoints + a *countable*
bail budget (≈50 tool-calls / ≈10 files), not from the agent predicting
its ceiling. For work units, the bail budget counts only the wrapper's
own tool calls (xmad invocation, file copies, worktree remove, baton
write) — xmad meters itself internally.

On `INCOMPLETE`: spawn a continuation seeded only with that baton path
(fresh context), same template, until `COMPLETE`. After reading STATE.md,
confirm `git -C <run-worktree-path> branch --show-current` matches the last
active `phase_branch` before spawning the next unit. If it does not, run
`git -C <run-worktree-path> switch <last-phase-branch>` before proceeding.
Three consecutive `INCOMPLETE` returns whose NOTES token is unchanged → fatal error; NOTES token changed between returns → continue spawning a continuation.

## Commits (manager only)

One commit per completed unit (work and each fix), after the unit returns.
Transient red is acceptable — the phase's review→fix loop heals it before
the draft PR. Conventional commits, scoped to the phase; write the message
to a temp file and `git commit -F <file>`:

- work: `feat(phase-N): <work-unit summary>` (cite xmad team + synthesis
  report path in the body — the team is the "how" and the report is the
  "why")
- fix:  `fix(phase-N): address review findings (iter k)`
- fold the `baton-runner/<run-id>/` log/state updates into the same commit.

## Failure handling

When a phase exhausts the 3-iteration cap (or a unit returns `FATAL`):

1. **Preserve everything** — no autonomous `git reset`, branch deletion,
   or force-anything. Preserve and explain, don't tidy. The failure baton
   MUST be `git add`'d and committed to the phase branch BEFORE any
   `git worktree remove` runs, otherwise the file lives only in the
   removed worktree and is lost. If an xmad sub-worktree is leftover at
   pause time (FATAL during work-unit step 5), do NOT auto-`--force`
   remove — surface it as part of the pause state and let the user
   inspect xmad's sub-worktree before the manager cleans up.
2. **Write a failure baton**: what each iteration tried, the standing
   review findings, the last gate output path, the xmad synthesis report
   path (if the failure was downstream of a completed xmad run), and the
   best hypothesis for the block.
3. **Offer the user three choices**, act only on their pick:
   - **Guide & resume** → user adds direction; spawn a fresh fix unit
     seeded with the failure baton + guidance (iteration counter resets).
     The user may also choose to re-run xmad with a *different* team via
     a fresh work-unit; that resets the phase to WORK state.
   - **Waive & proceed** → user explicitly accepts remaining findings;
     record the waiver in the phase's PR body + log; close the phase.
   - **Abandon/rollback** → ONLY here may the manager `git reset` the
     phase branch, and only because the user said so.

**Review-unit `INCOMPLETE`.** A review unit may return `INCOMPLETE` if it
ran out of budget before finishing (e.g., synthesizer didn't return).
Treat it the same as a work-unit `INCOMPLETE`: spawn a continuation
seeded from its baton, with the same template. The 3-iteration cap counts
only review→fix cycles where the review actually emitted a `VERDICT`.

**Review VERDICT `ISSUES` with no fix unit spawned.** If for any reason
the manager decides not to spawn the fix unit immediately after an
`ISSUES` verdict (e.g., the user paused mid-loop), the uncommitted review
baton must still be `git add`'d and committed to the phase branch before
any worktree cleanup; otherwise the next session has no record of what
the review found.

## Fatal errors (→ PAUSE; status PAUSED, or FAILED if unrecoverable)

- A required skill (`baton-pass`/`multi-agent-developer`/
  `multi-agent-developer-setup`/`multi-agent-review`/`tdd`) or
  `scripts/gate.sh` is missing in the worktree.
- xmad's framework agents (`ecc-code-explorer.md`,
  `ecc-code-architect.md`) are missing from `<repo>/.claude/agents/`.
  Resolution: user runs `/multi-agent-developer-setup` once on
  `origin/main`, commits, and re-bases the run worktree. Do NOT auto-run
  setup from the run worktree — setup edits the main checkout's tracked
  `.claude/agents/`.
- A work-unit reports xmad asked an unexpected blocking question
  (anything other than the Phase 5 team-approval gate it was
  pre-authorised to auto-`y`): activation halt, branch-slug collision,
  disagreement escalation, etc.
- xmad's sub-worktree could not be removed by the work-unit (lock /
  uncommitted state) — the manager must clean up by hand before retrying;
  never auto-`--force`.
- Test infrastructure cannot run at all (not "tests fail" — that is
  normal work).
- A unit returns `FATAL`, or `INCOMPLETE` ≥3× with no progress.
- Review can't reach `CLEAN` within the 3-iteration cap.
- A global/per-phase budget ceiling is hit.
- `gh pr create` fails, or a merge/rebase conflict needs non-mechanical
  judgment.
- Any unit reports it must act outside the containment contract.

On fatal: set `STATE = PAUSED` (or `FAILED` if unrecoverable), record the
reason and the exact resume point, show the user, and stop. Resuming
re-reads `STATE.md`.
