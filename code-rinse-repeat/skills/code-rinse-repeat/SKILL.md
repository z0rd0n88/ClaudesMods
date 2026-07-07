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

# Bound total cost / wall-clock (defaults below):
code-rinse-repeat ./specs/X.md --max-wall-minutes 60 --max-cost-usd 15

# Resume / disambiguate a colliding slug:
code-rinse-repeat ./specs/X.md --resume
code-rinse-repeat ./specs/X.md --slug-suffix v2
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
| `--max-wall-minutes <n>` | no | integer 10–480, default 90; total wall-clock budget across all phases |
| `--max-cost-usd <n>` | no | number 1–500, default 25; total estimated agent-spend budget |
| `--resume` | no | resume from `.code-rinse-repeat/<slug>/state.json` instead of erroring on slug collision |
| `--slug-suffix <s>` | no | append to derived slug; use to deconflict with a stale prior run without resuming it |
| `--checks <csv>` | no | comma-separated project-check commands; overrides discovery (see §5.2.d) |
| `--smoke-cmd <cmd>` | no | explicit smoke command; overrides discovery |
| `--reviewers-round-<n> <csv>` | no | per-round reviewer roster override (e.g. `--reviewers-round-2 security-reviewer,database-reviewer,architect`) |
| `--squash-on-approve` | no | collapse per-finding commits into per-round commits at ship time |
| `--pause-after-build` | no | halt between Phase 1 and Phase 2 for human inspection (skipped automatically in non-interactive runs — see §5.1.5) |
| `--medium-accumulation-threshold <n>` | no | integer ≥0, default 8; triggers MEDIUM-flood prompt when cumulative deferred-MEDIUM count crosses it. 0 disables. See §5.2.b.1 |
| `--exclusion-ttl <n>` | no | integer ≥0, default 2; rounds before a deferred finding is re-evaluated against current code. 0 disables (exclusions are permanent). See §6 |

## 4. Defaults

- **`--max-iterations`**: **3**. Same logic as `multi-agent-review-loop` — most builds stabilize in 1–2 review rounds; round 3 catches genuine follow-ons; beyond that reviewers are nitpicking. Hard ceiling **8**.
- **`--allow-rebuild`**: **0**. By default a CRITICAL architectural finding does NOT trigger a rebuild — the coordinator either fixes in place or escalates. Set to 1 or 2 to allow rebuilds (slow + expensive; use only when the spec itself was likely the problem).
- **`--max-wall-minutes`**: **90**. Total wall-clock from skill invocation to ship report. Most spec→APPROVE runs land in 30–60 min; 90 catches one rebuild or a stubborn round 3. Hard ceiling **480** (8 h).
- **`--max-cost-usd`**: **25**. Estimated agent-spend across XMAD + every XMAR pass. A single XMAR round on a small worktree is ~$1–3; a full XMAD pass is ~$5–10. The default covers build + 3 review rounds with headroom. Hard ceiling **500**.
- **Action floor**: every CRITICAL and HIGH must be addressed each round (apply, defer with rationale, or escalate). MEDIUM is coordinator's judgment. LOW gets a PR comment, not a fix.
- **Smoke test gate**: re-run between rounds only if a fix touched code paths the smoke exercises. `--no-smoke` opts out entirely.

## 5. Workflow

Four phases: **preflight**, **build**, **review-loop**, **ship**. Every phase respects the wall-clock and cost budgets — see §7.5.

### Phase 0 — Preflight (runs once, before any agent invocation)

1. **Parse target.** Verify the target exists and is parseable (spec file readable, issue fetchable). If not, halt with `BAD-TARGET` and stop.
2. **Derive slug.** From the spec filename, issue title, or explicit `--slug-suffix`. Slugs are kebab-case, ≤40 chars.
3. **Collision check.** Test each of these in order; the FIRST hit decides the action:
   - `.code-rinse-repeat/<slug>/state.json` exists AND `--resume`: jump to §8 (Resumability) — do NOT re-derive slug, do NOT touch the worktree.
   - `.code-rinse-repeat/<slug>/state.json` exists AND no `--resume`: halt with `SLUG-COLLISION`; tell the user the prior run's verdict (read from `state.json`) and offer `--resume` or `--slug-suffix`.
   - Worktree path `.worktrees/feat/<slug>` exists on disk OR branch `feat/<slug>` exists in `git branch --list`: halt with `SLUG-COLLISION` — a prior run was interrupted before writing `state.json`. Tell the user to either `git worktree remove --force <path> && git branch -D <branch>` or pass `--slug-suffix`.
   - Otherwise: clean slate, proceed.
