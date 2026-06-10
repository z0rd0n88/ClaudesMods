# total-review-scaffold — Reference

Detail for steps 2 (stack detection), 4 (slice extraction), 6 (agent activation). Loaded on demand from SKILL.md.

## Stack detection

Probe in order; return the first match. Use `Glob`/`Read` — no shell-out unless needed.

| Stack | Probe |
|---|---|
| `python` | `pyproject.toml` or `setup.py` at repo root, OR `requirements*.txt` + any `*.py` in src tree |
| `kotlin` | `build.gradle.kts` or `settings.gradle.kts` at root, OR `*.kt` files within depth 3 |
| `typescript` | `package.json` at root without `"next"` in `dependencies`/`devDependencies` (Next.js gets its own overlay path one day) |
| `multi` | More than one of the above matches; ask user via `AskUserQuestion` to pick primary |

Pin the chosen stack into `config.project.stack`. Reviewers don't read it directly, but it determines which overlay agents the scaffold installs.

## Slice extraction from ARCH.md

`ARCH.md` (auto-maintained per `~/.claude/rules/common/architecture-mapping.md`) has three zones; the curated **Key Paths** block is the source of slice candidates.

Markers: between `<!-- ARCH:DESC -->` and `<!-- /ARCH:DESC -->`. Each curated line looks like:

```
- `src/<project>/domain/` — Pure dataclass models + invariants, error taxonomy, pure functions.
```

Extract `(path, description)` pairs. Each becomes a slice candidate where:

- `slug` = path's last meaningful component (`domain`, `application`, `adapters/discord_bot` → `discord_bot`).
- `path` = the path as listed.
- `description` = the prose (shown to user during confirmation, not written to config).
- `lenses` = the effective agent set for that stack, *minus* known low-value pairings (e.g. drop `python-reviewer`/`python-pro` from `tests/` slice — test code has different idioms).

If `ARCH:DESC` markers aren't present, fall back to listing direct child directories of `src/` (or repo root). Print a warning that ARCH.md doesn't have a curated Key Paths block and recommend filling one out.

## Default lens-skip rules per slice

Apply these by default when generating `lenses` lists in the new `config.yml`; user edits as needed.

| Slice slug pattern | Skip these lenses by default |
|---|---|
| `tests`, `test`, `*-tests` | `python-reviewer`, `python-pro`, `kotlin-reviewer` (test idioms differ) |
| `wiring`, `container`, `main`, `bootstrap` | `tdd-guide` (entry points rarely benefit) |
| `docs`, `documentation` | All review agents; this slice is for the `docs` mode only |

## Agent activation algorithm

Goal: given an agent's internal `name:` field (e.g. `code-reviewer`), find the right file in `~/.claude/agents-parked/` and copy it into `<repo>/.claude/agents/`.

Algorithm (Bash):

```bash
PARKED=~/.claude/agents-parked
DEST=.claude/agents
mkdir -p "$DEST"
for agent_name in <list>; do
  # find filename whose 'name:' field equals $agent_name
  file=$(grep -l "^name: $agent_name$" "$PARKED"/*.md 2>/dev/null | head -1)
  if [[ -z "$file" ]]; then
    echo "WARN: agent '$agent_name' not in agents-parked/ — project must provide"
    continue
  fi
  base=$(basename "$file")
  if [[ -f "$DEST/$base" ]] && ! cmp -s "$file" "$DEST/$base"; then
    # exists with different content; ask before overwriting
    echo "PROMPT: $base already present in project with different content"
    continue
  fi
  cp -n "$file" "$DEST/$base"
  git add "$DEST/$base"
done
```

Common name → filename map (for reference; the algorithm above derives it dynamically):

| Internal `name:` | Filename in `agents-parked/` |
|---|---|
| `code-reviewer` | `ecc-code-reviewer.md` |
| `python-reviewer` | `ecc-python-reviewer.md` |
| `python-pro` | `python-pro.md` |
| `kotlin-reviewer` | `ecc-kotlin-reviewer.md` |
| `refactor-cleaner` | `ecc-refactor-cleaner.md` |
| `unused-code-cleaner` | `unused-code-cleaner.md` |
| `security-reviewer` | `ecc-security-reviewer.md` |
| `silent-failure-hunter` | `ecc-silent-failure-hunter.md` |
| `tdd-guide` | `ecc-tdd-guide.md` |
| `performance-optimizer` | `ecc-performance-optimizer.md` |
| `sql-pro` | `sql-pro.md` |
| `documentation-expert` | `documentation-expert.md` |
| `critical-thinking` | `critical-thinking.md` |
| `code-explorer` | not parked at user scope as of 2026-06-07 — already activated in most owned repos under `.claude/agents/code-explorer.md`; if missing, the explorer is also available as a built-in subagent type in many setups |
| `code-architect` | not commonly parked at user scope; activate from a sibling repo's `.claude/agents/` or skip the `architecture` mode |
| `typescript-reviewer` | not parked at user scope; TypeScript projects must provide one or fall back to generic `code-reviewer` only |

## Effective agent set per stack

Union of generic + stack overlay across all canonical modes (so a single scaffold pass activates everything the project might use across modes):

- **python**: `code-reviewer`, `python-reviewer`, `python-pro`, `refactor-cleaner`, `unused-code-cleaner`, `security-reviewer`, `code-architect`, `critical-thinking`, `silent-failure-hunter`, `tdd-guide`, `performance-optimizer`, `sql-pro`, `documentation-expert`, `code-explorer`
- **kotlin**: as above, replacing `python-reviewer`/`python-pro` with `kotlin-reviewer`; keep `sql-pro` only if project has SQL
- **typescript**: as above, replacing `python-reviewer`/`python-pro`/`kotlin-reviewer` with `typescript-reviewer` (gap — see name map)

Agents flagged as "not parked at user scope" produce a warning during activation but don't abort the scaffold. The wrapper still works for modes that don't reference the missing agent; modes that do will warn at runtime per REFERENCE.md's failure-mode guards.

## Idempotency

Rerunning the scaffold in a repo that already has `<slug>-total-review/`:

1. Re-detect stack; if changed, ask whether to update `config.project.stack`.
2. Re-extract slices from ARCH.md; show diff vs. existing `config.yml`; ask before overwriting.
3. Re-activate agents — `cp -n` is no-op when target exists; only newly-required agents copy in.
4. Tracker config — preserve user edits; never overwrite.
