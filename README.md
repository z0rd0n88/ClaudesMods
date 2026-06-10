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
