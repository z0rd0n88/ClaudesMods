---
description: "Build a spec/PRD/issue with a TDD multi-agent dev team across RED→GREEN→REFACTOR rounds"
argument-hint: "<spec-path-or-issue-ref> [flags]"
---

Invoke the `multi-agent-developer` skill and follow it exactly.

Arguments forwarded: `$ARGUMENTS`

The skill orchestrates a TDD-disciplined dev team to implement a spec, PRD, or issue. The orchestrating agent (you) **is** the manager — no nested manager agent.

Phases:

1. **Bootstrap.** Required framework agents (`ecc-code-explorer`, `ecc-code-architect`) must be active in the project; if missing, halt with the `/multi-agent-developer-setup` instruction.
2. **Explore.** Dispatch `ecc-code-explorer` to map the relevant slice.
3. **Select team.** Score active project agents + parked candidates; pick ≤4 dev specialists; surface alternatives as a footnote.
4. **User approval.** Block-and-wait approval of the team + the auto-derived branch slug.
5. **Three TDD rounds.** RED → GREEN → REFACTOR in markdown shared-context blocks; agents debate in caveman-compressed context.
6. **Synthesize.** Converge via `ecc-code-architect`.
7. **Materialize.** Create `.worktrees/feat/<slug>`, apply files via Write/Edit.
8. **Verify.** Run the project's test command; on failure, run one GREEN-redux retry.

All dev agents run on Opus. Caveman compression applies to internal shared-context blocks only — never to user-facing chat.

If this is a fresh repo, run `/multi-agent-developer-setup` first.
