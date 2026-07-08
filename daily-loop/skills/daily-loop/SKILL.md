---
name: daily-loop
description: Route every work session through the right skill chain: feature → brainstorming+plans+tdd; returning work → recall; 3+ steps → planning-with-files; pre-merge → multi-agent-review-loop.
user-invocable: false
---

# Daily Loop — Workflow Routing Table

This skill encodes the standard workflow routing decisions so they are harness-enforceable rather than advice. Apply this at the start of every session to pick the right chain.

## Session Type → Skill Chain

| Situation | Required skill chain |
|-----------|----------------------|
| New feature or new functionality | `superpowers:brainstorming` → `superpowers:writing-plans` → `superpowers:test-driven-development` → `superpowers:verification-before-completion` |
| Returning to in-progress work | Check `memory/MEMORY.md` + recent session summaries in `~/.claude/session-data/` first, then resume |
| Any task with 3+ tool calls or steps | `planning-with-files` (create task_plan.md before touching code) |
| Pre-merge / pre-PR | `multi-agent-review-loop` as the quality gate before opening a PR |
| Stuck / uncertain which model/approach | `thinking-skills:thinking-model-router` |

## Brainstorm Routing

| Goal | Use |
|------|-----|
| New product, business direction, or research angle | `idea-panel` |
| Scope or design a feature | `superpowers:brainstorming` |
| Attack an existing plan or proposal | `grill-with-docs` |

## Rules

1. **Never skip brainstorming for creative work.** "Let me just start" → use `superpowers:brainstorming` first.
2. **Never skip plans for multi-step work.** 3+ steps → `planning-with-files` before the first edit.
3. **Never merge without a review.** Feature branch → `multi-agent-review-loop` before opening PR.
4. **Returning work → recall first.** Read `memory/MEMORY.md` and the latest entry in `session-data/` before asking what was last done.
5. **Stuck → model-router, not a thinking lens at random.** `thinking-skills:thinking-model-router` selects the right mental model for the problem type.

## Precision Principle

Fewer, non-contradictory instructions produce better routing than more instructions. This skill exists to enforce the critical chain — don't add steps outside this table without a concrete reason.
