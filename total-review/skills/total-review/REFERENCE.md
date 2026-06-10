# total-review — Reference

Shared workflow library. Wrappers at `<repo>/.claude/skills/<slug>-total-review/SKILL.md` follow this file step-by-step using their sibling `config.yml`.

## Shared primitives

This skill is one of three (alongside `xan-multi-agent-review` and `xan-multi-agent-developer`) that share these primitives — read the refs once and apply them wherever they appear below:

- [`~/.claude/refs/multi-agent/fanout-consolidation.md`](../../refs/multi-agent/fanout-consolidation.md) — parallel `Agent` fan-out contract, dedupe, and the cross-axis severity budget. The *Consolidation rules* section below is a project-specific layer on top of this ref.
- [`~/.claude/refs/multi-agent/exclusion-list.md`](../../refs/multi-agent/exclusion-list.md) — tracker-issue exclusion-list discipline (the single highest-leverage technique against duplicate-finding noise in recurring sweeps). Step 2 below is the project-tracker binding of that ref.
- [`~/.claude/refs/multi-agent/agent-catalog-lookup.md`](../../refs/multi-agent/agent-catalog-lookup.md) — how the *Default agent matrix* names below resolve to files in `<repo>/.claude/agents/` and `~/.claude/agents-parked/`.
- [`~/.claude/refs/multi-agent/spec-injection.md`](../../refs/multi-agent/spec-injection.md) — for `pre-pr` mode only, the originating spec/issue MAY be injected via an optional `--spec <path>` argument so reviewers also check "does this satisfy the originating intent?" rather than only "is this well-written?".

## Workflow (every mode that files an issue)

1. **Confirm scope.** Read `<repo>/ARCH.md` first. Verify the slices declared in `config.yml` still match the tree; if a slice path no longer exists, warn and skip that slice (do not error). Read `<repo>/.claude/skills/<slug>-total-review/config.yml`.
1a. **Resolve diff scope (optional).** If the invocation passes `--against <base-ref>` (e.g. `--against origin/main`), classify the diff via `git diff --name-only <base>...HEAD` and `git diff --shortstat <base>...HEAD`, then apply the *Trivial-diff pre-filter* and *Diff-aware slice filter* sections below. Without `--against`, this is a full sweep — skip this step (the recurring audit case; e.g. weekly `code`/`architecture` runs against the whole tree). The `--all-slices` flag forces a full sweep even when `--against` is set (escape hatch for "I changed one file but want to re-audit the whole layer").
2. **Resolve exclusions.** Run `config.tracker.exclusion_query` via Bash. Parse the result into a flat skip list of `<short title> — <file:line>` entries. **Inject this verbatim** into every reviewer prompt below a `DO NOT report findings already tracked in:` heading. If the query returns nothing, emit a one-line notice on stdout (`echo "exclusion query returned 0 issues — no prior findings will be skipped"`) so the operator sees the empty result, then proceed with an empty skip list. **`gh issue list --label a,b,c` is AND semantics across the comma list, not OR** — to union multiple labels, iterate per-label and merge with `jq -s 'add | unique_by(.number)'`. See *Failure modes & guards* for the canonical snippet.
3. **Map** (modes that need it). For `code`, `architecture`, `perf`: fan out `code-explorer` agents one per slice. Skip mapping for `cleanup`, `security`, `test`, `docs`, `pre-pr`.
4. **Review fan-out.** Compute the effective `(slice, agent)` pairs for the requested mode (see *Effective fan-out rule*). Launch all agents **in one message with multiple `Agent` tool calls** so they run concurrently. Cap each agent at its mode word budget. Apply the exclusion list verbatim in every prompt. Pass the project invariants from `config.project.invariants` into every prompt.
5. **Consolidate.** Dedupe by `(file, line, root cause)`; merge bodies when two lenses raise the same call site. Bucket by severity (CRITICAL/HIGH/MEDIUM/LOW). Group HIGH items by theme for the PR-slicing block. See *Consolidation rules*.
6. **File the issue** unless `mode.files_issue` is false. Compose the title from `config.tracker.title_template` substituting `{mode}`, `{crit}`, `{high}`, `{med}`, `{low}`. **Sanitise `{mode}` against an allowlist `^[a-z0-9_-]+$` before substitution** — reject any other value with a hard-fail before invoking `gh`, so a malicious or typo'd mode name can't inject shell metacharacters into the tracker command. The numeric counts are integers from consolidation and don't need sanitisation. **`{title}` (the rendered result) MUST NOT be f-string-interpolated into the `gh` command line** — it is composed from `title_template` and substituted into a double-quoted shell argument (`--title "{title}"`), so embedded `"`/`$`/backticks would break out of the quoted region. Pass it via an environment variable instead:

   ```bash
   TITLE="<rendered title>" gh issue create ... --title "$TITLE" --body-file - ...
   ```

   Or use `gh`'s `--title-file -` if the installed version supports it. Compose the body from the *Issue body template* below. Run `config.tracker.file_issue` via Bash with the body piped on stdin.
