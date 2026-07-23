---
name: multi-agent-developer
description: Manager-led TDD dev team (≤4 Opus agents) debates a spec across RED→GREEN→REFACTOR rounds in markdown, then a synthesizer materializes a worktree and runs tests with one retry on failure.
allowed-tools:
  - Bash
  - Read
  - Glob
  - Grep
  - Edit
  - Write
  - Agent
  - AskUserQuestion
---

# multi-agent-developer

## 1. Purpose

Orchestrate a TDD-disciplined dev team to implement a spec, PRD, or issue. Counterpart to `multi-agent-review` (read-only review): this skill produces verified, runnable code on a feature branch in a fresh worktree.

## Shared primitives

This skill is one of three (alongside `total-review` and `multi-agent-review`) that share these primitives:

- [`refs/multi-agent/fanout-consolidation.md`](../../refs/multi-agent/fanout-consolidation.md) — the parallel-fan-out and synthesis contract that the RED/GREEN/REFACTOR rounds and `ecc-code-architect` synthesis pass instantiate.
- [`refs/multi-agent/agent-catalog-lookup.md`](../../refs/multi-agent/agent-catalog-lookup.md) — how Phase 5.4 auto-selection and `--agents <csv>` resolve names against the project active catalog and the user-scope parked tier.
- [`refs/multi-agent/spec-injection.md`](../../refs/multi-agent/spec-injection.md) — the spec IS the target of this skill; the specialist briefs MUST carry it under the canonical heading from the ref so "the change must satisfy this" is a first-class round constraint, not a paraphrased summary.

The orchestrating Claude **IS** the manager (no nested manager agent). The manager:

1. **Bootstraps** required framework agents (`ecc-code-explorer`, `ecc-code-architect`) into the project, or halts with the setup command if missing.
2. **Explores** the codebase via `ecc-code-explorer`.
3. **Selects** ≤4 dev specialists by scoring active project agents + user-parked catalog candidates, surfacing parked alternatives as a footnote.
4. **Gets user approval** of the team AND the auto-derived branch slug (block-and-wait, `AskUserQuestion` when options are crisp).
5. **Runs 3 fixed TDD-phased rounds** in markdown (RED → GREEN → REFACTOR) where agents debate in shared, caveman-compressed context.
6. **Synthesizes** the converged implementation via `ecc-code-architect`.
7. **Materializes** the worktree (`.worktrees/feat/<slug>`) and applies files via `Write`/`Edit`.
8. **Verifies** by running the project's test command in the worktree; on failure, runs one GREEN-redux retry round.

All dev agents run on Opus. Caveman compression applies to **internal Shared Context Blocks only** — not to user-facing chat.

## 2. When to use

Trigger phrases:
- `/multi-agent-developer <target>` / `multi-agent-developer …`
- "build this spec with a multi-agent dev team"
- "implement this PRD with a TDD dev team"
- "multi-agent dev on issue #N"

Do NOT use for:
- Simple single-file edits — call the relevant agent directly.
- Review-only tasks — use `/multi-agent-review`.
- Sequential issue grinding — use `/baton-runner`.
- Pure refactors with no test coverage — invoke `--no-tdd` or use `/code-simplify` (currently parked under `skills/disabled/`; `git mv` it into `skills/` first to activate).

## 3. Invocation grammar

```
multi-agent-developer <target-type> <target-args...> [flags]
```

Examples:

```
multi-agent-developer file docs/specs/new-feature.md
multi-agent-developer file docs/prd/auth-rework.md
multi-agent-developer issue 42
multi-agent-developer issue https://github.com/owner/repo/issues/42

# Manual team override (skips Phase 5.4 auto-selection, still requires 5.5 approval):
multi-agent-developer file foo.md --agents ecc-tdd-guide, python-pro, ecc-security-reviewer

# Skip TDD (e.g., for doc-only or config-only tasks):
multi-agent-developer file foo.md --no-tdd

# Disable post-synthesis test retry:
multi-agent-developer file foo.md --no-retry

# Save synthesis report alongside the worktree:
multi-agent-developer file foo.md --write-report docs/dev-reports/foo-impl.md
```

