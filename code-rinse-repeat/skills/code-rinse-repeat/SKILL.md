---
name: code-rinse-repeat
description: Build a spec/PRD/issue end-to-end as a multi-agent TDD dev team, then loop multi-agent review→fix→re-review until APPROVE or max iterations. Composes multi-agent-developer (build) with multi-agent-review (review) under a single orchestrator. User-invoked; the orchestrating agent (you) is the coordinator.
allowed-tools:
  - Bash
  - Read
  - Edit
  - Write
  - Glob
  - Grep
  - Agent
  - Skill
  - AskUserQuestion
  - TaskCreate
  - TaskUpdate
---

# code-rinse-repeat

> Lather, rinse, repeat — but for code. Build it, get it reviewed, fix what's broken, re-review, ship when it's clean.

## Abbreviations used in this skill

| Short | Full skill name | What it does |
|---|---|---|
| **XMAD** | `multi-agent-developer` | TDD-disciplined multi-agent dev team (≤4 Opus agents) that debates a spec across RED→GREEN→REFACTOR rounds and materializes a worktree. |
| **XMAR** | `multi-agent-review` | Parallel multi-perspective review pass (architect, critical-thinking, silent-failure, security by default), merged by a synthesizer agent into one prioritized report. |
| **XMAR-Loop** | `multi-agent-review-loop` | Iterative wrapper that runs XMAR → coordinator-applies-fixes → re-XMAR on an **existing PR** until APPROVE or a max-iterations cap. |

`code-rinse-repeat` is the next composition up: XMAD-then-XMAR-Loop, on a **spec** rather than an existing PR.

## 1. Purpose

`code-rinse-repeat` is the single-target end-to-end loop:

```
build (XMAD)
  → review (XMAR)
  → fix (coordinator applies)
  → re-review
  → … until APPROVE or max iterations
```

XMAD produces a verified-tests-pass worktree from a spec, but tests-pass ≠ ship-ready — there are still architecture issues, silent-failure landmines, security smells, and idiom-rot to catch. XMAR-Loop is the existing loop primitive but it operates on an **existing PR** that you already pushed.

This skill wires them together for the **"I have a spec, I want clean code on a branch, no manual handoff between build and review"** case. The orchestrating agent (you) is the coordinator across both phases.

## 2. When to use

Trigger phrases:
- `/code-rinse-repeat <spec>` / explicit invocation
- "build this spec and loop review until clean"
- "rinse this PRD" / "rinse-repeat issue #N"
- "end-to-end TDD build + multi-agent review"

Do NOT use for:
- A spec you only want **built** (no review loop) — use `multi-agent-developer` directly.
- An **existing PR** you want review-looped — use `multi-agent-review-loop` directly.
- A simple bug fix where the spec is one paragraph — TDD overhead isn't worth it; do it in-conversation.
- A target where you don't intend to apply fixes — the loop only makes sense when the coordinator will actually iterate.

## 3. Invocation grammar

```
code-rinse-repeat <target> [flags]
```

Examples:

```
code-rinse-repeat ./specs/2026-06-payment-replay.md
code-rinse-repeat #142                          # issue ref
code-rinse-repeat https://github.com/owner/repo/issues/142

# Cap review iterations (default 3, hard ceiling 8):
code-rinse-repeat ./specs/X.md --max-iterations 5

# Lock the dev team roster:
code-rinse-repeat ./specs/X.md --dev-agents code-architect,python-pro,security-reviewer,silent-failure-hunter

# Lock the review roster:
code-rinse-repeat ./specs/X.md --reviewers code-reviewer,architect,critical-thinking,silent-failure-hunter,security-reviewer

# Auto-defer MEDIUM/LOW findings; only CRITICAL+HIGH drive iteration:
code-rinse-repeat ./specs/X.md --high-and-up-only

# Allow one rebuild round if the review surfaces architectural CRITICALs:
code-rinse-repeat ./specs/X.md --allow-rebuild 1

# Skip the per-round smoke test:
code-rinse-repeat ./specs/X.md --no-smoke
```

| Position / flag | Required | Values |
|---|---|---|
| `<target>` (positional 1) | yes | spec path, PRD path, issue ref, or issue URL |
| `--max-iterations <n>` | no | integer 1–8, default 3; review loop cap |
| `--dev-agents <csv>` | no | passed through to `multi-agent-developer` |
| `--reviewers <csv>` | no | passed through to `multi-agent-review` |
| `--synthesizer <name>` | no | passed through to `multi-agent-review` |
| `--high-and-up-only` | no | auto-defer MEDIUM/LOW each round |
| `--allow-rebuild <n>` | no | integer 0–2, default 0; cap on how many times the review may trigger a full `multi-agent-developer` re-run for architectural CRITICALs |
| `--no-smoke` | no | skip the smoke-test gate between rounds |

## 4. Defaults

