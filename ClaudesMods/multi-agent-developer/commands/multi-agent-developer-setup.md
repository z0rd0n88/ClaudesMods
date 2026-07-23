---
description: "Bootstrap multi-agent-developer in this repo (activates required framework agents)"
---

Invoke the `multi-agent-developer-setup` skill and follow it exactly.

One-time per-project bootstrap. Activates the framework agents `multi-agent-developer` requires (`ecc-code-explorer`, `ecc-code-architect`) into `<repo>/.claude/agents/` from your user-scope `~/.claude/agents-parked/` library.

Idempotent — safe to re-run. Per-agent decision:
- Already active in project → skip
- Source available in user-scope parked tier → activate (move)
- Both missing → hard-fail with the missing-agent name

After this completes, `/multi-agent-developer` will pass its Phase 1 bootstrap check.
