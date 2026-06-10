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
| [`i-cant-even`](./i-cant-even/) | Design-decision advisor. Orients on the codebase, grills you one question at a time, runs a 4-persona panel (conservative + balanced + aggressive + critical-thinker) in parallel, then synthesizes a one-screen recommendation memo. The critical-thinker has veto power on framing. |
| [`multi-agent-developer`](./multi-agent-developer/) | Manager-led TDD dev team (≤4 Opus agents) that debates a spec across RED → GREEN → REFACTOR rounds, synthesizes via an architect agent, materializes a worktree, and verifies via tests. Ships a one-time setup skill for activating the required framework agents. |
| [`code-rinse-repeat`](./code-rinse-repeat/) | End-to-end spec→APPROVE orchestrator. Composes `multi-agent-developer` (build) with `multi-agent-review` (review-fix loop) into one pipeline so there's no manual handoff between the dev and review phases. |
| [`baton`](./baton/) | Long-running multi-phase build orchestrator. `baton-runner` queues specs as implement→review→fix units; `baton-runner-multi-agent` uses multi-agent dev teams per phase; `baton-pass` writes append-only session handoff notes. |
| [`scratchpad`](./scratchpad/) | User-invoked `/scratchpad` capture for a long-running experiment & research backlog (a single GitHub checkbox issue). Smart `##`-section placement, dup-detection, check-off support, configurable target via env / per-project / user-scope config. |

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
