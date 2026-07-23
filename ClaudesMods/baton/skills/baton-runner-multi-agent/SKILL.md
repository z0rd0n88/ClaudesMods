---
name: baton-runner-multi-agent
description: Fork of /baton-runner whose work-unit delegates to /multi-agent-developer (≤4 Opus dev specialists debating RED→GREEN→REFACTOR). User-invoked; multi-phase builds wanting a multi-agent debate at the implement step.
---

# baton-runner-multi-agent

Fork of `baton-runner` whose **work-unit step delegates to
`/multi-agent-developer` (xmad)** instead of running `tdd` directly in
a single subagent. Use this when each phase benefits from a multi-agent
debate — e.g., a phase that crosses Kotlin idiomaticness + crypto-signing
safety + BigDecimal precision lanes, where one TDD specialist alone would
miss cross-lane interactions. For phases where a single implementer plus
the standard review-unit is enough, prefer `/baton-runner` — it has
strictly less moving machinery.

Orchestrates a multi-phase build. You (the session running this skill) are the
**baton-runner-multi-agent-manager**: a thin, restartable scheduler. You never write
product code, run tests, or read diffs/baton contents — you spawn **units**
(subagents), thread file *paths* between them, commit, open a draft PR per
phase, enforce budgets, log, and pause. All state lives on disk
(`baton-runner/<run-id>/`) so a fresh manager session resumes from `STATE.md`
indistinguishably.

> Run in an **Opus** session. Correctness over speed. Detail lives in
> [REFERENCE.md](REFERENCE.md); this file is the control flow.

## Golden rules

1. **Opus only** — every spawn uses `model: opus`. xmad internally also forces
   `model: opus` for each dev specialist it spawns, so the chain is Opus
   end-to-end.
2. **Manager stays lean** — read only each unit's short return block
   (STATUS/VERDICT/BATON/NOTES for review units; STATUS/BATON/NOTES for
   work and fix units); move *paths*, never contents; never open
   diffs/batons/gate-logs/xmad-synthesis-reports. Write `STATE.md` at each
   phase boundary; when your own window fills, finalize STATE, tell the
   user to resume fresh, and stop. The NOTES line itself is part of the
   manager's input — it is not a file contents — so you may compare
   NOTES text across returns (see "No progress" below) without violating
   this rule.
3. **Manager does all git/remote; units never do.** xmad's sub-worktree
   creation/removal is the one exception — the work-unit owns that
   lifecycle because xmad owns the sub-worktree, not the manager.
4. **Verification is delegated** — "done" = the unit's `STATUS` + the review
   unit's `VERDICT`, never your own inspection. Note xmad's
   in-sub-worktree test run is a *first* signal, not the authoritative
   one; `scripts/gate.sh` (run by the review-unit on the *integrated*
   phase chain) is the gate.
5. **Context crosses agents only through files** (batons, phase-exit digest,
   xmad synthesis reports).
6. **Stop, don't guess** — user-input, budget ceiling, or fatal error → PAUSE
   (write STATE, show the user, stop).

## Roles

| Term | Meaning |
|---|---|
| **work-unit** | Invokes `/multi-agent-developer` (xmad) to implement a phase's acceptance criteria with a TDD-disciplined multi-agent dev team (≤4 Opus agents debating RED→GREEN→REFACTOR, synthesised via `ecc-code-architect`). Operates as a thin wrapper: pre-resolves the team and passes it via `--agents` (so xmad's Phase 5 approval gate becomes a one-line auto-approve), then ports xmad's delta-against-`main` into the baton-runner-multi-agent phase worktree. xmad still creates its own sub-worktree at `.worktrees/feat/<xmad-slug>` per its invariants — the work-unit copies the changed files out and removes that sub-worktree before returning. See REFERENCE → "Work unit" for the exact flow. |
| **review-unit** | Independent of the implementer. Thin wrapper around `/multi-agent-review` (xmar): runs `scripts/gate.sh`, then invokes xmar over the phase diff with the phase's pre-resolved `--reviewers` roster and `--write-to baton-runner/<run-id>/review-phase-<N>-iter-<k>.md`; emits `VERDICT` from xmar's synthesized report (zero CRITICAL/HIGH findings); on `CLEAN` writes the phase-exit digest. Symmetric to the work-unit's xmad wrapper. |
| **fix-unit** | Implements the review-unit's findings via `tdd` directly (lightweight — fix units do NOT re-invoke xmad; the multi-agent debate already happened in the work-unit). |
| **baton / digest** | `baton-pass` file carrying unit state (updated incrementally) / terse map of public surface + decisions threaded to later phases. A work-unit baton MUST record the xmad **synthesis report path** (`--write-report` output) and the **list of files copied** into the baton-runner-multi-agent worktree, so the review-unit can correlate xmad's reasoning to the phase diff without opening xmad's (already-removed) sub-worktree. |

