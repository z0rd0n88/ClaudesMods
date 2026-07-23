---
name: multi-agent-developer-setup
description: One-time per-project bootstrap for /multi-agent-developer. Activates ecc-code-explorer and ecc-code-architect into <repo>/.claude/agents/ from user-scope agents-parked. Idempotent.
allowed-tools:
  - Bash
  - Read
  - Glob
---

# multi-agent-developer-setup

## 1. Purpose

Bootstrap the two framework agents that `/multi-agent-developer` requires in every project:

- `ecc-code-explorer` — maps codebase in Phase 2
- `ecc-code-architect` — synthesizes converged implementation in Phase 6

These live parked at user scope (`~/.claude/agents-parked/`). This skill moves them into the current project's `.claude/agents/` so they're discoverable when `/multi-agent-developer` runs.

**Run once per project.** Idempotent — re-running is safe; existing destinations are skipped.

## 2. When to use

Trigger phrases:
- `/multi-agent-developer-setup` (direct invocation)
- "set up multi-agent dev for this project"
- After `/multi-agent-developer` halts at Phase 0 with the setup-required message

## 3. Workflow

### Step 1 — Verify environment

1. Determine repo root: `git rev-parse --show-toplevel`. If not in a git repo → hard-fail with `not a git repository — /multi-agent-developer requires a git project`.
2. Verify the user-scope config repo is reachable at `~/.claude/` (directory exists). Do NOT hard-fail on missing parked sources here — that check is per-agent in Step 3, after the destination check, so re-runs stay idempotent.

### Step 2 — Create `<repo>/.claude/agents/` if absent

```bash
mkdir -p "<repo-root>/.claude/agents"
```

### Step 3 — Activate each framework agent (destination-first, idempotent)

For each of `ecc-code-explorer.md` and `ecc-code-architect.md`, branch in this order:

1. **Destination already present** → skip (already activated in this repo). This must come first so that re-running after a successful prior activation is a no-op — the parked source is gone by design after the first run.
2. **Source present in `~/.claude/agents-parked/`** → activate.
3. **Both missing** → hard-fail with `<file> missing from BOTH ~/.claude/agents-parked/ AND <repo>/.claude/agents/ — your user-scope agent roster is broken`.

We use `mv` + per-repo index updates (not `git mv`) because `git mv` cannot span repositories — `~/.claude/` and the project repo are independent working trees, and `git mv` rejects paths outside its repo with `fatal: '…' is outside repository`.

```bash
src="$HOME/.claude/agents-parked/<file>"
dest="<repo-root>/.claude/agents/<file>"

if [ -f "$dest" ]; then
  echo "skip: <file> already present"
elif [ -f "$src" ]; then
  # 1. plain mv across the filesystem (works regardless of repo boundary)
  mv "$src" "$dest"

  # 2. update each repo's index so working trees stay clean
  ( cd "$HOME/.claude" && git rm --quiet "agents-parked/<file>" )
  ( cd "<repo-root>"   && git add        ".claude/agents/<file>" )

  echo "activated: <file>"
else
  echo "ERROR: <file> missing from BOTH ~/.claude/agents-parked/ AND <repo>/.claude/agents/ — your user-scope agent roster is broken" >&2
  exit 1
fi
```

> **Why `mv` + per-repo index updates, not `git mv`:** `~/.claude/` and the project repo are two separate git repos. `git mv` cannot cross repo boundaries. Plain `mv` moves the file across the filesystem regardless of repo membership, then each repo's index is updated in its own subshell — the user-scope repo records the deletion, the project repo records the addition. Single source of truth is preserved (the file exists in exactly one place) and both working trees stay clean.

### Step 4 — Report

Print a concise summary:

```
multi-agent-developer setup — <repo-name>

Activated framework agents in <repo-root>/.claude/agents/:
- ecc-code-explorer.md    [activated | already present]
- ecc-code-architect.md   [activated | already present]

Next:
  /multi-agent-developer <target-type> <target-args>

Notes:
- Dev specialists (security-reviewer, python-pro, etc.) are NOT activated by this setup.
  They're picked per-task in Phase 3 of /multi-agent-developer.
- To deactivate (return to user scope), use the same mv + per-repo index pattern in reverse
  (git mv cannot span repos):

    src="<repo-root>/.claude/agents/<file>"
    dest="$HOME/.claude/agents-parked/<file>"
    mv "$src" "$dest"
    ( cd "<repo-root>"   && git rm --quiet ".claude/agents/<file>" )
    ( cd "$HOME/.claude" && git add        "agents-parked/<file>" )
```

## 4. Error handling

| Condition | Action |
|---|---|
| Not in a git repo | Hard-fail with message. |
| Destination present in `<repo>/.claude/agents/` | Skip that agent (already activated); continue with the other. |
| Source present in `~/.claude/agents-parked/`, destination absent | Activate via `mv` + per-repo index updates. |
| Both source AND destination missing for an agent | Hard-fail with `<file> missing from BOTH ~/.claude/agents-parked/ AND <repo>/.claude/agents/ — your user-scope agent roster is broken`. Suggest user verify their `~/.claude/` config repo. |
| Both files already present at destination | Print summary noting both are already activated; exit 0. |

## 5. Out of scope

This skill does NOT:
- Activate dev specialists — they're per-task selections.
- Modify `<repo>/.claude/settings.json`.
- Commit changes — the activation produces deltas in **two** repos: a staged deletion in `~/.claude/agents-parked/<file>` and a staged addition in `<repo>/.claude/agents/<file>`. Commit each separately. The `~/.claude` commit will trigger `agents-parked/CATALOG.md` regeneration via its pre-commit hook.
