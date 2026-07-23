# claude-md-trim

Trim a repository's always-loaded agent context files (CLAUDE.md / AGENTS.md / GEMINI.md) to **invariants + pointers only**.

These files load into every session's prompt budget. Procedures, config tables, incident narratives, and status sections belong in linked docs (`docs/guide/`, `docs/progress/`), not in the prompt. This skill runs the full operation: base-freshness check, worktree isolation, session-log + git-log mining for missing signal (recurring fixes and failures the context files should cover but don't), section classification (KEEP or MOVE, with verification of everything carried forward), relocation with fact preservation, link verification, derived-artifact regeneration, and a PR with a before/after table.

## Invocation

- Single repo: invoke `claude-md-trim` in the target repo.
- Multiple repos: list the repo paths — each gets its own worktree, branch, and PR, processed sequentially, with a cross-repo summary at the end.

## Guarantees

- Relocation + compression only — no invariant's meaning changes.
- Every load-bearing fact survives, reachable via a link.
- Stale facts are corrected with an itemized note in the PR, never silently.
- Every relative link in touched files is verified with positive per-link output.
