# weekly-wrapup

User-invoked `/weekly-wrapup` — turns the latest `/insights` report plus a cross-project
`/standup` into a dated report at `/home/alex/WeeklyWrapup/<isodate>-wrapup.md`, compares it
against last week's when one exists, and appends a critical (not flattering) GitHub-issues
table plus a next-steps section for the coming week.

```
/insights          # refresh ~/.claude/usage-data/report.html
/weekly-wrapup      # read that report + run standup + write the wrapup
```

## Where insights data comes from

`/insights` is a native Claude Code CLI command — not a skill or tool, so the plugin can't
invoke it. It doesn't need to: every run writes a self-contained report to
`~/.claude/usage-data/report.html`. **The skill reads that file.** Run `/insights` first to
refresh it; the skill still runs on a stale or missing report and notes the age.

## What it produces

1. **Insights** — the narrative extracted from `report.html` (what's working / hindering /
   quick wins, project areas, where things go wrong, tool + session stats), with the report date.
2. **Standup** — `engineering:standup` over all flagship repos (`~/.claude`, `BotHaus`,
   `VistaMobileBE`, `ClaudesMods`), last 7 days of git activity.
3. **Week-over-Week Comparison** *(only if a prior wrapup exists)* — positives, negatives,
   and named recommendations (tools/skills/plugins/articles), critical by design.
4. **Potential GitHub Issues (ClaudeConfig)** — a table of proposed issues, each row citing
   the finding it's drawn from. Proposals only; nothing gets filed.
5. **Next Steps** — a prioritized list for the coming week, traceable to the findings above.

## Weekly automation (WSL cron)

Both steps run headless via `claude -p`, verified to process native slash commands. A weekly
crontab entry (Mondays 08:00), each step its own invocation so both are proven-good:

```cron
0 8 * * 1 cd /home/alex && /usr/bin/env claude -p "/insights" >> /home/alex/WeeklyWrapup/.cron.log 2>&1 && /usr/bin/env claude -p "/weekly-wrapup" >> /home/alex/WeeklyWrapup/.cron.log 2>&1
```

Requires the machine (WSL) to be running at the scheduled time and `gh` auth available to the
Bash environment. Adjust the path to `claude` if it isn't on cron's PATH (`which claude`).

## Install

```bash
/plugin marketplace add z0rd0n88/ClaudesMods
/plugin install weekly-wrapup@claudes-mods
```
