# daily-loop

Session-start workflow routing table. Encodes standard "which skill chain do I run for this kind of session" decisions as a lookup so the harness enforces them instead of the user re-deciding every time.

```
New feature      → superpowers:brainstorming
                 → superpowers:writing-plans
                 → superpowers:test-driven-development
                 → superpowers:verification-before-completion
Returning work   → read memory/MEMORY.md + recent session-data/ first, then resume
3+ tool calls    → planning-with-files (task_plan.md before first edit)
Pre-merge / PR   → multi-agent-review pr <ref> --yes as the quality gate
Stuck / uncertain→ thinking-skills:thinking-model-router
Brainstorm       → idea-panel (products/directions) | superpowers:brainstorming (features)
                 | grill-with-docs (attack an existing plan)
```

**Not user-invocable.** There is no `/daily-loop` slash command; the skill activates via session-start context sensing and shapes the assistant's default chain.

## Why a routing table?

Fewer, non-contradictory routing rules produce better outcomes than a long list of instructions. The skill exists to enforce the critical chain — don't add steps outside this table without a concrete reason.

## Composition

Names the following as canonical downstream targets:
- `multi-agent-review pr <ref> --yes` — this marketplace, plugin `multi-agent-review`
- `idea-panel` — this marketplace, plugin `idea-panel`
- `planning-with-files` — openskills cohort
- `superpowers:brainstorming`, `superpowers:writing-plans`, `superpowers:test-driven-development`, `superpowers:verification-before-completion`
- `thinking-skills:thinking-model-router`

If any target is absent, routing degrades gracefully — the skill is guidance, not a hard dependency.

## Install

```bash
/plugin marketplace add z0rd0n88/ClaudesMods
/plugin install ClaudesMods@claudes-mods
```

## Version

1.0.0 — initial release.
