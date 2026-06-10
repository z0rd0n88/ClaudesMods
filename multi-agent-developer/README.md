# Multi-Agent Developer

A manager-led TDD dev team that takes a spec/PRD/issue and produces a verified worktree of runnable code. Up to 4 Opus specialists debate the implementation across RED → GREEN → REFACTOR rounds; an architect agent synthesizes the converged design; the manager materializes the worktree and runs the tests.

```
spec  →  explore  →  pick team  →  RED  →  GREEN  →  REFACTOR  →  synthesize  →  worktree + tests
```

The orchestrating agent (you) **is** the manager. There's no nested manager agent — flattening the hierarchy avoids context drift and gives the user a single accountable orchestrator they can interrupt at any phase.

## The two skills

| Skill | What it does | Command |
|---|---|---|
| [`multi-agent-developer`](./skills/multi-agent-developer/SKILL.md) | The orchestrator. Bootstrap → explore → pick team → 3 TDD rounds → synthesize → worktree → tests. Retries once on test failure. | `/multi-agent-developer` |
| [`multi-agent-developer-setup`](./skills/multi-agent-developer-setup/SKILL.md) | One-time per-project bootstrap. Activates required framework agents (`ecc-code-explorer`, `ecc-code-architect`) into `<repo>/.claude/agents/`. Idempotent. | `/multi-agent-developer-setup` |

## What makes it different

Five load-bearing properties:

1. **The manager is the orchestrator, not a delegated agent.** No "manager agent that spawns sub-managers." You stay in the loop on team selection, branch slug approval, and verification — interrupt-friendly.
2. **Three fixed TDD rounds in markdown.** RED → GREEN → REFACTOR isn't a vibe, it's a state machine. Each round has explicit shared-context blocks the agents debate inside. The discipline survives multi-day builds.
3. **≤4 specialists, scored against active + parked catalogs.** The setup skill keeps your user-scope `~/.claude/agents/` empty (no global prompts in every session); specialists are picked per-task and activated per-project. The catalog-lookup ref governs the scoring.
4. **Architect synthesizer.** After the three debate rounds, `ecc-code-architect` produces the canonical implementation. The dev specialists generate variants; the architect picks and integrates. Prevents "design by committee" where the rounds drift but no consensus crystallizes.
5. **Caveman compression on shared-context blocks only.** Internal round artifacts use ultra-compressed prose to fit more debate in less context budget. User-facing chat stays fully formed — compression is an internal optimization, not a UX choice.

## Bundled shared primitives

The `refs/multi-agent/` directory ships the contracts this skill builds on (also used by `multi-agent-review` and `total-review`):

- [`fanout-consolidation.md`](./refs/multi-agent/fanout-consolidation.md) — parallel-fan-out contract for the round dispatches.
- [`agent-catalog-lookup.md`](./refs/multi-agent/agent-catalog-lookup.md) — how `--agents <csv>` and Phase 5.4 auto-selection resolve names.
- [`spec-injection.md`](./refs/multi-agent/spec-injection.md) — how the spec gets carried into specialist briefs under the canonical heading (not paraphrased).

## Install

```bash
claude marketplace add github:z0rd0n88/ClaudesMods
claude plugin install multi-agent-developer
```

After installing, run the bootstrap once per project:

```bash
/multi-agent-developer-setup
```

Then on each feature build:

```bash
/multi-agent-developer ./specs/feature-x.md
/multi-agent-developer #142
/multi-agent-developer https://github.com/owner/repo/issues/142
```

## Output

Each invocation lands the same artifact: a feature worktree at `.worktrees/feat/<slug>/` with:

- The implementation, applied file-by-file from the architect synthesis.
- Tests passing (the manager runs them; one retry round on failure).
- Branch name `feat/<slug>`, ready to push + open a PR.

## Composition

| Layer | Skill | Where it lives |
|---|---|---|
| **Spec → code** | **`multi-agent-developer`** | this plugin |
| Code → findings | [`multi-agent-review`](https://github.com/z0rd0n88/ClaudesMods/tree/main/multi-agent-review) | sibling plugin |
| Findings → APPROVE on existing PR | `multi-agent-review-loop` | inside `multi-agent-review` |
| Spec → APPROVE end-to-end | [`code-rinse-repeat`](https://github.com/z0rd0n88/ClaudesMods/tree/main/code-rinse-repeat) | composes this plugin + multi-agent-review |
| Multi-phase queues | [`baton`](https://github.com/z0rd0n88/ClaudesMods/tree/main/baton) | drives multiple specs via this plugin |

The bundled `refs/multi-agent/` shares format and intent with the same dir in `multi-agent-review`. If you install both plugins, you'll have two copies — intentional (each plugin self-contained). Keep them in sync when editing primitives.

## Layout

```
multi-agent-developer/
├── .claude-plugin/plugin.json
├── README.md
├── commands/
│   ├── multi-agent-developer.md
│   └── multi-agent-developer-setup.md
├── refs/
│   └── multi-agent/
│       ├── fanout-consolidation.md
│       ├── agent-catalog-lookup.md
│       └── spec-injection.md
└── skills/
    ├── multi-agent-developer/SKILL.md
    └── multi-agent-developer-setup/SKILL.md
```

(`exclusion-list.md` is NOT bundled here — it's a review-side primitive; install `multi-agent-review` or `total-review` for that.)

## License

[MIT](../LICENSE).
