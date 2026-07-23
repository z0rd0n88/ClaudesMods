# deep-research

A cost-guardrailed deep-research harness for Claude Code. Runs a fan-out research workflow —
decompose → parallel web search → fetch & extract falsifiable claims → multi-vote **adversarial**
verification → cited synthesis — and returns a structured, fact-checked report.

## The problem it fixes

The original `deep-research` workflow spawned ~80–95 subagents per run, **all inheriting the
session model**, with **no token ceiling** and high fixed caps (15 fetch / 25 claims / 3 votes).
From an Opus session that is extremely expensive, extremely fast.

## The guardrails

| Lever | Before | After |
|---|---|---|
| Model per stage | session model everywhere (~90 agents) | `sonnet` on scope/search/fetch/verify; `opus` synthesis |
| Token ceiling | none | reads the `budget` global; trims caps + hard-gates the verify fan-out |
| Caps | fixed 15 / 25 / 3 | depth presets — `quick` 5/6/2 · `standard` 8/12/3 · `deep` 15/25/3 |
| Overrides | none | `args` object: `depth`, `maxFetch`, `maxClaims`, `votes`, `models` |
| Transparency | — | upfront cost estimate; dropped sources/claims logged, never silent |

Adversarial rigor is preserved — verification still runs multiple skeptical voters per claim
(default-refute-if-uncertain); the savings come from running those voters on a cheap model and
bounding how many run, not from weakening the check.

## Usage

Invoke the `deep-research` skill (or call the Workflow tool directly):

```
Workflow({
  scriptPath: "${CLAUDE_PLUGIN_ROOT}/deep-research/skills/deep-research/deep-research.workflow.js",
  args: "How reliable is intermittent fasting for weight loss in 2026?"
})
```

Override guardrails by passing an object as `args` — see [`skills/deep-research/SKILL.md`](skills/deep-research/SKILL.md).

## Install

```
/plugin marketplace update claudes-mods
/plugin install deep-research@claudes-mods
```

Requires the Workflow tool (multi-agent orchestration) and `WebSearch` / `WebFetch`.