7. **Report.** Print the issue URL, severity counts, verdict, and any cross-references to existing issues that overlap.

For `pre-pr` and `docs`: skip step 6; emit findings inline in chat. For `docs` only, if drift is small, propose a minimal patch instead of filing.

## Effective fan-out rule

For each requested mode, the set of agent invocations is:

```
{(s, a) | s ∈ enabled_slices, a ∈ mode.agents ∩ s.lenses}
```

- `mode.agents` = canonical defaults from the matrix below, then `config.modes.<mode>` overrides applied in this order:
  1. **Replace** — if `config.modes.<mode>.agents:` is set, it fully replaces the canonical baseline + stack overlay for that mode.
  2. **Additive** — otherwise, start from the canonical baseline + stack overlay, apply `config.modes.<mode>.agents_remove:` (subtract listed names), then apply `config.modes.<mode>.agents_add:` (union, dedup).
  Wrappers should prefer `agents_add` / `agents_remove` over the replace-style `agents:` key — additive overrides let canonical defaults evolve without copy-pasting the baseline into every wrapper.
  **Mutually exclusive** — if a mode block sets BOTH `agents:` (replace) AND `agents_add:` / `agents_remove:` (additive), this is a config error: hard-fail at config-load with `mode <name>: agents (replace) and agents_add/agents_remove (additive) are mutually exclusive; pick one form`. Never silently coerce one form into the other.
- `s.lenses` = each slice's declared `lenses` list in `config.yml`. Acts as a per-slice allowlist — if `python-pro` is in `mode.agents` but not in `slices.tests.lenses`, no `python-pro` agent runs on `tests/`. This is the lens→slice affinity, the lever for cutting low-value cells.
- A slice missing `lenses` entirely defaults to allowing every agent (no filtering).
- If `(slice, agent)` pair count exceeds 16 for one mode, **batch the fan-out** in two messages — Discord/runtime parallelism limits.

## Diff-aware slice filter

Only active when `--against <base-ref>` is set (and `--all-slices` is NOT). Applied AFTER `enabled_slices` is built from `config.yml` and BEFORE the *Effective fan-out rule* expands `(slice, agent)` pairs.

```
diff_paths   = `git diff --name-only <base>...HEAD`
touched(s)   = any(p starts with s.path for p in diff_paths)
enabled_slices := { s ∈ enabled_slices | touched(s) }
```

Modes where the filter applies: `code`, `architecture`, `perf`, `test`, `cleanup`. Modes where the filter does NOT apply: `security`, `docs`, `pre-pr`. Rationale:

- `security` is intentionally **not** filtered. A diff that touches `application/trading.py` can still introduce an auth-bypass elsewhere via a transitive call into `adapters/` — security review needs a wider lens than what the diff literally touches. If you want diff-scoped security, use `pre-pr` mode (already diff-only by design).
- `docs` is not filtered because its lens is `documentation-expert` checking drift across `ARCH.md`/`ADR`/`baton-pass` — the very paths the diff usually does NOT touch.
- `pre-pr` is already diff-only (it has no slice fan-out concept).

**Empty result handling.** If post-filter `enabled_slices` is empty, hard-fail with:

```
no slices touched by diff <base>...HEAD for mode '<mode>'
options:
  - rerun with --all-slices to force a full sweep
  - rerun without --against for a full audit
  - use mode 'pre-pr' for a diff-only sanity check
```

