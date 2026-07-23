# Code Rinse Repeat

Lather, rinse, repeat — but for code. The single-target end-to-end layer that composes [`multi-agent-developer`](https://github.com/z0rd0n88/ClaudesMods/tree/main/ClaudesMods/multi-agent-developer) (build) with [`multi-agent-review`](https://github.com/z0rd0n88/ClaudesMods/tree/main/ClaudesMods/multi-agent-review) (review-fix loop) into one orchestrator.

```
build (multi-agent-developer)
  → review (multi-agent-review)
  → fix (coordinator applies inline)
  → re-review
  → … until APPROVE or max iterations
```

You hand it a spec, PRD, or issue. You get back a verified, reviewed worktree with a ship report — without manually moving artifacts between the dev and review phases.

## Why it exists

`multi-agent-developer` produces a verified-tests-pass worktree from a spec — but tests-pass ≠ ship-ready. There are still architecture issues, silent-failure landmines, security smells, and idiom-rot to catch. `multi-agent-review pr <ref> --yes` (the `multi-agent-review` plugin's loop-by-default PR mode) is the existing loop primitive — but it operates on an **existing pushed PR**.

This skill fills the gap: **"I have a spec, I want clean code on a branch, no manual handoff between build and review."**

## The acronym glossary

The skill body uses short identifiers for the composed skills — defined once at the top of `SKILL.md`:

| Short | Full | What it does |
|---|---|---|
| **XMAD** | `multi-agent-developer` | TDD-disciplined ≤4-Opus dev team across RED → GREEN → REFACTOR rounds |
| **XMAR** | `multi-agent-review` | Parallel multi-perspective review with synthesizer dedup |
| **XMAR-Loop** | `multi-agent-review pr <ref> --yes` | Iterative review → fix → re-review loop mode on an existing PR |

(`XMAD` / `XMAR` are the original brand identifiers from before the public-rename — kept because "MAD" / "MAR" would read oddly and the glossary makes the mapping explicit.)

## Three phases

### 1. Build (one pass)

Invokes `multi-agent-developer`, captures:

- Worktree path (`.worktrees/feat/<slug>`)
- Branch name (`feat/<slug>`)
- Test result (must be GREEN — if XMAD's final retry left it RED, halt with `BUILD-FAILED`)

### 2. Review loop (1 to `max-iterations` rounds)

Each round runs `multi-agent-review` in a **fresh subagent** (so reviewer transcripts never bloat the coordinator's context). Then the coordinator triages findings:

| Severity | Default action |
|---|---|
| CRITICAL | MUST address (fix in place, OR if `--allow-rebuild > 0` and finding is architectural, trigger rebuild) |
| HIGH | MUST address (fix or defer with rationale + tracker issue) |
| MEDIUM | Coordinator judgment — fix if cheap; else defer + PR comment |
| LOW | PR comment only; do not iterate |

Fixes are applied **inline by the coordinator**, not delegated. Triage requires whole-project context the coordinator holds.

Exit conditions per round:
- VERDICT = APPROVE (no CRITICAL, no HIGH) → ship
- Architectural CRITICAL + rebuild budget remaining → tear down worktree, re-spec, re-build from Phase 1
- Round-N findings ≥80% identical to N-1 → halt with `STUCK-AT-N`
- Round count hits cap → halt with `MAX-ITERATIONS-AT-N`

The **exclusion list** grows across rounds — every deferred or filed finding is added so the next round's reviewers see them under a "DO NOT report" heading. (Fixed findings are NOT added — they're gone from the code.)

### 3. Ship report

A single-screen Markdown summary: verdict + per-round severity table + open follow-ups + LOW-severity comments to paste into the PR description. The skill does NOT auto-open the PR — that's an explicit user action.

## What makes this different

Five load-bearing properties:

1. **One target, no manual handoff.** XMAD output → XMAR input wired together. No copying paths between sessions.
2. **Coordinator applies fixes.** Triage isn't delegated; the orchestrator does the editing. Triage requires whole-project context — subagents don't have it.
3. **Bounded iterations.** Default 3, hard ceiling 8. Past round 3 reviewers are usually nitpicking, not improving.
4. **State on disk.** `.code-rinse-repeat/<slug>/state.md` + `exclusion-list.md` + per-round review documents. Survives session interruption.
5. **Rebuild as escape hatch.** A CRITICAL architectural finding can trigger a tear-down + re-build (with the finding promoted into the spec as an addendum) up to `--allow-rebuild N` times. Slow + expensive; defaults to 0 (off).

## Composition

| Layer | Skill | Plugin |
|---|---|---|
| Spec → code | `multi-agent-developer` | [`multi-agent-developer`](https://github.com/z0rd0n88/ClaudesMods/tree/main/ClaudesMods/multi-agent-developer) |
| Code → findings | `multi-agent-review` | [`multi-agent-review`](https://github.com/z0rd0n88/ClaudesMods/tree/main/ClaudesMods/multi-agent-review) |
| Findings → APPROVE on existing PR | `multi-agent-review pr <ref> --yes` | [`multi-agent-review`](https://github.com/z0rd0n88/ClaudesMods/tree/main/ClaudesMods/multi-agent-review) |
| **Spec → APPROVE end-to-end** | **`code-rinse-repeat`** | **this plugin** |
| Multi-phase build queues | `baton-runner-multi-agent` | [`baton`](https://github.com/z0rd0n88/ClaudesMods/tree/main/ClaudesMods/baton) (drives `code-rinse-repeat` per unit) |

## Install

```bash
claude marketplace add github:z0rd0n88/ClaudesMods
claude plugin install ClaudesMods
```

Its dependencies (`multi-agent-developer`, `multi-agent-review`) are bundled in the same `ClaudesMods` plugin — no separate install needed.

All three are required — `code-rinse-repeat` is a pure orchestrator over the other two.

## Use

```bash
/code-rinse-repeat ./specs/2026-06-payment-replay.md
/code-rinse-repeat #142
/code-rinse-repeat https://github.com/owner/repo/issues/142

# Cap review iterations at 5:
/code-rinse-repeat ./specs/X.md --max-iterations 5

# Lock the dev team + reviewer rosters:
/code-rinse-repeat ./specs/X.md \
  --dev-agents code-architect,python-pro,security-reviewer,silent-failure-hunter \
  --reviewers code-reviewer,architect,critical-thinking,silent-failure-hunter,security-reviewer

# Allow one rebuild on architectural CRITICALs:
/code-rinse-repeat ./specs/X.md --allow-rebuild 1
```

## Layout

```
code-rinse-repeat/
├── .claude-plugin/plugin.json
├── README.md
├── commands/
│   └── code-rinse-repeat.md
└── skills/
    └── code-rinse-repeat/SKILL.md
```

## License

[MIT](../../LICENSE).
