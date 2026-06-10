---
description: "Multi-phase build queue where each implement step uses a multi-agent dev team"
argument-hint: "<queue-path-or-ref> [flags]"
---

Invoke the `baton-runner-multi-agent` skill and follow it exactly.

Arguments forwarded: `$ARGUMENTS`

Fork of `/baton-runner` where the **implement step** delegates to `multi-agent-developer` — a TDD-disciplined team of ≤4 Opus specialists debating RED → GREEN → REFACTOR per phase. Review step delegates to `multi-agent-review` with a per-phase roster that the user signs off on at queue start.

Use when:
- The phases are non-trivial (multiple files, real architecture decisions, test discipline matters)
- You want per-phase reviewer rosters tuned to the phase shape (e.g., migration-touching phases get a different roster than plain phases)
- The orchestrator manager should stay out of per-phase context budget (each phase is a fresh subagent dispatch)

**Required:** `multi-agent-developer` + `multi-agent-review` plugins must both be installed.

For phase-rosters tuning: at queue start the manager proposes per-phase rosters and waits for user approval. The user can swap/add/drop reviewers before any phase runs. See [`skills/baton-runner-multi-agent/REFERENCE.md`](../skills/baton-runner-multi-agent/REFERENCE.md) for the full roster-decision logic.