Never silently downgrade to a no-op review.

**Cost benchmark.** For a typical PR touching 1–2 slices in a 6-slice repo, the filter cuts review-fan-out wall-clock by ~60–70% (the `(slice, agent)` matrix shrinks proportionally to enabled-slice count). For a sweeping refactor that touches every slice, the filter is a no-op and adds no cost beyond one `git diff --name-only`.

## Trivial-diff pre-filter

Only active when `--against <base-ref>` is set. Applied BEFORE the diff-aware slice filter, BEFORE step 2 exclusion resolution — fails fast on changes too small to warrant a heavy mode.

Classify the diff via `git diff --shortstat` (line count) and `git diff --name-only` (path categories):

| Class | Criteria | Behavior |
|---|---|---|
| `pure_docs` | All changed paths match `*.md`, `docs/**`, `README*`, `CHANGELOG*`, `LICENSE*` | If mode ∈ {`security`, `perf`, `architecture`, `code`, `cleanup`, `test`}: warn and refuse (`"this diff is docs-only; use mode 'docs' or 'pre-pr'"`). Allow `docs` and `pre-pr` to proceed unchanged. |
| `pure_config` | All changed paths match `*.{yml,yaml,toml,json,ini,cfg}` AND none are inside `src/`/`tests/` | If mode ∈ {`security`, `perf`, `architecture`}: warn and refuse. Allow `code`, `cleanup`, `pre-pr` to proceed. |
| `trivial` | `git diff --shortstat <base>...HEAD` reports < 20 lines changed AND ≤ 2 files changed | If mode ∈ {`code`, `cleanup`, `security`, `architecture`, `perf`, `test`}: warn and recommend `pre-pr` (`"this diff is trivial (<20 lines, ≤2 files); use mode 'pre-pr' instead"`). Hard-refuse for `all` (would spawn ~30 agents to review a 5-line change). |
| `normal` | Otherwise | No effect. |

**Override.** The user can force-proceed past any refusal with `--force-trivial`. The refusal is opinionated default behavior, not a hard correctness gate; agentic budget waste, not data corruption.

**Why refuse rather than auto-downgrade.** Auto-downgrading "user asked for security mode but it's docs-only" silently changes the user's intent. Refuse and tell them what to invoke instead — they may well have meant the heavy mode (e.g. a `*.yml` change that flips an auth flag *should* run `security`). The classifier can't read intent; the user can.

**Why `--force-trivial` is per-invocation, not in `config.yml`.** A repo-wide opt-out would defeat the purpose. Trivial-classification is a per-PR signal, not a project policy.

## Canonical modes

For each: purpose, default `files_issue`, default word budget per agent, whether mapping is needed.

| Mode | Purpose | `files_issue` | Word cap | Maps first? |
|---|---|---|---|---|
| `code` | Correctness + atomicity + idiom + typing | true | 1200 | yes (`code-explorer` × slices) |
| `cleanup` | Dead code, duplication, unused helpers | true | 900 | no |
| `security` | Input/output, money flow, auth, OWASP + economic exploits | true | 1300 | no |
| `architecture` | Hexagonal boundary checks, deepening, silent-failure ladder | true | 1100 | yes |
| `test` | Coverage gaps, fake parity, mock-spec adequacy | true | 1000 | no |
| `perf` | N+1, DB contention, hot-path Decimal/allocations | true | 1000 | yes |
| `docs` | `ARCH.md` / ADR / baton-pass drift | false | 800 | no |
| `pre-pr` | Diff-only sanity (`git diff <base>...HEAD`) | false | 700 | no |

## Invocation flags

Flags are passed through from the wrapper's slash command (e.g. `/<slug>-total-review code --against origin/main`).

