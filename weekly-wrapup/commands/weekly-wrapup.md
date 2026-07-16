---
description: "Generate the weekly wrapup from the persisted /insights report + cross-project /standup, compared against last week"
argument-hint: ""
---

Invoke the `weekly-wrapup` skill from this plugin.

The skill reads the latest insights report from `~/.claude/usage-data/report.html` (it does
not call `/insights` itself — that's a native CLI command). For the freshest data, run
`/insights` before this. The skill runs fine on a stale or missing report; it just notes the
age and proceeds.
