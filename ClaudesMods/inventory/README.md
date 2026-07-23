# Inventory

A Claude Code plugin that generates **`.CLAUDE.inventory.md`** in your project — a human-readable audit of every automation active for that project, organized by scope and tagged as **installed** (from a plugin or marketplace) or **custom** (you wrote it).

If you've ever stared at a fresh repo and wondered *what's actually loaded right now and where did it come from*, this answers that.

## What it produces

A single Markdown file at the project root, structured by scope:

```
.CLAUDE.inventory.md
├── User scope  (~/.claude/)
│   ├── Hooks
│   ├── Skills        — each tagged [installed:<plugin>] or [custom]
│   ├── Plugins
│   ├── Agents
│   └── MCP servers
├── Project scope (.claude/)
│   └── …same five categories
└── Enterprise scope (if present)
```

Plus a `.CLAUDE.inventory.json` sidecar (machine-readable, same data) and a `.CLAUDE.inventory.hash` used for staleness detection.

## How it stays fresh

A SessionStart hook compares the live config state against the last-generated hash. If anything changed (you installed a plugin, added a skill, edited `settings.json`) or the file is older than 24 hours, the hook injects a nudge into the next session:

> Automation inventory (.CLAUDE.inventory.md) is missing, stale, or configs have changed. Run /inventory to regenerate.

The hook only fires in git repos and exits silently otherwise — it won't spam your `~`.

## Install

```bash
claude marketplace add github:z0rd0n88/ClaudesMods
claude plugin install ClaudesMods
```

## Use

```bash
/inventory
```

That's it. The skill discovers everything, classifies it, and writes the file. Re-run any time the layout changes; the SessionStart hook will tell you when that's needed.

## Why it exists

Claude Code configs sprawl fast. Between user-scope plugins, project-scope skills, enterprise-managed hooks, MCP servers, and the occasional `agents-parked/` shuffle, "what's loaded for this repo right now" stops being obvious. The skill produces a single source of truth you can commit to the repo, share with collaborators, or hand to a new agent that needs to orient.

The **installed vs custom** tag is the load-bearing distinction — installed automations are reproducible from a manifest, custom ones live only in your config and need to be tracked deliberately.

## Layout

```
inventory/
├── .claude-plugin/plugin.json
├── README.md                       # this file
├── commands/
│   └── inventory.md                # /inventory entry point
├── hooks/
│   ├── hooks.json                  # SessionStart staleness check
│   ├── inventory.sh                # bash logic
│   └── inventory.cmd               # polyglot wrapper (Win/Unix)
└── skills/
    └── inventory/SKILL.md          # the actual generation logic
```

The hook script uses `${CLAUDE_PLUGIN_ROOT}` so it resolves correctly regardless of where the plugin is installed.

## License

[MIT](../../LICENSE).
