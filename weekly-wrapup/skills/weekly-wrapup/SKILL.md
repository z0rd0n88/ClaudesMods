---
name: weekly-wrapup
description: User-invoked only. Generates a weekly wrapup combining /insights and /standup output, compares it against last week, and appends a critical GitHub-issues table and next-steps section. Invoke ONLY when the user explicitly runs /weekly-wrapup or a scheduled weekly routine triggers it.
disable-model-invocation: true
---

# Weekly Wrapup

> [!IMPORTANT]
> **User-invoked only.** Run this skill ONLY when the user explicitly runs `/weekly-wrapup`
> or a scheduled routine invokes it. Never auto-trigger from general conversation about
> progress, retros, or reviews.

## Invocation contract

`/insights` is a native CLI command, not a tool — it cannot be called from inside this
skill. It only fires when its literal text is parsed as input *before* this skill loads.
The scheduled weekly routine's prompt MUST lead with the literal line `/insights` ahead of
whatever triggers this skill, so the CLI intercepts it and the report lands in context first.

- If insights output is already present earlier in this conversation (a system-injected
  block covering session count, date range, project areas, friction points, what's
  working, suggestions), that IS the insights data — read it in full before continuing.
- If no insights output is present, STOP and tell the user: "`/insights` did not run
  before this skill — re-trigger with `/insights` as the first line of the prompt." Do
  not fabricate insights content to fill the gap.

## Steps

### 1. Gather this week's data
- Read the `/insights` output already in context, completely — every section.
- Invoke the `standup` skill (`engineering:standup`) scoped to all projects. Read its
  entire report, completely.
- `mkdir -p /home/alex/WeeklyWrapup`.
- Get today's ISO date (`date +%F`) and write
  `/home/alex/WeeklyWrapup/<isodate>-wrapup.md` with a `## Insights` section (full
  insights content) and a `## Standup` section (full standup content).

**Done when:** both raw sections exist in the new file, in full — condense only where a
source section is itself enormous, never drop a section outright.

### 2. Load last week's wrapup
- List `/home/alex/WeeklyWrapup/*-wrapup.md`, excluding the file just created; take the
  most recent by the date in its filename.
- Found → read it completely.
- Not found → skip step 3 (comparison) entirely; go straight to step 4.

**Done when:** the prior wrapup is fully loaded, or its absence is confirmed by an empty
listing.

### 3. Compare weeks (skip if step 2 found nothing)
Critical, professional, unsparing — do not soften findings to spare the user's feelings.
For each axis (velocity, code-quality signals, friction points, tool/skill usage):

- **Positives** — what genuinely improved, with evidence from this week's data.
- **Negatives** — what regressed or stayed stuck, with evidence.
- **Recommendations** — concrete and named: a specific tool, skill, plugin, or article
  that addresses the gap. A recommendation with nothing named is a no-op; cut it.

Append this as `## Week-over-Week Comparison`.

**Done when:** every axis has an entry in each subsection, or an explicit "no signal
either way" note — never a silent omission.

### 4. Potential GitHub issues (always runs, comparison or not)
Append `## Potential GitHub Issues (ClaudeConfig)` with a table:

| Title | Body | Labels | Evidence |
|---|---|---|---|

Every row cites the specific insights/standup finding it's drawn from — no speculative
issues. Stay critical: the goal is surfacing what needs to change, not flattering the
user. This is a proposal list only — do not create the issues.

**Done when:** every recurring friction point or regression surfaced in step 1's data has
a corresponding row, or an explicit note that none warranted one.

### 5. Next steps
Append `## Next Steps` — a prioritized bullet list for the upcoming week, grounded in
steps 3 and 4, not generic advice.

**Done when:** every item traces back to a specific finding above it.

### 6. Save
Write the complete file (all sections from steps 1–5, in order: Insights, Standup,
[Week-over-Week Comparison], Potential GitHub Issues, Next Steps) to the path from step
1. Report the file path to the user.

**Done when:** the file on disk contains every section produced above, in that order.
