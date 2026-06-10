# baton-runner — Reference

Operational detail for [SKILL.md](SKILL.md). The manager follows this; each unit
receives only the slice it needs (its prompt template). The manager never opens
diffs, batons, or gate logs — it threads *paths*.

## Worktree & branches

**One worktree for the whole run** (the workflow is strictly sequential, so a
single worktree has no contention). Pick a short `<run-id>` (e.g.
`br-<date>-<slug>`):

```bash
git -C <repo-root> fetch origin --prune
git -C <repo-root> worktree add <repo-root>/.worktrees/<run-id> \
  -b feat/<run-id>/phase-1 origin/main
```

Worktree location is `<repo-root>/.worktrees/<run-id>` to match the
repo-wide convention in the root `CLAUDE.md` (not `.claude/worktrees/`).

All units operate inside that worktree. Phases share one linear, accumulating
history — phase N's agent sees phase N-1's code because the files are physically
there. "Stacked branches" are just labels on that history:

| Phase | Branch (created in the SAME worktree) | Draft PR base |
|---|---|---|
| 1 | `feat/<run-id>/phase-1` | `main` |
| N | `feat/<run-id>/phase-N` (`git switch -c` from phase-(N-1) tip) | `feat/<run-id>/phase-(N-1)` |

**The manager opens draft PRs and merges nothing.** Push the phase branch, then
`gh pr create --draft --base <prev-branch> --head feat/<run-id>/phase-N
--body-file <tmp>`. The body states: "machine-gated (`scripts/gate.sh`) +
agent-reviewed (`multi-agent-review`); **not yet human-reviewed**", plus
`Refs #<issue>` when the phase maps to one. The user merges the stack **in order**
afterward. A `gh` failure is a fatal pause. Note in the final summary: post-run
edits to an early PR require rebasing the downstream stack.

Write all commit messages and PR bodies to a temp file and use `-F` /
`--body-file` — WSL arg-mangling silently drops text after a `:` otherwise.

## Run log & state

