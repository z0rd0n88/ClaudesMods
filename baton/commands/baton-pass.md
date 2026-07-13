---
description: "Write a session baton-pass note to baton-pass/ (append-only, numbered, feature-scoped)"
argument-hint: "[feature-slug]"
---

Invoke the `baton-pass` skill and follow it exactly.

Arguments forwarded: `$ARGUMENTS`

Writes a session baton-pass note to `baton-pass/<feature-or-epic>/NNN-<slug>.md` in the project root. Append-only, three-digit sequential numbering, feature/epic subdirectories.

Use when:
- Ending a working block whose context the next session needs to inherit
- Crossing a session boundary mid-feature
- Internal: `baton-runner` and `baton-runner-multi-agent` invoke this between work units

The format is opinionated and small — three hard rules:
1. **Append-only.** Never edit prior notes.
2. **Sequential numbering.** `NNN-<slug>.md` (NNN = 3 digits, monotonic per feature).
3. **Feature/epic subdirectories.** `baton-pass/<feature>/NNN-…md`, not flat.

The note captures: what was decided, what's still open, where to look in the code, and the explicit next step. Optimized for an LLM-orchestrator to pick up cold.
