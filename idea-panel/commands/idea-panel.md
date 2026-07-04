---
description: "Parallel panel of thinking-skills mental-model lenses generates and ranks ideas for a topic"
argument-hint: "<topic...> [--lenses <csv>] [--panel-size <n>] [--context <path>] [--write-to <path>]"
---

Invoke the `idea-panel` skill and follow it exactly.

Arguments forwarded: `$ARGUMENTS`

The skill will:

1. Parse the topic and flags; validate `--lenses` tokens and resolve `--context`.
2. Spawn N lens agents in parallel (default: `thinking-first-principles`, `thinking-jobs-to-be-done`, `thinking-inversion`, `thinking-effectuation`) — each a distinct cognitive frame generating candidate ideas for the same topic.
3. Wait for all lenses to return, then synthesize via a single synthesizer agent — clusters, ranks, and dedupes into one shortlist.
4. Print the synthesized report verbatim. (Lens outputs are not surfaced separately.)

Common invocations:

```
idea-panel genetic security — new project/product directions
idea-panel loyalty rewards for indie coffee shops --panel-size 3
idea-panel developer tooling --lenses thinking-triz,thinking-second-order,thinking-jobs-to-be-done
idea-panel authentication UX --context docs/research/ --write-to docs/ideas/auth-panel.md
```

Common flags:
- `--lenses csv` — override the default lens roster (`thinking-<name>` slugs or named specialist agents like `market-researcher`, `product-strategist`)
- `--panel-size n` — clamp the default roster to 3–4 lenses
- `--context path` — background material prepended to every lens brief (16 KB cap)
- `--write-to path` — also save the report to a file (default: stdout only; refuses to overwrite without `--force`)

This skill is **read-only**. It does not edit source files. For evaluating an existing idea/proposal instead of generating new ones, use `idea-autopsy:stress-test-idea` or `idea-autopsy:evaluate-proposal-harsh`.
