---
description: "Generate the weekly wrapup report from /insights + /standup, compared against last week"
argument-hint: ""
---

Invoke the `weekly-wrapup` skill from this plugin.

Reminder: `/insights` must have already run earlier in this same prompt/conversation
(it's a native CLI command, not something this command can call) — the skill checks for
its output in context and stops with instructions if it's missing.
