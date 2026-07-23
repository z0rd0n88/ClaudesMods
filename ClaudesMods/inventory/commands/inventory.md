---
description: "Generate or refresh .CLAUDE.inventory.md for this project"
---

Invoke the `inventory` skill and follow it exactly. The skill will:

1. Discover every Claude Code automation active for this project (hooks, skills, plugins, agents, MCP servers) at user, project, and enterprise scope.
2. Tag each item as **installed** (from a plugin/marketplace) or **custom** (user-authored).
3. Write the report to `.CLAUDE.inventory.md` in the project root, with a `.CLAUDE.inventory.json` sidecar and a `.CLAUDE.inventory.hash` for staleness detection.

After it finishes, the SessionStart hook will stop nagging until configs change or 24h pass.