## Pre-flight — before work unit 1

- [ ] **`scripts/gate.sh` present on `origin/main`.** This file is the
      objective gate every review unit runs (see REFERENCE → "The objective
      gate"). Verify with `git -C <run-worktree-path> ls-files scripts/gate.sh`
      — if the command returns empty, stop and tell the user `scripts/gate.sh`
      is missing from `origin/main`.
- [ ] **Fresh single worktree**; confirm `baton-pass`,
      `multi-agent-developer`, `multi-agent-developer-setup`,
      `multi-agent-review`, `tdd`, and `scripts/gate.sh` resolve there.
      `multi-agent-developer`, `tdd`, and the setup skill are allowed
      to resolve from user scope (`~/.claude/skills/`); they do not need
      to live in the project's `.claude/skills/`. The `tdd` skill is still
      required because fix-units use it directly (work-units use it
      transitively through xmad).
- [ ] **xmad framework agents activated.** Verify both
      `<repo>/.claude/agents/ecc-code-explorer.md` and
      `<repo>/.claude/agents/ecc-code-architect.md` exist. If either is
      absent, **stop and instruct the user to run
      `/multi-agent-developer-setup`** once on `origin/main` (a
      one-time per-project move from `~/.claude/agents-parked/`), commit,
      and re-base the run worktree before re-invoking this skill. Do NOT
      auto-run setup — it edits the main checkout's tracked
      `.claude/agents/` and is a deliberate one-time act per project.
- [ ] **Parse + right-size** the phase list (each phase ≤ ~5 acceptance criteria
      / ~10 files; split larger into ordered sub-units).
- [ ] **Spec readiness** per phase → `READY` / `THIN` / `BLOCKED` (draft proposed
      criteria for `THIN`).
- [ ] **xmad team per phase (required, replaces work-unit-agent).** Pre-resolve
      the dev specialist team that the work-unit will pass to xmad's
      `--agents` flag. This is the *only* way to keep xmad's Phase 5
      approval gate non-blocking under autonomous control — the work-unit
      can auto-`y` when xmad asks because the team was already
      user-approved here. Default proposal: 4 specialists chosen against
      the phase's domain by the same heuristics xmad uses in its Phase 3
      (security/lane/consistency/simplicity); surface as a per-phase line
      in the signoff and let the user swap/add/drop before approving.
      Record as `xmad_agents` on the phase in STATE.
- [ ] **xmar reviewer roster per phase (required, mirrors the xmad team).**
      Pre-resolve the reviewer roster the review-unit will pass to xmar's
      `--reviewers` flag. Unlike xmad, xmar has no interactive approval
      gate (it runs the roster and synthesises) — so pre-resolution here
      isn't about unblocking, it's about making the per-phase review lens
      explicit and auditable. Default proposal: the project default roster
      (`numeric-precision-reviewer, crypto-security-reviewer,
      ecc-kotlin-reviewer, code-reviewer`); for phases whose diff is
      expected to touch `db/migration/` or an Exposed `Table` object,
      switch to the migration-aware roster (`ecc-kotlin-reviewer,
      crypto-security-reviewer, numeric-precision-reviewer,
      critical-thinking, flyway-exposed-parity-reviewer` — note
      `code-reviewer` is intentionally dropped). Surface per phase at
      signoff; let the user swap/add/drop. Record as `xmar_reviewers` on
      the phase in STATE. Fix units stay `general-purpose`. (The
      review-unit determines at invocation time whether the *actual*
      diff still matches the predicted "migration-touching" classification;
      if a phase predicted "plain" but the diff ended up touching
      migrations, the review-unit upgrades to the migration-aware roster
      and notes the override in its baton.)
- [ ] **Open questions + signoff** — surface ambiguities, the proposed criteria,
      the per-phase xmad team, and the per-phase xmar roster. **Do not
      spawn work unit 1 until the user signs off.**
- [ ] **Init** `baton-runner/<run-id>/` (`STATE.md` + `log.md` with tunable
      budgets). TodoWrite: one todo per phase.

## Per-phase loop

For each phase in order, with **fresh context** (this phase's spec + the
accumulated phase-exit digests only):

0. **Write the per-phase prelude.** Before WORK, the manager writes
   `baton-runner/<run-id>/phase-<N>-prelude.md` once, concatenating two
   sections per the canonical headings in
   [`refs/multi-agent/spec-injection.md`](../../refs/multi-agent/spec-injection.md)
   and [`refs/multi-agent/exclusion-list.md`](../../refs/multi-agent/exclusion-list.md):
   the phase's acceptance criteria block (or whole spec if criteria isn't
   delineated) and the tracker exclusion list fetched at this phase's
   start. The prelude is consumed by step 3 (xmar review) via
   `--prompt-prelude`; xmad (step 1 work) gets the originating intent
   through its existing target-file mechanism — the spec IS xmad's
   target arg — so no xmad change is needed. 16 KB hard cap; if the spec block
   alone exceeds it, fail-loud and ask the user to extract criteria
   explicitly rather than truncating silently. This file is short-lived
   (re-fetched each phase to keep the exclusion list fresh) and may be
   `git add`-ed alongside the STATE/log commit at step 5 if you want
   the historical prelude captured per phase.
