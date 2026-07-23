# ClaudesMods

A growing collection of mods for [Claude Code](https://www.anthropic.com/claude-code) — skills and slash commands, all in one plugin.

This repo is a **single-plugin marketplace**: everything lives under the `ClaudesMods` namespace, so every skill is addressed as `ClaudesMods:<skill-name>`.

## Install

```bash
claude marketplace add github:z0rd0n88/ClaudesMods
claude plugin install ClaudesMods
```

## What's inside

| Module | What it does |
|---|---|
| [`idea-autopsy`](./ClaudesMods/idea-autopsy/) | Four-skill idea-review loop: stress-test holes → iterate to v2 → invest/skip verdict → strategize forward. |
| [`inventory`](./ClaudesMods/inventory/) | Generate `.CLAUDE.inventory.md` — a per-project audit of every Claude Code automation (hooks, skills, plugins, agents, MCP servers), tagged installed vs custom. SessionStart hook nudges when the inventory goes stale. |
| [`total-review`](./ClaudesMods/total-review/) | Parallel multi-agent code review pattern. Fans specialised reviewers along clean layer boundaries (`domain → application → adapters`) with built-in dedup against the issue tracker. Eight canonical modes. Ships a scaffold to bootstrap the project wrapper. |
| [`multi-agent-review`](./ClaudesMods/multi-agent-review/) | One-pass parallel review with synthesizer dedup + cross-axis severity budget. Targets PR / dir / file / spec / diff / slices. Ships a review→fix→re-review loop wrapper for iterating an open PR to clean. |
| [`i-cant-even`](./ClaudesMods/i-cant-even/) | Design-decision advisor. Orients on the codebase, grills you one question at a time, runs a 4-persona panel (conservative + balanced + aggressive + critical-thinker) in parallel, then synthesizes a one-screen recommendation memo. |
| [`multi-agent-developer`](./ClaudesMods/multi-agent-developer/) | Manager-led TDD dev team (≤4 Opus agents) that debates a spec across RED → GREEN → REFACTOR rounds, synthesizes via an architect agent, materializes a worktree, and verifies via tests. Ships a one-time setup skill for activating the required framework agents. |
| [`code-rinse-repeat`](./ClaudesMods/code-rinse-repeat/) | End-to-end spec→APPROVE orchestrator. Composes `multi-agent-developer` (build) with `multi-agent-review` (review-fix loop) into one pipeline. |
| [`baton`](./ClaudesMods/baton/) | Long-running multi-phase build orchestrator. `baton-runner` queues specs as implement→review→fix units; `baton-runner-multi-agent` uses multi-agent dev teams per phase; `baton-pass` writes append-only session notes. |
| [`scratchpad`](./ClaudesMods/scratchpad/) | User-invoked `/scratchpad` capture for a long-running experiment & research backlog (a single GitHub checkbox issue). |
| [`idea-panel`](./ClaudesMods/idea-panel/) | Parallel panel of thinking-skills mental-model lenses generates candidate ideas for a topic, then a synthesizer ranks and dedupes them into one shortlist. |
| [`idea-nebula`](./ClaudesMods/idea-nebula/) | Evidence-based brainstorming pipeline: independent entropy-source generators, mandatory boldness revision, blind pairwise-swap ranking, and a barbell (safe + moonshot) shortlist. |
| [`spec-tacular`](./ClaudesMods/spec-tacular/) | User-invoked only. Builds a code-grounded, implementation-ready engineering spec through three gated phases. |
| [`edit-agents`](./ClaudesMods/edit-agents/) | Toggle Claude Code agents on/off by moving `.md` files between `agents/` and a sibling `agents-parked/` dir. |
| [`daily-loop`](./ClaudesMods/daily-loop/) | Auto-triggered workflow routing table — session-type → skill-chain. Not user-invocable. |
| [`weekly-wrapup`](./ClaudesMods/weekly-wrapup/) | User-invoked `/weekly-wrapup`: combines `/insights` and `/standup` into a weekly report. |
| [`llm-fit-check`](./ClaudesMods/llm-fit-check/) | Right-sizes the model + effort to each prompt via a `UserPromptSubmit` hook; `/model-route` gives an on-demand recommendation. |

## Repo layout

```
ClaudesMods/
├── .claude-plugin/
│   └── marketplace.json      # registers the one ClaudesMods plugin
├── ClaudesMods/               # the plugin itself
│   ├── .claude-plugin/
│   │   └── plugin.json        # name: ClaudesMods — the shared skill namespace
│   ├── idea-autopsy/           # one module per top-level dir, nested under the plugin
│   │   ├── commands/
│   │   └── skills/
│   ├── llm-fit-check/
│   │   └── hooks/
│   └── ...
└── README.md
```

`plugin.json`'s `skills`, `commands`, and `hooks` fields list every module's nested directory explicitly, since a plugin only auto-scans its own top-level `skills/`/`commands/` by default.

Adding a new module:

1. Drop it into a new dir under `./ClaudesMods/<module-name>/` with its own `commands/`, `skills/`, etc. (no `.claude-plugin/plugin.json` of its own — there is only one, at the repo's `ClaudesMods/.claude-plugin/plugin.json`).
2. Add its `skills`/`commands`/`hooks` paths to the arrays in `ClaudesMods/.claude-plugin/plugin.json`.

## License

[MIT](./LICENSE).
