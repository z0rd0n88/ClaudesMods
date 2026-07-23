---
name: claude-md-trim
description: Use when always-loaded agent context files (CLAUDE.md/AGENTS.md/GEMINI.md) are long, noisy, or stale and need trimming to invariants + pointers, or when session/git logs should be mined for missing guidance; one repo or many.
---

# CLAUDE.md Trim — Signal-to-Noise for Always-Loaded Context

## Overview

Context files (CLAUDE.md / AGENTS.md / GEMINI.md) load into every session's prompt budget. Target state: **invariants + pointers only** — rules every code change needs, cross-module contracts, short gotchas, and links. Everything else moves to linked docs. The operation is **relocation + compression, never deletion**, and never changes an invariant's meaning.

**The litmus test for every line:** *does every code change in this repo need this loaded?* If not, it moves behind a link.

## When to Use

- A CLAUDE.md exceeds ~150 lines or contains: step-by-step procedures, verbose config tables, incident write-ups, shipped-feature changelogs, "next steps" sections, code examples.
- Facts in a context file contradict the code or a status doc (drift).
- When NOT to use: files that are already invariants + pointers; third-party/vendored files; modules slated for deletion (excluding them IS part of this skill's scope rules).

## Inputs

| Parameter | Default |
|---|---|
| PROJECTS | current repo. Multiple: user lists repo paths — process each **sequentially and completely** (own worktree, own trim, own PR) before starting the next. Never share a branch or PR across repos. |
| CONTEXT_FILES | `git ls-files '*CLAUDE.md' '*AGENTS.md' '*GEMINI.md'` per repo |
| DETAIL_HOMES | the repo's own convention if declared (read the root context file's doc-hygiene rule — it overrides these defaults); else `docs/guide/<topic>.md` (how-to/reference) and `docs/progress/<module>-status.md` (status that drifts), created as needed |
| EXCLUSIONS | deprecated/slated-for-deletion modules, third-party-owned files — list them in the summary with the reason; do not edit |

## Per-Repo Process

**1. Base freshness (do this FIRST).** `git fetch`, then `git rev-list --left-right --count HEAD...origin/<default>`. Fast-forward or rebase onto the current remote default branch. A stale base silently trims content that no longer exists. Check for prior trim attempts (`gh pr list --search "CLAUDE.md trim"`): read them for scope hints only; start from today's default branch and state in the PR that this supersedes them.

**2. Isolation.** Dedicated worktree, feature branch, absolute paths. Never edit the default branch.

**3. Discovery.** Enumerate CONTEXT_FILES; record per-file line counts (the PR needs a before/after table, including untouched and excluded files with reasons); read every in-scope file fully; note recent history (`git log --oneline -- '*CLAUDE.md'`) — recent rewrites/renames change what "current" means.

**4. Mine session + git logs for missing signal.** The trim removes noise; this step finds what the context files *should* say but don't. Sources:
- **Git log:** repeated fix subjects (`git log --pretty='%s' | sort | uniq -c | sort -rn` filtered to `fix|revert`) — a defect fixed twice is a regression class worth a gotcha. Most-churned files (`git log --name-only --pretty=format: -150 | sort | uniq -c | sort -rn`) show where guidance drifts or is missing.
- **Session logs / transcripts** (e.g. `~/.claude/projects/<project>/*.jsonl`): aggregate tool errors (`is_error` results), user rejections, and correction-shaped user messages; also read any distilled auto-memory index. Aggregate with a script — never page raw transcripts into context.
- **Landing filter — a mined candidate is added only if it passes all three:** (a) verified against ground truth (read the actual fix commits / code before writing the gotcha); (b) not already documented at its point of use (a trap covered in the relevant skill/guide/tracked issue does not get re-added); (c) placed per the hygiene rule — gotcha/guide docs by default, the context file itself only if every code change needs it loaded.

**5. Classify each section (KEEP or MOVE), verifying everything carried forward:**
- **KEEP** (possibly compressed): invariants, safety rules, cross-module contracts, short gotchas, links. Compression must not change meaning.
- **MOVE** to DETAIL_HOMES: procedures, setup, config detail, code examples, incident narratives, status sections. Create the target doc if missing; leave a one-line pointer + link.
- **VERIFY** everything before carrying it forward — check claims against ground truth (code, status docs, referenced files). Stale facts get corrected or dropped **with an explicit note in the PR**, never silently relocated or silently deleted. Dead links are never carried into new docs.

**6. Relocate, never delete.** Before dropping a section as "duplicated elsewhere," open the alleged duplicate and confirm it contains *every* fact — a file table's one-line purposes are not in an auto-generated tree; a summary is not the incident narrative. Anything the duplicate lacks moves there first. Preserve incident narratives and security-adjacent reasoning verbatim in their new home.

**7. Verify links.** Script a resolver over every touched file's relative links; it must print positive OK/MISS per link — an empty grep is not proof.

**8. Regenerate derived artifacts** (architecture maps, catalogs, indexes) if the repo auto-generates them and you added/moved files.

**9. Deliver.** Commit; open a PR whose body contains: "no invariant changed, relocation only"; the before/after line-count table; sections moved + new homes (linked); mined additions with their evidence (commits/log aggregates); stale facts corrected with evidence; superseded-attempt note. Then move to the next repo, if any.

## Common Mistakes

| Mistake | Fix |
|---|---|
| Dropping a section because "ARCH.md/openapi has this" without opening it | Verify the duplicate holds every fact; move the delta first |
| Trimming on a stale local base | Step 1 is mandatory, first, every repo |
| Fixing drift silently | Every correction is itemized in the PR with evidence |
| Moving a section, forgetting the pointer | Add pointer + link before touching the next section |
| Compressing an incident narrative "to its lesson" | The narrative moves verbatim; only the in-place stub is compressed |
| One mega-branch/PR across multiple repos | One worktree + branch + PR per repo, sequential |
| Trusting an empty grep as link verification | Positive per-link OK/MISS output required |
| Trusting an empty grep during log mining | Verify the filter matches the log format on a known-present sample first — a false negative that confirms "nothing to find" is invisible |
| Relative paths in multi-repo/worktree shells | Shell cwd drifts between calls; use absolute paths and `git -C <abs-path>` for every mining and verification command |
| Re-adding a mined trap already documented at point of use | Check the relevant skill/guide/tracked issue before writing; mining output must pass the landing filter in step 4 |

## Multi-Project Runs

For N repos: complete steps 1–9 for repo 1 before opening repo 2. Emit one final cross-repo summary: per-repo PR links, line-count deltas, and any repo skipped (with reason). If a repo has no doc-hygiene convention, note that its PR introduces `docs/guide/` + `docs/progress/` so reviewers see the convention is new.