- **`--max-iterations`**: **3**. Same logic as `multi-agent-review-loop` — most builds stabilize in 1–2 review rounds; round 3 catches genuine follow-ons; beyond that reviewers are nitpicking. Hard ceiling **8**.
- **`--allow-rebuild`**: **0**. By default a CRITICAL architectural finding does NOT trigger a rebuild — the coordinator either fixes in place or escalates. Set to 1 or 2 to allow rebuilds (slow + expensive; use only when the spec itself was likely the problem).
- **Action floor**: every CRITICAL and HIGH must be addressed each round (apply, defer with rationale, or escalate). MEDIUM is coordinator's judgment. LOW gets a PR comment, not a fix.
- **Smoke test gate**: re-run between rounds only if a fix touched code paths the smoke exercises. `--no-smoke` opts out entirely.

## 5. Workflow

Three phases: **build**, **review-loop**, **ship**.

### Phase 1 — Build (single pass, runs once)

1. Verify the target exists and is parseable (spec file readable, issue fetchable). If not, halt with the failure mode and stop.
2. Invoke the `multi-agent-developer` skill via `Skill` with `<target>`, passing through `--dev-agents` and any other relevant flags. Block until it returns.
3. Capture from XMAD's output:
   - **Worktree path** — `.worktrees/feat/<slug>` (or whatever XMAD picked).
   - **Branch name** — `feat/<slug>`.
   - **Test result** — must be GREEN; if XMAD's final retry failed and it's still RED, halt with `BUILD-FAILED` and stop. Do not enter the review loop on red tests.
4. Write initial state to `.code-rinse-repeat/<slug>/state.md`:
   ```
   target: <path-or-ref>
   slug: <slug>
   worktree: .worktrees/feat/<slug>
   branch: feat/<slug>
   phase: review-loop
   round: 0
   max-iterations: <n>
   rebuilds-remaining: <allow-rebuild>
   started: <iso-timestamp>
   ```

### Phase 2 — Review loop (1 to max-iterations rounds)

For round N from 1 to max-iterations:

#### 2.N.a Run review

