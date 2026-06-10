# Exclusion-list discipline

Shared primitive for any review skill that runs against a codebase with an existing issue tracker. Prevents reviewers from re-flagging findings already captured in open issues. Cited by `total-review`, `multi-agent-review`.

The single highest-leverage technique against duplicate-finding noise in recurring multi-agent review. Validated in practice: across a multi-pass review run on a real Python application, follow-up passes adding `python-pro`, `security-reviewer`, and `silent-failure-hunter` lenses re-flagged nothing already tracked from the prior pass — proof the discipline holds when reviewer rosters rotate.

## The pattern

Before fan-out, fetch open-issue findings from the project tracker and inject them verbatim into every reviewer prompt under a `## DO NOT report findings already tracked in:` heading. Reviewers drop silently anything they would have raised that matches.

## Query construction

The exclusion query is project-specific (defined in `config.yml` or `--prompt-prelude`). Typical shape for GitHub:

```bash
set -eo pipefail
for label in review tech-debt security performance architecture; do
  gh issue list --repo <owner>/<repo> --state open --limit 30 \
    --label "$label" --json number,title,body
done | jq -s 'add | unique_by(.number)'
```

## Critical gotchas

### `gh issue list --label a,b,c` is AND, not OR

A single comma-separated `--label` argument requires issues to carry *all three* labels. To union labels (the usual case for exclusion queries), iterate per-label and merge with `jq -s 'add | unique_by(.number)'`. A single comma-separated invocation silently under-reports and lets already-tracked findings re-surface.

### `set -eo pipefail` is mandatory

Without it, a single per-label `gh` call failing (auth blip, rate limit, transient 5xx) silently drops that label's issues from the merge. The exclusion list under-reports with no warning.

### Cap at ~30 issues per label

Reviewer prompts get flooded if the exclusion list is too large. If the merged query returns >30, the caller's labels are too broad — re-prompt with tighter scope rather than truncating silently.

### Empty result handling

Emit a one-line notice on stdout (`echo "exclusion query returned 0 issues — no prior findings will be skipped"`) so the operator sees the empty result rather than assuming exclusion ran silently. Then proceed with an empty skip list — don't error.

### Stale exclusion list

Re-fetch on every invocation; cache only within one run. A review pass started 20 minutes after issue #82 was filed should already exclude #82's findings — never rely on a cached query result across invocations.

## Injection into reviewer prompts

Parse the merged JSON into a flat skip list of `<short title> — <file:line>` entries (titles truncated to ~80 chars; bodies dropped — too noisy for reviewer context). Inject under a fixed heading:

```markdown
## DO NOT report findings already tracked in:
- C1 — composite-key violation in lock_manager — `application/lock_manager.py:42`
- H3 — Decimal cast leaks through ORM — `adapters/persistence/models.py:118`
...
```

This heading is part of the contract — reviewer briefs MUST match this exact text so the dedupe rule in [`fanout-consolidation.md`](fanout-consolidation.md) (rule 5: "drop excluded findings silently") fires consistently across lenses.

## Cross-skill use

For non-recurring reviews (`multi-agent-review`), the exclusion list is project-defined and passed via `--prompt-prelude <path>`. For recurring sweeps (`total-review`), the list is fetched fresh from `config.tracker.exclusion_query` each run. Both forms feed the same heading; the dedupe contract doesn't care which source produced the list.