| Flag | Default | Effect |
|---|---|---|
| `--against <base-ref>` | unset | Enables the *Trivial-diff pre-filter* and *Diff-aware slice filter* (step 1a). Without this flag, the run is a full audit and the filters are no-ops. Typical value: `origin/main` or the PR's base branch. Validated at parse time — must resolve via `git rev-parse <ref>`; otherwise hard-fail before reviewer fan-out. |
| `--all-slices` | false | When `--against` is set, force the run over the full `enabled_slices` set, bypassing the diff-aware slice filter. The trivial-diff pre-filter still applies. Use case: "the diff touches one file but I want to re-audit the whole layer that file lives in." |
| `--force-trivial` | false | Bypass the *Trivial-diff pre-filter*'s refusal step. Validates intent: when set without `--against`, hard-fail (the flag is meaningless without the classifier active). |
| `--high-cap <n\|off>` | `8` | Override the cross-axis severity budget for HIGH findings (see [`fanout-consolidation.md`](../../refs/multi-agent/fanout-consolidation.md) and *Consolidation rules* §3). Set `off` when a downstream pipeline gates on HIGH count and demotion would false-CLEAN. Per-mode override available via `config.consolidation.high_cap:` in `config.yml`. |
| `--spec <path>` | unset | Only valid in `pre-pr` mode. Inject the originating spec/issue body verbatim into reviewer prompts under the canonical `## ORIGINATING SPEC` heading per [`spec-injection.md`](../../refs/multi-agent/spec-injection.md). For non-`pre-pr` modes (full audits), the originating spec concept is ill-defined — the flag is ignored with a warning. |

## Default agent matrix

Stack-aware, additive overlays on a generic baseline. Generic agents are *always* included; stack overlay agents are *appended*. Stack is detected by the scaffold at bootstrap time and pinned in `config.project.stack` (one of `python`, `kotlin`, `typescript`, `multi`).

| Mode | Generic baseline | Python overlay | Kotlin overlay | TypeScript overlay |
|---|---|---|---|---|
| `code` | `code-reviewer` | `+ python-reviewer, python-pro` | `+ kotlin-reviewer` | `+ typescript-reviewer` ⚠ |
| `cleanup` | `refactor-cleaner, unused-code-cleaner` | — | — | — |
| `security` | `security-reviewer` | — | — | — |
| `architecture` | `code-architect, critical-thinking, silent-failure-hunter` | — | — | — |
| `test` | `tdd-guide` | `+ python-reviewer` | `+ kotlin-reviewer` | — |
| `perf` | `performance-optimizer` | `+ sql-pro` if any `*.sql` present, `+ python-pro` | — | — |
| `docs` | `documentation-expert` | — | — | — |
| `pre-pr` | `code-reviewer, security-reviewer, silent-failure-hunter` | `+ python-reviewer` | `+ kotlin-reviewer` | `+ typescript-reviewer` ⚠ |

⚠ = `typescript-reviewer` not yet parked at user scope as of 2026-06-07. TS projects must provide their own or fall back to the generic `code-reviewer` only.

These names are the agents' internal `name:` field (what the `Agent` tool dispatches on). The scaffold maps each name to the filename in `~/.claude/agents-parked/` at activation time — most files are prefixed `ecc-` (e.g. `ecc-code-reviewer.md` carries `name: code-reviewer`). `code-architect` resolves to `ecc-code-architect.md` and `code-explorer` resolves to `ecc-code-explorer.md` — both parked at user scope as of 2026-06-07.

## Config schema

```yaml
project:
  slug: <slug>                     # short repo handle; matches wrapper skill name <slug>-total-review
  stack: python                    # python | kotlin | typescript | multi
  invariants:                       # injected verbatim into every reviewer prompt
    - "money = Decimal quantised $0.01 ROUND_HALF_EVEN"
    - "datetimes = tz-aware UTC"

slices:                            # the layer map; reviewer scopes
  domain:
    path: src/<pkg>/domain
    lenses: [code-reviewer, python-reviewer, python-pro]
  application:
    path: src/<pkg>/application
    lenses: [code-reviewer, python-reviewer, python-pro, silent-failure-hunter]
  persistence:
    path: src/<pkg>/adapters/persistence
    lenses: [code-reviewer, python-reviewer, sql-pro]
  # ...
  tests:
    path: tests
    lenses: [code-reviewer]        # narrow lens set; skip idiom reviewers on tests

modes:                             # optional; only override canonical defaults when needed
  # Replace-style (rare — discards baseline + stack overlay):
  # security:
  #   agents: [security-reviewer, my-domain-auditor]
  #
  # Additive (preferred — extends canonical defaults):
  # code:
  #   agents_add: [my-domain-auditor]
  # architecture:
  #   agents_remove: [code-architect]      # opt out of a default lens
  #   agents_add: [my-boundary-checker]
  #
  # disabled: [perf]
  # add:
  #   compliance:
  #     agents: [my-compliance-reviewer]
  #     slices: [application, persistence]
  #     files_issue: true
  #     word_cap: 1200

tracker:
  exclusion_query: |
    gh issue list --repo <owner>/<repo> --state open --limit 30 \
      --label review,tech-debt,security,performance,architecture \
      --json number,title,body
  file_issue: |
    gh issue create --repo <owner>/<repo> --title "{title}" --body-file - \
      --label review
  title_template: "{mode} review: {crit} CRITICAL · {high} HIGH · {med} MEDIUM · {low} LOW"
  cross_ref_phrase: "Refs #<meta-tracker-issue>"
```

