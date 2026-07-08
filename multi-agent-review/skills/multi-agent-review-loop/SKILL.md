---
name: multi-agent-review-loop
description: Iterative wrapper around multi-agent-review for a single PR — spawns a fresh review subagent per round, applies fixes, re-reviews, until APPROVE or max iterations. User-invoked; the invoking agent orchestrates the loop.
allowed-tools:
  - Bash
  - Read
  - Edit
  - Write
  - Glob
  - Grep
  - Agent
  - Skill
  - TaskCreate
  - TaskUpdate
---

# multi-agent-review-loop

## 1. Purpose

`multi-agent-review` is report-only — one parallel review pass, one synthesized verdict. This wrapper composes it into a **review → fix → re-review** loop bounded against a single open PR, with the invoking agent acting as the loop coordinator. Each review round runs in a **fresh subagent** so the per-round reviewer transcripts never enter the coordinator's context window; the coordinator only sees each round's prioritized findings list.

The coordinator (you, the agent running this skill) applies fixes itself between rounds — fixes are not delegated to another subagent because triage (which findings to action, which to defer, when to file follow-ups, when to escalate to a human) requires the project context that only the coordinator holds. This skill is the **protocol** the coordinator follows; the per-round review work is what gets sandboxed.

## 2. When to use

Trigger phrases:
- "loop the multi-agent review until clean on PR #N"
- "iterative review on PR #N"
- "review-fix-review PR #N"
- explicit invocation: `multi-agent-review-loop <PR>`

Do NOT use for:
- A single one-shot review pass — use `multi-agent-review` directly.
- Targets that are not PRs (directories, files, spec sets) — the loop's value is "fix-apply-push-re-review," which requires a mutable branch backing the target.
- A PR you are about to merge regardless of findings — the loop only makes sense when fixes will actually be applied.

## 3. Invocation grammar

```
multi-agent-review-loop <pr-ref> [flags]
```

Examples:

```
multi-agent-review-loop 203
multi-agent-review-loop https://github.com/owner/repo/pull/42

# Override the iteration cap (default 3, hard ceiling 8):
multi-agent-review-loop 203 --max-iterations 5

# Pass-through to the inner review (reviewer roster override):
multi-agent-review-loop 203 --reviewers crypto-security-reviewer,code-reviewer

# Auto-defer MEDIUM/LOW findings (don't even ask the coordinator):
multi-agent-review-loop 203 --high-and-up-only

# Skip the per-round live smoke (unit tests still run):
multi-agent-review-loop 203 --no-smoke
```

| Position / flag | Required | Values |
|---|---|---|
| `<pr-ref>` (positional 1) | yes | PR number or GitHub URL |
| `--max-iterations <n>` | no | integer 1–8, default 3 |
| `--reviewers <csv>` | no | passed through to `multi-agent-review` |
| `--synthesizer <name>` | no | passed through to `multi-agent-review` |
| `--high-and-up-only` | no | coordinator auto-defers MEDIUM/LOW each round; only CRITICAL + HIGH drive iteration |
| `--no-smoke` | no | skip live smoke test on the round even when connector/runtime code changed |

## 4. Defaults