Directory `baton-runner/<run-id>/` (committed as the run's audit trail).

`STATE.md` — single source of truth for resume; keep current after every
transition:

```markdown
# baton-runner run <run-id>
status: RUNNING | PAUSED | DONE | FAILED
worktree: <abs path>
phase: <N of TOTAL>  unit: WORK|REVIEW|FIX  review_iter: <k of 3>
current_baton: <path>          # last baton produced
units_used: <n>                # against global ceiling
pause_reason: <text or ->
budgets: { global_ceiling: 75, phase_thrash: 20, bail_calls: 50, bail_files: 10 }
phases:
  - id: phase-1  spec: <issue#|file|inline>  readiness: READY|THIN|BLOCKED
    work_agent: general-purpose   # user-nominated agent for work units
    phase_branch: feat/<run-id>/phase-1   # the actual branch name used in this worktree
    branch: ...  pr: <url|->  digest: baton-runner/<run-id>/digest-phase-1.md
    units: <n>  state: DONE
  - id: phase-2  spec: ...  state: RUNNING ...
```

`log.md` — append-only, one UTC-stamped line per action (spawn, return status,
baton path, VERDICT, commit SHA, PR URL, budget counter, pause/resume).
Progress line format: `phase 3/6 · FIX iter2 · VERDICT ISSUES · units 17/75`.

## The objective gate — `scripts/gate.sh`

A committed, deterministic runner so verification is fixed and reproducible, not
improvised per spawn. The **review unit** runs it first; the manager never does.

```
scripts/gate.sh baton-runner/<run-id>/gate-phase-<N>-iter-<k>/
```

It runs `uv run pytest`, `uv run ruff check .`, `uv run ruff format --check .`,
`uv run mypy "$MYPY_TARGET"`, tees each to the log dir, prints `GATE: PASS|FAIL`,
and exits non-zero if any check fails. A green self-report with a red gate exit
means the unit is not done.

**Configurable env vars** (set in the worktree env at pre-flight; document any
override in `STATE.md` so resume sessions see the same gate):

- `MYPY_TARGET` — path mypy type-checks. Default `src`. Override per project
  (e.g. `src/foo`, `.`).
- `GATE_RUNNER` *(future-proofing)* — the gate currently assumes `uv run` is
  available. On non-uv projects, replace the `uv run` prefix in `scripts/gate.sh`
  with the project's equivalent (`poetry run`, `python -m`, etc.) — there is no
  runtime indirection yet, so this is an edit, not just an env override.
  `uv` must be present in the worktree pre-flight checklist.

## Unit prompt templates

Every spawn: `model: opus` (forced — overrides the agent's own default). Work
units use the phase's **work-agent** (default `general-purpose`); review and fix
units use `general-purpose`. Fill the `<...>`.

### Containment contract (append to EVERY unit prompt)

```
CONTAINMENT — you may read the repo but WRITE only inside this worktree: <path>.
Never touch ~/.claude, other worktrees, the main checkout, or system paths.
Do NOT run any mutating git command, push, or gh — the manager owns all git and
remote actions. You may run read-only git (diff/log/status) and tests/lint.
If you need a new dependency, DECLARE it in your baton; never add it silently.
If you need anything outside this contract, return STATUS: NEEDS_USER and stop.
```

### Return contract (append to EVERY unit prompt)

```
RETURN CONTRACT — your final message MUST be exactly these lines:
  STATUS: COMPLETE | INCOMPLETE | NEEDS_USER | FATAL
  BATON: <path to the baton-pass file you wrote/updated>
  NOTES: progress=<N>; <=3 lines: done / remaining / blocking question
Write/update the baton via the baton-pass skill BEFORE returning. Update it
incrementally — after each acceptance criterion and at least every ~10 tool
calls — so it is always a current resumable checkpoint. If you have made >=50
tool calls OR touched >=10 files (checked only at a stable point, never
mid-edit), OR cannot finish well, STOP and return INCOMPLETE with precise
remaining-work notes. Never sacrifice correctness to "finish".

PROGRESS TOKEN — `progress=<N>` is a monotonic integer counter you choose
(e.g. count of acceptance criteria with passing tests, or files completed).
It MUST increase between successive INCOMPLETE returns on the same baton. The
manager compares this number across continuations without opening the baton —
if it does not change across two INCOMPLETEs, that is a no-progress signal.
```

### Work unit

```
You implement ONE work-unit. Worktree: <path>.
Scope (your ONLY scope): <inline spec | `gh issue view <n>` | file path>.
Acceptance criteria (the bar you are held to): <criteria list>.
Continuity (what already exists — honor it, don't duplicate or contradict):
  <accumulated phase-exit digest paths, or "none — phase 1">.
[If continuation:] Resume from this baton (your full context): <baton path>.

Use the `tdd` skill. For EACH acceptance criterion: write the test first, run it,
and RECORD THE ACTUAL FAILING (RED) OUTPUT in your baton, then implement to green.
Honor the repo CLAUDE.md. Implement exactly the criteria — no scope creep.
<CONTAINMENT CONTRACT>
<RETURN CONTRACT>
```

### Review unit (independent of the implementer)

```
You review the work just done. Worktree: <path>. Do NOT change product code.
Work baton (what was claimed + the RED evidence): <baton path>.
Acceptance criteria / intent to verify against: <criteria / spec ref>.
Phase base branch (for diff): <base-branch>.

1. Run: scripts/gate.sh baton-runner/<run-id>/gate-phase-<N>-iter-<k>/
   If it exits non-zero, VERDICT is ISSUES — record the failures as findings;
   no deep review needed on broken code.

2. If gate is green: identify the files changed in this phase:
     git diff <base-branch>...HEAD --name-only
   Invoke /multi-agent-review in a single call that yields ONE
   synthesized report (the VERDICT must be single-valued):
   - Multiple changed files: multi-agent-review spec <path1> [<path2> ...]
     (one invocation, all paths)
   - Or, if changes are confined to one directory and there are many of
     them: multi-agent-review dir <that-subdir>
   Do NOT issue N separate `multi-agent-review file <path>` calls — that
   produces N unmerged reports with no single VERDICT to act on.
   Persist the synthesized report by passing
     --write-to baton-runner/<run-id>/review-phase-<N>-iter-<k>.md
   so the manager can reference the path without opening it.
   Use the project default roster (no --reviewers flag needed) unless the
   project's CLAUDE.md documents a specific review override for this type
   of change.
   Write the review report path to a temp file for inclusion in the baton.

3. Verify each acceptance criterion is genuinely met AND its tests are real
   (would fail if the implementation were reverted/mutated — not tautological).
   Flag any criterion lacking RED evidence in the baton.

4. Flag every newly added dependency for the user's visibility.

VERDICT = CLEAN iff: gate exits 0 AND the multi-agent-review synthesized
report contains zero CRITICAL or HIGH findings AND intent is met.
ON CLEAN, also write the phase-exit digest to
  baton-runner/<run-id>/digest-phase-<N>.md
(<=40 lines: public surface added — modules + key signatures — and decisions/
conventions the next phase must honor).
RETURN: STATUS line, then `VERDICT: CLEAN | ISSUES`, then BATON + NOTES.
<CONTAINMENT CONTRACT (no product-code edits)>
```

### Fix unit

```
You implement the findings from a review. Worktree: <path>.
Review baton (your scope — fix exactly these, nothing more): <review baton path>.
Use the `tdd` skill: add/adjust tests proving each finding is resolved (capture
RED first), then fix. Write a baton summarizing what was fixed and anything
deliberately deferred + why.
<CONTAINMENT CONTRACT>
<RETURN CONTRACT>
```

A fix-unit INCOMPLETE return is handled identically to a work-unit
continuation: the manager spawns a fresh fix unit seeded only with the fix
baton path (same template, fresh context) until it returns COMPLETE. The
3-iteration review cap is per review→fix loop, not per continuation.

## Spec readiness (pre-flight)

A spec is buildable only with (1) a clear outcome, (2) **testable acceptance
criteria**, (3) explicit scope/non-goals. Classify each phase:

- **READY** → proceed.
- **THIN** (goal clear, criteria missing/weak) → manager drafts proposed
  acceptance criteria and gets the user to confirm them at signoff. Never invent
  silently.
- **BLOCKED** (fundamental ambiguity/contradiction) → raise as an open question;
  the phase cannot start until resolved.

## Work-unit agent

By default work units (and their continuations) spawn as `general-purpose` — it
holds `*` tools, so it can edit files, run Bash, and invoke the `tdd` and
`baton-pass` skills the contract requires. At signoff the user may **nominate a
different agent per phase** (e.g. a domain specialist). Before accepting one:

- **Tool check.** The agent must support file edits + Bash **and the `Skill`
  tool** — most specialized agents (`python-pro`, `backend-developer`, …) carry
  `Read/Write/Edit/Bash/Glob/Grep` but **not** `Skill`, so they cannot run
  `/tdd` or `/baton-pass`. If the nominated agent lacks skill access, tell the
  user and either fall back to `general-purpose` or get explicit confirmation to
  proceed with an adapted contract (inline TDD + manual baton write).
- **Scope.** The nomination applies to **work units only**; review and fix units
  stay `general-purpose` (they must run the gate + review skills).
- **Model.** Spawns still force `model: opus` regardless of the agent's default.
- Record the choice as `work_agent` on the phase in `STATE.md`.

## Heuristic context split & resilience

The manager can't meter a subagent's context, so resilience comes from
right-sizing (pre-flight) + incremental baton checkpoints + a *countable* bail
budget (50 tool-calls or 10 files, whichever first), not from the agent
predicting its ceiling. On `INCOMPLETE`: spawn a continuation seeded only with
that baton path (fresh context), same template, until `COMPLETE`. Three
`INCOMPLETE`s with no progress = a fatal error.

**No-progress detection is path-only — never open the baton.** Compare the
`progress=<N>` token each unit prints on its NOTES line across successive
INCOMPLETE returns on the same baton. If `N` does not strictly increase
between two consecutive INCOMPLETEs, count it as a no-progress iteration;
three in a row is fatal. The manager records each token in `log.md` next to
the unit's progress line and reads it from there on resume — Golden Rule 2 is
preserved (paths, not contents).

## Commits (manager only)

One commit per completed unit (work and each fix), after the unit returns.
Transient red is acceptable — the phase's review→fix loop heals it before the
draft PR. Conventional commits, scoped to the phase; write the message to a temp
file and `git commit -F <file>`:

- work: `feat(phase-N): <work-unit summary>`
- fix:  `fix(phase-N): address review findings (iter k)`
- fold the `baton-runner/<run-id>/` log/state updates into the same commit.

## Failure handling

When a phase exhausts the 3-iteration cap (or a unit returns `FATAL`):

1. **Preserve everything** — no autonomous `git reset`, branch deletion, or
   force-anything. Preserve and explain, don't tidy. The failure baton
   MUST be `git add`'d and committed to the phase branch BEFORE any
   `git worktree remove` runs, otherwise the file lives only in the
   removed worktree and is lost.
2. **Write a failure baton**: what each iteration tried, the standing review
   findings, the last gate output path, and the best hypothesis for the block.
3. **Offer the user three choices**, act only on their pick:
   - **Guide & resume** → user adds direction; spawn a fresh fix unit seeded with
     the failure baton + guidance (iteration counter resets).
   - **Waive & proceed** → user explicitly accepts remaining findings; record the
     waiver in the phase's PR body + log; close the phase.
   - **Abandon/rollback** → ONLY here may the manager `git reset` the phase
     branch, and only because the user said so.

**Review-unit `INCOMPLETE`.** A review unit may return `INCOMPLETE` if it
ran out of budget before finishing (e.g., synthesizer didn't return).
Treat it the same as a work-unit `INCOMPLETE`: spawn a continuation seeded
from its baton, with the same template. The 3-iteration cap counts only
review→fix cycles where the review actually emitted a `VERDICT`.

**Review VERDICT `ISSUES` with no fix unit spawned.** If for any reason
the manager decides not to spawn the fix unit immediately after an
`ISSUES` verdict (e.g., the user paused mid-loop), the uncommitted
review baton must still be `git add`'d and committed to the phase branch
before any worktree cleanup; otherwise the next session has no record
of what the review found.

## Fatal errors (→ PAUSE; status PAUSED, or FAILED if unrecoverable)

- A required skill (`baton-pass`/`tdd`/`multi-agent-review`) or
  `scripts/gate.sh` is missing in the worktree.
- Test infrastructure cannot run at all (not "tests fail" — that is normal work).
- A unit returns `FATAL`, or `INCOMPLETE` ≥3× with no progress.
- Review can't reach `CLEAN` within the 3-iteration cap.
- A global/per-phase budget ceiling is hit.
- `gh pr create` fails, or a merge/rebase conflict needs non-mechanical judgment.
- Any unit reports it must act outside the containment contract.

On fatal: set `STATE = PAUSED` (or `FAILED` if unrecoverable), record the reason
and the exact resume point, show the user, and stop. Resuming re-reads `STATE.md`.