## Consolidation rules

1. **Dedupe by `(file, line, root cause)`.** If two lenses raise the same call site, merge bodies and note both perspectives. Never list twice.
2. **Severity bucketing.** Reviewers' severity stands unless a lens disagrees — pick the higher.
3. **Cross-axis severity budget (HIGH cap).** After dedupe + tiebreak, apply the budget from [`fanout-consolidation.md`](../../refs/multi-agent/fanout-consolidation.md): `high_cap = min(declared_cap, ceil(N_lenses * 1.5))` where `declared_cap = 8` by default and `N_lenses` is the count of distinct reviewer agents that actually returned for this mode. If post-dedupe HIGH count exceeds `high_cap`: rank the HIGH findings by impact-score (CRITICAL-adjacent failure mode > correctness > maintainability > style; ties broken by number of distinct lenses that raised it), keep the top `high_cap` as HIGH, **demote the rest to MEDIUM** with a one-line note in each demoted entry: `_(demoted from HIGH by severity budget; <reason>)_`. CRITICAL is never demoted; LOW is never promoted. The intent is to prevent N lenses each producing "one HIGH" → N blockers — a real-bug-budget that forces the synthesizer to rank impact rather than concatenate. Wrappers may override `declared_cap` via `config.consolidation.high_cap:` in `config.yml` (rare — only if a project routinely produces >8 genuinely-critical HIGHs per pass).
4. **Group HIGH items into themes** for the PR-slicing block. Typical themes: *money math*, *atomicity*, *tasks*, *persistence*, *Discord/HTTP boundary*, *taxonomy/duplication*, *tests/typing*. Themes drive the suggested PR breakdown.
5. **Tag with slice slug** as a prefix *only* if the finding spans multiple slices; otherwise the file path is enough.
6. **Drop silently** any finding already in the exclusion list — never re-report.
7. **Verdict** — BLOCK if any CRITICAL; WARN if no CRITICAL but ≥1 (post-budget) HIGH; INFO otherwise. Demoted-to-MEDIUM items do NOT push the verdict to WARN — that's the point of the budget. One-line rationale at the top; if any HIGH demotions happened, name the count (`12 HIGH → top 6 kept, 6 demoted to MEDIUM by budget`).
8. **`cross_ref_phrase` rendering** — if `config.tracker.cross_ref_phrase` is `""` or YAML `null` (unset), drop the trailing template line containing the placeholder entirely (do not render a blank line in its place). Only emit the line when a non-empty phrase is configured.

## Issue body template