| Position / flag | Required | Values |
|---|---|---|
| `<target-type>` | yes | `file` (any markdown: spec/PRD/notes) \| `issue` (GitHub issue number or URL) |
| `<target-args>` | yes | file: one path. issue: number or URL |
| `--agents <csv>` | no | comma-separated dev specialist slugs; whitespace trimmed; unknown names hard-fail. Skips Phase 5.4 auto-selection but Phase 5.5 approval still required |
| `--max-agents <n>` | no | dev specialist cap, range [1, 4], default 4 (does NOT include framework agents) |
| `--no-tdd` | no | Disable the fixed 3-phase TDD round structure; use a single round of free-form collaboration. Implies `--no-retry` |
| `--no-retry` | no | Disable the post-synthesis test retry round |
| `--write-report <path>` | no | Save the final synthesis report markdown to `<path>` in addition to the worktree |
| `--force` | no | With `--write-report`, allow overwrite |

> **Why `--write-to` is gone.** The worktree IS the deliverable. `--write-report` exists for the human-readable synthesis summary (a separate artifact from the code).

## 4. Defaults

- **Framework agents** (always required, set up once per project via `/multi-agent-developer-setup`): `ecc-code-explorer`, `ecc-code-architect`
- **Dev specialist count**: ≤ 4
- **Round structure**: 3 fixed TDD phases (RED, GREEN, REFACTOR), unless `--no-tdd`
- **Retry**: one GREEN-redux on test failure, unless `--no-retry`
- **Synthesizer**: `ecc-code-architect` (hard-coded; not user-overridable since materialization assumes its output shape)
- **Model for all dev agents**: opus
- **Caveman scope**: Shared Context Block (between-round outputs) only; NEVER user-facing chat
- **Branch naming**: auto-derived from target → `feat/<slug>`, overridable at approval gate
- **Worktree root**: `.worktrees/feat/<slug>` relative to `git rev-parse --show-toplevel`

## 5. Workflow

### 5.0 Phase 0 — Bootstrap check

Before any agent runs, verify framework deps are project-activated. If any are missing, halt:

```bash
ls "<repo-root>/.claude/agents/ecc-code-explorer.md"   # must exist
ls "<repo-root>/.claude/agents/ecc-code-architect.md"  # must exist
```

If either is missing:

```
HALT — framework agents not activated in this project.

Run once:
  /multi-agent-developer-setup

Then re-invoke /multi-agent-developer with the same args.
```

Do not spawn anything. Do not auto-activate. The setup command is a deliberate one-time act per project (see "Sister command" below).

### 5.1 Phase 1 — Parse and validate

1. Parse positional args + flags per §3.
2. Hard-fail with one-line usage and exit if:
   - `<target-type>` missing or not `file|issue`.
   - `<target-args>` invalid.
   - `--agents` present but empty.
   - `--max-agents` outside `[1, 4]`.
3. **`--agents` CSV validation**: split on `,`, strip whitespace, reject empty tokens or tokens containing internal whitespace.
4. **`--write-report` overwrite guard (early)**: resolve `<path>` absolute (relative to `git rev-parse --show-toplevel` if not already). If destination exists AND `--force` not set → hard-fail BEFORE any agent spawn.
5. If `--agents` is set, validate every name against the catalog union (Phase 5.4 reads both project agents and user-level `~/.claude/agents-parked/CATALOG.md`).

### 5.2 Phase 1b — Resolve target materials

| Target type | Resolution |
|---|---|
| `file <path>` | Resolve absolute; verify exists; read full contents into `{{TARGET_BLOCK}}`. Any markdown is acceptable — spec, PRD, design doc, notes. |
| `issue <n\|url>` | Require `gh` on PATH (hard-fail with install instructions otherwise). Run `gh issue view <ref> --json number,title,body,labels,author,url,assignees,milestone,comments`. Embed JSON. Hard-fail with `gh` stderr if it errors. |

### 5.3 Phase 2 — Codebase exploration

Spawn ONE `Agent` call:
- `subagent_type`: `ecc-code-explorer`
- `description`: `"multi-agent-developer: explore for <target-label>"`
- `prompt`: `{{TARGET_BLOCK}}` + explicit instruction to read `ARCH.md` (if present), trace likely-affected execution paths, and return: affected files (absolute paths), language/framework, existing utilities to reuse, test locations, architectural risks.

