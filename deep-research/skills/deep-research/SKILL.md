---
name: deep-research
description: Run a cost-guardrailed deep-research report — fan-out web search, adversarial claim verification, cited synthesis — with cheap models on the bulk stages and a token-budget ceiling.
argument-hint: <research question>
user-invocable: true
---

# Deep Research (guardrailed)

Produces a multi-source, adversarially fact-checked research report by running the
`deep-research.workflow.js` orchestration script via the **Workflow** tool. This skill's
instructions are the explicit opt-in that authorizes the Workflow call.

## Why this exists

The bare deep-research workflow fans out ~80–95 subagents per run (5 search + up to 15
fetch + up to 25×3 adversarial verify + synthesis) with **every agent inheriting the session
model** and **no token ceiling** — it can cost a fortune from an Opus session. This skill runs
a guardrailed port that keeps the adversarial rigor but controls the spend.

## Guardrails (built into the script)

- **Cheap models on the high-volume stages.** Search / fetch / verify run on `haiku`;
  only scope-decomposition (`sonnet`) and final synthesis (`opus`) use a strong model.
  This is the biggest cost lever — the mechanical, schema-constrained stages don't need a
  frontier model.
- **Token-budget ceiling.** The script reads the turn's `budget` global. If a `+N` budget
  was set, it trims the fetch/claim/vote caps up front and hard-gates the verify fan-out so a
  large claim pool can't blow the ceiling. Trimmed items are logged, never silently dropped.
- **Depth presets** (default `standard`): `quick` (5 fetch / 6 claims / 2 votes),
  `standard` (8 / 12 / 3), `deep` (15 / 25 / 3). Lower than the old fixed 15 / 25 / 3.
- **Upfront cost estimate.** Logs the worst-case agent count and active caps before spending.

## Before invoking

1. **Is the question specific enough?** If underspecified (e.g. "what car to buy" with no
   budget/use-case/region), ask 2–3 clarifying questions first, then weave the answers into
   the question you pass.
2. **Pick a depth.** Default to `standard`. Use `quick` for a fast sanity check, `deep` only
   when the user wants exhaustive coverage and accepts the cost.

## How to run

Call the Workflow tool with the script path and the question as `args`:

```
Workflow({
  scriptPath: "${CLAUDE_PLUGIN_ROOT}/skills/deep-research/deep-research.workflow.js",
  args: "<the refined research question>"
})
```

To override the guardrails, pass an **object** instead of a string:

```
Workflow({
  scriptPath: "${CLAUDE_PLUGIN_ROOT}/skills/deep-research/deep-research.workflow.js",
  args: {
    question: "<question>",
    depth: "quick" | "standard" | "deep",   // preset; default "standard"
    maxFetch: 8,                              // override sources fetched
    maxClaims: 12,                            // override claims verified
    votes: 3,                                 // adversarial votes per claim
    models: { verify: "sonnet", synthesize: "opus" }  // override any stage's model
  }
})
```

`${CLAUDE_PLUGIN_ROOT}` resolves to this plugin's install directory. If it isn't substituted
(e.g. running the skill by hand), use the absolute path to
`skills/deep-research/deep-research.workflow.js` under the plugin.

## After it returns

The workflow returns a structured object: `summary`, `findings` (each with confidence +
sources), `refuted` and `unverified` claims (for transparency), `sources`, and a `stats` block
(agent count, caps hit, claims dropped to the cap). Relay the summary and findings to the user
with citations; surface the caveats and anything the cost cap left unverified.