```markdown
# <Mode> review (<YYYY-MM-DD>)

A parallel sweep using <agents/skills> over <slices>. Findings consolidated below with checkboxes for tracking. Cross-references to in-flight issues are noted; **do not double-tick**.

**Severity counts:** CRITICAL <n> · HIGH <n> · MEDIUM <n> · LOW <n>
**Verdict:** BLOCK | WARN | INFO — <one-line rationale>

---

## CRITICAL (block)
- [ ] **C1 — <one-line title>.** <evidence>. **Fix:** <action>. — `path/to/file.py:LL-LL`

## HIGH (warn)

### <Theme A>
- [ ] **H1 — ...** — `path:LL`

### <Theme B>
- [ ] **H2 — ...** — `path:LL`

## MEDIUM (info)
- [ ] **M1 — ...** — `path:LL`

## LOW (note)
- [ ] **L1 — ...** — `path:LL`

---

## Suggested PR slicing

Branches grouped by shared file/intent so each fits one reviewable PR:

1. **`<branch-name>`** — Cn, Hn, Hn (one-line scope)
2. **`<branch-name>`** — ...

## Source of findings

- Mapped by `<agent>` × N (<slice>, <slice>, ...).
- Reviewed by `<agent>` × N (<lens>) and `<agent>` × N (<lens>).
- Excluded findings already tracked in: <list of issue numbers from exclusion query>.
- Verdict rationale: <one paragraph>.

<cross_ref_phrase>
```

## Failure modes & guards

- **Word-budget overrun** — agent returns too long. Re-prompt with a stricter cap or split the slice. Hard cap at 1500 words.
- **Stale exclusion list** — re-fetch on every invocation; cache only within one run.
- **Empty directory slice** — slice declares only `path:` and the directory has no matching files. Skip silently; do not spawn an agent.
- **Enumerated-paths slice with missing files** — slice declares `paths:` (explicit list) and one or more listed files are missing on disk. **Warn loudly**, list the missing files in the warning, and proceed with the present ones; do not skip the slice. A `paths:` entry going missing is almost always a refactor that the wrapper hasn't caught up to, and silently skipping would hide degraded coverage.
- **Agent not in `<repo>/.claude/agents/`** — the wrapper relies on each `mode.agents ∩ slice.lenses` member being activated in the project. If a name is missing, warn loudly and ask the user to run `total-review-scaffold --activate-missing` (or copy from `~/.claude/agents-parked/` manually) before retrying. Do not silently skip — a missing lens degrades coverage.
- **GH auth** — requires `gh auth status` clean. `GH_TOKEN` is sourced from `~/.secrets` per CLAUDE.md.
- **`gh issue list --label` is AND, not OR** — passing `--label a,b,c` returns only issues carrying *all three* labels. To union labels (the usual case for exclusion queries), iterate per-label and merge. Prepend `set -eo pipefail` so a single per-label `gh` failure surfaces loudly rather than being silently absorbed by `jq -s 'add'`:
  ```bash
  set -eo pipefail
  for label in review tech-debt security performance architecture; do
    gh issue list --repo <owner>/<repo> --state open --limit 30 \
      --label "$label" --json number,title,body
  done | jq -s 'add | unique_by(.number)'
  ```
  Wrappers' `tracker.exclusion_query` should follow this pattern. A single comma-separated `--label` invocation will silently under-report and let already-tracked findings re-surface. Without `pipefail`, the for-loop under-reports the exclusion list with no warning whenever one label's `gh` call fails (auth blip, rate-limit, transient 5xx).
