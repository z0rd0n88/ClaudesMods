# Total Review

A parallel multi-agent code review pattern designed around clean architectural layers, with built-in dedup against an issue tracker. The design insight, in one sentence:

> Clean `domain → application → adapters`-style layer boundaries let reviewers divide work along those seams with minimal overlap, and pairing a *correctness* lens (e.g. `code-reviewer`) with an *idiom* lens (e.g. `python-reviewer`, `kotlin-reviewer`) surfaces complementary findings on the same file without duplication.

This plugin ships two skills:

| Skill | What it does |
|---|---|
| [`total-review`](./skills/total-review/SKILL.md) | The library. A project's wrapper skill delegates to its [`REFERENCE.md`](./skills/total-review/REFERENCE.md) with a sibling `config.yml`. Not invoked directly. |
| [`total-review-scaffold`](./skills/total-review-scaffold/SKILL.md) | One-time bootstrap. Detects your stack, reads `ARCH.md`, suggests slices, and writes the project wrapper for you. User-invoked via `/total-review-init`. |

## The eight canonical modes

| Mode | Purpose | Files issue? |
|---|---|---|
| `code` | Correctness + atomicity + idiom + typing | yes |
| `cleanup` | Dead code + duplication + unused helpers | yes |
| `security` | Input/output + money flow + OWASP framing | yes |
| `architecture` | Hexagonal boundaries + deepening + silent-failure ladder | yes |
| `test` | Coverage + fake parity + mock-spec adequacy | yes |
| `perf` | N+1 + DB contention + hot-path numerics | yes |
| `docs` | ARCH / ADR / handoff drift | no (inline patch or small issue) |
| `pre-pr` | Diff-only sanity check before opening a PR | no (inline summary) |

`all` runs every mode except `pre-pr` and files one tracker issue per mode.

## The exclusion-list discipline (the #1 dedup lever)

Before any fan-out, the workflow fetches open-issue findings from your tracker and injects them verbatim into every reviewer's prompt under a **"DO NOT report"** heading. Validated against a real multi-pass review where consecutive passes were re-reporting the same 3–4 findings; injecting the prior-pass issues as exclusions eliminated the duplicates without losing genuinely new findings.

This is what lets you run `/<slug>-total-review code` weekly without drowning in repeat tickets.

## How wrappers consume this

A project's wrapper lives at:

```
<repo>/.claude/skills/<slug>-total-review/
  SKILL.md     # short trigger; description names the project; body says
               # "follow ~/.claude/skills/total-review/REFERENCE.md using ./config.yml"
  config.yml   # slices, mode overrides, tracker commands, invariants
```

The wrapper's `config.yml` declares:

- **Slices** — `(slug, path, lenses)` per slice; the layer map of the project.
- **Mode overrides** — per-canonical-mode agent overrides, per-mode disables, project-specific add-on modes.
- **Tracker** — shell commands for exclusion query and issue filing; title template; cross-ref phrase.
- **Invariants** — project rules every reviewer must respect (e.g. money type, datetime tz, key shape).

`total-review-scaffold` writes a sensible starter `config.yml` based on your stack and `ARCH.md`; you tune it per project.

## Install

```bash
claude marketplace add github:z0rd0n88/ClaudesMods
claude plugin install total-review
```

## Use

In a fresh repo:

```bash
/total-review-init
```

That writes the wrapper. Then run a review pass:

```bash
/<slug>-total-review code        # single mode
/<slug>-total-review all         # every mode except pre-pr; files N issues
/<slug>-total-review pre-pr      # diff-only sanity check
```

## Why it exists

Single-agent review is a thin filter. Multi-agent review without coordination is duplicated effort and noisy issue trackers. This plugin is the result of converging on a pattern that:

1. Carves work along architectural seams so reviewers don't trip over each other.
2. Pairs correctness + idiom lenses on the same file for complementary findings, not duplicates.
3. Reads the open tracker first so prior passes' findings don't get re-reported.
4. Files **one issue per mode** with PR-slicing suggestions in the body — actionable, not a wall of bullets.

The combination is what makes a weekly review cadence tractable.

## Layout

```
total-review/
├── .claude-plugin/plugin.json
├── README.md
├── commands/
│   └── total-review-init.md
└── skills/
    ├── total-review/
    │   ├── SKILL.md            # the library entry point
    │   └── REFERENCE.md        # workflow steps, agent matrix, config schema, issue template
    └── total-review-scaffold/
        ├── SKILL.md            # bootstrap entry point
        └── REFERENCE.md        # detection logic, default matrix, config writer
```

## License

[MIT](../LICENSE).
