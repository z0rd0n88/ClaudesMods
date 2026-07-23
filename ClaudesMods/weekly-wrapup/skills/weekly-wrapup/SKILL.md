---
name: weekly-wrapup
description: User-invoked only. Generates a weekly wrapup from the persisted /insights report plus a cross-project /standup, compares it against last week, and appends a critical GitHub-issues table and next-steps section. Invoke ONLY when the user runs /weekly-wrapup or a scheduled weekly routine triggers it.
disable-model-invocation: true
---

# Weekly Wrapup

> [!IMPORTANT]
> **User-invoked only.** Run this skill ONLY when the user runs `/weekly-wrapup` or a
> scheduled routine invokes it. Never auto-trigger from general talk about progress or retros.

## How insights data reaches this skill

`/insights` is a native CLI command — it cannot be called from inside a skill. It does not
need to be: every run persists a self-contained report to
`/home/alex/.claude/usage-data/report.html` (an always-latest copy). **This skill reads
that file** — it does not depend on `/insights` output being injected into context.

The weekly routine refreshes the file by running `/insights` in a separate headless call
*before* this one (see the plugin README's cron recipe). If the file is stale or absent,
this skill still runs — it just notes the report's age and proceeds with what it has.

## Steps

### 1. Load this week's insights
- Read `/home/alex/.claude/usage-data/report.html`. Extract the rendered narrative — the
  "At a Glance" summary (what's working / what's hindering / quick wins), the "What You
  Work On" project areas, "Where Things Go Wrong", tool/language/session stats, and any
  suggestions. Strip HTML; keep the substance.
- Record the report's date (from its filename/header) and message/session counts.
- File missing → note "no insights report found" and continue to step 2; do not fabricate.

**Done when:** the insights narrative and its date are captured, or its absence is recorded.

### 2. Gather cross-project standup
Invoke the `standup` skill (`engineering:standup`) over **all flagship projects**, pulling
the last 7 days of git activity (commits, PRs opened/reviewed/merged) from each:
`/home/alex/.claude` (ClaudeConfig), `/home/alex/BotHaus`, `/home/alex/VistaMobileBE`, and
`/home/alex/ClaudesMods`. Read the full standup output.

**Done when:** a per-project activity summary exists for every flagship repo, or an explicit
"no activity this week" note for the quiet ones.

### 3. Write the base wrapup file
- `mkdir -p /home/alex/WeeklyWrapup`; get today's ISO date (`date +%F`).
- Write `/home/alex/WeeklyWrapup/<isodate>-wrapup.md` with `## Insights` (full extracted
  narrative + report date) and `## Standup` (full cross-project summary).

**Done when:** both sections exist in the new file, in full.

### 4. Load last week's wrapup
- List `/home/alex/WeeklyWrapup/*-wrapup.md`, excluding the file just created; take the
  most recent by the date in its filename.
- Found → read it completely.
- Not found → skip step 5; go to step 6.

**Done when:** the prior wrapup is fully loaded, or its absence is confirmed.

### 5. Compare weeks (skip if step 4 found nothing)
Critical, professional, unsparing — do not soften findings. For each axis (velocity,
code-quality signals, friction points, tool/skill usage):

- **Positives** — what genuinely improved, cited to this week's data.
- **Negatives** — what regressed or stayed stuck, cited to this week's data.
- **Recommendations** — each names a specific tool, skill, plugin, or article that closes
  the gap. A recommendation naming nothing is a no-op; cut it.

Append as `## Week-over-Week Comparison`.

**Done when:** every axis has an entry in each subsection, or an explicit "no signal" note.

### 6. Potential GitHub issues (always runs)
Append `## Potential GitHub Issues (ClaudeConfig)` with a table:

| Title | Body | Labels | Evidence |
|---|---|---|---|

Every row cites the specific insights/standup finding it's drawn from — no speculative
issues. Stay critical: surface what needs to change, do not flatter the user. Proposals
only — do NOT create the issues.

**Done when:** every recurring friction point or regression in the week's data has a row,
or an explicit note that none warranted one.

### 7. Next steps
Append `## Next Steps` — a prioritized list for the coming week, each item traceable to a
finding in steps 5–6, not generic advice.

**Done when:** every item traces back to a specific finding above it.

### 8. Save & report
Ensure the file holds every section in order: Insights, Standup, [Week-over-Week
Comparison], Potential GitHub Issues, Next Steps. Report the file path to the user.

**Done when:** the on-disk file contains every section produced above, in that order.
