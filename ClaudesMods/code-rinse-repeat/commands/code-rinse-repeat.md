---
description: "Build a spec end-to-end + loop multi-agent review→fix until clean"
argument-hint: "<spec-path-or-issue-ref> [flags]"
---

Invoke the `code-rinse-repeat` skill and follow it exactly.

Arguments forwarded: `$ARGUMENTS`

The skill is the **single-target end-to-end** layer in the multi-agent stack:

```
build (multi-agent-developer)
  → review (multi-agent-review)
  → fix (coordinator applies)
  → re-review
  → … until APPROVE or max iterations
```

Four phases (plus one optional checkpoint):

0. **Preflight** — target validation, slug derivation, collision detection, `state.json` initialization.
1. **Build** via `multi-agent-developer` — TDD-disciplined multi-agent dev team produces a verified worktree at `.worktrees/feat/<slug>`.
1.5. **Pause-after-build** (optional, `--pause-after-build`) — inspect the worktree before spending review budget; wall-clock is suspended while paused.
2. **Review-loop** via `multi-agent-review` — parallel multi-perspective review; coordinator applies fixes between rounds; bounded by `--max-iterations` (default 3, ceiling 8). Round 1 begins with a spec-conformance pre-pass; round 2+ rotates in domain specialists and fresh-eyes reviewers.
3. **Ship report** with verdict (`APPROVE-ROUND-N` / `MAX-ITERATIONS-AT-N` / `STUCK-AT-N` / `BUILD-FAILED` / `BUDGET-EXHAUSTED-*` / `HALTED-AFTER-BUILD` / `HALTED-AT-MEDIUM-FLOOD-N`), per-round severity table, open follow-ups, and LOW-severity PR comments to paste.

Common flags:
- `--max-iterations N` (default 3) — review loop cap
- `--dev-agents csv` — lock the dev team roster
- `--reviewers csv` / `--reviewers-round-N csv` — lock or per-round-override the review roster
- `--high-and-up-only` — auto-defer MEDIUM/LOW findings
- `--allow-rebuild N` (default 0) — let architectural CRITICALs trigger a full rebuild
- `--no-smoke` — skip the smoke-test gate between rounds
- `--checks csv` / `--smoke-cmd cmd` — override auto-discovered project checks and smoke command
- `--max-wall-minutes N` (default 90) / `--max-cost-usd N` (default 25) — budget caps; halt cleanly on breach
- `--pause-after-build` — halt between build and review for human inspection (auto-skipped in non-interactive runs)
- `--medium-accumulation-threshold N` (default 8) — trip the MEDIUM-flood guard at N cumulative deferrals
- `--exclusion-ttl N` (default 2) — rounds before a deferred finding is re-evaluated against current code
- `--squash-on-approve` — collapse per-finding commits into per-round commits at ship
- `--resume` / `--slug-suffix s` — resume a prior run or fork on a slug collision

State persists at `.code-rinse-repeat/<slug>/state.json` for resumability; the exclusion list lives alongside at `.code-rinse-repeat/<slug>/exclusion-list.json`.

**Required:** the `multi-agent-developer` and `multi-agent-review` plugins must both be installed.