- **Tracker query returns >30 issues** — caller's query was too broad. Re-prompt with tighter label set; reviewers will be flooded with skip rules and the exclusion list becomes noise.
- **Empty exclusion result** — emit a one-line notice on stdout (step 2) so the operator sees the empty result rather than assuming exclusion ran silently.
- **`{mode}` substitution sanitisation** — reject any mode name not matching `^[a-z0-9_-]+$` with a hard-fail before invoking `gh`. Prevents shell-metacharacter injection through a malformed mode argument.
- **`{title}` substitution sanitisation** — the rendered title (composed from `title_template`) MUST be passed via an environment variable rather than f-string interpolated into the `gh` command line. Canonical pattern: `TITLE="<rendered>" gh issue create ... --title "$TITLE" --body-file - ...`. F-string interpolating directly into `--title "{title}"` lets an embedded `"`/`$`/backtick escape the quoted region; env-var passing keeps the value out of the shell's argv-parsing pass entirely. `--title-file -` is an acceptable alternative on `gh` versions that support it.
- **Override precedence: `agents:` (replace) vs `agents_add:` / `agents_remove:` (additive) — mutually exclusive.** If a mode block sets both forms, hard-fail at config-load with `mode <name>: agents (replace) and agents_add/agents_remove (additive) are mutually exclusive; pick one form`. Do not silently apply one and ignore the other — the wrapper author almost certainly meant one or the other, not both, and surfacing the ambiguity loudly is the only way to catch the mistake before reviewer fan-out drifts.
- **Empty `cross_ref_phrase`** — both `""` and YAML `null` (unset) are treated identically: omit the trailing line containing the placeholder *entirely* (no blank line in the rendered body). Wrappers without a meta-tracker issue should leave `cross_ref_phrase:` unset (canonical) or set it to `""` (legacy-compatible).
- **One mode in `all` fails** — record the failure, continue with remaining modes; surface failures in the final report.
- **`--against <base-ref>` resolves to nothing** — hard-fail before reviewer fan-out with `cannot resolve <ref>: git rev-parse failed`. Common cause: forgot to `git fetch origin` first, so `origin/main` is unknown locally. Tell the user to fetch and retry. Never silently fall back to a full sweep — the user asked for diff-scoped review and got something different.
- **`--against <base-ref>` resolves but the diff is empty** — hard-fail with `git diff <base>...HEAD is empty — nothing to review`. Usually means the user invoked from `main` itself (HEAD == base) or from a branch already merged. Do not spawn agents on an empty diff.
- **`--all-slices` without `--against`** — flag is meaningless without the filter active; warn-and-ignore (do not hard-fail — full sweeps are the default and this is just a no-op).
- **`--force-trivial` without `--against`** — hard-fail. The flag bypasses a classifier that doesn't run without `--against`; accepting it silently would suggest the bypass was applied when nothing was actually skipped. Tell the user to drop the flag.
- **Trivial-diff classifier disagrees with user intent** — the classifier categorises by path patterns + line count, NOT by semantic impact. A 5-line `*.yml` change flipping `enable_admin_bypass: true` is `pure_config` by classification but `security`-critical by impact. Always refuse-with-message (never auto-downgrade); let the user decide whether `--force-trivial` is appropriate. The classifier's job is to default-prevent agent waste, not to override judgment.
- **Diff-aware slice filter leaves enabled_slices empty** — hard-fail per the *Diff-aware slice filter* §Empty result handling block; never silently produce a vacuous review.

## Mode cheat-sheet

```
code         | correctness + idiom              | ~10-14 agents | 1 issue
cleanup      | dedup + dead code                |  3-5 agents   | 1 issue
security     | OWASP + economic exploits        |  3-4 agents   | 1 issue
architecture | hex boundaries + deepening       |  4-5 agents   | 1 issue
test         | coverage + fake parity           |  3-4 agents   | 1 issue
perf         | N+1 + contention + numerics      |  3-4 agents   | 1 issue
docs         | ARCH/ADR/drift                   |  1-2 agents   | 0-1 issue
pre-pr       | diff-only sanity                 |  3 agents     | 0 issues
all          | every mode except pre-pr         | ~30 agents    | 6 issues
```

## Worked example

Representative run on a mid-sized Python application repo, `code` mode, `all`:

- Mapping: 4 `code-explorer` agents in parallel (domain / application / adapters / tests+entry).
- Review: 6 agents in parallel (4 `code-reviewer` + 2 `python-reviewer`) across priority files surfaced by the explorers.
- Counts: 3 CRITICAL · 17 HIGH · 14 MEDIUM · 6 LOW.
- PR slicing: 5 themed branches in the issue body, each self-contained.
- Verdict: BLOCK — three CRITICALs.

A follow-up pass added `python-pro`, `security-reviewer`, `silent-failure-hunter` lenses without re-flagging anything from the prior pass — proof the exclusion-list discipline works in practice.

## Open follow-ups

- **TODO (`~/.claude/scripts/arch-map/gen_arch.py`)** — when run from inside a git worktree (`.worktrees/<name>/`), the generator currently emits `<name>/` as the tree root, leaking the worktree directory name into committed `ARCH.md`. Fix: derive the displayed root from `git config remote.origin.url` (or `basename $(git rev-parse --show-toplevel | xargs dirname)` on the main checkout) so the root is stable across worktrees. Workaround in the meantime: hand-edit `ARCH.md` to swap the worktree basename for the repo name before committing.
