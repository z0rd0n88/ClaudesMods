# daily-loop

Auto-triggered workflow routing skill. Encodes standard "which skill chain do I run for this kind of session" decisions as a lookup table, so the harness enforces them instead of the user re-deciding every time.

**Not user-invocable.** The skill's frontmatter carries `user-invocable: false` — it activates on session start / context sensing and shapes the assistant's default chain, rather than firing on a `/daily-loop` slash command.

## What it routes

| Situation | Chain |
|---|---|
| New feature / new functionality | `superpowers:brainstorming` → `superpowers:writing-plans` → `superpowers:test-driven-development` → `superpowers:verification-before-completion` |
| Returning to in-progress work | Read `memory/MEMORY.md` + recent session summaries first, then resume |
| Any task with 3+ tool calls | `planning-with-files` before the first edit |
| Pre-merge / pre-PR | `multi-agent-review-loop` as the quality gate |
| Stuck / uncertain approach | `thinking-skills:thinking-model-router` |

Plus a brainstorm-routing table (product/business direction → `idea-panel`; feature scoping → `superpowers:brainstorming`; attacking a plan → `grill-with-docs`).

## Design principle

Fewer, non-contradictory routing rules produce better outcomes than a long list of instructions. The skill exists to enforce the critical chain, not to catalogue every possibility.

## Composition

Names the following as canonical downstream targets:
- `multi-agent-review-loop` (this marketplace, plugin `multi-agent-review`)
- `idea-panel` (this marketplace, plugin `idea-panel`)
- `planning-with-files` (openskills)
- `superpowers:brainstorming`, `superpowers:writing-plans`, `superpowers:test-driven-development`, `superpowers:verification-before-completion`
- `thinking-skills:thinking-model-router`

If any of those are absent, the routing degrades gracefully — the skill is guidance, not a hard dependency.
