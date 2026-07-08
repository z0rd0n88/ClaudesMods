---
name: multi-agent-review
description: Fan-out multi-perspective review (architect, critical-thinking, silent-failure, security) over a PR, directory, or file; synthesizer merges findings.
allowed-tools:
  - Bash
  - Read
  - Glob
  - Grep
  - Agent
---

# multi-agent-review

## 1. Purpose

Run a fan-out / fan-in review over a single target. The skill spawns N reviewer agents in parallel, each with a self-contained brief containing the same materials and severity rubric. After all reviewers return, a synthesizer agent merges their reports into one prioritized review document. The skill prints the synthesized report verbatim; reviewers' raw outputs are not surfaced separately.

The skill itself does not produce findings — it orchestrates agents and relays their output. It does not execute the recommendations.

## Shared primitives

This skill is one of three (alongside `total-review` and `multi-agent-developer`) that share these primitives:

- [`refs/multi-agent/fanout-consolidation.md`](../../refs/multi-agent/fanout-consolidation.md) — the parallel-fan-out contract, dedupe rules, and cross-axis severity budget the synthesizer applies. This skill's §6 brief template and synthesizer step instantiate that ref.
- [`refs/multi-agent/agent-catalog-lookup.md`](../../refs/multi-agent/agent-catalog-lookup.md) — how `--reviewers <csv>` names resolve to files in the project active catalog and the user-scope parked tier.
- [`refs/multi-agent/exclusion-list.md`](../../refs/multi-agent/exclusion-list.md) — pass an exclusion-list file via `--prompt-prelude <path>` to suppress already-tracked findings (the same prelude hook serves as the injection point).
- [`refs/multi-agent/spec-injection.md`](../../refs/multi-agent/spec-injection.md) — for PR/diff/dir reviews, pass the originating spec/issue via `--prompt-prelude <path>` so reviewers can raise CRITICAL if the diff fails to satisfy the originating intent. The prelude file may concatenate exclusion-list and spec under their respective headings.

## 2. When to use

Trigger phrases:
- "review this PR" / "audit PR <n>"
- "review/audit this directory" / "review `core/`"
- "review this file" / "review `<path>`"
- "review the spec" / "review the spec amendment" / "review SPEC.md and the update"
- "do a multi-agent review of …"
- explicit invocation: `multi-agent-review …`

Do NOT use for:
- Single-pass review by one specific agent (call the agent directly).
- Anything that would write to source files — this skill is read-only by default.

## 3. Invocation grammar

```
multi-agent-review <target-type> <target-args...> [flags]
```

Examples:

```
multi-agent-review pr 42
multi-agent-review pr https://github.com/owner/repo/pull/42
multi-agent-review dir core/
multi-agent-review file SPEC.md
multi-agent-review spec SPEC.md SPEC-UPDATE-001-foo.md PRD.md
multi-agent-review diff                       # uncommitted working-tree changes (git diff)
multi-agent-review diff --staged              # staged-but-uncommitted changes
multi-agent-review slices src/foo/ src/bar/   # fan-out per slice + cross-slice synth

# Reviewer override (comma-separated; surrounding whitespace around names is trimmed):
multi-agent-review pr 42 --reviewers architect-review, ecc-security-reviewer, python-reviewer

# Synthesizer override:
multi-agent-review dir core/ --synthesizer code-reviewer

# Opt-in file output:
multi-agent-review pr 42 --write-to docs/reviews/pr-42-review.md

# Prompt prelude (project-defined context / skip-list / exclusion notes prepended to every reviewer brief):
multi-agent-review pr 42 --prompt-prelude .claude/multi-agent-review-modes/skip-list.md
```

