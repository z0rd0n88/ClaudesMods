# weekly-wrapup

User-invoked `/weekly-wrapup` — combines `/insights` and `/standup` into a dated weekly
report at `/home/alex/WeeklyWrapup/<isodate>-wrapup.md`, compares it against last week's
if one exists, and appends a critical (not flattering) GitHub-issues table plus a
next-steps section for the upcoming week.

```
/insights
/weekly-wrapup
```

## Why two commands

`/insights` is a native Claude Code CLI command — it isn't a skill or a tool, so this
plugin can't invoke it for you. It only runs when its literal text is parsed as CLI
input. Send it first (as its own line, or the first line of a scheduled routine's
prompt) so its output lands in context before `/weekly-wrapup` runs. If the skill finds
no insights output in context, it stops and tells you to re-run with `/insights` first.

## What it produces

1. **Insights** — the full `/insights` output, verbatim in substance.
2. **Standup** — the full `engineering:standup` report, scoped to all projects.
3. **Week-over-Week Comparison** *(only if a prior wrapup exists)* — positives,
   negatives, and named recommendations (tools/skills/plugins/articles), critical and
   unsparing by design.
4. **Potential GitHub Issues (ClaudeConfig)** — a table of proposed issues, each row
   citing the specific finding it's drawn from. Proposals only; nothing gets filed.
5. **Next Steps** — a prioritized list for the coming week, traceable back to the
   findings above.

## Scheduling

Wire it into a weekly cron routine (`/schedule`) whose prompt is:

```
/insights
/weekly-wrapup
```

so the native command resolves first and the skill's context check passes.

## Install

```bash
/plugin marketplace add z0rd0n88/ClaudesMods
/plugin install weekly-wrapup@claudes-mods
```