After return, manager (orchestrator) **caveman-compresses** the explorer's output into a Codebase Context Block — preserves every concrete file path, function name, and architectural fact, drops filler. Code blocks and exact identifiers are preserved verbatim per caveman's own carve-out (`Code blocks unchanged. Errors quoted exact.`).

### 5.4 Phase 3 — Agent selection

**Step A — Scan both tiers:**

```
Read <repo-root>/.claude/agents/                       # project-active dev specialists
Read ~/.claude/agents-parked/CATALOG.md                # user-level catalog
Read ~/.claude/skills/CATALOG.md                       # user-level skills (incl. Disabled section)
```

Build a candidate list `[(slug, tier, description)]` where `tier ∈ {project, user-parked, user-disabled-skill}`.

> Framework agents (`ecc-code-explorer`, `ecc-code-architect`) are EXCLUDED from this pool — they're Phase 0 bootstrap dependencies, not part of the dev specialist count.

**Step B — Score against the task domain.** Heuristics:
- Domain match (Python task → +6 for `python-pro`, `ecc-python-reviewer`)
- Layer match (API → +5 for `api-architect`, `backend-developer`, `ecc-fastapi-reviewer`)
- Cross-cutting always considered: `ecc-security-reviewer` (+4 baseline; +6 if task touches auth/input/secrets/APIs); `ecc-tdd-guide` or `test-automator` (+5 since TDD is the default discipline)
- Tie-breakers: prefer ECC-flavored agents (`ecc-*`) for code-quality lanes; prefer specialists over generalists.

Lanes and their agents are resolved via `refs/multi-agent/context-aware-selection.md`
and `refs/multi-agent/lane-agent-table.md`. The Domain/Layer and cross-cutting
scores above are the **semantic matcher** used when the deterministic table does
not map a lane (or its mapped agent is absent from the pool). `--max-agents`
(default 4) is the CAP; framework agents remain excluded; parked alternatives are
surfaced in the footnote per Decision #13.

**No tier penalty.** Per Q13, scan both tiers and propose the best regardless of tier. Show parked alternatives as a transparent footnote so user can override.

**Step C — Pick top N (≤ `--max-agents`):** Distinct lanes only; do not pick two agents for the same role.

If `--agents` was passed: skip Steps B/C and use the user-supplied list verbatim (validated in §5.1).

**Step D — Build proposal:**

```
TEAM PROPOSAL — target: <target-label>
Branch: feat/<auto-slug>   (collision warning if .worktrees/feat/<slug> exists → using feat/<slug>-2)

Selected dev specialists (N/<max>):
1. <slug>  [tier]  — <role assigned for this task>
2. <slug>  [tier]  — <role>
3. <slug>  [tier]  — <role>
4. <slug>  [tier]  — <role>

Could-be-stronger-with (parked alternatives, not selected):
- [user-parked] <slug> — <reason it might be stronger>
- [user-disabled-skill] <slug> — <reason>
- (none if none)

If you want a parked alternative activated, reply: `activate <slug>` and I'll halt
with the git mv command for you to run, then re-invoke.

Approve? (`y` / `swap N for <slug>` / `add <slug>` / `drop N` /
           `swap branch <name>` / `activate <slug>` / `n`)
```

### 5.5 Phase 4 — User approval gate

**Block-and-wait.** No dev agents spawn until you respond.

**Input mode selection (per Q8):**
- If the choice is "approve this team, yes or no", use `AskUserQuestion` with 2 options + `Other`.
- If the choice is open-ended (e.g., complex swap, "activate this parked one but also drop slot 2"), use a prose prompt and parse the response.

Acceptable response grammar:
- `y` / `yes` / `approve` → proceed.
- `swap N for <slug>` → replace slot N. Validate against the candidate pool union.
- `add <slug>` → append (reject if exceeds `--max-agents`).
- `drop N` → remove slot N (reject if team would be empty).
- `swap branch <name>` → change branch slug. Validate `[a-z0-9-]+`, sanitize.
- `activate <slug>` → emit activation halt (see below); user runs `git mv`; user re-invokes.
- `n` / `no` / `reject` → abort skill; print `aborted by user`.