| Position / flag | Required | Values |
|---|---|---|
| `<target-type>` (positional 1) | yes | `pr` \| `dir` \| `file` \| `spec` \| `diff` \| `slices` |
| `<target-args>` (positional 2..N) | yes | per type: PR number/URL; directory path; one file path; one or more markdown paths; (none for `diff`); two or more directory paths for `slices` |
| `--reviewers <csv>` | no | comma-separated agent names; default = the generic roster (see §4). Validated at parse time (§5.1): whitespace around commas is stripped; unknown names hard-fail before any agent is spawned. |
| `--synthesizer <name>` | no | single agent name; default = `knowledge-synthesizer`. Validated at parse time (§5.1) against the same agent union as `--reviewers`. |
| `--write-to <path>` | no | path to also save the final report; default = stdout only |
| `--force` | no | with `--write-to`, allow overwriting an existing file |
| `--max-files <n>` | no | override the directory file-count cap (default 50) |
| `--max-slices <n>` | no | override the `slices` per-invocation slice cap (default 6). Each slice spawns its own roster, so total reviewer agents = `len(roster) × len(slices) + 1` synthesizer; the cap prevents runaway agent fan-out. |
| `--staged` | no | only valid with `diff`; resolve materials from `git diff --staged` (staged-but-uncommitted hunks) instead of the working-tree `git diff`. |
| `--mode <name>` | no | named preset that supplies the default reviewer roster and (optionally) the synthesizer. Presets live in `.claude/multi-agent-review-modes/<name>.md` (project) or `<plugin-install-root>/modes/<name>.md` (user); project shadows user by filename. Explicit `--reviewers` / `--synthesizer` still win. |
| `--prompt-prelude <path>` | no | path to a markdown/text file whose contents are prepended to every reviewer brief (and the synthesizer brief) under a `## PROJECT PRELUDE` section. Used for project-defined skip-lists (e.g., "do not re-raise findings already tracked in issues #82/#83/#84"), house-style notes, or terminology glossaries. Resolved relative to `git rev-parse --show-toplevel` when not absolute; missing file = hard-fail before any agent is spawned. Size capped at 16 KB; larger files = hard-fail with the size + cap. |
| `--high-cap <n\|off>` | no | cross-axis severity budget for HIGH findings (see `refs/multi-agent/fanout-consolidation.md`). Default `8`. The synthesizer demotes HIGH findings beyond `min(cap, ceil(N_reviewers * 1.5))` to MEDIUM. Set `off` to suppress the budget entirely — required when this skill is used as a per-phase gate by an upstream pipeline (e.g. `baton-runner-multi-agent`) that derives `VERDICT = CLEAN iff zero CRITICAL+HIGH`; demotion in that context would silently let unresolved HIGHs through. For one-shot PR/audit reviews, leave at default. |

Example with a mode:

```
multi-agent-review pr 42 --mode security
multi-agent-review dir core/ --mode architecture --synthesizer code-reviewer
```

Example with a slice fan-out + project prelude:

```
multi-agent-review slices src/foo/domain/ src/foo/application/ src/foo/adapters/ \
  --mode code --prompt-prelude .claude/multi-agent-review-modes/skip-list.md
```

Example with the uncommitted-diff target (pre-PR sanity check on the working tree):

```
multi-agent-review diff --mode pre-pr
multi-agent-review diff --staged --reviewers ecc-security-reviewer, silent-failure-hunter
```

## 4. Defaults

- **Reviewer roster** (when `--reviewers` is omitted, in this order):
  1. `architect-review`
  2. `critical-thinking`
  3. `ecc-silent-failure-hunter`
  4. `ecc-security-reviewer`
- **Synthesizer**: `knowledge-synthesizer`
- **Directory file-count cap**: 50 (override with `--max-files <n>`)
- **Slice fan-out cap**: 6 slices per invocation (override with `--max-slices <n>`); each slice spawns the full roster in parallel.
- **PR diff size warning threshold**: 100 KB (warn on stderr, do not auto-truncate)
- **`--write-to` overwrite policy**: refuse if destination exists, unless `--force` is also set
- **Mode preset**: when `--mode <name>` is supplied without `--reviewers`, the mode's `reviewers` list replaces the default roster above; when supplied without `--synthesizer`, the mode's `synthesizer` (if any) replaces the default synthesizer. Explicit flags always override the preset.
- **Prompt prelude**: when `--prompt-prelude <path>` is supplied, the file's contents are prepended verbatim to every reviewer brief AND the synthesizer brief under a `## PROJECT PRELUDE` section (see §5.3 and §5.6). Max prelude size 16 KB; absent flag = no prelude (briefs render as today).
- **Diff target**: `diff` resolves to `git diff` against the working tree; with `--staged`, to `git diff --staged`. Both run from `git rev-parse --show-toplevel`. Empty diff = hard-fail (nothing to review).

## 5. Workflow

Execute these steps in order on every invocation:

### 5.1 Parse and validate

1. Parse positional args + flags per §3.
2. Hard-fail with a clear error and exit if:
   - `<target-type>` is missing or not one of `pr|dir|file|spec|diff|slices`.
   - `<target-args>` don't match the type (e.g., `pr` with no number/URL; `file` with more than one path; `diff` with any positional arg other than nothing; `slices` with fewer than two paths).
   - `--reviewers` is present but empty.
   - `--staged` is present and `<target-type>` is not `diff`.
   - `--prompt-prelude` is present and the resolved path does not exist OR exceeds the 16 KB cap.
   - `<target-type>` is `slices` and the number of paths exceeds `--max-slices` (default 6).
3. **Validate `--reviewers` CSV.** Split on `,`, then strip surrounding
   whitespace from each token (natural inputs like `a, b, c` are
   accepted). Reject only if a token is empty after stripping (consecutive
   commas) or contains internal whitespace (`a b` inside a single token).
4. **Resolve `--mode <name>` (if present).** Scan for the mode file in this
   order, stopping at the first hit:
   1. `<repo-root>/.claude/multi-agent-review-modes/<name>.md` (project scope;
      `<repo-root>` = `git rev-parse --show-toplevel`, skipped when not
      inside a git repo).
   2. `<plugin-install-root>/modes/<name>.md` (user scope).

   Unknown mode → hard-fail with the union of mode-file stems found across
   both scopes (use this list to make the error actionable; if both
   directories are absent, say so).

   Parse the mode file's YAML frontmatter (the leading `---`-delimited
   block). Required keys: `name` (string; must equal the filename stem —
   mismatch is a hard-fail to prevent renamed-without-rewrite drift),
   `reviewers` (YAML list of strings, or a CSV string parsed per step 3).
   Optional key: `synthesizer` (single agent name). The body after the
   frontmatter is human-facing documentation and is ignored by the parser.
