---
description: "Parallel multi-perspective review over a PR, dir, file, spec, diff, or slice set"
argument-hint: "<target-type> <target-args> [flags]"
---

Invoke the `multi-agent-review` skill and follow it exactly.

Arguments forwarded: `$ARGUMENTS`

The skill will:

1. Spawn N reviewer agents in parallel (default: architect-review, critical-thinking, ecc-silent-failure-hunter, ecc-security-reviewer) — each with a self-contained brief, the same materials, and the same severity rubric.
2. Wait for all reviewers to return.
3. Synthesize via the synthesizer agent (default: `knowledge-synthesizer`) — applies the dedup, cross-axis severity budget, and exclusion-list discipline from the bundled `refs/multi-agent/` primitives.
4. Print the synthesized report verbatim. (Reviewers' raw outputs are not surfaced separately.)

Common invocations:

```
multi-agent-review pr 42
multi-agent-review dir core/
multi-agent-review file SPEC.md
multi-agent-review spec SPEC.md SPEC-UPDATE.md PRD.md
multi-agent-review diff                         # uncommitted working-tree changes
multi-agent-review diff --staged                # staged hunks
multi-agent-review slices src/foo/ src/bar/    # fan-out per slice + cross-slice synth
```

Common flags:
- `--reviewers csv` — override the default reviewer roster
- `--synthesizer name` — override the synthesizer
- `--mode name` — named preset (e.g. `security`, `architecture`, `pre-pr`)
- `--prompt-prelude path` — inject a project-defined prelude into every brief (skip-lists, house terminology, exclusion list)
- `--high-cap n|off` — cross-axis HIGH-severity budget (default 8; `off` when used as a gate)
- `--write-to path` — also save the report to a file (default: stdout only)

This skill is **read-only**. It does not edit source files. For the iterate-until-clean variant, use `/multi-agent-review-loop`.