4. **Initialize state.** Write `.code-rinse-repeat/<slug>/state.json` (see §7.6 for schema) with `phase: build`, `round: 0`, the resolved flags, the budget caps, and `started_at: <iso-timestamp>`.

### Phase 1 — Build (single pass, runs once)

1. Invoke the `multi-agent-developer` skill via `Skill` with `<target>`, passing through `--dev-agents` and any other relevant flags. Block until it returns.
2. Capture from XMAD's output:
   - **Worktree path** — `.worktrees/feat/<slug>` (or whatever XMAD picked; reconcile with the slug from Phase 0 — if XMAD picked a different slug, update `state.json` and rename the `.code-rinse-repeat/<slug>/` dir to match).
   - **Branch name** — `feat/<slug>`.
   - **Test result** — must be GREEN; if XMAD's final retry failed and it's still RED, halt with `BUILD-FAILED` and stop. Do not enter the review loop on red tests.
3. Update `state.json`: `phase: "review-loop"`, append `build` to `phases_completed`, record `build.cost_usd_estimate` and `build.duration_seconds` from XMAD's report (or `null` if unavailable).

### Phase 1.5 — Pause-after-build checkpoint (optional, runs at most once)

Only fires when `--pause-after-build` was set AND the run is interactive. Interactive detection: `os.getenv("BATON_RUN_ID")` is absent AND `os.getenv("CODE_RINSE_REPEAT_NONINTERACTIVE") != "1"`. If non-interactive, log a one-line "pause-after-build skipped (non-interactive)" notice to `state.json.notes[]` and proceed directly to Phase 2.

Steps:

1. **Snapshot the build.** Compute `files_created`, `files_modified`, and a 1-line per-test-file pass count (e.g. `47 passed, 0 failed in tests/`). Read current `cost_estimate` and `wall_elapsed`.
2. **Pause the wall-clock.** Write `paused_at: <iso-timestamp>` to `state.json`. Wall-clock budget enforcement (§7.5) treats time between `paused_at` and `resumed_at` as zero.
3. **Prompt the user** via `AskUserQuestion`:

   ```
   Build complete — review the worktree before spending review budget?

     Branch:    <branch>
     Worktree:  <path>
     Files:     <created> created, <modified> modified
     Tests:     GREEN (<passed> passed, 0 failed)
     Cost:      $<spent> spent / $<remaining> remaining
     Elapsed:   <minutes>m of <max> max
   ```

   Options:
   - **Continue to review loop** (default) — proceed to Phase 2.
   - **Halt and inspect** — emit ship report with verdict `HALTED-AFTER-BUILD`, exit. User may resume later via `--resume`.
   - **Halt and rebuild with addendum** — only offered if `--allow-rebuild > 0` and `rebuilds_remaining > 0`. Prompt for the architectural addendum text inline, then jump to §7 rebuild trigger with the addendum.

4. **Resume the clock.** Write `resumed_at: <iso-timestamp>` and `paused_after_build: true` to `state.json`. The next-invocation resume path checks `paused_after_build` and SKIPS this checkpoint (user already inspected).

### Phase 2 — Review loop (1 to max-iterations rounds)

For round N from 1 to max-iterations:

#### 2.N.a Run review

**Round 1 only — spec-conformance pre-pass.** Before invoking the multi-agent review, run a dedicated conformance check via the `Agent` tool. Prefer a `spec-conformance-reviewer` agent if available; otherwise dispatch the synthesizer agent with a focused brief: *"Answer ONLY: does this worktree satisfy every acceptance criterion in the attached spec? List each criterion + PASS/FAIL/AMBIGUOUS + evidence (file:line). Do not raise architecture, security, or style issues."* Any CRITICAL (= a FAIL on a stated criterion) from this pass blocks entry to the multi-agent review — treat as a §5.2.d fix immediately and re-run the pre-pass. Write the result to `.code-rinse-repeat/<slug>/round-1-conformance.md`. Rationale: separates "wrong thing built" from "right thing built badly" so the broader reviewers don't drown a missing-feature CRITICAL in style nitpicks.

