---
name: baton-runner
description: Sequentially build an ordered list of specs/PRDs/issues as implement→review→fix subagent units with baton-pass handoffs in a fresh worktree. User-invoked; use to drive multi-phase builds.
---

# baton-runner

Orchestrates a multi-phase build. You (the session running this skill) are the
**baton-runner-manager**: a thin, restartable scheduler. You never write product
code, run tests, or read diffs/baton contents — you spawn **units** (subagents),
thread file *paths* between them, commit, open a draft PR per phase, enforce
budgets, log, and pause. All state lives on disk (`baton-runner/<run-id>/`) so a
fresh manager session resumes from `STATE.md` indistinguishably.

> Run in an **Opus** session. Correctness over speed. Detail lives in
> [REFERENCE.md](REFERENCE.md); this file is the control flow.

## Golden rules

1. **Opus only** — every spawn uses `model: opus`.
2. **Manager stays lean** — read only each unit's short return block
   (STATUS/VERDICT/BATON/NOTES for review units; STATUS/BATON/NOTES for
   work and fix units); move *paths*, never contents; never open
   diffs/batons/gate-logs. Write `STATE.md` at each phase boundary; when
   your own window fills, finalize STATE, tell the user to resume fresh,
   and stop. The NOTES line itself is part of the manager's input — it is
   not a file contents — so you may compare NOTES text across returns
   (see "No progress" below) without violating this rule.
3. **Manager does all git/remote; units never do.**
4. **Verification is delegated** — "done" = the unit's `STATUS` + the review
   unit's `VERDICT`, never your own inspection.
5. **Context crosses agents only through files** (batons, phase-exit digest).
6. **Stop, don't guess** — user-input, budget ceiling, or fatal error → PAUSE
   (write STATE, show the user, stop).

## Roles

| Term | Meaning |
|---|---|
| **work-unit** | Implements a phase's acceptance criteria via `tdd`, capturing RED test output as evidence. |
| **review-unit** | Independent of the implementer. Runs `scripts/gate.sh`, then `/multi-agent-review` over the phase diff; emits `VERDICT`; on `CLEAN` writes the phase-exit digest. |
| **fix-unit** | Implements the review-unit's findings via `tdd`. |
| **baton / digest** | `baton-pass` file carrying unit state (updated incrementally) / terse map of public surface + decisions threaded to later phases. |

## Pre-flight — before work unit 1

- [ ] **`scripts/gate.sh` present on `origin/main`.** This file is the
      objective gate every review unit runs (see REFERENCE → "The objective
      gate"). If it is absent from `origin/main`, **stop and instruct the
      user to merge the PR that introduces it** before re-invoking this skill.
      A fresh worktree branched off `origin/main` will not contain the gate
      until that PR lands.
- [ ] **Fresh single worktree**; confirm `baton-pass`, `tdd`, `multi-agent-review`,
      and `scripts/gate.sh` resolve there. The `tdd` skill is allowed to
      resolve from user scope (`~/.claude/skills/tdd/`) — it does not need
      to live in the project's `.claude/skills/`.
- [ ] **Parse + right-size** the phase list (each phase ≤ ~5 acceptance criteria
      / ~10 files; split larger into ordered sub-units).
- [ ] **Spec readiness** per phase → `READY` / `THIN` / `BLOCKED` (draft proposed
      criteria for `THIN`).
- [ ] **Work-unit agent (optional)** — let the user nominate an agent for work
      units; default `general-purpose`. Any choice must support file edits +
      Bash + the `tdd`/`baton-pass` skills (most specialized agents lack the
      Skill tool — see REFERENCE → "Work-unit agent"). Record per phase in STATE.
- [ ] **Open questions + signoff** — surface ambiguities, the proposed criteria,
      and the chosen agent. **Do not spawn work unit 1 until the user signs off.**
- [ ] **Init** `baton-runner/<run-id>/` (`STATE.md` + `log.md` with tunable
      budgets). TodoWrite: one todo per phase.

## Per-phase loop

For each phase in order, with **fresh context** (this phase's spec + the
accumulated phase-exit digests only):

1. **WORK** — spawn a work-unit (`subagent_type` = the phase's work-agent). On
   return: `INCOMPLETE` → continuation from its baton until `COMPLETE`;
   `NEEDS_USER`/`FATAL` → PAUSE immediately (write STATE, show the user,
   stop).
2. **Commit** (manager; transient red is fine — healed before the PR).
3. **REVIEW loop (max 3):** review-unit runs the gate then runs
   `/multi-agent-review` over the phase diff → `VERDICT`.
   `CLEAN` → digest written, break. Else fix-unit → commit → loop. Any
   review or fix unit return of `NEEDS_USER` or `FATAL` → PAUSE
   immediately (do not consume another iteration). Not `CLEAN` after 3 →
   PAUSE with a failure baton; offer **guide-resume / waive / abandon**.
4. **Draft PR** stacked on the previous phase.
5. **Commit STATE/log updates** — after `CLEAN` and the draft PR are in
   place, the manager makes a single commit folding the
   `baton-runner/<run-id>/STATE.md` + `log.md` updates into the phase
   branch: `git commit -m "chore(phase-N): baton-runner STATE + log update"`.
   (Per-unit commits land earlier; this one captures the post-PR state.)
6. **Progress line**, update `STATE.md`, advance.

`VERDICT` = `CLEAN` iff: gate exits 0 AND the synthesized review report
contains zero CRITICAL or HIGH findings AND intent is met (acceptance
criteria genuinely satisfied, per the review unit's verification).

The work-unit `multi-agent-review` invocation always uses a target
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

- **Spawn:** `model: opus` always; work units use the phase's work-agent
  (default `general-purpose`), review/fix units use `general-purpose`. Build
  prompts from the REFERENCE templates — always include the spec/baton path, the
  worktree path, the return + containment contracts, and the bail budget
  (≈50 tool-calls / ≈10 files). Record the returned baton path in STATE first.
- **Budgets:** a progress line after every unit; **global ceiling 75 units**
  (pause → reauthorize); **per-phase thrash alarm 20**. Tunable in STATE.
- **Containment:** units write only inside the worktree, never mutate git/remote,
  and must declare (not silently add) dependencies. Out-of-bounds → PAUSE.
  (Full contract in REFERENCE.)
- **Pause/resume:** on any pause, write `STATE = PAUSED` with the exact resume
  point and stop; re-invoking the skill reads `STATE.md` and continues. Never
  restart completed phases.

## References

[REFERENCE.md](REFERENCE.md) — state schema, prompt templates, gate script,
branch/PR mechanics, budgets, failure & containment detail, fatal errors.
Depends on `baton-pass`, `tdd`, `multi-agent-review`.