- **`--max-iterations`**: **3**. Most projects stabilize in 1–2 rounds; 3 catches genuine fix follow-ons; beyond that the reviewers are usually nitpicking. Hard ceiling is **8** — refuse anything higher (a `--max-iterations 50` request indicates a misunderstanding of the loop's purpose).
- **Action floor**: by default the coordinator MUST address every CRITICAL and HIGH; MEDIUM is coordinator's judgment; LOW is "note in PR comment, do not iterate on." With `--high-and-up-only`, MEDIUM and LOW are auto-deferred without prompting.
- **Smoke test gate**: re-run the project's live smoke ONLY if a fix touched code paths the smoke exercises (project-specific — for VistaTrader: connector loop, parse path, allowlist filter, metric increment, route handlers). Skip otherwise. `--no-smoke` opts out entirely.
- **Inner skill name**: `multi-agent-review`. If absent at both project and user scope, hard-fail with "this loop wraps `multi-agent-review`; activate that skill first."

## 5. Workflow

The coordinator MUST follow these steps in order on every invocation:

### 5.1 Parse and validate

1. Parse positional arg + flags per §3.
2. Hard-fail with a clear error if:
   - `<pr-ref>` is missing or doesn't parse as a number or `gh`-acceptable URL.
   - `--max-iterations` is < 1 or > 8.
3. Verify `gh` is on PATH (`command -v gh`) — fail with install instructions if not.
4. Verify the PR exists and is open: `gh pr view <ref> --json state,headRefName,baseRefName,url`. Hard-fail on `state != OPEN` (closed/merged PRs can't be iterated).
5. Verify `multi-agent-review` is available (the inner skill). If invocable via `Skill(skill="multi-agent-review", ...)`, proceed. If absent, hard-fail.
6. Verify the working directory is a git worktree on the PR's `headRefName` (or `cd` into one if a worktree for that branch exists locally). If neither, hard-fail with `please create a worktree on <headRefName> before invoking this loop`.

### 5.2 Initialize loop state

Create a TodoWrite-style task list — one task per planned iteration plus a final "summarize and close" task — to make progress visible. Initialize:

- `iterationsCompleted = 0`
- `findingsFixedThisRun = { CRITICAL: 0, HIGH: 0, MEDIUM: 0, LOW: 0 }`
- `findingsDeferredThisRun = { MEDIUM: [], LOW: [] }`
- `priorFindingsFingerprints = Set<string>` (used in §5.7 for regression detection)

### 5.3 Per-iteration: dispatch the review subagent

For iteration `N = 1, 2, …, maxIterations`:

1. Spawn a **fresh general-purpose subagent** via the `Agent` tool. The brief MUST be self-contained — the subagent has no shared context with the coordinator.

2. The subagent brief MUST include:
   - The repo's worktree path (absolute).
   - The PR number and the branch name.
   - The instruction: `Skill(skill="multi-agent-review", args="<pr-ref> <pass-through flags>")`.
   - **Hard rule:** "Do NOT apply any fixes. Report-only. The orchestrator session applies fixes."
   - The required output schema:
     ```
     VERDICT: APPROVE | NEEDS_CHANGES | BLOCK

     ## CRITICAL
     - <file_path>:<line> — finding — fix recommendation

     ## HIGH
     - ...

     ## MEDIUM
     - ...

     ## LOW
     - ...

     ## Notes
     - any reviewer disagreements
     - any tool-availability failures (e.g. "Agent tool not exposed to subagent — reviewers ran inline")
     ```
   - The explicit fallback chain for the inner skill's invocation grammar: `args="<n>"` → `args="PR <n>"` → no-args. If all fail, list the skill files at `/home/alex/VistaTrader/.claude/skills/multi-agent-review/` (or equivalent) and stop.

3. **Subagent-dispatch precondition check**: the brief MUST instruct the subagent to verify the `Agent` tool is available in its environment before invoking the inner skill. If it is not, the subagent MUST emit a `## Notes` line saying so and execute the four reviewer lanes inline (one agent role-playing four, scoped strictly to the reviewer agent files), then synthesize. The coordinator should weight findings from an inline-fallback round less than a true-parallel round (treat one HIGH as one HIGH, but don't trust "no disagreements" — the same author found all four lanes).

### 5.4 Per-iteration: triage findings

When the subagent returns:

1. If VERDICT = APPROVE → break the loop. Goto §5.8.

2. Compute a fingerprint for every finding: `sha256(file_path + line + finding_one_line_summary)`. If the same fingerprint appeared in `priorFindingsFingerprints` AND the prior round claimed it was fixed → STOP the loop and emit the "regression detected" report (§5.7). Either the fix didn't land or the reviewer is mis-flagging; either way it's a human-judgment moment, not a coordinator-fixable one.

3. Otherwise, partition findings:
   - **Auto-action**: every CRITICAL and HIGH.
   - **Coordinator judgment**: every MEDIUM. The coordinator decides per-finding whether to fix or defer based on (a) whether the fix is small (< ~20 LOC), (b) whether the fix risks regressions, (c) whether the finding actually applies to this PR vs. is a pre-existing pattern smell. Default for `--high-and-up-only`: auto-defer all MEDIUM.
   - **Defer to comment**: every LOW. Never iterate on LOW.

4. Add new finding fingerprints to `priorFindingsFingerprints`.

### 5.5 Per-iteration: apply fixes

For each finding the coordinator decided to fix:

1. Edit the affected file(s) in the worktree using the `Edit` / `Write` tools.
2. After all edits for the round are in, run the project's unit tests for the affected module:
   - VistaTrader: `./gradlew :aggro:test` (or the appropriate module).
   - Generic: read the project's CLAUDE.md or the inner skill's notes for the test command.
3. If tests regress → STOP. Revert (`git checkout -- <paths>`), emit a "test regression on round N" report, surface the failing test output to the user, do NOT push.
4. If a fix touched code paths the live smoke covers AND `--no-smoke` is not set → run the smoke. If smoke fails, same treatment as test regression.
5. Regenerate any auto-maintained docs (project-specific: VistaTrader `ARCH.md` via `python3 .githooks/gen_arch.py --root .` if any tracked file was added/renamed).

### 5.6 Per-iteration: commit + push

1. `git add` the specific touched paths (do not use `git add -A`).
2. Commit with `git -c core.hooksPath=/dev/null commit -m "fix(<scope>): address review round N findings — <one-line summary>"` — the `core.hooksPath=/dev/null` is the standing VistaTrader gotcha (pre-commit hooks fail silently under the Claude Code harness; manual ARCH.md regen in §5.5 is the substitute). For other projects, drop the override.
3. The commit body should list the addressed findings by `file_path:line` so the PR diff history reflects the review-iteration trail.
4. `git push` to update the PR.
5. Increment `iterationsCompleted` and update `findingsFixedThisRun` counters.

### 5.7 Loop control & safety stops

Continue the loop only if:

- VERDICT was NEEDS_CHANGES or BLOCK (not APPROVE).
- `iterationsCompleted < maxIterations`.
- No regression (§5.4 step 2).
- No test/smoke failure (§5.5 steps 3-4).

If any stop condition fires, emit the final report (§5.8) explaining which condition stopped the loop. **Never silently continue past a stop condition** — surface it.

### 5.8 Final report

Print a single structured report:

```
# Review loop report — PR #<n>

Final verdict: APPROVE | STOPPED_<reason>
Iterations completed: <N>
Iterations cap: <max>

## Findings fixed
- CRITICAL: <count>
- HIGH: <count>
- MEDIUM: <count>

## Findings deferred (filed as PR comment / follow-up issue)
- <list, with severity + file:line + reason for deferral>

## Findings remaining (only if STOPPED_*)
- <full list of unresolved findings from the last round>

## Notes
- <reviewer-tool-availability flags from each round>
- <reviewer disagreements that the coordinator adjudicated>

## Next action
<one-sentence recommendation to the user>
```

Additionally:

1. **Post a single PR comment** summarizing the loop's actions: total rounds, fixes applied with commit refs, items deferred with reasoning, and any items left unresolved. Use `gh pr comment <ref> --body ...`.
2. **File a follow-up issue** for every deferred MEDIUM that survives the loop (LOW items get inlined into the PR comment instead — don't pollute the issue tracker with style nits).

## 6. Anti-patterns

- **Don't delegate the fix step to another subagent.** Triage requires project context; sub-fixers without that context produce sloppy patches the coordinator then has to re-review.
- **Don't loop on LOW findings.** A LOW today is a LOW tomorrow; iterating on style nits is the treadmill failure mode.
- **Don't auto-merge after APPROVE.** The human owns merge approval. The loop ends at "ready for human review," not "merged."
- **Don't run the smoke test on every round.** Smoke is expensive (port binding, DB, full app boot). Run only when the fix actually touched code the smoke exercises.
- **Don't suppress reviewer disagreements.** When two lanes contradict, the coordinator picks the safer side and **says so** in the round's commit message and the final report.
- **Don't accept a "no disagreement" claim from an inline-fallback round at face value.** Same author found all four lanes; disagreements were suppressed by construction.

## 7. Resolved decisions

| # | Decision | Choice | Rationale |
|---|---|---|---|
| 1 | Loop scope | PR only | Dir/file/spec sets have no "apply fix and re-review" cadence; the loop's whole value is the mutate-and-re-test cycle. |
| 2 | Max iterations default | 3, hard ceiling 8 | Most issues caught in round 1; 3 catches fix follow-ons; > 8 indicates a fundamental disagreement, not a mechanical loop. |
| 3 | Fix step in the coordinator, not a sub-fixer | Coordinator has project context (which MEDIUMs apply to this PR vs. project-wide; which findings the human author would push back on); a sub-fixer has neither and produces over-eager patches. |
| 4 | LOW findings never iterate | Comment-and-defer | Iterating on LOW is the treadmill failure mode that makes the loop useless. |
| 5 | Regression detection (same-fingerprint twice) | Stop loop, surface to human | Either the fix didn't land or the reviewer is wrong; coordinator can't adjudicate that. |
| 6 | `--high-and-up-only` flag | Opt-in | Some teams want MEDIUM judgment in the loop; some want only CRITICAL/HIGH discipline. Default is "judgment", flag is "discipline". |
| 7 | Inline-fallback round handling | Run the loop, weight disagreements less | The inner skill currently can't guarantee subagent-of-subagent dispatch; refusing to loop in that case would block the skill on a tooling problem unrelated to its purpose. |
| 8 | Smoke gate trigger | Project-specific touched-path heuristic + `--no-smoke` escape hatch | Always-on smoke makes the loop too expensive; never-on smoke makes connector-loop regressions invisible until merge. Heuristic + opt-out is the middle. |
| 9 | PR comment + follow-up issue at end | Always | The PR's review history should reflect what happened; deferred MEDIUMs need a place to live so they aren't forgotten. |

## 8. Composition with other skills

- **Inside this loop, the coordinator MAY use** `tdd`, `diagnose`, `kotlin-review`, project-specific skills (e.g. VistaTrader `aggro-new-exchange-connector`) when applying fixes. Using `multi-agent-review` itself outside the loop's subagent dispatch is fine for a one-off sanity check after a controversial fix.
- **This skill MUST NOT be invoked from inside another loop skill** (e.g. `baton-runner`, `multi-agent-developer`). Nested loops create non-deterministic finish conditions and exponential agent fan-out.
