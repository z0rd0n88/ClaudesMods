# edit-agents

Toggle Claude Code agents on/off by moving `.md` files between the active `agents/` dir and a sibling `agents-parked/` — because `agents/` is scanned **recursively**, so an `agents/disabled/` subfolder does *not* hide anything; parked agents must live outside the tree.

## Why

Every agent under `<root>/agents/` (recursively) loads into the session roster at start and eats context budget whether you use it or not. If you have a large user-scope roster, you want most of them parked most of the time — and re-enabled per-project when actually useful.

The naive fix — `mv agents/foo.md agents/disabled/foo.md` — doesn't work: `disabled/` is still under `<root>` and still gets scanned. Parking has to happen in a **sibling** dir (`<root>-parked/`) outside the scanned tree.

This plugin encodes that convention as a one-shot script + a SKILL.md that tells future sessions to use it instead of hand-rolling `mv` commands.

## What ships

- `skills/edit-agents/SKILL.md` — routing for the assistant
- `skills/edit-agents/edit-agents.sh` — the actual toggle script
- `skills/edit-agents/examples/categories` — sample categories config

## Commands

```
edit-agents list [enabled|parked|all]      # show state
edit-agents enable <name>...               # move parked → enabled
edit-agents disable <name>...              # move enabled → parked
edit-agents enable-category <cat>          # bulk enable (needs config)
edit-agents disable-category <cat>         # bulk disable (needs config)
edit-agents categories                     # list configured categories
edit-agents --scope project|user list      # override auto-detect
edit-agents --dir <path> list              # arbitrary root
```

Auto-detects scope: `$PWD/.claude/agents` if present, else `~/.claude/agents`.

## Categories (optional)

Category commands are gated behind a user-supplied config so nothing ships hardcoded to one person's roster.

Create `$XDG_CONFIG_HOME/edit-agents/categories` (or `~/.config/edit-agents/categories`), or point `$CLAUDE_EDIT_AGENTS_CATEGORIES` at a file elsewhere:

```
review:   architect-review code-explorer commit-guardian
security: crypto-security-reviewer penetration-tester
impl:     backend-developer kotlin-specialist
```

Blank lines and `#` comments are ignored. Names are agent file basenames without `.md`. See `skills/edit-agents/examples/categories` for a starter file.

## Restart caveat

Agent definitions are loaded at session start. **The current session's tool list does not change.** Toggles take effect the next time Claude Code starts.

## Install

```bash
/plugin marketplace add z0rd0n88/ClaudesMods
/plugin install ClaudesMods@claudes-mods
```