5. **Apply mode defaults.** If `--mode` was set:
   - When `--reviewers` is absent, use the mode's `reviewers` as the
     roster.
   - When `--synthesizer` is absent AND the mode declares one, use the
     mode's `synthesizer`.
   Explicit `--reviewers` / `--synthesizer` flags always win over the mode.
6. If `--reviewers` is still unset → use the default roster from §4.
7. If `--synthesizer` is still unset → use `knowledge-synthesizer`.
8. Validate every reviewer name AND the synthesizer name against the union of `.claude/agents/*.md` (project) and `~/.claude/agents/*.md` (user). Unknown name → hard-fail before spawning anything, with the list of known agent names. (This step catches typos in mode files for free — the mode's reviewer list is validated by the same union.)
9. **Resolve `--prompt-prelude <path>` (if present).** Resolve `<path>` to
   absolute (relative to `git rev-parse --show-toplevel` when not already
   absolute). Hard-fail if the path does not exist, is not a regular file,
   or exceeds 16 KB (`stat -c%s` / `wc -c`). On success, read the file's
   contents into the `{{PROJECT_PRELUDE}}` placeholder string used by the
   reviewer brief (§5.3, §7) and the synthesizer brief (§5.6, §8). When
   `--prompt-prelude` is absent, `{{PROJECT_PRELUDE}}` resolves to the
   empty string AND the surrounding `## PROJECT PRELUDE` block is stripped
   from the brief template before dispatch (no orphan heading).
10. **`--write-to` overwrite guard (early).** If `--write-to <path>` is set:
   resolve `<path>` to absolute (relative to `git rev-parse --show-toplevel`
   if not already absolute); if the destination file exists AND `--force`
   is NOT set → hard-fail HERE, before any reviewer agent is spawned.
   Running the fan-out and discovering an overwrite conflict at write
   time would waste N reviewer + 1 synthesizer agent calls.

**Mode-file shape** (one file per preset, frontmatter-only parser):

```yaml
---
name: security
description: Security-focused review using boundary, money-flow, and OWASP lenses.
reviewers:
  - ecc-security-reviewer
  - security-reviewer
  - silent-failure-hunter
synthesizer: knowledge-synthesizer   # optional; omit to inherit the §4 default
---

Free-text body — rationale, when to use, caveats. The parser only reads
frontmatter; the body is purely human-facing.
```

`reviewers` accepts a YAML list (shown above) or a single CSV string
(`reviewers: "a, b, c"`). Both forms feed the same validation as
`--reviewers`.

### 5.2 Resolve materials per target type

Each branch produces a **materials block** — a self-contained string that every reviewer brief will embed verbatim. Reviewers receive NO shared conversation state, so the materials block is the only way they see the target.

| Target type | Resolution steps |
|---|---|
| `pr <n\|url>` | If `gh` is not on PATH → hard-fail with install instructions. Run `gh pr view <ref> --json number,title,body,headRefName,baseRefName,files,author,url`. Run `gh pr diff <ref> --patch` (the `--patch` flag pins unified-diff output; do not rely on the default format) — if `gh pr diff` exits non-zero or emits an empty diff, hard-fail with the `gh` error output (do not proceed with an empty materials block). From the JSON, extract each changed file's path and resolve to absolute (relative to `git rev-parse --show-toplevel`). For fork PRs, files in the PR's file list may not exist in the local checkout; for any such file, include only its diff hunk in the materials block and note "file not available locally; review from diff only" — do NOT instruct reviewers to `Read` a path that does not exist on disk. If the diff exceeds 100 KB, emit a single-line warning to stderr and proceed without truncation. Materials block contains: PR metadata table, full diff, and the file list with absolute paths and an explicit instruction to read each in full. |
| `dir <path>` | Resolve to absolute. **Verify the path exists and is a directory** before invoking `git ls-files` — if it does not exist or is not a directory, hard-fail with the missing/invalid path. (An absent path silently produces an empty `git ls-files` output, which would yield a vacuous review.) Run `git ls-files <path>` (respects `.gitignore`). If the file count exceeds the cap (default 50, override via `--max-files`), abort with a message listing the count, the cap, **and the `--max-files <n>` override flag**; do not proceed. Materials block contains: the directory's absolute path, the file list with absolute paths, and an instruction to read each in full. |
| `file <path>` | Resolve to absolute. Verify the file exists and is readable. Reject if more than one path is given. Materials block contains: the absolute path and an instruction to read it in full. |
| `spec <p1> [<p2> ...]` | Resolve each path to absolute. Verify each exists and is readable. Materials block contains: the list of absolute paths and an instruction to read each in full. |
| `diff` (no paths) | Verify the cwd is inside a git repo (`git rev-parse --show-toplevel`). Run `git diff` (or `git diff --staged` if `--staged` was passed) — capture stdout. If the diff is empty, hard-fail with: `diff target has no changes` (or `... --staged hunks` when `--staged`). If the diff exceeds 100 KB, emit a warning to stderr (same threshold as PR diff) and proceed without truncation. Also enumerate changed files via `git diff --name-only` (with `--staged` when applicable) and resolve to absolute paths. Materials block contains: the diff mode label (`working-tree` or `staged`), the full diff, and the file list with absolute paths plus an instruction to read each in full (reviewers may want full-file context, not just hunks). |
| `slices <p1> <p2> [<p3> ...]` | **Fan-out target.** Each path is treated as its own `dir`-style sub-target — resolve each to absolute, verify each is a directory, run `git ls-files` per slice, enforce the same `--max-files` cap per slice (not globally). Reject if slice count exceeds `--max-slices` (default 6). Build one materials block PER SLICE (same shape as a `dir` materials block), labelled with the slice's relative path from `git rev-parse --show-toplevel`. The dispatch step (§5.4) and synthesis step (§5.6) treat slices specially: every reviewer runs once per slice in parallel, and a single cross-slice synthesizer merges all `len(roster) × len(slices)` outputs into one report organised by slice. |

> **Reviewer tool requirements:** For `dir`, `file`, and `spec` targets, the materials block delegates file reads to the reviewer agents. **Reviewer agents must therefore have `Read` (and `Glob`/`Grep` for `dir`) in their own `allowed-tools` frontmatter.** The skill's `allowed-tools` governs only the orchestrator. If a reviewer lacks `Read`, it will return an empty or hallucinated report; verify each rostered reviewer's `allowed-tools` before opting an unfamiliar agent into the roster. Alternative: embed the file contents directly into the materials block (this skill currently does not, to keep brief size bounded).

### 5.3 Build reviewer briefs

For each reviewer in the roster, expand the [Reviewer brief template](#7-reviewer-brief-template) with the values resolved above. The brief must be self-contained — the agent will not see this skill's conversation.

**Placeholder values to fill in:**

| Placeholder | Source |
|---|---|
| `{{REVIEWER_NAME}}` | The reviewer's agent name (the current entry in the roster). |
| `{{TARGET_TYPE}}` | The resolved target type from §5.1 (`pr` / `dir` / `file` / `spec` / `diff` / `slices`). |
| `{{MATERIALS_BLOCK}}` | The materials block from §5.2 (verbatim, same for every reviewer in a non-`slices` invocation; per-slice for `slices`). |
| `{{REVIEWER_ROLE_DESCRIPTION}}` | The reviewer's role description (see resolution rule below). |
| `{{PROJECT_PRELUDE}}` | The contents of the `--prompt-prelude` file from §5.1 step 9. Empty string when the flag is absent — in that case strip the entire `## PROJECT PRELUDE` block (heading + body) from the template before dispatch. |
| `{{SLICE_LABEL}}` | For `slices` only: the slice's relative path from repo root (e.g., `src/foo/domain/`). For all other targets, strip the `## SLICE` block from the template. |

When expanding the template, **strip every line that begins with `#` from
the body of the template itself** — those `#`-prefixed lines are
annotations to the skill author about where each placeholder comes from
and should not be sent verbatim to the agent. (Lines beginning with `##`
that are real markdown section headings in the brief are kept; only the
single-`#` annotation lines that immediately follow a placeholder are
stripped.)

For `{{REVIEWER_ROLE_DESCRIPTION}}`:
1. Attempt to read `.claude/agents/<reviewer-name>.md` (project scope).
2. If absent, try `~/.claude/agents/<reviewer-name>.md` (user scope).
3. If both absent (e.g., built-in agent) → use the literal fallback string: `"Apply your standard review lens to the materials above."`
4. If found → extract the first non-empty, non-heading block of the agent
   definition's body. "Body" = everything after the closing `---` of the
   frontmatter. **Skip any lines matching `^#+ ` (markdown headings)**
   when locating the first paragraph, since many agent files open with
   a `# <Name>` heading that is not the role description. The first
   paragraph is the first run of consecutive non-empty, non-heading
   lines after the frontmatter, terminated by a blank line.

### 5.4 Spawn reviewers IN PARALLEL

> ⚠️ **PARALLELISM RULE — DO NOT SERIALIZE**
>
> All reviewer `Agent` tool calls MUST be issued in a SINGLE assistant message containing N parallel tool invocations. Do NOT spread them across multiple turns. If the roster has N reviewers, the orchestrator message contains exactly N `Agent` tool uses, all dispatched together.
>
> Each call MUST set:
> - `subagent_type` to the reviewer's agent name.
> - `description` to `"Multi-agent review: <reviewer-name>"` (for `slices`, append ` (<slice-label>)`).
> - `prompt` to the fully-expanded reviewer brief (see §7).
>
> **Note:** `subagent_type` must match an available agent type at runtime (as registered by the Claude Code Agent tool — typically derived from the canonical filename of an active `.claude/agents/*.md` or `~/.claude/agents/*.md` file). If an invalid value is passed, the Agent tool will reject the call. The parse-time validation in §5.1 reads the same on-disk agent files and is meant to catch this before dispatch, but the Agent tool's live schema is the ultimate authority.
>
> **`slices` dispatch shape.** For a `slices` invocation with roster size N and slice count M, the single dispatch message contains **N × M** `Agent` tool uses, one per (reviewer, slice) pair, all issued together. Build one fully-expanded brief per pair using the slice's per-slice materials block (§5.2) and the slice's label as `{{SLICE_LABEL}}`. Do not serialise slices: a 3-reviewer × 5-slice review must spawn 15 agents in one assistant message, not 5 sequential 3-agent messages. The `--max-slices` cap (default 6, override per §3) bounds the explosion.

### 5.5 Collect outputs

After all reviewers return, capture each reviewer's output verbatim, keyed by reviewer name in the order they appeared in the roster. Do not edit, summarize, reformat, or filter at this stage.

For `slices` targets, key each output by `(slice-label, reviewer-name)` so the synthesizer can render findings under per-slice subheadings. Preserve slice order from the command line and reviewer order from the roster — both are deterministic inputs to the cross-slice synthesis.

### 5.6 Invoke synthesizer

Expand the [Synthesizer brief template](#8-synthesizer-brief-template) with:
- `{{SYNTHESIZER_NAME}}` = the resolved synthesizer (default `knowledge-synthesizer`).
- `{{N_REVIEWERS}}` = the roster size.
- `{{HIGH_CAP}}` = the resolved `--high-cap` value (default `8`; literal `off` when the caller passed `--high-cap off`). Parsed in §5.1; values other than a positive integer or the literal `off` hard-fail before any agent is spawned.
- `{{TARGET_TYPE}}` = the resolved target type.
- `{{PROJECT_PRELUDE}}` = the contents of the `--prompt-prelude` file (§5.1 step 9). Empty string when absent — in that case strip the entire `## PROJECT PRELUDE` block from the synthesizer brief before dispatch (no orphan heading).
- `{{MATERIALS_BLOCK}}` = the same materials block from §5.2. For `slices`, expand to the concatenation of every per-slice materials block, each preceded by a `### Slice: <slice-label>` heading and a `---` separator.
- `{{REVIEWER_OUTPUTS}}` = the concatenated reviewer outputs. For non-`slices` targets, for each reviewer in roster order, insert a block of exactly this shape (literal text, no templating):

  ```
  ---
  ### Reviewer: <reviewer-name>
  <reviewer's verbatim output>
  ---
  ```

  For `slices` targets, group by slice first, then by reviewer:

  ```
  ===
  ## Slice: <slice-label>
  ===
  ---
  ### Reviewer: <reviewer-name>
  <reviewer's verbatim output for this slice>
  ---
  ### Reviewer: <next-reviewer-name>
  <…>
  ---
  ```

  Concatenate all blocks into a single string before substitution.
- `{{TARGET_LABEL}}` = a human-readable label for the target (e.g., `PR #42: <title>`, `directory core/`, `file SPEC.md`, `spec set: SPEC.md + SPEC-UPDATE-001-foo.md`, `working-tree diff`, `staged diff`, `slices: src/foo/domain/ + src/foo/application/ + …`).
- `{{SLICE_LIST}}` = for `slices` only, a comma-separated list of slice labels. For other targets, strip the `## SLICES IN SCOPE` block from the template.

Spawn the synthesizer as a single `Agent` tool call with `subagent_type` = the synthesizer name and `description` = `"Multi-agent review: synthesize"`.

### 5.7 Print verbatim

Print the synthesized report verbatim as the final assistant message. If
`--write-to` was set, prepend exactly one line — `Wrote: <absolute path>` —
followed by the verbatim report; otherwise emit no preamble and no
postscript.

When `--write-to <path>` is set:
1. The overwrite guard already ran in §5.1 — the destination is known to
   be writable at this point. (If it existed and `--force` was not set,
   the skill exited early with no reviewer agents spawned.)
2. Create parent directories as needed (`mkdir -p`).
3. Write the synthesizer's output to `<path>`.
4. Print the `Wrote: <absolute path>` line, then the synthesizer's output verbatim.

**Synthesizer-failure fallback with `--write-to`:** if the synthesizer
fails (see §10) AND `--write-to` was set, still write a file at `<path>`
containing a single header line noting the synth failure, followed by
each reviewer's verbatim output with delimiters. Better to persist the
raw reviewer outputs than to discard them by silently skipping the
write. Then print the same content to stdout (with the leading
`Wrote: <absolute path>` line).

## 6. Parallelism rule (callout)

> Reviewer dispatch is the load-bearing optimization of this skill. If you spawn agents one at a time across multiple assistant turns, latency multiplies by N and you've reduced this skill to a sequential checklist with extra steps. Always emit all reviewer `Agent` calls in ONE message.

## 7. Reviewer brief template

Expand placeholders (`{{ ... }}`) at invocation time. Pass the result verbatim as the `prompt` field of each `Agent` call.

```
You are the {{REVIEWER_NAME}} agent reviewing the following target. You have no prior conversation context. Read every file and diff listed in the MATERIALS section in full before producing your report. Do not skim, do not sample.

## PROJECT PRELUDE
{{PROJECT_PRELUDE}}
# Verbatim contents of the file passed via --prompt-prelude. Typical use:
# project-defined skip-list ("do not re-raise these tracked findings"),
# house-style notes, or terminology glossary. When --prompt-prelude is
# absent, strip this entire `## PROJECT PRELUDE` block (heading + body)
# from the template before dispatch — no orphan heading.

## SLICE
{{SLICE_LABEL}}
# For `slices` target only: the slice you are reviewing (relative path
# from repo root). Reviewers receive ONE slice's materials per dispatch;
# the cross-slice synthesis happens in the synthesizer. When the target
# is anything other than `slices`, strip this `## SLICE` block from the
# template before dispatch.

## TARGET TYPE
{{TARGET_TYPE}}   # one of: pr | dir | file | spec | diff | slices

## MATERIALS
{{MATERIALS_BLOCK}}
# For pr: PR metadata, full diff, list of changed files with absolute paths.
# For dir: directory absolute path + file list with absolute paths.
# For file: single absolute path.
# For spec: list of absolute markdown paths.
# For diff: diff mode label (working-tree | staged), full diff, changed-file list.
# For slices: ONE slice's directory absolute path + file list (one brief per slice per reviewer).

## YOUR ROLE
{{REVIEWER_ROLE_DESCRIPTION}}
# Pulled from .claude/agents/<name>.md or ~/.claude/agents/<name>.md (first paragraph of body).
# If no definition exists, this is the literal: "Apply your standard review lens to the materials above."

## SEVERITY SCALE
Use these levels for every finding (EXCEPT if you are critical-thinking — see below):
- CRITICAL: Security vulnerability, data loss risk, or correctness bug that breaks the contract.
- HIGH: Significant bug, design flaw, or maintainability issue that should block merge.
- MEDIUM: Quality concern that should be addressed but does not block.
- LOW: Style, minor suggestion, or nit.

If you are the `critical-thinking` reviewer: do NOT use this scale. Instead, return a list of unstated assumptions, missing context, decisions made without justification, and questions the author should answer before proceeding.

## RETURN FORMAT
Return a single markdown document with this structure:

### Summary
One paragraph: what you reviewed and your overall take.

### Findings
For severity-using reviewers: a section per severity level (CRITICAL → LOW), each finding with:
- **Title**
- **Location** (file:line or file region)
- **Description**
- **Suggested fix**

For critical-thinking: a flat list of assumptions/questions/missing-context items, each with:
- **Item**
- **Why it matters**
- **What to verify or decide**

### Confidence
One line: how confident you are in this review and what would raise that confidence.

Do not include preamble or sign-off. Start with `### Summary`.
```

## 8. Synthesizer brief template

```
You are the {{SYNTHESIZER_NAME}} agent. You have no prior conversation context. Your job is to merge {{N_REVIEWERS}} reviewer reports into a single prioritized review document.

## PROJECT PRELUDE
{{PROJECT_PRELUDE}}
# Same prelude every reviewer received. Apply it to your synthesis: do
# not re-raise findings listed as already-tracked in the prelude; honour
# any house-style notes when phrasing recommendations. Strip this whole
# block when --prompt-prelude was not set.

## SLICES IN SCOPE
{{SLICE_LIST}}
# `slices` target only. Comma-separated list of slice labels. Each
# finding in your output MUST be attributed to its slice. Strip this
# block for non-`slices` targets.

## TARGET TYPE
{{TARGET_TYPE}}

## MATERIALS THE REVIEWERS READ
{{MATERIALS_BLOCK}}

## REVIEWER REPORTS (verbatim)
{{REVIEWER_OUTPUTS}}
# Expand {{REVIEWER_OUTPUTS}} BEFORE sending the brief, by concatenating
# every reviewer's output as plain text. For each reviewer, append the
# following block (no template engine — the synthesizer LLM cannot expand
# Handlebars or any other templating syntax):
#
#   ---
#   ### Reviewer: <reviewer-name>
#   <reviewer's verbatim output>
#   ---
#
# Repeat the block for each reviewer in roster order, separated by the
# `---` delimiters above. The final expanded string replaces the
# {{REVIEWER_OUTPUTS}} placeholder verbatim.

## MERGE INSTRUCTIONS

Produce a single markdown report with EXACTLY this structure and these section headings:

# Multi-Agent Review: {{TARGET_LABEL}}

## Executive Summary
2-4 sentences: what was reviewed, how many reviewers, headline findings, recommended action.

## Critical Findings
Every CRITICAL-severity finding from any severity-using reviewer. Deduplicate when two reviewers raised the same issue (note both reviewer names). Each finding: title, location, description, suggested fix, attribution (which reviewer(s) raised it). For `slices` targets, also tag each finding with its slice label so cross-slice patterns are visible at a glance.

## High Findings
Same format as Critical, for HIGH-severity findings. **Apply the cross-axis severity budget** from `refs/multi-agent/fanout-consolidation.md` before rendering this section, UNLESS `{{HIGH_CAP}}` is `off` (in which case skip this whole paragraph and render every HIGH as-is — used when a downstream pipeline gates on HIGH count and silent demotion would be wrong). When the budget is active: `high_cap = min({{HIGH_CAP}}, ceil(N_reviewers * 1.5))` where `N_reviewers = {{N_REVIEWERS}}`. If post-dedupe HIGH findings exceed `high_cap`, rank by impact (CRITICAL-adjacent > correctness > maintainability > style; ties broken by the number of distinct reviewers that raised the finding), keep the top `high_cap` as HIGH, **and demote the rest to MEDIUM** with the suffix `_(demoted from HIGH by severity budget; <reason>)_` on each demoted entry. CRITICAL is never demoted; LOW is never promoted. Mention the demotion count in the Executive Summary if any demotions happened (`12 HIGH → top 6 kept, 6 demoted by budget`). For `slices` targets, the budget is global across slices, not per-slice — the intent is one ranked HIGH list, not N slices each filling their own budget.

## Medium and Low Findings
A single table with columns: Severity | Title | Location | Reviewer(s) | One-line description. Demoted-from-HIGH items render here with their original-severity note preserved.

## Unstated Assumptions and Open Questions (from critical-thinking)
The critical-thinking reviewer's output, integrated as its own section. Do NOT fold its items into the severity buckets above. If no critical-thinking reviewer was in the roster, omit this section entirely (do not emit an empty section).

## Reviewer Disagreements
List places where two or more reviewers contradicted each other. For each disagreement: the issue, what each reviewer said, and your recommended resolution.

## Recommended Changes (Prioritized)
An ordered list of concrete actions, sequenced by severity then by dependency. Each item is one sentence.

## Open Questions for the Author
Decisions or clarifications the author must make before acting on this review.

## Cross-Slice Patterns (slices target only)
For `slices` targets, add this section: identify findings or themes that span two or more slices (e.g., a missing-error-handling pattern repeated in domain + application). This is the *unique value* of slice fan-out over per-slice review and must be surfaced explicitly. Omit this section for non-`slices` targets.

Do not include preamble. Start with `# Multi-Agent Review: ...`.
```

## 9. Critical-thinking integration note

The `critical-thinking` reviewer is in the default roster and returns a flat list of unstated assumptions, missing context, and questions — NOT severity-tagged findings.

In the synthesized report:
- Its output goes in the **"Unstated Assumptions and Open Questions (from critical-thinking)"** section.
- It is **NOT** folded into the Critical / High / Medium-Low buckets.
- If `critical-thinking` is not in the roster, omit that section from the synthesized report entirely.

This carve-out is intentional: severity buckets reward false-positive findings (any reviewer can manufacture a "MEDIUM"); the critical-thinking output rewards surfacing what the author isn't seeing, which is a different cognitive task and a different output shape.

## 10. Error handling

| Condition | Action |
|---|---|
| Missing or invalid `<target-type>` | Hard-fail with a one-line usage summary. Do not spawn agents. |
| `gh` not on PATH and target is `pr` | Hard-fail with: `gh CLI is required for PR review. Install: https://cli.github.com/`. |
| `gh pr diff` fails or returns empty | Hard-fail with the `gh` error output (stderr) — do not proceed with an empty materials block. |
| `dir` target path does not exist or is not a directory | Hard-fail with the missing/invalid path; do not run `git ls-files` against it (which would silently emit empty output and produce a vacuous review). |
| Directory has > `--max-files` files | Hard-fail with the count, the cap, and the override flag (`--max-files <n>`). |
| `file` target has more than one path | Hard-fail. Tell the user: for multiple files use `dir <shared-directory>` if they share a directory, otherwise issue separate `file` invocations. `spec` is only for multiple markdown specification documents — do not suggest it for non-markdown file sets. |
| Path doesn't exist (`file` or `spec`) | Hard-fail with the missing path; do not silently skip. |
| Unknown reviewer or synthesizer name | Hard-fail before any agent is spawned, with the union of known names from `.claude/agents/` and `~/.claude/agents/`. |
| `--write-to` destination exists, no `--force` | Hard-fail in §5.1, BEFORE any reviewer agent is spawned (don't waste N agent calls). |
| Reviewer agent fails or returns empty output | Continue with the remaining reviewers' outputs. Note the failed reviewer in the synthesizer brief as `<reviewer-name>: [FAILED — no output]` so the synthesizer can flag it in "Reviewer Disagreements". |
| Synthesizer fails | Print: `Synthesizer <name> failed. Reviewer outputs follow:` then dump each reviewer's verbatim output with delimiters. If `--write-to` was also set, write the same content to the destination path with a leading header noting the synth failure (see §5.7) — better to persist raw material than discard it. |
| PR diff > 100 KB | Emit a warning to stderr (`warning: PR diff is <n>KB; reviewers may truncate`) and proceed. Do NOT auto-truncate. |
| `diff` target outside a git repo | Hard-fail: `diff target requires a git repository (cwd: <pwd>)`. |
| `diff` target has empty diff | Hard-fail: `diff target has no working-tree changes` (or `… no staged hunks` when `--staged`). Do not proceed with empty materials. |
| `--staged` without `diff` target | Hard-fail at parse time: `--staged is only valid with the diff target`. |
| `slices` with fewer than 2 paths | Hard-fail at parse time: `slices target requires at least two directory paths; use 'dir' for a single directory`. |
| `slices` exceeds `--max-slices` | Hard-fail with the count, the cap, and the `--max-slices <n>` override flag. Default cap 6 keeps the agent-fanout (N × M) bounded; lift it deliberately, not accidentally. |
| `--prompt-prelude` path missing | Hard-fail: `--prompt-prelude file not found: <abs-path>`. |
| `--prompt-prelude` > 16 KB | Hard-fail: `--prompt-prelude file is <n>KB; cap is 16KB. Split or trim it.` Large preludes pollute every reviewer brief with low-signal context. |

## 11. Resolved decisions

| # | Decision | Choice | Rationale |
|---|---|---|---|
| 1 | Directory file-count cap | 50, override via `--max-files <n>` | 50 keeps reviewer briefs within typical context budgets; explicit override beats silent truncation. |
| 2 | Unknown reviewer name | Hard-fail with list of known agents | Failing fast at parse time beats spawning an `Agent` call that errors mid-flight with an opaque message. |
| 3 | `gh` CLI absence (PR target) | Hard-fail with install instructions | The PR branch cannot proceed without `gh`; no manual-paste fallback because diffs are too large to copy by hand. |
| 4 | PR URL parsing | Pass through to `gh pr view` unchanged | `gh` already handles `github.com` URLs, enterprise hosts, and `#<n>` shorthand — re-parsing duplicates work and introduces drift. |
| 5 | Subagent-spawn tool name | `Agent` | Verified against the Claude Code Agent tool schema exposed in this build; `subagent_type` is the parameter name the tool takes. |
| 6 | Reviewer agent discovery | Validate at parse time against `.claude/agents/` + `~/.claude/agents/` | Fail-fast at parse time; see #2. |
| 7 | `--write-to` overwrite | Refuse if exists, allow with `--force` | Aligns with `cp`/`mv` defaults; review reports often accumulate and silent overwrite would destroy history. |
| 8 | PR diff size limit | Warn at 100 KB, do not auto-truncate | Truncation would silently degrade review quality; the user can split a megapatch into chunks themselves. |
| 9 | Default roster (user scope) | `architect-review`, `critical-thinking`, `ecc-silent-failure-hunter`, `ecc-security-reviewer` | Generic multi-perspective coverage: architecture lens, assumptions/critical-thinking, silent-failure hunting, and security. Override per-invocation via `--reviewers` for domain-specific lenses. |
| 10 | Mode presets | Bring-your-own — put `<name>.md` files under `.claude/multi-agent-review-modes/<name>.md` in a project, or under `<plugin-install-root>/modes/<name>.md` if you fork the plugin to ship defaults. This plugin ships no preset library out of the box; project scope shadows user scope by filename; explicit `--reviewers` / `--synthesizer` still override the preset. | Mirrors the agents/skills/commands "one file with frontmatter" shape so each repo can carry its own preset library without inventing a new config format. Not shipping defaults keeps the plugin opinion-free; the plugin ships the mechanism, not the taxonomy. |
| 11 | `diff` target | `git diff` (working tree) by default; `git diff --staged` with `--staged`; empty diff = hard-fail | Pre-PR reviews target uncommitted code by definition; making this a first-class target removes the "open a draft PR just to review it" anti-pattern. Working tree is the default because that is where unstaged refactors live; `--staged` exists for cases where the user has already curated the commit. |
| 12 | `slices` target | Fan-out reviewer roster across N directories in ONE parallel dispatch; meta-synthesizer attributes findings per slice and surfaces cross-slice patterns; `--max-slices` cap defaults to 6 | The pre-existing per-slice review pattern (invoke this skill once per slice) required N sequential invocations with no cross-slice analysis. Folding it into a single target gives O(1) human invocation, O(N×M) parallel agent work, and a meta-synth that can identify shared patterns — the actual value-add over per-slice review. Cap prevents runaway agent fan-out. |
| 13 | `--prompt-prelude` | File path; injected verbatim as `## PROJECT PRELUDE` into every reviewer + synthesizer brief; 16 KB cap | Projects need a real hook to tell reviewers "do not re-raise findings already tracked in issues #82/#83/#84" or to enforce house terminology. The "paste it into the chat" workaround documented in some project READMEs was not a real mechanism. File-based + size-capped + applied uniformly = reproducible, version-controllable, and bounded. |