After any modification, re-print the proposal and re-ask.

**Activation halt** (for `activate <slug>` or selected parked member):

```
HALT — selected team requires activation. Run:
  git mv ~/.claude/agents-parked/<slug>.md <repo>/.claude/agents/<slug>.md

Or for a disabled user-level skill:
  git mv ~/.claude/skills/disabled/<slug> ~/.claude/skills/<slug>

Then re-invoke /multi-agent-developer with the same args.
```

### 5.6 Phase 5 — TDD-phased dev rounds

Three fixed rounds map to TDD phases. Each round dispatches ALL N dev agents in parallel.

| Round | TDD Phase | Lead agent role | Other agents do |
|---|---|---|---|
| 1 | **RED** | `ecc-tdd-guide` / `test-automator` (if in team) | Propose test cases for their domain (e.g., security reviewer proposes auth tests; api architect proposes contract tests) |
| 2 | **GREEN** | Implementer specialists (`python-pro`, `typescript-pro`, etc.) | Each contributes implementation for their lane; reviewers flag issues against draft impl |
| 3 | **REFACTOR** | `ecc-code-architect` or `ecc-code-simplifier` (if in team) | All agents review final unified impl; surface any remaining concerns |

If `--no-tdd`: collapse to ONE round of free-form collaboration (round goal: "produce a unified implementation given the spec"). Skip the phase-specific framing.

**Shared Context Block** (rebuilt each round, caveman-compressed per Q11):

```
## SHARED CONTEXT [round N / 3 — TDD phase: <RED|GREEN|REFACTOR>]

### TARGET (caveman)
<TARGET_BLOCK compressed>

### CODEBASE (caveman)
<CODEBASE_BLOCK from §5.3>

### TEAM
- <slug-1> — <lane / role for this phase>
- <slug-2> — <lane / role for this phase>
- ...

### PHASE GOAL
<RED: "agree on the test set" | GREEN: "agree on impl that passes tests"
 | REFACTOR: "agree on cleaned-up final form">

### PROGRESS LOG (cumulative, caveman)
R1 <slug-1> → tests for auth flow (4 cases)
R1 <slug-2> → security tests (input validation, token leak)
R2 <slug-1> → impl auth.py (passes 4/4)
...

### PREVIOUS ROUND OUTPUTS (caveman-compressed, code blocks verbatim)
--- <slug-1> [R1] ---
<caveman-compressed prose; code blocks intact>
--- <slug-2> [R1] ---
<caveman-compressed prose; code blocks intact>

### DISAGREEMENTS PENDING
- <one-line description if unresolved>
- (empty if none)

### RESOLUTIONS APPLIED (cumulative)
- R1: <conflict> → <decision> (reason: <axis>)
```

