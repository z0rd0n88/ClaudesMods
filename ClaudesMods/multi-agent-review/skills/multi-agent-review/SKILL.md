---
name: multi-agent-review
description: "Parallel multi-perspective review over a PR/dir/file/spec/diff/slices; a PR target loops review→fix→re-review by default (--no-loop for a one-shot read-only report)."
allowed-tools:
  - Bash
  - Read
  - Edit
  - Write
  - Glob
  - Grep
  - Agent
  - Skill
  - TaskCreate
  - TaskUpdate
---

# multi-agent-review

## 1. Purpose

Two modes, one skill:

- **One-shot review (all targets).** Run a fan-out / fan-in review over a single target. The skill spawns N reviewer agents in parallel, each with a self-contained brief containing the same materials and severity rubric. After all reviewers return, a synthesizer agent merges their reports into one prioritized review document. The skill prints the synthesized report verbatim; reviewers' raw outputs are not surfaced separately. This mode is **read-only** — it orchestrates agents and relays their output; it does not edit source files or execute the recommendations.
- **Review loop (`pr` target, the default).** For a `pr` target, the skill composes the one-shot review into a **review → fix → re-review** loop bounded against a single open PR, with the invoking agent acting as the loop coordinator. Each review round runs in a **fresh subagent** (so the per-round reviewer transcripts never enter the coordinator's context window; the coordinator only sees each round's prioritized findings list); the coordinator applies fixes itself between rounds, commits, pushes, and repeats until APPROVE or max iterations. This mode is **mutating** — it edits files, commits, and pushes on the PR's head branch. It is entered via a confirmation gate (§5.0) unless `--yes` is passed; `--no-loop` restores the one-shot read-only report.

State the distinction up front when invoked: `pr` **loops by default (mutating)**; every other target (`dir`/`file`/`spec`/`diff`/`slices`) is always one-shot read-only; `--no-loop` forces one-shot on `pr` too.

## Shared primitives

This skill is one of three (alongside `total-review` and `multi-agent-developer`) that share these primitives:

- [`refs/multi-agent/fanout-consolidation.md`](../../refs/multi-agent/fanout-consolidation.md) — the parallel-fan-out contract, dedupe rules, and cross-axis severity budget the synthesizer applies. This skill's §6 brief template and synthesizer step instantiate that ref.
- [`refs/multi-agent/agent-catalog-lookup.md`](../../refs/multi-agent/agent-catalog-lookup.md) — how `--reviewers <csv>` names resolve to files in the project active catalog and the user-scope parked tier.
- [`refs/multi-agent/exclusion-list.md`](../../refs/multi-agent/exclusion-list.md) — pass an exclusion-list file via `--prompt-prelude <path>` to suppress already-tracked findings (the same prelude hook serves as the injection point).
- [`refs/multi-agent/spec-injection.md`](../../refs/multi-agent/spec-injection.md) — for PR/diff/dir reviews, pass the originating spec/issue via `--prompt-prelude <path>` so reviewers can raise CRITICAL if the diff fails to satisfy the originating intent. The prelude file may concatenate exclusion-list and spec under their respective headings.

## 2. When to use

Trigger phrases:
- "review this PR" / "audit PR <n>"
- "loop the multi-agent review until clean on PR #N"
- "iterative review on PR #N" / "review-fix-review PR #N"
- "review/audit this directory" / "review `core/`"
- "review this file" / "review `<path>`"
- "review the spec" / "review the spec amendment" / "review SPEC.md and the update"
- "do a multi-agent review of …"
- explicit invocation: `multi-agent-review …`

**Mode selection:** a `pr` target loops by default; pass `--no-loop` for a one-shot read-only report; non-`pr` targets are always one-shot.

Do NOT use for:
- Single-pass review by one specific agent (call the agent directly).
- Anything that would write to source files **outside a looping `pr` target** — every non-`pr` target and every `--no-loop` run is read-only.
- Loop mode on a PR you are about to merge regardless of findings — the loop only makes sense when fixes will actually be applied. Use `--no-loop` for a final read-only sanity pass instead.

## 3. Invocation grammar

```
multi-agent-review <target-type> <target-args...> [flags]
```

Examples:

```
multi-agent-review pr 42                      # LOOPS by default: review→fix→re-review (confirmation gate; mutating)
multi-agent-review pr 42 --yes                # loop without the confirmation gate (unattended runs)
multi-agent-review pr 42 --no-loop            # one-shot read-only report (the pre-2.0 default)
multi-agent-review pr https://github.com/owner/repo/pull/42
multi-agent-review pr 42 --max-iterations 5   # loop, cap at 5 rounds
multi-agent-review pr 42 --high-and-up-only   # loop, auto-defer MEDIUM/LOW
multi-agent-review pr 42 --no-smoke           # loop, skip the live smoke gate
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
multi-agent-review pr 42 --no-loop --write-to docs/reviews/pr-42-review.md

# Prompt prelude (project-defined context / skip-list / exclusion notes prepended to every reviewer brief):
multi-agent-review pr 42 --prompt-prelude .claude/multi-agent-review-modes/skip-list.md
```

