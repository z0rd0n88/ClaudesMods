---
name: total-review
description: Shared multi-agent codebase review workflow library. Project wrappers at .claude/skills/<slug>-total-review/ delegate to this skill's REFERENCE.md with a sibling config.yml declaring layer slices, agent picks, and tracker commands.
---

# total-review

Library skill, not invoked directly. Each owned repo gets its own thin wrapper at `<repo>/.claude/skills/<slug>-total-review/` that delegates to this skill's [`REFERENCE.md`](REFERENCE.md) using a sibling `config.yml`.

## The pattern

Parallel multi-agent code review tailored to a repo's specific layer layout. Each mode fans out specialised agents along clean layer seams so reviewer outputs are complementary, not duplicated.

The design insight: **clean `domain → application → adapters`-style layer boundaries let reviewers divide work along those seams with minimal overlap, and pairing a *correctness* lens (e.g. `code-reviewer`) with an *idiom* lens (e.g. `python-reviewer` / `kotlin-reviewer`) surfaces complementary findings on the same file without duplication.**

The #1 lever against duplicate work is the **exclusion list**: before fan-out, fetch open-issue findings from the tracker and inject them verbatim into every reviewer prompt under a "DO NOT report" heading. Validated against a real multi-pass review where consecutive passes were re-reporting the same 3–4 findings; injecting prior-pass issues as exclusions eliminated the duplicates without losing genuinely new findings.

## Modes (canonical eight)

| Mode | Purpose | Files issue? |
|---|---|---|
| `code` | Correctness + atomicity + idiom + typing | yes |
| `cleanup` | Dead code + duplication + unused helpers | yes |
| `security` | Input/output + money flow + OWASP framing | yes |
| `architecture` | Hexagonal boundaries + deepening + silent-failure ladder | yes |
| `test` | Coverage + fake parity + mock-spec adequacy | yes |
| `perf` | N+1 + DB contention + hot-path numerics | yes |
| `docs` | ARCH.md / ADR / baton-pass drift | no (inline patch or small issue) |
| `pre-pr` | Diff-only sanity check before opening a PR | no (inline summary) |

`all` runs every mode except `pre-pr` and files one tracker issue per mode.

## How wrappers consume this

A project's wrapper looks like:

```
<repo>/.claude/skills/<slug>-total-review/
  SKILL.md     # short trigger; description names the project; body says
               # "follow ~/.claude/skills/total-review/REFERENCE.md using ./config.yml"
  config.yml   # slices, modes overrides, tracker commands, invariants
```

A project's config.yml declares:
- **Slices** — `(slug, path, lenses)` per slice; the layer map of the project.
- **Mode overrides** — per-canonical-mode agent overrides, per-mode disables, and project-specific add-on modes.
- **Tracker** — shell commands for exclusion query and issue filing; title template; cross-ref phrase.
- **Invariants** — project rules every reviewer must respect (e.g. money type, datetime tz, key shape).

See [`REFERENCE.md`](REFERENCE.md) for the workflow steps, default agent matrix per stack, config schema, and issue body template. See the sibling `total-review-scaffold` skill to bootstrap a wrapper in a fresh repo.
