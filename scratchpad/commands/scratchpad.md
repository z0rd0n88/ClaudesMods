---
description: "Add to or tick off items on your scratchpad backlog issue"
argument-hint: "[item text]  |  done: <item text>  |  uncheck: <item text>"
---

Invoke the `scratchpad` skill from this plugin. Pass `$ARGUMENTS` through as the user's intent.

The skill does its own target resolution (env → per-project `.scratchpad.json` → user-scope `~/.config/scratchpad/config.json`). If none is configured it will print the setup instructions and stop — do not try to guess a target.

If `$ARGUMENTS` is empty, treat it as "show me the scratchpad" — fetch and echo the issue body so the user can see what's on it, then await further input.