**Multi-agent review (every round).** Invoke `multi-agent-review` via the `Agent` tool as a **fresh subagent** (so the reviewer transcripts never enter the coordinator's context — only the synthesized findings list returns). Brief:

- **Target scope:**
  - Round 1: full worktree directory review.
  - Round 2+: cumulative diff, pinned to merge-base — `git diff $(git merge-base HEAD main)..HEAD`. NOT "diff vs the previous round" (that would hide regressions in earlier rounds and rebase as the base shifts).
- **Reviewers (with rotation):**
  - Round 1: from `--reviewers`, else XMAR's defaults (architect, critical-thinking, silent-failure-hunter, security-reviewer).
  - Round 2: add a domain specialist if the spec or changed files match the keyword/glob table below. Drop one of the round-1 reviewers if the specialist would push the roster past 5.
  - Round 3+: include one **fresh-eyes** reviewer that did NOT participate in any prior round. The synthesizer picks from the available agent pool.
  - Override any round with `--reviewers-round-<n> <csv>`.
- Synthesizer: from `--synthesizer`, else XMAR's default.
- Exclusion list: built up across rounds — see §6.
- Spec injection: pass the original `<target>` content as `--prompt-prelude` so reviewers can raise CRITICAL if the implementation fails to satisfy the originating intent.

**Domain-specialist keyword/glob table (round 2 trigger):**

| Match (spec keyword OR changed-files glob) | Specialist to add |
|---|---|
| `auth`, `login`, `session`, `oauth`, `jwt`, `password` / `**/auth/**`, `**/session*` | `security-reviewer` (if not already in roster), else `auth-domain-reviewer` |
| `sql`, `query`, `migration`, `schema`, `index` / `**/migrations/**`, `**/*.sql` | `database-reviewer` |
| `http`, `api`, `endpoint`, `webhook`, `request` / `**/api/**`, `**/routes/**` | `api-design-reviewer` |
| `crypto`, `encrypt`, `sign`, `hash`, `nonce` / any `**/*crypto*` | `crypto-reviewer` |
| `concurrency`, `lock`, `mutex`, `goroutine`, `async`, `race` | `concurrency-reviewer` |

If no row matches, round 2 uses the round-1 roster unchanged.

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

#### 2.N.b.1 MEDIUM-accumulation guard

After categorization, before exit-early checks, compute:

```
cumulative_deferred_mediums =
  len(this_round_findings filtered to MEDIUM that will be deferred)
  + sum(prior_rounds[].deferred_mediums)
```

Threshold defaults to **8** (set via `--medium-accumulation-threshold <n>`; **0 disables the guard entirely**). If the threshold trips:

- **Interactive runs:** prompt via `AskUserQuestion`:

  ```
  N MEDIUM findings have accumulated without fix (threshold: T). Triage required:

    1. Show me the list (read-only, then re-prompt)
    2. Promote K highest-ranked to HIGH this round and fix them
    3. Confirm all remain deferred (acknowledge the risk)
    4. Halt and let me look at the worktree
  ```

  Option 2 ranking (highest first):
  1. Synthesizer-provided `confidence` score if present.
  2. `file_touch_count`: a MEDIUM affecting 4 files outranks one affecting 1.
  3. Order of appearance in the synthesized review.

  Option 3 writes `medium_flood_acked_at: <round N>` to `state.json` and proceeds without re-prompting in subsequent rounds.

  Option 4 emits ship report with verdict `HALTED-AT-MEDIUM-FLOOD-N`; user can `--resume` after inspection.

- **Non-interactive runs** (`BATON_RUN_ID` set or `CODE_RINSE_REPEAT_NONINTERACTIVE=1`): proceed with auto-defer, but write `medium_flood_warning: true` to `state.json` AND prepend a prominent warning block to the Phase 3 ship report. Do NOT halt.

Track per-round `deferred_mediums: [<finding_id>, ...]` in `state.json` so subsequent rounds can compute the cumulative count without re-deriving it.

#### 2.N.c Exit-early checks

Before applying any fixes, check exit conditions:

- **APPROVE**: no CRITICAL and no HIGH findings. → Skip to Phase 3 with verdict `APPROVE-ROUND-N`.
- **Architectural CRITICAL + rebuild remaining**: a CRITICAL finding the synthesizer marks as architectural (touches module boundaries, type contracts, persistence shape, or invariants) AND `rebuilds-remaining > 0`. → Treat as a rebuild trigger; see §7.
- **Stuck**: round-N and round-(N-1) findings overlap ≥80% by finding-identity (see below). → Halt with verdict `STUCK-AT-ROUND-N`, summarize for human, stop.

  **Finding-identity rule (in order of preference):**
  1. If XMAR emits a stable `finding_id` for each finding, compare on that. Recommended emission shape: `finding_id = sha256(rule_or_synth_category + ":" + file + ":" + line_start + "-" + line_end)[:12]`. The synthesizer is expected to carry these IDs through.
  2. Fallback when `finding_id` is absent: build a tuple `(file_path, severity, normalized_title)` where `normalized_title` = the finding title lowercased, with whitespace collapsed and trailing punctuation stripped. Compare on the tuple.
  3. Last-resort fallback (no file path, no ID — e.g. a cross-file architectural critique): tuple `(severity, normalized_title)` only. Document this case explicitly when it fires, since false-positive "stuck" risk is highest here.

  **Overlap computation:** Jaccard index over the two finding-identity sets, restricted to CRITICAL + HIGH (MEDIUM/LOW churn shouldn't trigger stuck). Threshold `>= 0.80`. A round with zero CRITICAL+HIGH does NOT fire stuck — that's APPROVE territory and is checked first.

#### 2.N.d Apply fixes (coordinator inline)

The coordinator (you) applies fixes directly via `Edit`/`Write`/`Bash` in the worktree. Do NOT delegate fixes to a subagent — triage requires the coordinator's whole-project context.

**GREEN gate definition.** "GREEN" in this skill means **all three** of:
- Tests pass (project's discovered test command).
- Project-checks pass (lint + typecheck + format — see discovery below).
- Smoke passes when triggered (see smoke discovery below; only re-runs if the fix touches smoke paths).

A fix is committed only if all three are GREEN after applying it.

**Project-check discovery (one-time, cached in `state.json` after round 1):**
1. If `--checks <csv>` was passed, use that comma-separated command list verbatim.
2. Else, in priority order, take the first match:
   - `package.json` with a `scripts.check` entry → `npm run check` (or `pnpm`/`yarn` per lockfile).
   - `Makefile` with a `check:` target → `make check`.
   - `pyproject.toml` with a `[tool.code-rinse-repeat]` `checks = [...]` array → run each.
3. Otherwise, append every language-default that has its config file present:
   - Python: `ruff check .` (if `ruff.toml`/`pyproject.toml`), `mypy .` (if `mypy.ini` or `[tool.mypy]`), `black --check .` (if `[tool.black]`).
   - TS/JS: `tsc --noEmit` (if `tsconfig.json`), `eslint .` (if `.eslintrc*` or `eslint.config.*`), `prettier --check .` (if `.prettierrc*`).
   - Go: `go vet ./...`, `gofmt -l .` (fail if non-empty).
   - Rust: `cargo check`, `cargo clippy -- -D warnings` (if `clippy.toml` or workspace opts in).
4. If discovery finds nothing at all, log a one-line warning and skip the project-check leg (tests + smoke still gate). Do not invent commands.

The discovered list is written to `state.json` under `checks: [...]` after round 1's first successful resolution, so later rounds don't re-discover.

**Smoke discovery (one-time, cached in `state.json`):**
1. If `--smoke-cmd <cmd>` was passed, use that.
2. Else, first match:
   - `package.json` with `scripts.smoke` → `npm run smoke`.
   - `Makefile` with `smoke:` target → `make smoke`.
   - `pyproject.toml` test config that supports `-m smoke` markers → `pytest -m smoke`.
   - File `smoke.sh` at repo root → `bash smoke.sh`.
3. If nothing matches AND `--no-smoke` was NOT passed: log a one-line warning ("no smoke command discovered; skipping smoke gate") and skip. Do not fail the round.

**Smoke trigger rule:** re-run smoke after a fix if any of the fix's changed files appear in the smoke command's known file set. If the file set is unknowable (a `make smoke` or arbitrary shell script), conservatively run smoke for every fix that lands in the round's first half, then only on the round's last fix afterward (cuts cost without sacrificing the final gate).

**Per-finding workflow.** For each finding being addressed this round:
1. Apply the fix.
2. Re-run tests. If RED: revert, mark `FIX-FAILED-ROUND-N`, file a tracker issue with the finding + the revert reason, continue.
3. Re-run project-checks. If any fail: revert + tracker issue, same as #2 (failure reason recorded as `CHECKS-FAILED-ROUND-N:<which check>`).
4. If smoke trigger fires: re-run smoke. If RED: revert + tracker issue.
5. Commit the fix per §5.2.e (one commit per finding).

For each deferred finding (HIGH or MEDIUM rationale-deferred): write a tracker issue with the finding body verbatim + the rationale.

For each LOW: collect into a "PR comment" buffer for Phase 3.

#### 2.N.e Commit + advance

Commits are **per-finding**, not per-round, so the PR is bisectable and individual fixes can be reverted. After each green fix from §5.2.d step 5:

```bash
cd <worktree>
git add -A
git commit -m "fix(code-rinse-repeat): r<N>/<finding-id> — <one-liner>"
```

Where `<finding-id>` is the stable ID from §5.2.c finding-identity rule (truncated to 12 chars when sha-derived). The `<one-liner>` is the finding's normalized title; coordinator may append a parenthetical `(deferred from r<M>)` if this fix addresses a finding that was originally deferred in an earlier round.

After the **last** fix of the round commits, write a single trailing **round-marker commit** (empty if no fixes landed this round, e.g. a fully-deferred round):

```bash
git commit --allow-empty -m "chore(code-rinse-repeat): round N complete — <K fixes, M deferred, summary>"
```

This marker serves as the boundary for stuck-detection and ship-report aggregation.

**`--squash-on-approve`** (default off): when Phase 3 fires with verdict APPROVE-ROUND-N, the coordinator runs `git reset --soft $(git merge-base HEAD main)` and creates one bundled commit per round (`fix(code-rinse-repeat): round N — <summary>`), preserving round granularity but collapsing per-finding noise. Off by default because per-finding bisectability is usually worth the extra commits; turn on for high-frequency-MEDIUM rounds where the per-finding history is mostly mechanical.

Update `state.json`: set `round: N`, append `{round: N, summary, cost_usd_estimate, duration_seconds, finding_commits: [<sha>...]}` to the `rounds[]` array.

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

The coordinator maintains `.code-rinse-repeat/<slug>/exclusion-list.json` (v1 schema). After each round:

- Add every finding the coordinator **deferred** (with rationale, `type: "deferred"`) — reviewers should not re-flag these.
- Add every finding the coordinator **filed as a tracker issue** (`type: "tracker-issued"`) — same reason.
- Do NOT add findings that were **fixed** — they're gone from the code, no exclusion needed.

### 6.1 Entry schema

```json
{
  "schema_version": 1,
  "entries": [
    {
      "finding_id": "a1b2c3d4e5f6",
      "type": "deferred",
      "added_round": 1,
      "last_reevaluated_round": 1,
      "file_path": "src/payments/replay.py",
      "severity": "MEDIUM",
      "title": "unbounded retry loop on transient failure",
      "rationale": "scope creep — file tracker issue #142; revisit after retry policy lands"
    },
    {
      "finding_id": "b2c3d4e5f6a1",
      "type": "tracker-issued",
      "added_round": 2,
      "last_reevaluated_round": 2,
      "file_path": null,
      "severity": "HIGH",
      "title": "session-token storage doesn't meet compliance",
      "tracker_url": "https://github.com/owner/repo/issues/189"
    }
  ]
}
```

### 6.2 Re-evaluation rules

At the **start of every review round N ≥ 2** (before invoking XMAR), the coordinator walks the exclusion list and re-evaluates entries by these rules — in order, first match wins:

1. **Type `tracker-issued` entries are EXEMPT.** The coordinator has explicitly filed an issue, so the finding is managed elsewhere. Skip re-evaluation; keep the entry indefinitely.
2. **File-touch invalidation.** If any commit since the entry was last evaluated touched the file in `file_path`, the entry is flagged for re-evaluation regardless of age.
3. **TTL expiry.** If `N - last_reevaluated_round >= --exclusion-ttl` (default 2), the entry is flagged for re-evaluation. `--exclusion-ttl 0` disables TTL — entries persist permanently (subject only to rule 2).

For each flagged entry, dispatch a short synthesizer call:

> "Given the current state of `<file_path>`, is this finding still applicable? Finding: `<title>`. Reply YES (still applies, refresh and keep) or NO (no longer applies, drop)."

Apply the result:
- **YES** → set `last_reevaluated_round: N` and keep the entry. The exclusion remains active for this round.
- **NO** → drop the entry silently (no notification needed; if the finding genuinely recurs, the next reviewer pass will surface it as a fresh finding, which is the desired self-correcting behavior).

Entries with `file_path: null` (cross-file architectural critiques) can't use rule 2; they rely on TTL only.

**Cost envelope.** Each re-evaluation is ~$0.01 (short single-agent call). For a 3-round loop with <10 deferrals, this adds <$0.10 to the run — well below the noise floor of the cost cap.

### 6.3 Rebuild interaction

When `§7` rebuild fires, the post-rebuild codebase is wholesale-different. The coordinator **clears the exclusion list entirely** rather than copying it forward — every prior entry referenced a now-deleted codebase, so carrying them forward would suppress findings that genuinely re-apply in the new build. A fresh `exclusion-list.json` with `entries: []` is written at the start of the post-rebuild round 1. The archived pre-rebuild list at `.code-rinse-repeat/<slug>/pre-rebuild-<iso-timestamp>/exclusion-list.json` remains available for forensic purposes; tracker-issue URLs from it are copied into `state.json.notes[]` so the ship report can still reference them.

### 6.4 XMAR injection

The exclusion list is passed to each round's XMAR invocation via `--prompt-prelude <path>`. The skill renders `exclusion-list.json` to a markdown view at write time so reviewers see a "DO NOT report" heading with one bullet per entry, listing `<file_path> — <title> (severity, added round N)`. Entries with `type: "tracker-issued"` get an additional `[TRACKED: <tracker_url>]` suffix.

This is the same exclusion-list discipline `total-review` uses; the ref lives at `~/.claude/refs/multi-agent/exclusion-list.md`.

## 7. Rebuild trigger (`--allow-rebuild`)

If `--allow-rebuild > 0` and a CRITICAL finding is architectural (synth marks it `[ARCH]` or coordinator judges so):

1. Decrement `rebuilds_remaining` in `state.json`.
2. Construct a **delta spec**: the original `<target>` + a "## Architectural addendum" section quoting the architectural CRITICAL and what it implies must change.
3. Archive the current run: `mv .code-rinse-repeat/<slug> .code-rinse-repeat/<slug>/pre-rebuild-<iso-timestamp>/` (preserves exclusion list, prior round reviews, tracker-issue context for forensic purposes). Then tear down the existing worktree: `git worktree remove <path> --force`.
4. Restart from **Phase 1** with the delta spec as the target. Round counter resets to 0; iteration cap unchanged. Per §6.3, the live `exclusion-list.json` is reset to `entries: []` — do NOT copy the archived list forward. Any tracker-issue URLs from the archive should be preserved in `state.json.notes[]` so the ship report can reference them, but they no longer suppress reviewer findings.

Rebuilds are slow + expensive. Default 0 (off) is intentional. Use 1 when the first build was a reasonable attempt that just got the architecture wrong; use 2 only if you really expect the spec to evolve through review.

## 7.5 Budget enforcement (wall-clock + cost)

The coordinator enforces both budgets after every agent invocation (XMAD pass, XMAR pass, rebuild trigger):

1. Compute `wall_elapsed = now - state.started_at`.
2. Compute `cost_estimate = state.build.cost_usd_estimate + sum(state.rounds[].cost_usd_estimate)`.
3. If `wall_elapsed >= max_wall_minutes * 60` OR `cost_estimate >= max_cost_usd`: halt with verdict `BUDGET-EXHAUSTED-AT-<phase>:<round>`, commit any in-flight fixes that already passed tests, and emit the ship report with open findings.

Cost estimation rule: prefer the agent's reported usage if XMAD/XMAR surfaces it. Otherwise use the fallback table — XMAD pass ≈ $7, XMAR pass ≈ $2, coordinator-applied fix round ≈ $1 (fixed cost regardless of finding count). These are deliberately pessimistic so the budget halt fires early rather than late.

The check runs **before** committing the round-N fix commit, so a budget halt leaves the worktree clean and resumable.

## 7.6 State schema (`state.json`)

```json
{
  "schema_version": 1,
  "target": "./specs/2026-06-payment-replay.md",
  "slug": "payment-replay",
  "worktree": ".worktrees/feat/payment-replay",
  "branch": "feat/payment-replay",
  "phase": "review-loop",
  "round": 2,
  "max_iterations": 3,
  "rebuilds_remaining": 0,
  "max_wall_minutes": 90,
  "max_cost_usd": 25,
  "started_at": "2026-06-22T10:14:00Z",
  "phases_completed": ["preflight", "build"],
  "build": {
    "cost_usd_estimate": 6.4,
    "duration_seconds": 1320,
    "dev_agents": ["code-architect", "python-pro", "security-reviewer", "silent-failure-hunter"]
  },
  "checks": ["npm run check"],
  "smoke_cmd": "npm run smoke",
  "medium_accumulation_threshold": 8,
  "exclusion_ttl": 2,
  "paused_after_build": true,
  "paused_at": "2026-06-22T10:36:00Z",
  "resumed_at": "2026-06-22T10:38:12Z",
  "medium_flood_acked_at": null,
  "medium_flood_warning": false,
  "rounds": [
    {"round": 1, "summary": "fixed 2 CRIT (sql injection, race), deferred 1 HIGH", "cost_usd_estimate": 2.1, "duration_seconds": 480, "finding_commits": ["a1b2c3d4e5f6", "b2c3d4e5f6a1"], "reviewers": ["architect", "critical-thinking", "silent-failure-hunter", "security-reviewer"], "deferred_mediums": ["m1234567890a"]},
    {"round": 2, "summary": "fixed 1 HIGH (unbounded query); APPROVE imminent", "cost_usd_estimate": 1.9, "duration_seconds": 410, "finding_commits": ["c3d4e5f6a1b2"], "reviewers": ["architect", "critical-thinking", "silent-failure-hunter", "security-reviewer", "database-reviewer"], "deferred_mediums": []}
  ],
  "verdict": null,
  "notes": []
}
```

`verdict` stays `null` until Phase 3. `notes[]` is freeform — coordinator may append human-readable observations any time without breaking the schema. `paused_at`/`resumed_at` may appear in matched pairs in `notes[]` if the run pauses more than once (resume after `--pause-after-build`, then `--resume` later).

## 7.7 Progress reporting (user-facing emissions)

The coordinator emits a single canonical line to the user at every phase/round boundary so a long-running orchestration stays legible without scrolling. Every line is prefix-tagged `[code-rinse-repeat]` so the user can `grep` to follow the run.

**Emission contract:**

| When | Format |
|---|---|
| Phase 0 done | `[code-rinse-repeat] preflight ok slug=<slug> branch=<branch> worktree=<path>` |
| Phase 1 done | `[code-rinse-repeat] phase=build status=GREEN files=<created>+<modified> cost=$<n> elapsed=<m>m` |
| Phase 1.5 paused | `[code-rinse-repeat] paused-after-build (waiting on user; clock suspended)` |
| Phase 1.5 resumed | `[code-rinse-repeat] resumed-after-build action=<continue\|halt\|rebuild>` |
| Round N review done | `[code-rinse-repeat] r<N> review done: <C> CRIT / <H> HIGH / <M> MED / <L> LOW (cost=$<n> elapsed=<m>m)` |
| Round N fixes done | `[code-rinse-repeat] r<N> fixes done: applied <A> / deferred <D> / fix-failed <F> (cost=$<n> elapsed=<m>m)` |
| MEDIUM-flood trip | `[code-rinse-repeat] r<N> medium-flood: <count> deferred mediums (threshold <T>) — <action>` |
| Phase 3 ship | `[code-rinse-repeat] verdict=<verdict> cost=$<n> elapsed=<m>m → ship report at .code-rinse-repeat/<slug>/report.md` |
| Budget halt | `[code-rinse-repeat] BUDGET-EXHAUSTED-AT-<phase>:<round> cost=$<n> elapsed=<m>m (cap=$<cap>/<wall>m)` |
| Stuck halt | `[code-rinse-repeat] STUCK-AT-<N> jaccard=<j> (open: <C> CRIT / <H> HIGH)` |

**Rules:**

- One line per emission. No multi-line output, no progress bars, no spinners.
- Emissions go to the user-facing channel (the coordinator agent emits them as plain text between tool calls), NOT to a log file. If the user is `tail`ing a log, they can pipe the coordinator's stdout themselves.
- Subagent invocations (XMAD, XMAR, synthesizer calls) must run **between** emissions, not during — i.e., the coordinator emits the round-N-review-done line only after the XMAR subagent has fully returned.
- Format is fixed; do not add verbosity levels or JSON output. A single canonical format keeps the contract auditable and `grep`-friendly.

The Phase-3 ship-emission line carries the final verdict — this is what `baton-runner-multi-agent` (or any other dispatcher) greps to record per-unit outcomes.

## 8. Resumability

If the orchestrating agent is interrupted (out-of-context, user `Esc`, hook fail), `state.json` is the source of truth. The user resumes with `code-rinse-repeat <target> --resume`. The coordinator:

1. Reads `.code-rinse-repeat/<slug>/state.json` and validates `schema_version`.
2. Reads `.code-rinse-repeat/<slug>/exclusion-list.json` (missing file or `{"entries": []}` is fine).
3. Recomputes remaining budget = `max_wall_minutes * 60 - (now - started_at)` and `max_cost_usd - sum(prior cost_usd_estimate)`. If either is ≤ 0, halt with `BUDGET-EXHAUSTED-ON-RESUME`.
4. Resumes at `phase: review-loop, round: <state.round + 1>` — i.e., the next round to run.

The build phase is not resumable mid-run; if `state.json` shows `phase: "build"` (XMAD was interrupted), the resume path is to manually `git worktree remove --force <path>`, delete `.code-rinse-repeat/<slug>/`, and re-invoke fresh.

## 9. Failure modes

| Mode | Cause | Action |
|---|---|---|
| `BAD-TARGET` | Spec file unreadable or issue unfetchable in Phase 0 | Halt; report parse error; stop before any agent invocation |
| `SLUG-COLLISION` | Existing `state.json`, worktree, or branch for the derived slug | Halt; suggest `--resume` (for prior `state.json`) or `--slug-suffix` (for stale worktree/branch) |
| `BUILD-FAILED` | XMAD's final retry left tests RED | Halt; summarize; do not enter review loop |
| `STUCK-AT-N` | Round N findings ≥80% identical to N-1 | Halt; summarize remaining + suggest human review |
| `MAX-ITERATIONS-AT-N` | Hit cap without APPROVE | Halt; ship with open findings logged; PR description carries the list |
| `FIX-FAILED-ROUND-N` (per finding) | Tests went RED after the fix | Revert that fix, file tracker issue, continue with next finding |
| `CHECKS-FAILED-ROUND-N:<which>` (per finding) | Lint/typecheck/format check failed after the fix | Revert that fix, file tracker issue noting which check tripped, continue |
| `SMOKE-FAILED-ROUND-N` (per finding) | Smoke went RED after the fix | Revert that fix, file tracker issue, continue |
| `REBUILD-EXHAUSTED` | `--allow-rebuild` cap hit but architectural CRITICAL recurs | Halt; escalate to human; do not rebuild again |
| `BUDGET-EXHAUSTED-AT-<phase>:<round>` | `max_wall_minutes` or `max_cost_usd` reached | Halt; commit any in-flight green fixes; emit ship report with open findings; run is resumable via `--resume` if user bumps the caps |
| `BUDGET-EXHAUSTED-ON-RESUME` | Resume attempt has zero remaining budget | Halt; user must raise `--max-wall-minutes` / `--max-cost-usd` to continue |
| `HALTED-AFTER-BUILD` | User picked "Halt and inspect" at the §5.1.5 pause checkpoint | Halt; emit ship report at build-only level; resumable via `--resume` |
| `HALTED-AT-MEDIUM-FLOOD-N` | User picked option 4 at the §5.2.b.1 MEDIUM-accumulation prompt | Halt; emit ship report with the flood-warning block prepended; resumable via `--resume` |

## 10. Defaults summary (TL;DR)

- 1 build pass (XMAD).
- Optional pause-after-build checkpoint (`--pause-after-build`); auto-skipped in non-interactive runs.
- Round 1 starts with a spec-conformance pre-pass (FAIL ≡ CRITICAL, blocks broader review).
- Up to 3 review-fix rounds (XMAR + coordinator-applied fixes), reviewers rotate (domain specialist in r2, fresh-eyes in r3).
- 0 rebuilds (CRITICAL architectural findings get escalated, not rebuilt). Rebuild clears the exclusion list.
- GREEN gate = tests + project-checks (lint/typecheck/format, discovered or `--checks`) + smoke (when triggered).
- One commit per finding; trailing round-marker commit per round; `--squash-on-approve` collapses at ship.
- Round 2+ review scope pinned to `git diff $(git merge-base HEAD main)..HEAD` — cumulative diff, not last-round diff.
- Stuck detection uses Jaccard ≥0.80 over finding-identity tuples restricted to CRITICAL+HIGH.
- MEDIUM-flood guard at 8 cumulative deferrals (interactive prompt) / silent warning + ship-report banner (non-interactive). Disable with `--medium-accumulation-threshold 0`.
- Exclusion list is structured JSON; deferred entries auto-re-evaluated every 2 rounds (`--exclusion-ttl`) or whenever the entry's file is touched; tracker-issued entries are exempt.
- All CRITICAL and HIGH addressed every round.
- Wall-clock cap 90 min (paused while waiting on user), cost cap $25 — whichever hits first halts cleanly with a ship report.
- Slug collisions halt by default; `--resume` to continue a prior run, `--slug-suffix` to fork.
- One-line user emissions at every phase/round boundary (see §7.7), prefix-tagged `[code-rinse-repeat]` for `grep`.
- Resumable from `state.json` (v1 schema, see §7.6).

## 11. Composition

This skill is the **end-to-end** layer in the multi-agent stack:

| Layer | Skill | What it owns |
|---|---|---|
| Spec → code | `multi-agent-developer` | TDD build, one pass |
| Code → findings | `multi-agent-review` | Parallel review, one pass |
| Findings → APPROVE | `multi-agent-review-loop` | Review-fix loop on existing PR |
| Spec → APPROVE | **`code-rinse-repeat`** | Build + review-fix loop, end-to-end |

If you need a sequential queue of code-rinse-repeat targets across multiple specs, that's `baton-runner-multi-agent`'s job — it can dispatch this skill as the per-unit work.
