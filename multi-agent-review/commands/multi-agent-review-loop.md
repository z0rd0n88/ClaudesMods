---
description: "Loop multi-agent-review→fix→re-review on an open PR until APPROVE or max iterations"
argument-hint: "<pr-ref> [flags]"
---

Invoke the `multi-agent-review-loop` skill and follow it exactly.

Arguments forwarded: `$ARGUMENTS`

The skill is an **iterative wrapper** around `multi-agent-review` for a single open PR. The orchestrating agent (you) is the coordinator across rounds. Each round:

1. Spawns a **fresh subagent** to run `multi-agent-review` (so the per-round reviewer transcripts never enter the coordinator's context — only the synthesized verdict + findings list returns).
2. Triages the findings — every CRITICAL and HIGH MUST be addressed; MEDIUM is coordinator's judgment; LOW gets a PR comment, no iteration.
3. Applies fixes **inline** (the coordinator does the editing — not delegated, because triage needs whole-project context).
4. Runs unit tests + smoke gate, reverts the fix on regression.
5. Commits with `fix(<scope>): address review round N findings — …`.
6. Re-runs the loop until VERDICT = APPROVE, max iterations hit, or stuck-detection fires.

Examples:

```
multi-agent-review-loop 203
multi-agent-review-loop https://github.com/owner/repo/pull/42
multi-agent-review-loop 203 --max-iterations 5
multi-agent-review-loop 203 --reviewers crypto-security-reviewer,code-reviewer
multi-agent-review-loop 203 --high-and-up-only   # auto-defer MEDIUM/LOW
multi-agent-review-loop 203 --no-smoke           # skip live smoke gate
```

Defaults:
- `--max-iterations 3` (hard ceiling 8)
- Action floor: every CRITICAL + HIGH addressed each round
- Smoke gate runs only if a fix touched smoke-relevant paths
- Inner skill: `multi-agent-review` (must be available at project or user scope)

Do not use for:
- A single one-shot review — use `/multi-agent-review` directly
- Non-PR targets (dirs, files, spec sets) — the loop needs a mutable branch
- A PR you'll merge regardless of findings — the loop only makes sense when fixes will actually be applied
