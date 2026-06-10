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

Three phases:

1. **Build** via `multi-agent-developer` — TDD-disciplined multi-agent dev team produces a verified worktree at `.worktrees/feat/<slug>`.
2. **Review-loop** via `multi-agent-review` — parallel multi-perspective review; coordinator applies fixes between rounds; bounded by `--max-iterations` (default 3, ceiling 8).
3. **Ship report** with verdict (`APPROVE` / `MAX-ITERATIONS` / `STUCK` / `BUILD-FAILED`), per-round severity table, open follow-ups, and LOW-severity PR comments to paste.

Common flags:
- `--max-iterations N` (default 3) — review loop cap
- `--dev-agents csv` — lock the dev team roster
- `--reviewers csv` — lock the review roster
- `--high-and-up-only` — auto-defer MEDIUM/LOW findings
- `--allow-rebuild N` (default 0) — let architectural CRITICALs trigger a full rebuild
- `--no-smoke` — skip the smoke-test gate between rounds

State persists at `.code-rinse-repeat/<slug>/state.md` for resumability.

**Required:** the `multi-agent-developer` and `multi-agent-review` plugins must both be installed.
