---
description: "Run a queue of specs as implement→review→fix work units with baton-pass notes"
argument-hint: "<queue-path-or-ref> [flags]"
---

Invoke the `baton-runner` skill and follow it exactly.

Arguments forwarded: `$ARGUMENTS`

The skill drives an **ordered queue of specs/PRDs/issues** through `implement → review → fix` work units in a single worktree. Each unit is a sequential subagent dispatch; baton-pass notes get written between units so the next session (or the next unit) inherits context.

Lean manager pattern: the orchestrator stays out of per-unit context — each implement / review / fix subagent runs in isolation. The manager only sees the unit boundaries + gate checks + the queue cursor.

Use when:
- You have 3+ related specs you want built sequentially in one worktree
- You want disk-resumable state across sessions
- You need per-unit gates (compile + test + lint) before moving on

Companion skills in this plugin:
- `/baton-runner-multi-agent` — same loop, but each implement step delegates to `multi-agent-developer` (≤4 Opus specialists debating per phase) instead of a single subagent.
- `/baton-pass` — write standalone session baton-pass notes (used internally by both runners, also user-invokable).
