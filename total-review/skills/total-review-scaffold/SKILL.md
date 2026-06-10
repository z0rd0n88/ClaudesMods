---
name: total-review-scaffold
description: Bootstrap a project wrapper for the total-review pattern. Detects stack (python/kotlin/ts), reads ARCH.md for slice candidates, activates required agents, and writes .claude/skills/<slug>-total-review/{SKILL.md, config.yml}. Use when setting up multi-agent code review for a new repo.
---

# total-review-scaffold

One-time bootstrap for the [`total-review`](../total-review/SKILL.md) pattern in a fresh repo. Produces the project wrapper skill, its config, and activates the agents the default matrix references.

## When to invoke

- New owned repo where you want `/<slug>-total-review` available.
- An existing repo whose review workflow has drifted (rerun is idempotent — it diffs against existing files and asks before overwriting).

## Prerequisites

- Cwd is the repo root.
- `ARCH.md` exists at the repo root (auto-maintained by `.githooks/pre-commit` per `~/.claude/rules/common/architecture-mapping.md`).
- `gh auth status` is clean (the scaffold suggests a tracker query; the user can edit).
- A worktree on a non-`main` feature branch per the CLAUDE.md hard rule. The scaffold writes tracked files; doing it on `main` defeats PR review.

## Workflow

1. **Sanity-check.** Confirm cwd is a git repo root with an `ARCH.md`. If on `main`, refuse and instruct: `git worktree add .worktrees/total-review-init -b chore/total-review-init main`.

2. **Detect stack.** Probe in this order, return the first match:
   - `pyproject.toml` or `setup.py` → `python`
   - `build.gradle.kts` or `settings.gradle.kts` or `*.kt` files at depth ≤ 3 → `kotlin`
   - `package.json` (without `next` dep) → `typescript`
   - Multiple matches → `multi`; ask user via `AskUserQuestion` to pick the primary stack (overlays for the others can be added by hand to config later).

3. **Propose slug.** Default = repo directory name (lowercased). Ask user to confirm or override.

4. **Propose slices from ARCH.md.** Parse `ARCH.md` between `<!-- ARCH:DESC -->` and `<!-- /ARCH:DESC -->` markers (curated Key Paths block). Each line of the form `- \`<path>\` — <description>` is a slice candidate. If no marker block, fall back to top-level directories under `src/` (or repo root if no `src/`). Show user the proposed slice list via a single `AskUserQuestion` summary; user confirms or edits. Default slice slugs: derived from path's last component (e.g. `src/foo/domain` → `domain`).

5. **Compute effective agent set.** From [`~/.claude/skills/total-review/REFERENCE.md`](../total-review/REFERENCE.md)'s default matrix, take the generic baseline ∪ the stack overlay across all canonical modes. Examples by stack:
   - **python**: `code-reviewer, python-reviewer, python-pro, refactor-cleaner, unused-code-cleaner, security-reviewer, code-architect, critical-thinking, silent-failure-hunter, tdd-guide, performance-optimizer, sql-pro, documentation-expert, code-explorer`
   - **kotlin**: replace python ones with `kotlin-reviewer`; drop `python-pro`/`sql-pro` unless project hits SQL.
   - **typescript**: replace with `typescript-reviewer` (gap — flag the missing parked agent).

6. **Activate agents.** For each agent name in the effective set, find the matching file in `~/.claude/agents-parked/` by `name:` frontmatter (since filenames are often `ecc-`-prefixed but internal names aren't). For each found file:
   - Copy to `<repo>/.claude/agents/<filename>` if not already present.
   - If destination exists with different content, ask user before overwriting.
   - If the agent isn't parked, warn loudly: `Agent <name> not in agents-parked/; project must provide before /<slug>-total-review will work end-to-end.`
   
   `git add` the copied agent files but don't commit.

7. **Suggest tracker config.** Detect the GitHub remote (`gh repo view --json nameWithOwner -q .nameWithOwner`). Default `exclusion_query`:
   ```
   gh issue list --repo <owner>/<repo> --state open --limit 30 \
     --label review,tech-debt,security,performance,architecture \
     --json number,title,body
   ```
   Ask user via `AskUserQuestion` for: cross-ref phrase (e.g. `Refs #2` if there's a meta-tracker issue, else empty); whether to use `review-finding` or `review` as the primary label.

8. **Write wrapper files.** Generate:
   - `<repo>/.claude/skills/<slug>-total-review/SKILL.md` from the template below.
   - `<repo>/.claude/skills/<slug>-total-review/config.yml` from the template below, substituting slug/stack/slices/tracker.
   
   `git add` both. Do not commit (the user is in their worktree; they commit when ready).

9. **Print next steps.** Show:
   ```
   ✓ Scaffold complete. Files staged (not yet committed):
       .claude/skills/<slug>-total-review/SKILL.md
       .claude/skills/<slug>-total-review/config.yml
       .claude/agents/*.md  (N activated)
   
   Next:
       git status                          # review staged files
       <edit slices/lenses in config.yml as needed>
       git commit -m "feat: scaffold <slug>-total-review skill"
       gh pr create
   
   After the wrapper lands on main, /<slug>-total-review will be available.
   ```

## Wrapper SKILL.md template

```markdown
---
name: <slug>-total-review
description: Multi-agent codebase review for <project-noun>. Modes — code, cleanup, security, architecture, test, perf, docs, pre-pr. Triggers on /<slug>-total-review or "review pass", "security sweep", "architecture audit", "pre-PR triage".
---

# <slug>-total-review

Project wrapper for the shared [`total-review`](~/.claude/skills/total-review/SKILL.md) pattern. Follow `~/.claude/skills/total-review/REFERENCE.md` step-by-step using this directory's `config.yml`. Read this repo's `ARCH.md` first.

Quick start, mode catalog, and worked examples — see the shared REFERENCE.md.

## Project-specific notes

<-- Optional: invariants that aren't already in config.yml, repo-specific gotchas,
    common false positives reviewers should be told to skip. -->
```

## config.yml template

```yaml
project:
  slug: <slug>
  stack: <python|kotlin|typescript|multi>
  invariants:
    # Inserted verbatim into every reviewer prompt. Project rules that must hold.
    - "<invariant 1>"
    - "<invariant 2>"

slices:
  <slug>:
    path: <relative path from repo root>
    lenses: [<agent names — per-slice allowlist of lenses>]
  # ...

modes:
  # Optional. Only override canonical defaults when needed.
  # Example overrides:
  # security:
  #   agents: [security-reviewer, <my-custom-auditor>]
  # disabled: [perf]    # if mode isn't applicable
  # add:
  #   <new-mode>:
  #     agents: [<agent>]
  #     slices: [<slice>, <slice>]
  #     files_issue: true
  #     word_cap: 1200

tracker:
  exclusion_query: |
    gh issue list --repo <owner>/<repo> --state open --limit 30 \
      --label review,tech-debt,security,performance,architecture \
      --json number,title,body
  file_issue: |
    gh issue create --repo <owner>/<repo> --title "{title}" --body-file - --label review
  title_template: "{mode} review: {crit} CRITICAL · {high} HIGH · {med} MEDIUM · {low} LOW"
  cross_ref_phrase: "<e.g. Refs #2; empty string if no meta-tracker>"
```

See [`REFERENCE.md`](REFERENCE.md) for the agent-activation algorithm and stack-detection details.
