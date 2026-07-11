---
description: "Parallel multi-perspective review over a PR, dir, file, spec, diff, or slice set; a PR target loops review→fix→re-review by default"
argument-hint: "<target-type> <target-args> [flags]"
---

Invoke the `multi-agent-review` skill and follow it exactly.

Arguments forwarded: `$ARGUMENTS`

The skill will:

1. Select the mode: a `pr` target **loops by default** (review→fix→re-review until APPROVE or max iterations, behind a confirmation gate); `--no-loop` forces a one-shot read-only report; every other target (`dir`/`file`/`spec`/`diff`/`slices`) is always one-shot read-only.
2. Per review pass, spawn N reviewer agents in parallel (default: architect-review, critical-thinking, ecc-silent-failure-hunter, ecc-security-reviewer) — each with a self-contained brief, the same materials, and the same severity rubric.
3. Wait for all reviewers to return, then synthesize via the synthesizer agent (default: `knowledge-synthesizer`) — applies the dedup, cross-axis severity budget, and exclusion-list discipline from the bundled `refs/multi-agent/` primitives.
4. One-shot mode: print the synthesized report verbatim. Loop mode: triage findings (every CRITICAL + HIGH addressed; MEDIUM is coordinator judgment; LOW gets a PR comment), apply fixes inline, run tests + smoke gate, commit + push, re-review — then print the loop report and post a PR comment.

Common invocations:

```
multi-agent-review pr 42                       # LOOPS by default (confirmation gate; mutating)
multi-agent-review pr 42 --yes                 # loop without the gate (unattended runs)
multi-agent-review pr 42 --no-loop             # one-shot read-only report
multi-agent-review pr 42 --max-iterations 5    # loop, cap at 5 rounds
multi-agent-review dir core/
multi-agent-review file SPEC.md
multi-agent-review spec SPEC.md SPEC-UPDATE.md PRD.md
multi-agent-review diff                         # uncommitted working-tree changes
multi-agent-review diff --staged                # staged hunks
multi-agent-review slices src/foo/ src/bar/    # fan-out per slice + cross-slice synth
```

Common flags:
- `--no-loop` — one-shot read-only report on a `pr` target (accepted no-op elsewhere)
- `--yes` — skip the loop confirmation gate (looping `pr` only; required for unattended runs)
- `--max-iterations n` — loop round cap, 1–8, default 3 (looping `pr` only)
- `--high-and-up-only` — auto-defer MEDIUM/LOW each round (looping `pr` only)
- `--no-smoke` — skip the live smoke gate (looping `pr` only)
- `--reviewers csv` — override the default reviewer roster
- `--synthesizer name` — override the synthesizer
- `--mode name` — named preset (e.g. `security`, `architecture`, `pre-pr`)
- `--prompt-prelude path` — inject a project-defined prelude into every brief (skip-lists, house terminology, exclusion list)
- `--high-cap n|off` — cross-axis HIGH-severity budget (default 8; `off` when used as a gate; forced `off` on every inner pass in loop mode)
- `--write-to path` — also save the final report to a file (default: stdout only; loop mode writes once, the final loop report)

Loop-only flags (`--yes`, `--max-iterations`, `--high-and-up-only`, `--no-smoke`) are valid only on a looping `pr` target — combining a loop-control flag with `--no-loop` or a non-`pr` target is a parse-time hard-fail.

All non-`pr` targets, and any `--no-loop` run, are **read-only** — no source files are edited.