| Position / flag | Required | Valid on | Values |
|---|---|---|---|
| `<target-type>` (positional 1) | yes | — | `pr` \| `dir` \| `file` \| `spec` \| `diff` \| `slices` |
| `<target-args>` (positional 2..N) | yes | — | per type: PR number/URL; directory path; one file path; one or more markdown paths; (none for `diff`); two or more directory paths for `slices` |
| `--reviewers <csv>` | no | all targets | comma-separated agent names; default = the generic roster (see §4). Validated at parse time (§5A.1): whitespace around commas is stripped; unknown names hard-fail before any agent is spawned. In loop mode, forwarded to each inner review pass. |
| `--synthesizer <name>` | no | all targets | single agent name; default = `knowledge-synthesizer`. Validated at parse time (§5A.1) against the same agent union as `--reviewers`. In loop mode, forwarded to each inner review pass. |
| `--write-to <path>` | no | all targets | path to also save the final report; default = stdout only. In loop mode, writes **once** — the final loop report — not once per round. |
| `--force` | no | all targets | with `--write-to`, allow overwriting an existing file |
| `--max-files <n>` | no | all targets | override the directory file-count cap (default 50) |
| `--max-slices <n>` | no | `slices` | override the `slices` per-invocation slice cap (default 6). Each slice spawns its own roster, so total reviewer agents = `len(roster) × len(slices) + 1` synthesizer; the cap prevents runaway agent fan-out. |
| `--staged` | no | `diff` | only valid with `diff`; resolve materials from `git diff --staged` (staged-but-uncommitted hunks) instead of the working-tree `git diff`. |
| `--mode <name>` | no | all targets | named preset that supplies the default reviewer roster and (optionally) the synthesizer. Presets live in `.claude/multi-agent-review-modes/<name>.md` (project) or `<plugin-install-root>/modes/<name>.md` (user); project shadows user by filename. Explicit `--reviewers` / `--synthesizer` still win. In loop mode, forwarded to each inner review pass. |
| `--prompt-prelude <path>` | no | all targets | path to a markdown/text file whose contents are prepended to every reviewer brief (and the synthesizer brief) under a `## PROJECT PRELUDE` section. Used for project-defined skip-lists (e.g., "do not re-raise findings already tracked in issues #82/#83/#84"), house-style notes, or terminology glossaries. Resolved relative to `git rev-parse --show-toplevel` when not absolute; missing file = hard-fail before any agent is spawned. Size capped at 16 KB; larger files = hard-fail with the size + cap. In loop mode, forwarded to each inner review pass — its exclusion-list value is how the coordinator stops inner passes from re-raising already-triaged/tracked findings across rounds. |
| `--high-cap <n\|off>` | no | one-shot runs | cross-axis severity budget for HIGH findings (see `refs/multi-agent/fanout-consolidation.md`). Default `8`. The synthesizer demotes HIGH findings beyond `min(cap, ceil(N_reviewers * 1.5))` to MEDIUM. Set `off` to suppress the budget entirely — required when this skill is used as a per-phase gate by an upstream pipeline (e.g. `baton-runner-multi-agent`) that derives `VERDICT = CLEAN iff zero CRITICAL+HIGH`; demotion in that context would silently let unresolved HIGHs through. For one-shot PR/audit reviews, leave at default. **In loop mode this flag is NOT forwarded — the loop forces `--high-cap off` on every inner review pass** (see §4); an explicit `--high-cap <n>` on a looping `pr` target triggers a warning that it is overridden to `off`. |
| `--no-loop` | no | all; meaningful only on `pr` | forces a one-shot read-only report on a `pr` target (the pre-2.0 default behavior); accepted **no-op** on every other target (documented so uniform scripting doesn't break). Mutually exclusive with the loop-control flags below — combining them is a parse-time hard-fail. |
| `--yes` | no | looping `pr` only | skips the confirmation gate (§5.0) for unattended/automated runs — the only way to loop without the interactive prompt. No-op on non-`pr` targets and on `--no-loop` runs. |
| `--in-loop` | **internal / reserved** | loop's inner self-call only | Not for end users. Passed by the loop coordinator to each fresh-subagent review pass; §5.0 reads it from its own `args` and hard-refuses loop mode (forces one-shot) when present — the parser-visible recursion backstop behind `--no-loop`. |
| `--max-iterations <n>` | no | looping `pr` only | integer 1–8, default 3. Parse-time hard-fail when combined with `--no-loop` or a non-`pr` target. |
| `--high-and-up-only` | no | looping `pr` only | coordinator auto-defers MEDIUM/LOW each round; only CRITICAL + HIGH drive iteration. Parse-time hard-fail with `--no-loop` or non-`pr`. |
| `--no-smoke` | no | looping `pr` only | skip the live smoke test on a round even when connector/runtime code changed. Parse-time hard-fail with `--no-loop` or non-`pr`. |

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

- **Default mode on a `pr` target = loop** (review→fix→re-review, mutating, confirmation-gated). All other targets, and any `--no-loop` run, are one-shot read-only.
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
- **Prompt prelude**: when `--prompt-prelude <path>` is supplied, the file's contents are prepended verbatim to every reviewer brief AND the synthesizer brief under a `## PROJECT PRELUDE` section (see §5A.3 and §5A.6). Max prelude size 16 KB; absent flag = no prelude (briefs render as today).
- **Diff target**: `diff` resolves to `git diff` against the working tree; with `--staged`, to `git diff --staged`. Both run from `git rev-parse --show-toplevel`. Empty diff = hard-fail (nothing to review).

**Loop defaults (looping `pr` target only):**

- **`--max-iterations`**: **3**. Most projects stabilize in 1–2 rounds; 3 catches genuine fix follow-ons; beyond that the reviewers are usually nitpicking. Hard ceiling is **8** — refuse anything higher (a `--max-iterations 50` request indicates a misunderstanding of the loop's purpose).
- **Action floor**: by default the coordinator MUST address every CRITICAL and HIGH; MEDIUM is coordinator's judgment; LOW is "note in PR comment, do not iterate on." With `--high-and-up-only`, MEDIUM and LOW are auto-deferred without prompting.
- **Smoke test gate**: re-run the project's live smoke ONLY if a fix touched code paths the smoke exercises. The set of smoke-relevant paths is project-specific — typical examples: external-connector loops, request-parse paths, allowlist/permission filters, metric-increment sites, top-level route handlers. Skip the smoke when fixes only touched paths the smoke doesn't cover. `--no-smoke` opts out entirely.
- **`--high-cap` is forced `off` on every inner review pass.** The loop gates iteration on CRITICAL+HIGH findings; the default HIGH-severity budget (`--high-cap` on) would demote surplus HIGHs to MEDIUM, letting the loop reach APPROVE with real HIGHs still outstanding. Forcing the cap off keeps every HIGH visible to the gate. If a caller explicitly passes `--high-cap <n>` on a looping `pr` target, **warn that it is overridden to `off` in loop mode** — don't silently drop it.
- **One-shot flag behavior in loop mode:** `--write-to` writes **once** — the final loop report — not once per round (per-round reviewer transcripts stay in their fresh subagents; only the coordinator's final report is persisted). `--prompt-prelude`, `--mode`, `--reviewers`, `--synthesizer` are **forwarded to each inner review pass** (every round runs the same roster/mode/prelude).

## 5. Workflow

### 5.0 Parse, validate, and select mode

Execute this step first on every invocation:

1. Parse positional args + flags per §3.
2. **Determine `mode`:** if `<target-type>` is `pr` AND `--no-loop` is absent AND `--in-loop` is absent → `mode = loop`; else `mode = oneshot`.
   **Recursion backstop — two independent, parser-visible layers.** *Belt:* the loop's inner self-call passes `--no-loop`, which forces the inner pass to `oneshot`. *Suspenders:* the inner self-call **also** passes an explicit `--in-loop` token in its `args`, and this step reads `--in-loop` from its **own** `args` and **hard-refuses loop mode (forces `oneshot`) if present** — so the refusal is structural even if `--no-loop` were ever dropped from the self-call. (Both channels are real command tokens this skill's own arg parser sees; there is no env var or out-of-band brief marker, because this step only reads its parsed `args`.)
3. **Validate loop-only-flag exclusivity (parse-time hard-fail):** `--max-iterations`, `--high-and-up-only`, `--no-smoke` are valid only when `mode == loop`. Passing any of them together with `--no-loop`, or with a non-`pr` target, is a hard-fail with a clear message (e.g. `--max-iterations is only valid on a looping pr target; it conflicts with --no-loop`). `--yes` and `--no-loop` are accepted no-ops where they don't apply (see §3) — they never hard-fail on their own.
4. If `mode == oneshot` → continue at §5A (one-shot machinery). Steps 5–7 below apply only to `mode == loop`.
5. **Loop preconditions** (hard-fail on any miss — never guess):
   - `--max-iterations`, if present, parses as an integer 1–8.
   - `gh` is on PATH (`command -v gh`) — fail with install instructions if not.
   - The PR exists and is open: `gh pr view <ref> --json state,headRefName,baseRefName,url`. Hard-fail on `state != OPEN` (closed/merged PRs can't be iterated).
   - The working directory is a git worktree on the PR's `headRefName` (or `cd` into one if a worktree for that branch exists locally). If neither: hard-fail with `multi-agent-review loops by default on a PR and needs a worktree on <headRefName>. Create one, or pass --no-loop for a one-shot read-only report.` **Never silently mutate the wrong branch.**
6. **Confirmation gate.** When loop mode was entered **implicitly** (no `--yes`), prompt and wait before mutating: `Looping will edit/commit/push on <headRef> across up to N rounds; proceed? (pass --no-loop for a read-only report)`. Do not start the loop until the user confirms. This is a hard gate, not a fire-and-forget notice — it is the guard against a caller who expected the pre-2.0 read-only `multi-agent-review pr 42`. `--yes` skips the gate for unattended/automated runs (the only way to loop without the interactive prompt). **Non-interactive contexts hard-fail, never hang:** if the gate is reached with no attached human and no `--yes`, exit with `multi-agent-review pr loops by default and needs confirmation; pass --yes to run unattended` rather than blocking forever on an unanswerable prompt — a forgotten `--yes` fails loudly, not silently deadlocks. If the user declines the gate interactively, abort the loop cleanly with no mutation (offer `--no-loop` as the read-only alternative).
7. Continue at §5B (loop machinery).

### 5A. One-shot machinery (read-only)

Reached when `mode == oneshot` (any `--no-loop` run, any `--in-loop` inner pass, or any non-`pr` target). Execute these steps in order:

### 5A.1 Parse and validate

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
   reviewer brief (§5A.3, §7) and the synthesizer brief (§5A.6, §8). When
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

### 5A.2 Resolve materials per target type

Each branch produces a **materials block** — a self-contained string that every reviewer brief will embed verbatim. Reviewers receive NO shared conversation state, so the materials block is the only way they see the target.

| Target type | Resolution steps |
|---|---|
| `pr <n\|url>` | If `gh` is not on PATH → hard-fail with install instructions. Run `gh pr view <ref> --json number,title,body,headRefName,baseRefName,files,author,url`. Run `gh pr diff <ref> --patch` (the `--patch` flag pins unified-diff output; do not rely on the default format) — if `gh pr diff` exits non-zero or emits an empty diff, hard-fail with the `gh` error output (do not proceed with an empty materials block). From the JSON, extract each changed file's path and resolve to absolute (relative to `git rev-parse --show-toplevel`). For fork PRs, files in the PR's file list may not exist in the local checkout; for any such file, include only its diff hunk in the materials block and note "file not available locally; review from diff only" — do NOT instruct reviewers to `Read` a path that does not exist on disk. If the diff exceeds 100 KB, emit a single-line warning to stderr and proceed without truncation. Materials block contains: PR metadata table, full diff, and the file list with absolute paths and an explicit instruction to read each in full. |
| `dir <path>` | Resolve to absolute. **Verify the path exists and is a directory** before invoking `git ls-files` — if it does not exist or is not a directory, hard-fail with the missing/invalid path. (An absent path silently produces an empty `git ls-files` output, which would yield a vacuous review.) Run `git ls-files <path>` (respects `.gitignore`). If the file count exceeds the cap (default 50, override via `--max-files`), abort with a message listing the count, the cap, **and the `--max-files <n>` override flag**; do not proceed. Materials block contains: the directory's absolute path, the file list with absolute paths, and an instruction to read each in full. |
| `file <path>` | Resolve to absolute. Verify the file exists and is readable. Reject if more than one path is given. Materials block contains: the absolute path and an instruction to read it in full. |
| `spec <p1> [<p2> ...]` | Resolve each path to absolute. Verify each exists and is readable. Materials block contains: the list of absolute paths and an instruction to read each in full. |
| `diff` (no paths) | Verify the cwd is inside a git repo (`git rev-parse --show-toplevel`). Run `git diff` (or `git diff --staged` if `--staged` was passed) — capture stdout. If the diff is empty, hard-fail with: `diff target has no changes` (or `... --staged hunks` when `--staged`). If the diff exceeds 100 KB, emit a warning to stderr (same threshold as PR diff) and proceed without truncation. Also enumerate changed files via `git diff --name-only` (with `--staged` when applicable) and resolve to absolute paths. Materials block contains: the diff mode label (`working-tree` or `staged`), the full diff, and the file list with absolute paths plus an instruction to read each in full (reviewers may want full-file context, not just hunks). |
| `slices <p1> <p2> [<p3> ...]` | **Fan-out target.** Each path is treated as its own `dir`-style sub-target — resolve each to absolute, verify each is a directory, run `git ls-files` per slice, enforce the same `--max-files` cap per slice (not globally). Reject if slice count exceeds `--max-slices` (default 6). Build one materials block PER SLICE (same shape as a `dir` materials block), labelled with the slice's relative path from `git rev-parse --show-toplevel`. The dispatch step (§5A.4) and synthesis step (§5A.6) treat slices specially: every reviewer runs once per slice in parallel, and a single cross-slice synthesizer merges all `len(roster) × len(slices)` outputs into one report organised by slice. |

> **Reviewer tool requirements:** For `dir`, `file`, and `spec` targets, the materials block delegates file reads to the reviewer agents. **Reviewer agents must therefore have `Read` (and `Glob`/`Grep` for `dir`) in their own `allowed-tools` frontmatter.** The skill's `allowed-tools` governs only the orchestrator. If a reviewer lacks `Read`, it will return an empty or hallucinated report; verify each rostered reviewer's `allowed-tools` before opting an unfamiliar agent into the roster. Alternative: embed the file contents directly into the materials block (this skill currently does not, to keep brief size bounded).

### 5A.3 Build reviewer briefs

For each reviewer in the roster, expand the [Reviewer brief template](#7-reviewer-brief-template) with the values resolved above. The brief must be self-contained — the agent will not see this skill's conversation.

**Placeholder values to fill in:**

| Placeholder | Source |
|---|---|
| `{{REVIEWER_NAME}}` | The reviewer's agent name (the current entry in the roster). |
| `{{TARGET_TYPE}}` | The resolved target type from §5A.1 (`pr` / `dir` / `file` / `spec` / `diff` / `slices`). |
| `{{MATERIALS_BLOCK}}` | The materials block from §5A.2 (verbatim, same for every reviewer in a non-`slices` invocation; per-slice for `slices`). |
| `{{REVIEWER_ROLE_DESCRIPTION}}` | The reviewer's role description (see resolution rule below). |
| `{{PROJECT_PRELUDE}}` | The contents of the `--prompt-prelude` file from §5A.1 step 9. Empty string when the flag is absent — in that case strip the entire `## PROJECT PRELUDE` block (heading + body) from the template before dispatch. |
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

### 5A.4 Spawn reviewers IN PARALLEL

> ⚠️ **PARALLELISM RULE — DO NOT SERIALIZE**
>
> All reviewer `Agent` tool calls MUST be issued in a SINGLE assistant message containing N parallel tool invocations. Do NOT spread them across multiple turns. If the roster has N reviewers, the orchestrator message contains exactly N `Agent` tool uses, all dispatched together.
>
> Each call MUST set:
> - `subagent_type` to the reviewer's agent name.
> - `description` to `"Multi-agent review: <reviewer-name>"` (for `slices`, append ` (<slice-label>)`).
> - `prompt` to the fully-expanded reviewer brief (see §7).
>
> **Note:** `subagent_type` must match an available agent type at runtime (as registered by the Claude Code Agent tool — typically derived from the canonical filename of an active `.claude/agents/*.md` or `~/.claude/agents/*.md` file). If an invalid value is passed, the Agent tool will reject the call. The parse-time validation in §5A.1 reads the same on-disk agent files and is meant to catch this before dispatch, but the Agent tool's live schema is the ultimate authority.
>
> **`slices` dispatch shape.** For a `slices` invocation with roster size N and slice count M, the single dispatch message contains **N × M** `Agent` tool uses, one per (reviewer, slice) pair, all issued together. Build one fully-expanded brief per pair using the slice's per-slice materials block (§5A.2) and the slice's label as `{{SLICE_LABEL}}`. Do not serialise slices: a 3-reviewer × 5-slice review must spawn 15 agents in one assistant message, not 5 sequential 3-agent messages. The `--max-slices` cap (default 6, override per §3) bounds the explosion.

### 5A.5 Collect outputs

After all reviewers return, capture each reviewer's output verbatim, keyed by reviewer name in the order they appeared in the roster. Do not edit, summarize, reformat, or filter at this stage.

For `slices` targets, key each output by `(slice-label, reviewer-name)` so the synthesizer can render findings under per-slice subheadings. Preserve slice order from the command line and reviewer order from the roster — both are deterministic inputs to the cross-slice synthesis.

### 5A.6 Invoke synthesizer

Expand the [Synthesizer brief template](#8-synthesizer-brief-template) with:
- `{{SYNTHESIZER_NAME}}` = the resolved synthesizer (default `knowledge-synthesizer`).
- `{{N_REVIEWERS}}` = the roster size.
- `{{HIGH_CAP}}` = the resolved `--high-cap` value (default `8`; literal `off` when the caller passed `--high-cap off`). Parsed in §5A.1; values other than a positive integer or the literal `off` hard-fail before any agent is spawned.
- `{{TARGET_TYPE}}` = the resolved target type.
- `{{PROJECT_PRELUDE}}` = the contents of the `--prompt-prelude` file (§5A.1 step 9). Empty string when absent — in that case strip the entire `## PROJECT PRELUDE` block from the synthesizer brief before dispatch (no orphan heading).
- `{{MATERIALS_BLOCK}}` = the same materials block from §5A.2. For `slices`, expand to the concatenation of every per-slice materials block, each preceded by a `### Slice: <slice-label>` heading and a `---` separator.
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

### 5A.7 Print verbatim

Print the synthesized report verbatim as the final assistant message. If
`--write-to` was set, prepend exactly one line — `Wrote: <absolute path>` —
followed by the verbatim report; otherwise emit no preamble and no
postscript.

When `--write-to <path>` is set:
1. The overwrite guard already ran in §5A.1 — the destination is known to
   be writable at this point. (If it existed and `--force` was not set,
   the skill exited early with no reviewer agents spawned.)
2. Create parent directories as needed (`mkdir -p`).
3. Write the synthesizer's output to `<path>`.
4. Print the `Wrote: <absolute path>` line, then the synthesizer's output verbatim.

**Synthesizer-failure fallback with `--write-to`:** if the synthesizer
fails (see §11) AND `--write-to` was set, still write a file at `<path>`
containing a single header line noting the synth failure, followed by
each reviewer's verbatim output with delimiters. Better to persist the
raw reviewer outputs than to discard them by silently skipping the
write. Then print the same content to stdout (with the leading
`Wrote: <absolute path>` line).

### 5B. Loop machinery (mutating; `pr` target, default mode)

Reached when `mode == loop` — the preconditions and confirmation gate in §5.0 have already passed. The coordinator (you, the agent running this skill) runs a bounded review→fix→re-review loop against the open PR, following the per-round protocol in **§10** exactly:

1. **Initialize loop state** (§10.1): TodoWrite-style task list, iteration counters, finding fingerprints.
2. **Per round:** dispatch a **fresh subagent** whose brief instructs it to run the one-shot review via
   `Skill(skill="multi-agent-review", args="pr <ref> --no-loop --in-loop --high-cap off <pass-through review flags>")`
   — the self-call carries `--no-loop` (forces the inner pass one-shot), `--in-loop` (the parser-visible recursion backstop §5.0 hard-refuses on), and `--high-cap off` (keeps every HIGH visible to the iteration gate — see §4). Pass-through flags are `--reviewers`/`--synthesizer`/`--mode`/`--prompt-prelude` only; never forward loop-control flags. (§10.2)
3. **Triage** the round's findings: CRITICAL/HIGH auto-action, MEDIUM coordinator judgment, LOW comment-only; fingerprint findings for regression detection. (§10.3)
4. **Apply fixes inline** (the coordinator edits — not delegated), run unit tests + smoke gate with revert-on-regression. (§10.4)
5. **Commit scoped paths + push.** (§10.5)
6. **Repeat** until APPROVE, max-iterations, or a safety stop fires (§10.6); then emit the final report + PR comment + follow-up issues (§10.7).

> **Critical correctness note — the inner-invocation grammar was REWRITTEN for v2, not copied.** The pre-2.0 loop's fallback chain (`args="<n>"` → `args="PR <n>"` → no-args) is **deleted**: none of those forms carry `--no-loop`/`--in-loop`, and every one of them would now recurse, because the base command loops by default. Every fallback form of the §5B self-call MUST append `--no-loop --in-loop --high-cap off` (and must not pass loop-control flags) so the fresh subagent runs a single read-only pass with all HIGHs surfaced. The old chain assumed the inner skill was one-shot by default; that assumption is now false and inverted.

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

## 10. Loop coordinator details

The per-round protocol for §5B. The coordinator MUST follow these steps in order each round. (The one-shot skill invoked inside each round is read-only by construction — the fix step lives here, in the coordinator, not in the review subagent.)

### 10.1 Initialize loop state

Create a TodoWrite-style task list — one task per planned iteration plus a final "summarize and close" task — to make progress visible. Initialize:

- `iterationsCompleted = 0`
- `findingsFixedThisRun = { CRITICAL: 0, HIGH: 0, MEDIUM: 0, LOW: 0 }`
- `findingsDeferredThisRun = { MEDIUM: [], LOW: [] }`
- `priorFindingsFingerprints = Set<string>` (used in §10.6 for regression detection)

### 10.2 Per-iteration: dispatch the review subagent

For iteration `N = 1, 2, …, maxIterations`:

1. Spawn a **fresh general-purpose subagent** via the `Agent` tool. The brief MUST be self-contained — the subagent has no shared context with the coordinator.

2. The subagent brief MUST include:
   - The repo's worktree path (absolute).
   - The PR number and the branch name.
   - The instruction: `Skill(skill="multi-agent-review", args="pr <pr-ref> --no-loop --in-loop --high-cap off <pass-through review flags>")` — where `<pass-through review flags>` is exactly the caller's `--reviewers`/`--synthesizer`/`--mode`/`--prompt-prelude` (never the loop-control flags, never `--high-cap`).
   - **Hard rule:** "Do NOT apply any fixes. Report-only. The orchestrator session applies fixes."
   - The required output schema:
     ```
     VERDICT: APPROVE | NEEDS_CHANGES | BLOCK

     ## CRITICAL
     - <file_path>:<line> — finding — fix recommendation

     ## HIGH
     - ...

     ## MEDIUM
     - ...

     ## LOW
     - ...

     ## Notes
     - any reviewer disagreements
     - any tool-availability failures (e.g. "Agent tool not exposed to subagent — reviewers ran inline")
     ```
   - The inner self-call's fallback forms — **every form MUST carry the recursion guard.** Primary: `args="pr <n> --no-loop --in-loop --high-cap off <pass-through flags>"`. If that fails to resolve, retry once with the PR URL in place of the number: `args="pr <url> --no-loop --in-loop --high-cap off <pass-through flags>"`. NEVER issue a form without `--no-loop --in-loop --high-cap off` — the base command loops by default, so a bare self-call would recurse. If both forms fail, list the inner skill's installed location (e.g. `~/.claude/plugins/.../multi-agent-review/skills/multi-agent-review/SKILL.md`) and stop.

3. **Subagent-dispatch precondition check**: the brief MUST instruct the subagent to verify the `Agent` tool is available in its environment before invoking the inner skill. If it is not, the subagent MUST emit a `## Notes` line saying so and execute the four reviewer lanes inline (one agent role-playing four, scoped strictly to the reviewer agent files), then synthesize. The coordinator should weight findings from an inline-fallback round less than a true-parallel round (treat one HIGH as one HIGH, but don't trust "no disagreements" — the same author found all four lanes).

### 10.3 Per-iteration: triage findings

When the subagent returns:

1. If VERDICT = APPROVE → break the loop. Goto §10.7.

2. Compute a fingerprint for every finding: `sha256(file_path + line + finding_one_line_summary)`. If the same fingerprint appeared in `priorFindingsFingerprints` AND the prior round claimed it was fixed → STOP the loop and emit the "regression detected" report (§10.6). Either the fix didn't land or the reviewer is mis-flagging; either way it's a human-judgment moment, not a coordinator-fixable one.

3. Otherwise, partition findings:
   - **Auto-action**: every CRITICAL and HIGH.
   - **Coordinator judgment**: every MEDIUM. The coordinator decides per-finding whether to fix or defer based on (a) whether the fix is small (< ~20 LOC), (b) whether the fix risks regressions, (c) whether the finding actually applies to this PR vs. is a pre-existing pattern smell. Default for `--high-and-up-only`: auto-defer all MEDIUM.
   - **Defer to comment**: every LOW. Never iterate on LOW.

4. Add new finding fingerprints to `priorFindingsFingerprints`.

### 10.4 Per-iteration: apply fixes

For each finding the coordinator decided to fix:

1. Edit the affected file(s) in the worktree using the `Edit` / `Write` tools.
2. After all edits for the round are in, run the project's unit tests for the affected module. Read the project's CLAUDE.md or the inner skill's notes for the test command (examples: `pytest path/to/module`, `./gradlew :module:test`, `npm test -- path/to/module`).
3. If tests regress → STOP. Revert (`git checkout -- <paths>`), emit a "test regression on round N" report, surface the failing test output to the user, do NOT push.
4. If a fix touched code paths the live smoke covers AND `--no-smoke` is not set → run the smoke. If smoke fails, same treatment as test regression.
5. Regenerate any auto-maintained docs if any tracked file was added/renamed (e.g. `ARCH.md` generators wired into a pre-commit hook). Check the project's CLAUDE.md for the regen command.

### 10.5 Per-iteration: commit + push

1. `git add` the specific touched paths (do not use `git add -A`).
2. Commit with `git commit -m "fix(<scope>): address review round N findings — <one-line summary>"`. If the project's pre-commit hook is known to fail silently under the Claude Code harness (a documented gotcha in some setups), pre-stage any auto-regenerated docs by hand and use `git -c core.hooksPath=/dev/null commit …` as the documented escape hatch.
3. The commit body should list the addressed findings by `file_path:line` so the PR diff history reflects the review-iteration trail.
4. `git push` to update the PR.
5. Increment `iterationsCompleted` and update `findingsFixedThisRun` counters.

### 10.6 Loop control & safety stops

Continue the loop only if:

- VERDICT was NEEDS_CHANGES or BLOCK (not APPROVE).
- `iterationsCompleted < maxIterations`.
- No regression (§10.3 step 2).
- No test/smoke failure (§10.4 steps 3-4).

If any stop condition fires, emit the final report (§10.7) explaining which condition stopped the loop. **Never silently continue past a stop condition** — surface it.

### 10.7 Final report

Print a single structured report:

```
# Review loop report — PR #<n>

Final verdict: APPROVE | STOPPED_<reason>
Iterations completed: <N>
Iterations cap: <max>

## Findings fixed
- CRITICAL: <count>
- HIGH: <count>
- MEDIUM: <count>

## Findings deferred (filed as PR comment / follow-up issue)
- <list, with severity + file:line + reason for deferral>

## Findings remaining (only if STOPPED_*)
- <full list of unresolved findings from the last round>

## Notes
- <reviewer-tool-availability flags from each round>
- <reviewer disagreements that the coordinator adjudicated>

## Next action
<one-sentence recommendation to the user>
```

Additionally:

1. **Post a single PR comment** with `gh pr comment <ref> --body ...` containing both the loop summary (as above) AND, appended below it, the per-round detail from §10.7a — one comment total, not one per round. This keeps the full audit trail on the PR without flooding the thread.
2. **File a follow-up issue** for every deferred MEDIUM that survives the loop (LOW items get inlined into the PR comment instead — don't pollute the issue tracker with style nits).

### 10.7a Per-round detail (appended to the same comment)

Below the final-report body (§10.7's structured report), append one collapsible section per round that actually produced findings or changed the verdict — skip a round only if it's a bare repeat APPROVE with nothing new to show, since the final report above already states the outcome:

```markdown
## Per-round detail

<for each round 1..N with findings or a verdict change>
<details>
<summary>Round <N> — <VERDICT></summary>

#### CRITICAL
- none / <each finding with file:line, description, suggested fix>

#### HIGH
- none / <each finding with file:line, description, suggested fix>

#### MEDIUM
- none / <each finding with file:line, description, suggested fix>

#### LOW
- none / <each finding with file:line, description, suggested fix>

#### Notes
- <round's Notes: tool-availability flags, reviewer disagreements — exactly the `## Notes` block the round's subagent returned per §10.2 step 2>

</details>
<end for each round>
```

**Scope note:** this is *per-round* detail, not *per-reviewer* — the round subagent's return schema (§10.2 step 2) is one aggregated VERDICT + severity-bucketed findings list per round, with no per-reviewer attribution. Don't invent a reviewer-by-reviewer breakdown the coordinator was never given; if that attribution is wanted later, the round schema needs a `## By reviewer` section added first.

**Size guard:** GitHub caps a single comment body at 65,536 characters. Before posting, estimate the combined length; if it would exceed ~55,000 chars (headroom for the summary), drop the oldest rounds' `<details>` blocks first (they're superseded by later rounds' findings anyway) and add a one-line note stating how many earlier rounds were omitted and why — never truncate silently.

**Failure handling:** if `gh pr comment` fails (rate limit, permissions, network), retry once; if it still fails, fall back to printing the full comment body to the user with a note that it could not be posted, so the record isn't lost entirely.

**Notes:**
- Use `<details>` tags to keep the PR thread readable.
- Include even an all-APPROVE round's entry only if it's the round that ended the loop (so the reader sees the closing state); earlier bare-repeat APPROVE rounds are redundant with the final verdict and can be skipped per the scope rule above.

## 11. Error handling

| Condition | Action |
|---|---|
| Missing or invalid `<target-type>` | Hard-fail with a one-line usage summary. Do not spawn agents. |
| `gh` not on PATH and target is `pr` | Hard-fail with: `gh CLI is required for PR review. Install: https://cli.github.com/`. |
| `gh pr diff` fails or returns empty | Hard-fail with the `gh` error output (stderr) — do not proceed with an empty materials block. |
| Loop-only flag (`--max-iterations`/`--high-and-up-only`/`--no-smoke`) combined with `--no-loop` or a non-`pr` target | Parse-time hard-fail with a clear message (e.g. `--max-iterations is only valid on a looping pr target; it conflicts with --no-loop`). Prevents a caller silently believing a loop-tuning flag took effect on a one-shot run. |
| Default-loop precondition unmet (no worktree on `headRefName`) | Hard-fail: `multi-agent-review loops by default on a PR and needs a worktree on <headRefName>. Create one, or pass --no-loop for a one-shot read-only report.` Never guess a branch to mutate. |
| PR `state != OPEN` in loop mode | Hard-fail — closed/merged PRs can't be iterated. |
| Confirmation gate reached non-interactively without `--yes` | Hard-fail with `multi-agent-review pr loops by default and needs confirmation; pass --yes to run unattended` — never hang on an unanswerable prompt. |
| Confirmation gate declined interactively | Abort the loop cleanly, no mutation; suggest `--no-loop` for a read-only report. |
| Recursion guard | The loop's inner self-call must carry `--no-loop` **and** `--in-loop`; §5.0 reads the parser-visible `--in-loop` token from its own `args` and forces `oneshot` when present — the structural backstop even if `--no-loop` were dropped. |
| `--high-cap <n>` passed on a looping `pr` target | Warn that it is overridden to `off` in loop mode (the loop forces `--high-cap off` on every inner pass); do not silently drop it. |
| Inner self-call fails to resolve (loop round) | Retry once with the PR URL form (still carrying `--no-loop --in-loop --high-cap off`); if both fail, list the inner skill's installed location and stop the loop. |
| `dir` target path does not exist or is not a directory | Hard-fail with the missing/invalid path; do not run `git ls-files` against it (which would silently emit empty output and produce a vacuous review). |
| Directory has > `--max-files` files | Hard-fail with the count, the cap, and the override flag (`--max-files <n>`). |
| `file` target has more than one path | Hard-fail. Tell the user: for multiple files use `dir <shared-directory>` if they share a directory, otherwise issue separate `file` invocations. `spec` is only for multiple markdown specification documents — do not suggest it for non-markdown file sets. |
| Path doesn't exist (`file` or `spec`) | Hard-fail with the missing path; do not silently skip. |
| Unknown reviewer or synthesizer name | Hard-fail before any agent is spawned, with the union of known names from `.claude/agents/` and `~/.claude/agents/`. |
| `--write-to` destination exists, no `--force` | Hard-fail in §5A.1, BEFORE any reviewer agent is spawned (don't waste N agent calls). |
| Reviewer agent fails or returns empty output | Continue with the remaining reviewers' outputs. Note the failed reviewer in the synthesizer brief as `<reviewer-name>: [FAILED — no output]` so the synthesizer can flag it in "Reviewer Disagreements". |
| Synthesizer fails | Print: `Synthesizer <name> failed. Reviewer outputs follow:` then dump each reviewer's verbatim output with delimiters. If `--write-to` was also set, write the same content to the destination path with a leading header noting the synth failure (see §5A.7) — better to persist raw material than discard it. |
| PR diff > 100 KB | Emit a warning to stderr (`warning: PR diff is <n>KB; reviewers may truncate`) and proceed. Do NOT auto-truncate. |
| `diff` target outside a git repo | Hard-fail: `diff target requires a git repository (cwd: <pwd>)`. |
| `diff` target has empty diff | Hard-fail: `diff target has no working-tree changes` (or `… no staged hunks` when `--staged`). Do not proceed with empty materials. |
| `--staged` without `diff` target | Hard-fail at parse time: `--staged is only valid with the diff target`. |
| `slices` with fewer than 2 paths | Hard-fail at parse time: `slices target requires at least two directory paths; use 'dir' for a single directory`. |
| `slices` exceeds `--max-slices` | Hard-fail with the count, the cap, and the `--max-slices <n>` override flag. Default cap 6 keeps the agent-fanout (N × M) bounded; lift it deliberately, not accidentally. |
| `--prompt-prelude` path missing | Hard-fail: `--prompt-prelude file not found: <abs-path>`. |
| `--prompt-prelude` > 16 KB | Hard-fail: `--prompt-prelude file is <n>KB; cap is 16KB. Split or trim it.` Large preludes pollute every reviewer brief with low-signal context. |
| Test or smoke regression during a loop fix round | STOP: revert the round's edits (`git checkout -- <paths>`), emit the regression report, surface the failing output, do NOT push (§10.4). |
| Same finding fingerprint reappears after a claimed fix | STOP the loop and emit the "regression detected" report (§10.3 step 2 / §10.6) — a human-judgment moment, not a coordinator-fixable one. |

## 12. Anti-patterns

- **Don't delegate the fix step to another subagent.** Triage requires project context; sub-fixers without that context produce sloppy patches the coordinator then has to re-review.
- **Don't loop on LOW findings.** A LOW today is a LOW tomorrow; iterating on style nits is the treadmill failure mode.
- **Don't auto-merge after APPROVE.** The human owns merge approval. The loop ends at "ready for human review," not "merged."
- **Don't run the smoke test on every round.** Smoke is expensive (port binding, DB, full app boot). Run only when the fix actually touched code the smoke exercises.
- **Don't suppress reviewer disagreements.** When two lanes contradict, the coordinator picks the safer side and **says so** in the round's commit message and the final report.
- **Don't accept a "no disagreement" claim from an inline-fallback round at face value.** Same author found all four lanes; disagreements were suppressed by construction.

## 13. Resolved decisions

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
| 14 | Default mode on a `pr` target | Loop (review→fix→re-review) by default, entered via a **confirmation gate** (skip with `--yes`); `--no-loop` restores one-shot read-only | The loop is the higher-value default for the mutate-and-re-test cadence a PR affords; one-shot stays one flag away. An implicit loop prompts before it edits/commits/pushes; `--yes` is the explicit consent for unattended runs. Non-`pr` targets are always one-shot (no branch to push fixes to — dir/file/spec/diff/slices have no "apply fix and re-review" cadence). |
| 15 | Opt-out flag name | `--no-loop` | No collision with existing flags; parallels `--no-smoke`; exact inverse of the new default. |
| 16 | Loop-control flags are loop-only | `--max-iterations`/`--high-and-up-only`/`--no-smoke` hard-fail with `--no-loop` or a non-`pr` target | Prevents a caller silently believing a loop-tuning flag took effect on a one-shot run. |
| 17 | `/multi-agent-review-loop` disposition | **Removed outright (no alias)**; all callsites migrated to `multi-agent-review pr <ref>` | One real entrypoint beats maintaining a second skill+command surface forever; the migration is a bounded one-time edit (3 plugins + issue #47 + config), shipped atomically so nothing dangles. (Reversed the earlier permanent-alias call, 2026-07-11.) |
| 18 | Inner self-call recursion guard | The loop's fresh-subagent review pass calls `multi-agent-review pr <ref> --no-loop --in-loop` | Two parser-visible layers: `--no-loop` forces the inner pass one-shot; `--in-loop` makes §5.0's refusal structural even if `--no-loop` were dropped. Without them the default-loop would recurse infinitely. |
| 19 | Version bump | `1.1.0` → `2.0.0` | Default side-effect profile of the primary command flips read-only → mutating; backward-incompatible per semver. |
| 20 | Max iterations default | 3, hard ceiling 8 | Most issues caught in round 1; 3 catches fix follow-ons; > 8 indicates a fundamental disagreement, not a mechanical loop. |
| 21 | Fix step in the coordinator, not a sub-fixer | Coordinator applies fixes inline | Coordinator has project context (which MEDIUMs apply to this PR vs. project-wide; which findings the human author would push back on); a sub-fixer has neither and produces over-eager patches. |
| 22 | LOW findings never iterate | Comment-and-defer | Iterating on LOW is the treadmill failure mode that makes the loop useless. |
| 23 | Regression detection (same-fingerprint twice) | Stop loop, surface to human | Either the fix didn't land or the reviewer is wrong; coordinator can't adjudicate that. |
| 24 | `--high-and-up-only` flag | Opt-in | Some teams want MEDIUM judgment in the loop; some want only CRITICAL/HIGH discipline. Default is "judgment", flag is "discipline". |
| 25 | Inline-fallback round handling | Run the loop, weight disagreements less | The inner skill can't guarantee subagent-of-subagent dispatch; refusing to loop in that case would block the skill on a tooling problem unrelated to its purpose. |
| 26 | Smoke gate trigger | Project-specific touched-path heuristic + `--no-smoke` escape hatch | Always-on smoke makes the loop too expensive; never-on smoke makes connector-loop regressions invisible until merge. Heuristic + opt-out is the middle. |
| 27 | PR comment + follow-up issue at loop end | Always | The PR's review history should reflect what happened; deferred MEDIUMs need a place to live so they aren't forgotten. |

## 14. Composition with other skills

- **Inside loop mode, the coordinator MAY use** `tdd`, `diagnose`, language-specific reviewers (`kotlin-review`, `python-review`, …), or project-specific skills when applying fixes. A one-shot `multi-agent-review … --no-loop` run outside the loop's subagent dispatch is fine for a one-off sanity check after a controversial fix.
- **Loop mode MUST NOT be invoked from inside another loop skill** (e.g. `baton-runner`, `multi-agent-developer`, `code-rinse-repeat`). Nested loops create non-deterministic finish conditions and exponential agent fan-out. One-shot mode is safe to embed — that is exactly what the loop's own inner rounds (and orchestrators like `code-rinse-repeat`) do.
