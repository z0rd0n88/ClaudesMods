# Idea Autopsy

A three-skill plugin for honest, decision-shaped idea review. One slash command, three modes, one workflow.

```
stress-test-idea  →  iterate-to-v2  →  evaluate-proposal-harsh
   (find holes)      (change plan)        (verdict)
```

You start with a doc. You stress-test it to surface the weaknesses. You iterate to a tighter v2. Then you evaluate v2 for a clean invest/skip call. Each step is an independent skill; `/autopsy` is the router that picks the right one based on what you have right now.

## The three skills

| Skill | Input | Output | Use when |
|---|---|---|---|
| [`stress-test-idea`](./skills/stress-test-idea/SKILL.md) | A doc (v1) | Two-reviewer consensus + iteration recommendations | You want feedback to inform a rewrite |
| [`iterate-to-v2`](./skills/iterate-to-v2/SKILL.md) | Doc + critique | Section-by-section change plan, things-to-cut/add list | You have a critique in hand and need to produce v2 |
| [`evaluate-proposal-harsh`](./skills/evaluate-proposal-harsh/SKILL.md) | A doc (v2) | Four-axis graded review ending in invest/skip verdict | You want a decision, not iteration input |

Each skill is independent — you can run any of them stand-alone via its name or by triggering on its language. The `/autopsy` router only exists to pick between them.

## `/autopsy` routing

The router picks by what you provide and the language you use:

| You have | `/autopsy` invokes |
|---|---|
| Doc + critique (two inputs) | `iterate-to-v2` |
| Doc + verdict language ("should I build this?", "go/no-go", "give me a verdict") | `evaluate-proposal-harsh` |
| Doc + iteration language ("tear this apart", "what should I fix", "find the holes") | `stress-test-idea` |
| Doc only, no signal | Asks once: iteration or verdict? |
| No doc | Asks once for a doc |

The full rules are in [`commands/autopsy.md`](./commands/autopsy.md).

## Why this exists

Most LLM critiques default to encouraging-and-balanced when the user actually wants harsh-and-decisive. The three skills are architected to force decisiveness:

- **`stress-test-idea`** runs two independent reviewers in parallel (a thinking-skills battery + a devils-advocate critique) and synthesizes their findings into consensus / unique / contradictions buckets. Parallelism is load-bearing — sequential review lets the second reviewer anchor to the first.
- **`iterate-to-v2`** enforces a *change-vs-hedge* rule: a finding is "addressed" when the doc no longer makes the problematic claim, not when the doc acknowledges the problem. Hedging keeps bad content and apologizes for it; iteration removes or restructures it. Output is a section-by-section change plan, not an auto-rewrite — the founder owns the voice.
- **`evaluate-proposal-harsh`** runs four parallel axis-specific reviewers and ends in a verdict block that must commit to one of three answers (invest / skip / pivot). No balanced-on-the-one-hand-on-the-other endings.

The combination produces an iterable loop: critique → change → re-critique → … → verdict. You exit when the verdict says go (or when the critique can't find anything load-bearing left to flag).

## Install

### Via the ClaudesMods marketplace (recommended)

```bash
claude marketplace add github:z0rd0n88/ClaudesMods
claude plugin install idea-autopsy
```

### Standalone (local clone)

```bash
git clone https://github.com/z0rd0n88/ClaudesMods.git
claude --plugin-dir ./ClaudesMods/idea-autopsy
```

## Use

```
> /autopsy ./my-pitch.md
Routing to `stress-test-idea`…
[full review output]
```

Or just trigger the underlying skill by language:

```
> Tear this pitch apart: <paste>
> (stress-test-idea runs)

> Apply this critique to my pitch and tell me what to change for v2: <paste doc + critique>
> (iterate-to-v2 runs)

> Should I quit my job to build this? <paste doc>
> (evaluate-proposal-harsh runs)
```

## Layout

```
idea-autopsy/
├── .claude-plugin/plugin.json    # plugin metadata
├── README.md                     # this file
├── commands/
│   └── autopsy.md                # /autopsy router
└── skills/
    ├── stress-test-idea/SKILL.md
    ├── iterate-to-v2/SKILL.md
    └── evaluate-proposal-harsh/SKILL.md
```

## License

[MIT](../LICENSE).