1. **WORK** — spawn a work-unit (`subagent_type: general-purpose`). The
   work-unit prompt (see REFERENCE → "Work unit") instructs the subagent
   to invoke `/multi-agent-developer` with the phase's pre-resolved
   `--agents` list and `--write-report
   baton-runner/<run-id>/synthesis-phase-<N>.md`, auto-approve xmad's
   Phase 5 gate (since the team was user-approved at signoff), then copy
   xmad's delta-against-`main` from its sub-worktree into the
   baton-runner-multi-agent phase worktree and `git worktree remove` xmad's
   sub-worktree before returning. On return: `INCOMPLETE` → continuation
   from its baton until `COMPLETE`; `NEEDS_USER`/`FATAL` → PAUSE
   immediately (write STATE, show the user, stop). A continuation
   re-invokes xmad with the same `--agents` but seeded from the
   work-unit's baton (NOT xmad's own state — xmad does not support
   cross-invocation resume; the work-unit summarises what xmad already
   produced in its baton so the next invocation can pick up).
2. **Commit** (manager; transient red is fine — healed before the PR).
3. **REVIEW loop (max 3):** review-unit runs the gate then invokes
   `/multi-agent-review` (xmar) over the phase diff with the phase's
   pre-resolved `--reviewers` roster, `--write-to baton-runner/<run-id>/
   review-phase-<N>-iter-<k>.md`, **`--prompt-prelude baton-runner/<run-id>/phase-<N>-prelude.md`**, **and `--high-cap off`** — the per-phase prelude file the manager writes once at phase start concatenates the phase's originating spec (acceptance criteria block, under the `## ORIGINATING SPEC — the change MUST satisfy this:` heading per [`refs/multi-agent/spec-injection.md`](../../refs/multi-agent/spec-injection.md)) and the exclusion list fetched from the tracker (under the `## DO NOT report findings already tracked in:` heading per [`refs/multi-agent/exclusion-list.md`](../../refs/multi-agent/exclusion-list.md)). This makes "does the diff satisfy this phase's acceptance criteria?" a first-class CRITICAL category in the reviewers' rubric, not just "is the code well-written?" — addressing the per-phase "built the wrong thing" failure mode that no amount of debate-round looping catches. `--high-cap off` disables xmar's cross-axis severity budget for this invocation: the review-unit derives `VERDICT = CLEAN iff zero CRITICAL+HIGH`, so silently demoting excess HIGHs to MEDIUM would let unresolved HIGHs through the gate. The budget is for one-shot audits, not per-phase gating — keep it off here. → `VERDICT` (`CLEAN` iff gate exits 0 AND
   the synthesized xmar report contains zero CRITICAL or HIGH findings AND
   intent is met). `CLEAN` → digest written, break. Else fix-unit → commit
   → loop. Any review or fix unit return of `NEEDS_USER` or `FATAL` →
   PAUSE immediately (do not consume another iteration). Not `CLEAN`
   after 3 → PAUSE with a failure baton; offer **guide-resume / waive /
   abandon**. If the review-unit detects the actual diff touches
   `db/migration/` or an Exposed `Table` (regardless of the pre-flight
   prediction), it overrides to the migration-aware roster and notes the
   override in its baton — `--reviewers` REPLACES the entire roster, it
   does not append. See REFERENCE → "Review unit" for the exact
   migration-aware list.
