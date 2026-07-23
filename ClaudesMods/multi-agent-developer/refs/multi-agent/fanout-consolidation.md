# Parallel fan-out and consolidation

Shared primitive for any skill that runs N reviewer/specialist agents in parallel and merges their reports. Cited by `total-review`, `multi-agent-review`, `multi-agent-developer`.

## Fan-out contract

1. **One message, N `Agent` tool calls.** Parallel = same assistant turn. Sequential turns serialize at the harness level. Hard cap 16 per turn; batch into two turns if you exceed it.
2. **Self-contained briefs.** Each agent prompt MUST carry: target materials (paths or excerpts), severity rubric, project invariants, any exclusion-list (see [`exclusion-list.md`](exclusion-list.md)), and the word cap. Reviewers don't share state; assume each one sees only its brief.
3. **Word cap per agent.** Always set one. Without a cap, reviewers pad. Typical caps: 700 (diff-only), 900 (cleanup), 1000 (tests/perf), 1100–1300 (security/architecture). Hard ceiling: 1500.
4. **Model uniformity.** Pick one model for the whole roster (typically `opus`). Mixing models on the same fan-out skews severity calibration.

## Consolidation rules (the actual dedupe)

Reviewer reports almost always overlap. Without these rules the synthesized output triple-counts the same call site.

1. **Dedupe by `(file, line, root cause)`.** If two lenses raise the same call site for the same reason, merge bodies and keep both perspectives in one entry. Never list twice.
2. **Severity tiebreak: pick higher.** When two lenses disagree on severity for the same finding, take the higher one.
3. **Cross-axis severity budget.** After dedupe, cap total HIGH at `min(declared_cap, ceil(N_lenses * 1.5))`. Rank by impact (CRITICAL-adjacent > correctness > maintainability > style; ties broken by distinct-lens count); keep the top, demote the rest to MEDIUM with an inline `_(demoted from HIGH by severity budget; <reason>)_` note. CRITICAL never demotes; LOW never promotes. Prevents N lenses each finding "one HIGH" → N blockers. Set `declared_cap` per skill; `total-review` defaults to 8, `multi-agent-review` defaults to 8 via `--high-cap <n>`. **Off-switch is mandatory.** When the synthesized output feeds a downstream gate that decides on CRITICAL+HIGH counts (e.g. `baton-runner-multi-agent` per-phase `VERDICT`), the caller MUST be able to set `declared_cap = off` to skip the demotion step entirely — silently demoting under a gate produces false-CLEAN. Wrappers expose this as a flag (`multi-agent-review`: `--high-cap off`); per-phase gating callers pass it.
4. **Theme grouping for HIGH.** Group HIGH items by theme (e.g. *atomicity*, *boundary leak*, *money math*, *typing*). Themes drive PR-slicing suggestions.
5. **Drop excluded findings silently.** Anything matching the injected exclusion list is dropped without comment. Do not re-report; do not log "skipped".
6. **Verdict.** `BLOCK` if any CRITICAL. `WARN` if no CRITICAL but ≥1 HIGH after the budget cap. `INFO` otherwise. One-line rationale at top of the synthesized report.

## Synthesizer agent

Use one synthesizer agent (separate from reviewers) to apply the consolidation rules. The orchestrating skill MUST NOT do the dedupe itself in user-facing chat — the synthesizer pass keeps the orchestrator lean and makes the consolidation auditable as a single artifact.

Default synthesizer: `ecc-code-architect` (for build pipelines) or `knowledge-synthesizer` (for review pipelines). Override per skill if you need a different lens (e.g. `code-reviewer` when the synthesis output will be filed as a tracker issue).

## Failure modes

- **Word-budget overrun.** Re-prompt with a stricter cap or split the target. Never silently truncate.
- **One reviewer returns garbage / refuses.** Consolidate without it; surface in the report's *Source of findings* block. Don't retry inline — that doubles cost on a flaky lens.
- **Synthesizer disagrees with all reviewers on severity.** Reviewer severity wins on individual findings; synthesizer wins on cross-axis bucketing only. Don't let the synthesizer downgrade a reviewer's CRITICAL.
- **More reviewers than budget allows.** Cut by lens × target affinity (see `total-review`'s slice/lens matrix); do not run the whole roster at reduced cap.
