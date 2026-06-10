# Multi-Agent Review

Parallel multi-perspective code review with a synthesizer that dedupes findings across reviewer lenses, plus an iterative wrapper that runs review → fix → re-review on an open PR until it's clean.

Built around the insight that **single-agent review is a thin filter** and **multi-agent review without coordination is noise** — what's needed is parallel fan-out plus a synthesis layer that catches what each reviewer missed without re-reporting what they all caught.

## The two skills

| Skill | What it does | Command |
|---|---|---|
| [`multi-agent-review`](./skills/multi-agent-review/SKILL.md) | One-pass parallel review. Spawns N reviewer agents over a target (PR/dir/file/spec/diff/slice set), then a synthesizer merges the reports into one prioritized verdict. Read-only. | `/multi-agent-review` |
| [`multi-agent-review-loop`](./skills/multi-agent-review-loop/SKILL.md) | Iterative wrapper. Each round runs `multi-agent-review` in a fresh subagent (so the reviewer transcripts never bloat the coordinator's context), coordinator applies fixes between rounds, until VERDICT = APPROVE or max iterations. | `/multi-agent-review-loop` |

## Bundled shared primitives

The `refs/multi-agent/` directory ships the contracts both skills (and any future multi-agent skill in your toolkit) build on:

| Ref | What it codifies |
|---|---|
| [`fanout-consolidation.md`](./refs/multi-agent/fanout-consolidation.md) | Parallel-fan-out contract, dedupe rules, cross-axis severity budget (caps total HIGH so N reviewers each finding "one HIGH" doesn't = N blockers). |
| [`agent-catalog-lookup.md`](./refs/multi-agent/agent-catalog-lookup.md) | How `--reviewers <csv>` names resolve against the project active catalog + user-scope parked tier. |
| [`exclusion-list.md`](./refs/multi-agent/exclusion-list.md) | The "DO NOT report findings already tracked" discipline that prevents recurring sweeps from re-reporting open issues. |
| [`spec-injection.md`](./refs/multi-agent/spec-injection.md) | How to inject the originating spec/issue into reviewer briefs so they can raise CRITICAL if the diff fails to satisfy the originating intent. |

## What makes this different from "run a code reviewer agent"

Five load-bearing properties most ad-hoc review setups miss:

1. **Parallel, not sequential.** Reviewers run as concurrent agent tool calls in a single dispatch. Sequential review lets later reviewers anchor to earlier findings instead of reasoning fresh.
2. **Synthesizer is a separate role.** Reviewers produce raw findings; a synthesizer agent dedupes and prioritizes. Reviewers don't see each other's output. The skill prints only the synthesized verdict — raw reviewer transcripts stay sandboxed.
3. **Cross-axis severity budget.** If 4 reviewers each surface "one HIGH," that's not 4 blockers — it's noise that needs ranking. The budget demotes excess HIGHs to MEDIUM with explicit rationale.
4. **Exclusion-list discipline.** Open tracker issues are injected verbatim into every reviewer's prompt under a "DO NOT report" heading. Recurring sweeps stay quiet on issues you've already triaged.
5. **Target taxonomy.** `pr`, `dir`, `file`, `spec`, `diff`, and `slices` (fan-out across N directories with cross-slice meta-synth). Most review tools cover only `pr` or only `diff`; the spec/slices forms are rare and load-bearing.

## Install

```bash
claude marketplace add github:z0rd0n88/ClaudesMods
claude plugin install multi-agent-review
```

## Use

One-shot review of an open PR:

```bash
/multi-agent-review pr 42
```

Layer-sliced review of a hex-arch repo with project-defined skip-list:

```bash
/multi-agent-review slices src/foo/domain/ src/foo/application/ src/foo/adapters/ \
  --mode code --prompt-prelude .claude/multi-agent-review-modes/skip-list.md
```

Iterate until clean on PR 203, capped at 5 rounds:

```bash
/multi-agent-review-loop 203 --max-iterations 5
```

## Composition with other skills

This plugin pairs with the rest of the multi-agent stack:

| Layer | Skill | Where it lives |
|---|---|---|
| Spec → code | `multi-agent-developer` | [sibling plugin in ClaudesMods](https://github.com/z0rd0n88/ClaudesMods/tree/main/multi-agent-developer) |
| Code → findings | **`multi-agent-review`** | this plugin |
| Findings → APPROVE on existing PR | **`multi-agent-review-loop`** | this plugin |
| Spec → APPROVE end-to-end | `code-rinse-repeat` | [sibling plugin in ClaudesMods](https://github.com/z0rd0n88/ClaudesMods/tree/main/code-rinse-repeat) |
| Pattern library for repo-wide review sweeps | [`total-review`](https://github.com/z0rd0n88/ClaudesMods/tree/main/total-review) | sibling plugin in ClaudesMods |

`total-review` and `multi-agent-review` share the same `refs/multi-agent/` primitives. If you install both, the refs are duplicated in each plugin (intentional — each plugin stays self-contained). When you edit a primitive (e.g. the severity budget formula), keep the two copies in sync.

## Layout

```
multi-agent-review/
├── .claude-plugin/plugin.json
├── README.md
├── commands/
│   ├── multi-agent-review.md
│   └── multi-agent-review-loop.md
├── refs/
│   └── multi-agent/
│       ├── fanout-consolidation.md
│       ├── agent-catalog-lookup.md
│       ├── exclusion-list.md
│       └── spec-injection.md
└── skills/
    ├── multi-agent-review/SKILL.md
    └── multi-agent-review-loop/SKILL.md
```

## License

[MIT](../LICENSE).