**Dispatch rule**: ALL N agents in ONE assistant message (parallel `Agent` tool uses). Each agent:
- `subagent_type`: agent slug
- `description`: `"multi-agent-developer R<n>/<phase>: <slug>"`
- `model`: `opus`
- `prompt`: expanded [Dev agent brief template](#dev-agent-brief-template)

**Convergence check** (per Q4, D+C):

After each round, scan agent outputs for the mandatory `### Convergence` section:
```
STATUS: converged | needs_another_round
REASON: <one line>
```

- **All N agents say `converged`** (where N is the actual team size, which can range from 1 to 4 after the approval-gate drop) → skip remaining rounds → go to Phase 6.
- **Split** → manager (orchestrator) reads outputs and decides:
  - If split is on a stylistic nit / minor preference → call it converged, log resolution.
  - If split is on a substantive disagreement → enter Disagreement Resolution (§6).

If max rounds reached with unresolved disagreements → escalate all → after user decision, synthesize with current state.

### 5.7 Phase 6 — Synthesis

Spawn ONE `Agent` call:
- `subagent_type`: `ecc-code-architect` (hard-coded; not user-overridable since the manager's worktree write depends on its output shape)
- `description`: `"multi-agent-developer: synthesize implementation"`
- `model`: `opus`
- `prompt`: expanded [Synthesis brief template](#synthesis-brief-template)

Synthesizer returns a unified implementation as a structured artifact:
```
## Files to Create
### <repo-relative-path>
<full code>

## Files to Modify
### <repo-relative-path>
<full new content OR unified diff>

## Test Files
### <repo-relative-path>
<full test code>

## Architectural Decisions
- <decision> — <rationale>

## Open Questions
- <if any>
```

> **Path convention:** the synthesizer emits each file with its **repo-relative path** as the `###` heading (no leading `/`, no source-repo prefix). The manager joins each path onto the worktree root before writing — see the Manager-driven worktree write step below.

**Manager-driven worktree write:**

```bash
cd "$(git rev-parse --show-toplevel)"
default_branch=$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's|^origin/||')
default_branch=${default_branch:-main}
git worktree add .worktrees/feat/<slug> -b feat/<slug> "$default_branch"
```

Default branch is auto-detected from `origin/HEAD`; falls back to `main`.

**Apply files to the worktree.** Capture the absolute worktree root (e.g., `<source-repo-toplevel>/.worktrees/feat/<slug>`) as `<worktree-root>`. For each `### <relpath>` section in the synthesizer's artifact, compute the target path as `<worktree-root>/<relpath>` and `Write`/`Edit` there. **Never write to a path outside the worktree** — if a heading appears to be absolute (starts with `/`) or escapes the worktree (contains `..`), hard-fail and surface the offending path. Do NOT commit and do NOT `git add` — leave changes in the working tree (untracked for new files, unstaged for modified files) for user review via `git status` / `git diff`.

If `--write-report <path>` set: `mkdir -p` parent dirs, write the synthesizer's structured artifact to `<path>`, prepend `Wrote: <absolute path>` to console output.

### 5.8 Phase 7 — Verification

**Test command detection** in the worktree (in this order, first-match wins):
1. `Makefile` with a `test` target → `make test`
2. `package.json` with `scripts.test` → `npm test` (or `pnpm test` if `pnpm-lock.yaml` exists, `yarn test` if `yarn.lock` exists)
3. `pyproject.toml` with `[tool.pytest.ini_options]` OR `pytest.ini` OR `tests/` directory → `pytest`
4. `Cargo.toml` → `cargo test`
5. `go.mod` → `go test ./...`
6. `gradlew` → `./gradlew test`
7. Otherwise: emit `[VERIFY SKIPPED — no recognized test runner]`; continue to final report.

**Run the detected command** in the worktree (`cd .worktrees/feat/<slug> && <cmd>`).

**Result handling:**
- **Pass** → emit `[VERIFY PASS]` + concise output tail; proceed to final report.
- **Fail** AND `--no-retry` not set → spawn one GREEN-redux round:
  - All N dev agents dispatched in parallel with a fresh Shared Context Block whose `PHASE GOAL` is "fix the test failures below"
  - Test failure output included verbatim in the brief
  - Agents return revised code; manager re-synthesizes via `ecc-code-architect`; manager re-applies to worktree; tests run again
  - If second run also fails → emit `[VERIFY FAIL — retry exhausted]` + failure output; flag in final report as `STATUS: needs human attention`
- **Fail** AND `--no-retry` set → emit `[VERIFY FAIL]` + failure output; flag in final report.

### 5.9 Phase 8 — Final report

Print to console:

```
## multi-agent-developer — complete

Worktree: <absolute path>
Branch:   feat/<slug>
Team:     <slug-1>, <slug-2>, ...
Rounds:   3 (TDD: RED → GREEN → REFACTOR) [+1 retry if applicable]
Verify:   <PASS | FAIL | SKIPPED>

Files written:
- <path-1>
- <path-2>
- ...

Architectural decisions: <count>
Open questions: <count, if any>

Next steps:
  cd <worktree-path>
  git diff main..HEAD          # review changes
  <test-cmd>                   # re-run tests if you want
  /pr                          # open PR when ready
```

If `--write-report` set: emit `Wrote report: <absolute path>` line on top.

## 6. Disagreement resolution protocol

When two or more agents propose conflicting approaches and the convergence check (§5.6) flags a split:

**Step 1 — Manager auto-resolve heuristics, in priority order per Q14:**

1. **Security**: If one approach has a defensible security advantage (validates input, parameterizes queries, scopes auth correctly), it wins. Log: `chose <agent>'s approach: security wins`.
2. **Tests / Correctness**: If one approach has more comprehensive test coverage demonstrating correctness, it wins. Log: `chose <agent>'s approach: better test coverage`.
3. **Consistency**: If one approach matches existing codebase patterns (per Codebase Context Block) and the other introduces a new pattern, the consistent one wins. Log: `chose <agent>'s approach: matches existing pattern at <file>`.
4. **Simplicity**: If still tied, prefer fewer files, fewer abstractions, shorter call chain. Log: `chose <agent>'s approach: KISS tie-breaker`.

If a step decides, stop. Record in `RESOLUTIONS APPLIED` and re-dispatch the next round (or proceed to synthesis if this was the final round).

**Step 2 — Escalate to user (only if Step 1 inconclusive):**

Manager presents the conflict using **`AskUserQuestion` if the choice fits 2-4 options**:

```
question: "Round 2 disagreement: which auth flow?"
options:
  - label: "JWT (agent-A)"
    description: "Stateless tokens; faster; harder to revoke"
  - label: "Session cookie (agent-B)"
    description: "Server-tracked; easier to revoke; needs Redis"
  - label: "Defer to synthesizer"
    description: "Let ecc-code-architect pick based on existing patterns"
```

If the disagreement is open-ended (not cleanly 2-4 buttonable), **prose prompt** instead:

```
**Disagreement requires your decision:**

- **Issue:** <one-paragraph statement>
- **<agent-A>'s position:** <summary + rationale>
- **<agent-B>'s position:** <summary + rationale>
- **What's at stake:** <e.g., security vs UX, consistency vs clean-slate>
- **Manager's recommendation:** <if any, with reason>

Reply with: A / B / <freeform decision> / defer
```

Record user's decision in `RESOLUTIONS APPLIED`; re-dispatch next round.

## 7. Caveman scope (per Q7)

**Applied to (manager-side compression of internal data):**
- Codebase Context Block (compressed explorer output)
- Previous Round Outputs (in Shared Context Block — code blocks preserved per caveman's own rule)
- Progress Log entries

**NOT applied to (full prose required):**
- Any user-facing chat from the manager (this conversation stays normal)
- Team proposal block at approval gate
- Disagreement escalation prompts (Step 2 above)
- Activation halts and any error messages
- Final report
- Agent output briefs (agents return precise, complete code; do NOT instruct agents to use caveman)

Manager does NOT invoke the `/caveman` skill (which would be sticky for the session per its persistence rule). Instead, manager applies caveman's compression rules directly to the internal context blocks while writing them — same effect, no session-level state change.

## 8. Templates

### Dev agent brief template

Expand `{{ ... }}` at invocation time. Pass result verbatim as the `prompt` field. Strip lines beginning with `#` (skill-author annotations) before sending.

```
You are the {{AGENT_SLUG}} agent on a {{TEAM_SIZE}}-person TDD dev team. You have no prior conversation context — everything you need is below.

This is **round {{ROUND_N}}/{{TOTAL_ROUNDS}}** — TDD phase: **{{PHASE}}**.

Phase goal: {{PHASE_GOAL}}
# RED: "agree on the test set"
# GREEN: "agree on impl that passes tests"
# REFACTOR: "agree on cleaned-up final form"
# (or for --no-tdd: "produce a unified implementation given the spec")

## YOUR ROLE THIS PHASE
{{ROLE}}
# Pulled from Phase 5.4 assignment + phase-specific adjustment (e.g., security reviewer in RED → "propose security-focused tests"; in GREEN → "audit draft impl for security issues").

## SHARED CONTEXT
{{SHARED_CONTEXT_BLOCK}}
# Caveman-compressed per Q11. Code blocks intact.

## YOUR TASK THIS ROUND
{{ROUND_TASK}}

## SKILLS YOU MAY INVOKE
Invoke relevant user-installed skills as you work: /tdd (TDD discipline), /ecc-security-review (hardening checklist), /ecc-error-handling, /ecc-api-design, /caveman (compress your own output if needed). Use them — do not re-derive their content.

## DISAGREEMENT PROTOCOL
If you disagree with another agent's previous-round output, mark dissent at the TOP:

  DISAGREEMENT: <other-agent-slug> on <topic>
  My position: <one paragraph>
  Their position (as you understood it): <one paragraph>
  Why mine is better: <one paragraph>

Manager will auto-resolve via security > tests > consistency > simplicity. If unresolvable, user decides.

## RETURN FORMAT

Return one markdown document with EXACTLY these sections, in order:

### Summary
One paragraph: what you produced this round and how it integrates.

### Output
The concrete artifact for your role this phase:
- RED: test file paths + full test code, with rationale per case.
- GREEN: implementation file paths + full code. Mark new vs. modified.
- REFACTOR: revised file paths + full revised code. Note what changed and why.
- For reviewer/auditor roles: severity-tagged findings (CRITICAL/HIGH/MEDIUM/LOW) against the lead's draft.
- For architect/lane-design roles: module layout + interface definitions + data flow.

### Open Questions / TODO
List unresolved items with `OPEN QUESTION:` or `TODO:` prefix. Manager scans for these.

### Convergence
Mandatory two lines:
  STATUS: converged | needs_another_round
  REASON: <one line — what's settled / what's still open>

### Confidence
One line: how confident you are; what would raise that confidence.

Do not include preamble. Start with `### Summary` (or `DISAGREEMENT:` if applicable).
```

### Synthesis brief template

```
You are ecc-code-architect synthesizing {{TEAM_SIZE}} agents' work across {{ROUNDS_COMPLETED}} TDD rounds into ONE materializable implementation artifact.

## TARGET
{{TARGET_BLOCK}}

## CODEBASE
{{CODEBASE_BLOCK}}

## TEAM
{{TEAM_ROSTER}}

## FULL ROUND HISTORY (caveman-compressed; code blocks verbatim)
{{ALL_ROUND_OUTPUTS}}
# Expand before sending. For each round, in order:
#
#   ===== ROUND <n> — <PHASE> =====
#   --- <slug-1> ---
#   <output>
#   --- <slug-2> ---
#   <output>
#   ...

## RESOLUTIONS APPLIED
{{RESOLUTIONS_BLOCK}}

## REMAINING OPEN QUESTIONS
{{OPEN_QUESTIONS_BLOCK}}

## YOUR JOB

Produce a single markdown artifact with EXACTLY these sections, structured for the manager to apply file-by-file to a fresh worktree:

# Synthesis: {{TARGET_LABEL}}

## Files to Create
For each new file:
### <repo-relative path>
Purpose: <one line>
```<language>
<full file content>
```

## Files to Modify
For each modified file:
### <repo-relative path>
Change: <what region / function>
```<language>
<full new content of changed region OR unified diff>
```

## Test Files
For each test file (created or modified):
### <repo-relative path>
Maps to requirements: <which requirement(s) from TARGET>
```<language>
<full test content>
```

**Path convention (strict):** every `###` heading above MUST be a **repo-relative path** — no leading `/`, no source-repo prefix (e.g. `src/auth.py`, NOT `/abs/path/to/repo/src/auth.py`). The manager will join each path onto the worktree root (`.worktrees/feat/<slug>/<relpath>`) before writing. Absolute paths or `..` segments will cause the manager to hard-fail.

## Architectural Decisions
Numbered list. Each: decision + rationale + alternative considered.

## Security Notes
Concrete hardening choices made. If none needed, say so explicitly.

## Open Questions for the Author
Items from REMAINING OPEN QUESTIONS needing human decision before code is applied.

## Verification
- Test command to run inside the worktree: `<exact command>`
- Any env vars / fixtures / local services required.

Do not include preamble. Start with `# Synthesis: ...`.

NOTE: The manager will parse this artifact and apply each file via Write/Edit to the worktree. Use **repo-relative paths** in every `###` heading (the manager joins them onto the worktree root). Use full file content unless the change is small enough that a unified diff is unambiguous.
```

## 9. Error handling

| Condition | Action |
|---|---|
| Missing or invalid `<target-type>` | Hard-fail with one-line usage. No agent spawn. |
| `gh` not on PATH with `issue` target | Hard-fail: `gh CLI required for issue target. Install: https://cli.github.com/`. |
| `gh issue view` fails | Hard-fail with `gh` stderr. |
| `file` target path doesn't exist | Hard-fail with the missing path. |
| `ecc-code-explorer` or `ecc-code-architect` missing from `<repo>/.claude/agents/` | Halt at Phase 0 with setup-command instruction. |
| Unknown agent name in `--agents` or in user `swap`/`add` | Hard-fail with list of nearest matches from catalog union. |
| Selected team includes `[user-parked]` or `[user-disabled-skill]` member | Halt at Phase 5 with activation `git mv` command. |
| `--write-report` destination exists, no `--force` | Hard-fail in §5.1, before any agent spawn. |
| Dev agent returns empty output | Note in PROGRESS LOG as `<slug>: [FAILED — no output]`; continue round; do not retry. |
| All dev agents fail in a round | Hard-fail; print partial state; do not invoke synthesizer. |
| Max rounds reached with disagreements pending | Escalate to user (§6 Step 2); after decision, synthesize with current state. |
| Synthesizer (`ecc-code-architect`) fails or returns malformed artifact | Print `Synthesizer failed. Round outputs follow:` + dump every round verbatim with `--- ROUND N / <slug> ---` delimiters. Skip worktree write. If `--write-report` set, persist same content with leading failure header. |
| Worktree creation fails (e.g., branch exists) | Hard-fail. Suggest `swap branch <name>` to retry; do not auto-overwrite. |
| Test command detection finds nothing | Emit `[VERIFY SKIPPED — no recognized test runner]`; proceed to final report without retry. |
| Test command itself errors (e.g., compile failure before tests run) | Treat as `Fail` — same retry path as test failure. |
| Verification retry also fails | Final report flags `STATUS: needs human attention`; do NOT delete worktree. |

## 10. Sister command — `/multi-agent-developer-setup`

One-time per-project setup. Activates the two framework agents:

```bash
git mv ~/.claude/agents-parked/ecc-code-explorer.md  <repo>/.claude/agents/ecc-code-explorer.md
git mv ~/.claude/agents-parked/ecc-code-architect.md <repo>/.claude/agents/ecc-code-architect.md
```

Idempotent: skip the move if already present at the destination.

This skill ships as a separate file (`~/.claude/skills/multi-agent-developer-setup/SKILL.md`) — kept thin so it stays a 10-second operation per project.

## 11. Resolved decisions

| # | Decision | Choice | Source |
|---|---|---|---|
| 1 | Tier discovery | Project-scope first; user-parked needs activation step | Q1 grill |
| 2 | Manager identity | Orchestrating Claude (no nested manager agent) | Q2 grill |
| 3 | Output format | Hybrid: markdown rounds → synthesizer materializes worktree | Q3 grill |
| 4 | Convergence detection | Agents self-declare `STATUS:`; manager backstops on split | Q4 grill |
| 5 | Synthesis & write | `ecc-code-architect` merges → manager applies files | Q5 grill |
| 6 | Required-agent bootstrap | Sister command `/multi-agent-developer-setup` | Q6 grill |
| 7 | Caveman scope | Internal context blocks only; never user-facing chat | Q7 grill |
| 8 | Escalation UX | Block-and-wait; `AskUserQuestion` for crisp options, prose otherwise | Q8 grill |
| 9 | Verification | Manager invokes `/tdd` discipline; auto-run tests + one retry | Q9 grill |
| 10 | Round structure | Fixed 3-phase TDD (RED/GREEN/REFACTOR); `--no-tdd` escape | Q10 grill |
| 11 | Previous-round context | Caveman-compressed; code blocks verbatim | Q11 grill |
| 12 | Branch naming | Auto-derived at Phase 4; `swap branch <name>` overrides | Q12 grill |
| 13 | Agent discovery scope | Always scan both tiers; transparent footnote on parked alternatives | Q13 grill |
| 14 | Auto-resolve priority | security > tests > consistency > simplicity | Q14 grill |