4. **Draft PR** stacked on the previous phase.
5. **Commit STATE/log updates** — after `CLEAN` and the draft PR are in
   place, the manager makes a single commit folding the
   `baton-runner/<run-id>/STATE.md` + `log.md` updates into the phase
   branch: `git commit -m "chore(phase-N): baton-runner-multi-agent STATE + log update"`.
   (Per-unit commits land earlier; this one captures the post-PR state.)
6. **Progress line**, update `STATE.md`, advance.

`VERDICT` = `CLEAN` iff: gate exits 0 AND the synthesized review report
contains zero CRITICAL or HIGH findings AND intent is met (acceptance
criteria genuinely satisfied, per the review unit's verification).

The review-unit's `multi-agent-review` invocation always uses a target
type that produces ONE synthesized report (so the VERDICT is single-
valued): prefer `multi-agent-review spec <path1> [<path2> ...]` for
N changed files, OR `multi-agent-review dir <phase-specific-subdir>`
when the changes are confined to one directory. Do NOT issue N separate
`multi-agent-review file <path>` calls — that produces N unmerged
reports with no single VERDICT.

### Detecting "no progress" without reading the baton

A unit may return `INCOMPLETE` repeatedly. To detect a stuck loop without
opening the baton file (Golden Rule 2), require every unit to embed a
**numeric progress token** in its `NOTES` return line (e.g.
`progress=criteria 2/5; files 4`). The manager compares the NOTES text
(or the parsed token) across consecutive `INCOMPLETE` returns from the
same phase:

- NOTES unchanged across 3 consecutive `INCOMPLETE` returns → fatal,
  PAUSE with a failure baton (no real progress is being made).
- NOTES changed → continue spawning a continuation from the latest
  baton path.

The NOTES line is part of the manager's input (the unit's return), not
file content — comparing it does not violate the "never open batons"
rule.

When all phases are `CLEAN` + PR'd: set `STATE = DONE` and summarize (draft PRs,
stacked-merge order, any waivers).

## Spawning, budgets, pause

- **Spawn:** `model: opus` always; work units use `general-purpose` (it
  needs the `Skill` tool to invoke `/multi-agent-developer` and the
  full `*` tool set to copy files between worktrees and call
  `git worktree remove`); review/fix units use `general-purpose`. Build
  prompts from the REFERENCE templates — always include the spec/baton
  path, the worktree path, the return + containment contracts, and the
  bail budget (≈50 tool-calls / ≈10 files; for work units this counts
  the wrapper's own calls, not xmad's internal tool calls). Record the
  returned baton path in STATE first.
- **Budgets:** a progress line after every unit; **global ceiling 75 units**
  (pause → reauthorize); **per-phase thrash alarm 20**. Tunable in STATE.
- **Containment:** units write only inside the run worktree (work units
  additionally manage xmad's sub-worktree under it), never mutate the
  manager's git/remote state, and must declare (not silently add)
  dependencies. Out-of-bounds → PAUSE. (Full contract in REFERENCE.)
- **Pause/resume:** on any pause, write `STATE = PAUSED` with the exact resume
  point and stop; re-invoking the skill reads `STATE.md` and continues. Never
  restart completed phases.

## References

[REFERENCE.md](REFERENCE.md) — state schema, prompt templates, gate script,
branch/PR mechanics, budgets, failure & containment detail, fatal errors,
xmad sub-worktree mechanics. Depends on `baton-pass`,
`multi-agent-developer` (composes `tdd`, `ecc-code-explorer`,
`ecc-code-architect` internally), `multi-agent-review`, and `tdd`
directly for fix-units. Setup dependency: `multi-agent-developer-setup`
(one-time per project, before run 1).

For the single-implementer variant (no multi-agent debate at the work
step), use `/baton-runner` instead.