Invoke `multi-agent-review` via the `Agent` tool as a **fresh subagent** (so the reviewer transcripts never enter the coordinator's context — only the synthesized findings list returns). Brief:

- Target: `<worktree-path>` (treat as directory review for round 1; treat as diff-vs-base for round 2+).
- Reviewers: from `--reviewers`, else XMAR's defaults.
- Synthesizer: from `--synthesizer`, else XMAR's default.
- Exclusion list: built up across rounds — see §6.
- Spec injection: pass the original `<target>` content as `--prompt-prelude` so reviewers can raise CRITICAL if the implementation fails to satisfy the originating intent.

Capture the synthesized review document. Write it to `.code-rinse-repeat/<slug>/round-N-review.md`.

#### 2.N.b Categorize findings

From the synthesized review, classify each finding:

| Severity | Default action |
|---|---|
| CRITICAL | MUST address this round (fix in place, OR if architectural and `--allow-rebuild > 0`, queue for rebuild) |
| HIGH | MUST address this round (fix or defer with rationale + PR comment + tracker issue) |
| MEDIUM | Coordinator judgment — fix if cheap; else defer + PR comment |
| LOW | PR comment only; do not iterate on |

With `--high-and-up-only`, MEDIUM and LOW are auto-deferred without prompting.

#### 2.N.c Exit-early checks

Before applying any fixes, check exit conditions:

- **APPROVE**: no CRITICAL and no HIGH findings. → Skip to Phase 3 with verdict `APPROVE-ROUND-N`.
- **Architectural CRITICAL + rebuild remaining**: a CRITICAL finding the synthesizer marks as architectural (touches module boundaries, type contracts, persistence shape, or invariants) AND `rebuilds-remaining > 0`. → Treat as a rebuild trigger; see §7.
- **Stuck**: the round-N findings list is ≥80% identical to round N-1's (same finding IDs in the same severity buckets). → Halt with verdict `STUCK-AT-ROUND-N`, summarize for human, stop.

#### 2.N.d Apply fixes (coordinator inline)

The coordinator (you) applies fixes directly via `Edit`/`Write`/`Bash` in the worktree. Do NOT delegate fixes to a subagent — triage requires the coordinator's whole-project context.

For each finding being addressed this round:
1. Apply the fix.
2. Re-run the project's test command in the worktree. If RED: revert the fix, mark the finding as `FIX-FAILED-ROUND-N`, file a tracker issue with the finding + the revert, and continue with the next finding.
3. If the fix touched smoke-test paths (and `--no-smoke` is not set): re-run the smoke. If smoke fails: revert + tracker-issue, same as #2.

For each deferred finding (HIGH or MEDIUM rationale-deferred): write a tracker issue with the finding body verbatim + the rationale.

For each LOW: collect into a "PR comment" buffer for Phase 3.

#### 2.N.e Commit + advance

After all fixes for round N are applied + green:

```bash
cd <worktree>
git add -A
git commit -m "fix(code-rinse-repeat): round N — <synth one-liner of biggest fix>"
```

Update state.md: `round: N`, append a one-line summary of what this round changed.

If round N == max-iterations and no APPROVE: halt with verdict `MAX-ITERATIONS-AT-N`, summarize the remaining open findings, stop.

### Phase 3 — Ship

After APPROVE (or final-round-with-open-findings), produce the **ship report**:

```markdown
# code-rinse-repeat report — <slug>

**Spec:** <target>
**Worktree:** <path>
**Branch:** <branch>
**Verdict:** APPROVE-ROUND-N | MAX-ITERATIONS-AT-N | STUCK-AT-N | BUILD-FAILED

## Build summary
- Dev team: <agents>
- Final test result: GREEN
- Files changed: <count> across <files-list>

## Review rounds
| Round | CRITICAL | HIGH | MEDIUM | LOW | Action |
|---|---|---|---|---|---|
| 1 | …      | …    | …      | …   | fixed X, deferred Y |
| 2 | …      | …    | …      | …   | … |

## Open follow-ups
- <tracker-issue> — <one-line>
- …

## LOW-severity PR comments (paste into PR description)
- <comment> …
```

Print the report. Do NOT auto-open the PR — the user opens it (or you do explicitly if they ask).

## 6. The exclusion list (across rounds)

The coordinator maintains `.code-rinse-repeat/<slug>/exclusion-list.md`. After each round:

- Add every finding the coordinator **deferred** (with rationale) — reviewers should not re-flag these.
- Add every finding the coordinator **filed as a tracker issue** — same reason.
- Do NOT add findings that were **fixed** — they're gone from the code, no exclusion needed.

The exclusion list is passed to the next round's XMAR invocation via `--prompt-prelude <path>` so reviewers see the "DO NOT report" heading verbatim.

This is the same exclusion-list discipline `total-review` uses; the ref lives at `~/.claude/refs/multi-agent/exclusion-list.md`.

## 7. Rebuild trigger (`--allow-rebuild`)

If `--allow-rebuild > 0` and a CRITICAL finding is architectural (synth marks it `[ARCH]` or coordinator judges so):

1. Decrement `rebuilds-remaining` in state.md.
2. Construct a **delta spec**: the original `<target>` + a "## Architectural addendum" section quoting the architectural CRITICAL and what it implies must change.
3. Tear down the existing worktree: `git worktree remove <path> --force`.
4. Restart from **Phase 1** with the delta spec as the target. Round counter resets to 0; iteration cap unchanged.

Rebuilds are slow + expensive. Default 0 (off) is intentional. Use 1 when the first build was a reasonable attempt that just got the architecture wrong; use 2 only if you really expect the spec to evolve through review.

## 8. Resumability

If the orchestrating agent is interrupted (out-of-context, user `Esc`, hook fail), state.md is the source of truth. To resume:

1. Read `.code-rinse-repeat/<slug>/state.md`.
2. Read `.code-rinse-repeat/<slug>/exclusion-list.md`.
3. Resume at `phase: review-loop, round: <last+1>` — i.e., the next round to run.

The build phase is not resumable mid-run; if interrupted during XMAD, manually clean up the worktree and re-invoke `code-rinse-repeat` fresh.

## 9. Failure modes

| Mode | Cause | Action |
|---|---|---|
| `BUILD-FAILED` | XMAD's final retry left tests RED | Halt; summarize; do not enter review loop |
| `STUCK-AT-N` | Round N findings ≥80% identical to N-1 | Halt; summarize remaining + suggest human review |
| `MAX-ITERATIONS-AT-N` | Hit cap without APPROVE | Halt; ship with open findings logged; PR description carries the list |
| `FIX-FAILED-ROUND-N` (per finding) | Tests/smoke went RED after the fix | Revert that fix, file tracker issue, continue with next finding |
| `REBUILD-EXHAUSTED` | `--allow-rebuild` cap hit but architectural CRITICAL recurs | Halt; escalate to human; do not rebuild again |

## 10. Defaults summary (TL;DR)

- 1 build pass (XMAD).
- Up to 3 review-fix rounds (XMAR + coordinator-applied fixes).
- 0 rebuilds (CRITICAL architectural findings get escalated, not rebuilt).
- All CRITICAL and HIGH addressed every round.
- Smoke test runs between rounds when fixes touch smoke paths.
- Exclusion list grows across rounds; never includes fixed findings.
- Resumable from state.md.

## 11. Composition

This skill is the **end-to-end** layer in the multi-agent stack:

| Layer | Skill | What it owns |
|---|---|---|
| Spec → code | `multi-agent-developer` | TDD build, one pass |
| Code → findings | `multi-agent-review` | Parallel review, one pass |
| Findings → APPROVE | `multi-agent-review-loop` | Review-fix loop on existing PR |
| Spec → APPROVE | **`code-rinse-repeat`** | Build + review-fix loop, end-to-end |

If you need a sequential queue of code-rinse-repeat targets across multiple specs, that's `baton-runner-multi-agent`'s job — it can dispatch this skill as the per-unit work.
