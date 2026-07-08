---
name: edit-agents
description: Toggle Claude Code agents on/off by moving them between the active agents directory and a disabled/ subfolder; use for enable/disable/list requests on project- or user-scoped agents.
---

# Edit Agents

Toggle agents on/off by moving their `.md` file between `<root>/` (enabled) and `<root>-parked/` (parked — a **sibling** dir outside `<root>`). Claude Code scans `<root>` **recursively** at session start, so a `<root>/disabled/` subfolder does NOT hide an agent — it still loads into the roster. Parking therefore moves the file *out* of the `agents/` tree (to `<root>-parked/`), removing it from the next session without deleting it. (This differs from skills, which are scanned one level deep, so `skills/disabled/` works for skills but the equivalent does **not** work for agents.)

The mechanics live in `edit-agents.sh` (next to this file). The skill exists so future Claude sessions reach for the script instead of hand-rolling `mv` commands and putting parked agents in a still-scanned subfolder.

## When to use

- User asks to enable/disable a specific agent by name
- User asks to enable/disable a category of agents (security, review, impl, docs, ops, research, meta, product)
- User asks "what agents are available?" or "list my agents"
- User wants to reduce context overhead by parking unused agents

## When NOT to use

- Installing new agents from a repo or marketplace → use `agent-installer`
- Editing the contents of an agent's `.md` file → use `Edit`/`Write`
- Creating a brand-new agent → use `claude-code-setup:claude-automation-recommender`

## Default behavior (no specific request)

If the user invokes the skill without a specific operation (e.g., they say "manage agents", "show my agents", or just trigger it ambiguously), default to listing **both** project and user scopes so they can see everything before deciding:

```bash
bash <plugin-install-root>/skills/edit-agents/edit-agents.sh list
bash <plugin-install-root>/skills/edit-agents/edit-agents.sh --scope user list
```

If the project root and user root resolve to the same directory (no project-specific `.claude/agents/`), show only one block and note that. Then prompt: "What would you like to do? (enable/disable an agent or category)"

## Step 1: Pick the scope

The script auto-detects: project-scoped (`$PWD/.claude/agents`) if that directory exists, else user-scoped (`~/.claude/agents`). Override with `--scope project|user` or `--dir <path>`.

If the user's intent is ambiguous (they say "enable kotlin-specialist" while standing in a project that has agents), default to the project scope and tell them which scope was chosen.

## Step 2: Run the command

```bash
bash <plugin-install-root>/skills/edit-agents/edit-agents.sh <command> [args]
```

Common commands:

| Command | Effect |
|---------|--------|
| `list` | Show enabled and disabled agents in the resolved root |
| `list enabled` / `list disabled` | Filter to one bucket |
| `enable <name>...` | Move from `disabled/` → enabled root |
| `disable <name>...` | Move from enabled root → `disabled/` |
| `enable-category <cat>` | Enable every agent in a category |
| `disable-category <cat>` | Disable every agent in a category |
| `categories` | Print category names with their member agents |
| `--help` | Full usage |

Names are passed without the `.md` suffix.

## Step 3: Commit if in a git repo

If the resolved root is inside a git working tree (e.g., a project's `.claude/agents/` is tracked), the rename is an unstaged change. Tell the user — they may want to commit.

```bash
git status .claude/agents
git add .claude/agents
git commit -m "chore: enable kotlin-specialist + crypto-security-reviewer"
```

The user-scoped `~/.claude/agents/` is also tracked (in `~/Documents/ClaudeConfig`, hardlinked) on this machine, so the same applies there.

## Step 4: Inform about restart

Agent definitions are loaded at session start. **The current session's tool list does not change.** New/disabled agents take effect the next time Claude Code starts. Mention this so the user isn't confused when `subagent_type: kotlin-specialist` still works (or doesn't) in the same session.

## Categories (current)

Defined inline in `edit-agents.sh`. To add a category or move an agent between categories, edit the `CATEGORIES` associative array at the top of the script.

| Category | Members |
|----------|---------|
| `review` | architect-review, code-explorer, commit-guardian, critical-thinking, demonstrate-understanding |
| `security` | crypto-security-reviewer, compliance-auditor, penetration-tester, security-engineer, smart-contract-auditor |
| `impl` | backend-developer, kotlin-specialist, kotlin-mcp-expert, blockchain-developer, smart-contract-specialist, web3-integration-specialist |
| `docs` | api-documenter, technical-writer, diagram-architect, code-tour, specification |
| `ops` | debug, error-detective, database-optimization, unused-code-cleaner |
| `research` | research-orchestrator, competitive-analyst, knowledge-synthesizer |
| `meta` | agent-installer, agent-organizer, agent-overview, context-manager, command-expert, prompt-builder |
| `product` | product-strategist, legal-advisor, simple-app-idea-generator |

**Names match file basenames (without `.md`).** The defaults reflect the agents in `awesome-claude-code-subagents` and what was historically in this user's project. Other installations may name files differently (e.g., `architect-reviewer.md` vs `architect-review.md`). The script fails loudly with `not found in disabled/: <name>` rather than silently no-op'ing, so a category mismatch is visible immediately — edit the script's `CATEGORIES` array to fix.

An agent may legitimately appear in two categories (e.g., `crypto-security-reviewer` ↔ both `review` and `security`). The script tolerates this: enabling a category that names an already-enabled agent is a no-op with a friendly message.

## Common mistakes

| Mistake | Fix |
|---------|-----|
| Running `mv` by hand and forgetting the `disabled/` subfolder | Use the script — the path convention is encoded |
| Telling the user "enabled" without warning about session restart | Always include the restart caveat (Step 4) |
| Renaming inside a tracked repo without committing | Surface `git status` so the user sees the unstaged change |
| Confusing project vs user scope when both exist | Run `list` first, show the resolved root, then act |
| Using full filename like `kotlin-specialist.md` | Pass the bare name; script appends `.md` |
