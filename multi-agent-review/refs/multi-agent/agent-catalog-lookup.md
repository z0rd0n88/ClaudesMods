# Agent catalog lookup

Shared primitive for any multi-agent skill that picks specialists from the project's active agents plus the user-scoped parked catalog. Cited by `total-review`, `multi-agent-review`, `xan-multi-agent-developer`.

## The two catalogs

| Location | Scope | Loaded into context? |
|---|---|---|
| `<repo>/.claude/agents/` | project — recursively scanned | yes, every session |
| `~/.claude/agents-parked/` | user-scope library | no — discoverable, not loaded |

The parked tier exists so user-scope `~/.claude/agents/` can stay empty (no global agent prompts in every session). Specific agents are *activated* per-project by `git mv`-ing them from `agents-parked/` into `<repo>/.claude/agents/`.

## Lookup procedure

When a multi-agent skill needs to resolve an agent name (e.g. `python-reviewer`):

1. **Try the active project catalog first.**
   ```bash
   grep -lE "^name: <name>$" <repo>/.claude/agents/**/*.md 2>/dev/null | head -1
   ```
   If found, use the active agent directly. The internal `name:` field is the canonical identifier — filenames are often `ecc-`-prefixed (e.g. `ecc-code-reviewer.md` carries `name: code-reviewer`), so do NOT match by filename.

2. **Fall back to the parked catalog as a candidate** (not an automatic activation).
   ```bash
   grep -lE "^name: <name>$" ~/.claude/agents-parked/*.md 2>/dev/null | head -1
   ```
   If found here but not in `(1)`, surface it as a parked candidate. **Do not silently copy it into the project** — agent activation is a deliberate user act (it edits the project's tracked `.claude/agents/`). Either ask for activation, or hard-fail with the activation command pasted (`cp ~/.claude/agents-parked/<file>.md <repo>/.claude/agents/`).

3. **If neither catalog has it, hard-fail.** Do not auto-pick a similar name. Reviewer rosters must be explicit; degraded coverage from a missing lens is worse than refusing to start.

## Selection heuristics (when the skill picks the roster)

For build/review skills that auto-select specialists (xmad, total-review's mode matrix):

- **Generic baseline first.** Every roster starts with a stack-agnostic lens (`code-reviewer` for review, `tdd-guide` for build).
- **Stack overlay second.** Pin the stack at scaffold time (`python`/`kotlin`/`typescript`); append the matching idiom reviewer (`python-reviewer` / `kotlin-reviewer` / `typescript-reviewer`).
- **Domain lenses third.** Add domain-specific reviewers when the target spans their concern (e.g. `sql-pro` when `*.sql` is touched; `security-reviewer` when auth/IO touched; `silent-failure-hunter` for application-layer work).
- **Cap the roster.** Hard cap 4 for build (xmad); soft cap 6 per slice for review (total-review). Beyond that, the synthesizer struggles to merge coherently.

## Failure modes

- **Name collision.** Two `agents/disabled/<name>.md` and `agents/<name>.md` both have the same `name:` field. Harness loads one silently and drops the other. Audit project agents with `grep -rh ^name: <repo>/.claude/agents/ | sort | uniq -d`.
- **Parked agent depended on by a wrapper that doesn't activate it.** A `<slug>-total-review/config.yml` references a lens that's parked but not activated → reviewer fan-out runs with degraded coverage. The orchestrator MUST warn loudly (not silently skip) and ask the user to activate before retrying.
- **Filename ≠ internal name.** Resolving by filename (`python-reviewer.md`) misses agents that live as `ecc-python-reviewer.md` with `name: python-reviewer`. Always resolve by `^name:` grep.
