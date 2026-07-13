# Baton

Three skills for driving long-running, multi-phase code work — the "I have 5 specs to build sequentially, the context budget per session can't hold all of them, and I want disk-resumable state between phases" toolkit.

```
queue of specs
  → unit 1 (implement → review → fix)  → baton-pass note
  → unit 2 (implement → review → fix)  → baton-pass note
  → unit 3 ...
```

The orchestrator stays **out of per-unit context** — each implement / review / fix step runs in a fresh subagent. The manager only sees unit boundaries, gate checks, and the queue cursor. Disk artifacts (worktree state + baton-pass notes) let the next session pick up cold.

## The three skills

| Skill | What it does | Command |
|---|---|---|
| [`baton-runner`](./skills/baton-runner/SKILL.md) | Drives an ordered queue of specs as sequential implement→review→fix work units in a single worktree. Each unit is a clean subagent dispatch. Per-unit gates (compile + test + lint) before advancing. | `/baton-runner` |
| [`baton-runner-multi-agent`](./skills/baton-runner-multi-agent/SKILL.md) | Fork where the **implement step** delegates to `multi-agent-developer` (≤4 Opus specialists, RED → GREEN → REFACTOR) and the **review step** delegates to `multi-agent-review` with a user-approved per-phase roster. | `/baton-runner-multi-agent` |
| [`baton-pass`](./skills/baton-pass/SKILL.md) | Standalone session baton-pass notes to `baton-pass/<feature>/NNN-…md`. Append-only, numbered, feature-scoped. Used internally by the runners; also user-invokable. | `/baton-pass` |

## What makes baton-runner-multi-agent different

The plain `baton-runner` uses single subagents for each step. The multi-agent variant delegates `implement` to a TDD dev team and `review` to a parallel multi-perspective review pass. That changes the cost + quality envelope:

- **Implement:** 1 agent → ≤4 Opus specialists debating across RED → GREEN → REFACTOR rounds (via `multi-agent-developer`)
- **Review:** 1 reviewer → N parallel reviewers + synthesizer with cross-axis severity budget (via `multi-agent-review`)
- **Per-phase roster overrides:** the user signs off on per-phase reviewer rosters at queue start; phases touching specific code surfaces (e.g., DB migrations) can swap to a specialized roster automatically. The override REPLACES the default — does not append.
- **Cost:** real — every phase fans out 4–8 Opus invocations instead of 1. Use when the phases are non-trivial enough to need TDD discipline + multi-perspective review.

## What makes baton-pass different

The note format is opinionated and small. Three hard rules:

1. **Append-only.** Never edit prior notes. The history is the audit trail.
2. **Sequential numbering.** `NNN-<slug>.md` — three-digit zero-padded, monotonic per feature.
3. **Feature/epic subdirectories.** `baton-pass/<feature>/NNN-…md`, not a flat directory. Browsing the directory should tell you the structure of the work.

The note body captures: what was decided this session, what's still open, where to look in the code, and the **explicit next step**. The format is optimized for an LLM-orchestrator to pick up cold — no implicit context.

## Composition

| Pattern | Skill | Plugin |
|---|---|---|
| Single spec → APPROVE | `code-rinse-repeat` | [`code-rinse-repeat`](https://github.com/z0rd0n88/ClaudesMods/tree/main/code-rinse-repeat) |
| Queue of specs, single-agent units | `baton-runner` | this plugin |
| Queue of specs, multi-agent units | `baton-runner-multi-agent` | this plugin |
| Session baton-pass notes (standalone) | `baton-pass` | this plugin |

`baton-runner-multi-agent` is the most powerful: it composes `multi-agent-developer` (build) + `multi-agent-review` (review) + `baton-pass` (session notes) on a queue. If `code-rinse-repeat` is "build one spec to APPROVE end-to-end", `baton-runner-multi-agent` is "build a queue of N specs to APPROVE end-to-end."

## Install

```bash
claude marketplace add github:z0rd0n88/ClaudesMods
claude plugin install baton
```

For `baton-runner-multi-agent`, also install:

```bash
claude plugin install multi-agent-developer
claude plugin install multi-agent-review
```

`/baton-runner` and `/baton-pass` work standalone with no other plugins.

## Use

```bash
# Plain runner over a queue file:
/baton-runner queue.md

# Multi-agent runner with user-approved per-phase rosters:
/baton-runner-multi-agent queue.md

# Write a standalone baton-pass note:
/baton-pass payment-replay
```

## Layout

```
baton/
├── .claude-plugin/plugin.json
├── README.md
├── commands/
│   ├── baton-runner.md
│   ├── baton-runner-multi-agent.md
│   └── baton-pass.md
└── skills/
    ├── baton-runner/
    │   ├── SKILL.md
    │   ├── REFERENCE.md
    │   └── scripts/
    │       └── gate.sh                 # compile + test + lint per-unit gate
    ├── baton-runner-multi-agent/
    │   ├── SKILL.md
    │   └── REFERENCE.md
    └── baton-pass/SKILL.md
```

## License

[MIT](../LICENSE).
