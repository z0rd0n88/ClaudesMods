---
description: "Start / append to today's per-project brain-dump log"
argument-hint: "[optional: specific points to dump right now]"
---

Invoke the `big-brain-dumper` skill from this plugin.

Resolve today's dump file (env `$BRAINDUMP_DIR` → per-project `.braindump.json` → default `docs/brain-dumps/YYYY-MM-DD-brain-dump.md`), seed it if new, fix a session label, then append a block capturing the session so far.

If `$ARGUMENTS` is non-empty, dump those points specifically as this block. Then hold the standing discipline: keep appending key points, decisions, and action items for the rest of the session. Append-only — never rewrite existing entries.
