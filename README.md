# ClaudesMods

A growing collection of mods for [Claude Code](https://www.anthropic.com/claude-code) — plugins, skills, and slash commands.

This repo is structured as a **multi-plugin marketplace**. Add it once, then install any individual plugin by name.

## Install the marketplace

```bash
claude marketplace add github:z0rd0n88/ClaudesMods
```

## Plugins

| Plugin | What it does |
|---|---|
| [`idea-autopsy`](./idea-autopsy/) | Three-skill idea-review loop: stress-test holes → iterate to v2 → invest/skip verdict. One `/autopsy` command that routes by intent. |
| [`inventory`](./inventory/) | Generate `.CLAUDE.inventory.md` — a per-project audit of every Claude Code automation (hooks, skills, plugins, agents, MCP servers), tagged installed vs custom. SessionStart hook nudges when the inventory goes stale. |
| [`total-review`](./total-review/) | Parallel multi-agent code review pattern. Fans specialised reviewers along clean layer boundaries (`domain → application → adapters`) with built-in dedup against the issue tracker. Eight canonical modes. Ships a scaffold to bootstrap the project wrapper. |
| [`multi-agent-review`](./multi-agent-review/) | One-pass parallel review with synthesizer dedup + cross-axis severity budget. Targets PR / dir / file / spec / diff / slices. Ships a review→fix→re-review loop wrapper for iterating an open PR to clean. |

Install any of them with:

```bash
claude plugin install <name>
```

## Repo layout

```
ClaudesMods/
├── .claude-plugin/
│   └── marketplace.json    # registers every plugin in this repo
├── idea-autopsy/           # one plugin per top-level dir
│   ├── .claude-plugin/plugin.json
│   ├── commands/
│   └── skills/
└── README.md
```

Adding a new plugin is two files:

1. Drop the plugin into a new top-level dir (`./<plugin-name>/`) with its own `.claude-plugin/plugin.json`, `commands/`, `skills/`, etc.
2. Add an entry to `plugins[]` in `.claude-plugin/marketplace.json`.

That's it. No restructuring needed as the collection grows.

## License

[MIT](./LICENSE).
