# Idea Autopsy

A four-skill plugin for honest, decision-shaped idea review. One slash command, four modes, one auditable loop on disk.

```
stress-test-idea  →  iterate-to-v2  →  evaluate-proposal-harsh  →  strategize-from-verdict
   (find holes)      (change plan)        (verdict)                 (forward strategy)
```

You start with a doc. You stress-test it to surface the weaknesses. You iterate to a tighter v2. Then you evaluate v2 for a clean Invest / Proceed-with-caution / Pivot / Skip call with a measurable flip-condition — and, when the verdict says Pivot or Proceed, you strategize forward into ranked alternative theses. Each step is an independent skill; `/autopsy` is the router that picks the right one based on what you have right now AND what's already on disk from prior runs.

**Accuracy note (v1.2.0):** in the two review skills, every high-severity finding now passes an *independent verification pass* before it counts toward the output, and each finding carries a provenance tag — `[doc-claim]`, `[reviewer-inference]`, or `[verified]` — so a reviewer's outside-knowledge assertion is never silently read as established fact. Opt into web fact-checking of the doc's external claims with `--verify-claims`.

## The four skills

| Skill | Input | Output | Use when |
|---|---|---|---|
| [`stress-test-idea`](./skills/stress-test-idea/SKILL.md) | A doc (v1) | Three-reviewer consensus + iteration recommendations (verified, provenance-tagged) | You want feedback to inform a rewrite |
| [`iterate-to-v2`](./skills/iterate-to-v2/SKILL.md) | Doc + critique | Section-by-section change plan with required "Removes problematic claim by:" field | You have a critique in hand and need to produce v2 |
| [`evaluate-proposal-harsh`](./skills/evaluate-proposal-harsh/SKILL.md) | A doc (v2) | Four-axis graded review with multiplicity-aware verdict + measurable flip-condition | You want a decision, not iteration input |
| [`strategize-from-verdict`](./skills/strategize-from-verdict/SKILL.md) | A verdict + findings | Ranked alternative theses, wedge→platform sequencing, re-aimed flip-condition | You have a Pivot/Proceed verdict and want the forward path |

Each skill is independent — you can run any of them stand-alone via its name or by triggering on its language. The `/autopsy` router exists to pick between them and to drive the full loop (`--loop` flag).

## Scope

Designed for **product and business proposals** — pitches, decks, project briefs, business plans, RFPs, one-pagers. The lenses (jobs-to-be-done, TAM, business-model PASS/FAIL, ROI math, etc.) assume a doc that proposes something to build, ship, and monetize.

For research proposals, internal architecture specs, OSS roadmaps, or creative briefs the lenses will produce uneven findings ("Doc has no TAM. Critical." on a research grant is nonsense). If your doc is non-business, declare it at invocation so the irrelevant axes can be downweighted — or use a different review tool.

## Confidentiality

`stress-test-idea` and `evaluate-proposal-harsh` dispatch reviewer subagents via the Task tool with the **full document text in each prompt**. With three reviewers (stress-test) or four reviewers (evaluate) plus one verification subagent, the doc is replicated several times across subagent transcripts. For confidential pitch decks, unannounced fundraising material, or anything with cap-table details, excerpt or anonymize before running.

By default everything stays **closed-world** — no network calls. Two opt-in flags change that: `--verify-claims` (review skills) and `--validate` (`strategize-from-verdict`) send extracted claims and proposed theses to **web search** via a bundled research agent. Do not enable them on confidential or unannounced material — treat turning them on as publishing those claims to a third-party search service.

`iterate-to-v2` does not fan out — it runs on the main thread.

## `/autopsy` routing

The router picks by what you provide, the language you use, and what's on disk:

| You have | `/autopsy` invokes |
|---|---|
| Doc + critique (two inputs, OR state.json with prior critique) | `iterate-to-v2` |
| Doc + verdict language ("should I build this?", "go/no-go", "give me a verdict") | `evaluate-proposal-harsh` |
| Doc + iteration language ("tear this apart", "what should I fix", "find the holes") | `stress-test-idea` |
| Doc only, no signal, state.json present | Next-logical step based on what's missing |
| Doc only, no signal, no state | Asks once: iteration or verdict? |
| No doc | Asks once for a doc |

### Flags

| Flag | Behavior |
|---|---|
| `--loop` | Run the full cycle in one orchestrated session (stress-test → user provides v2 → evaluate). Caps at 3 versions. |
| `--status` | Print where you are in the cycle (reads `./.autopsy/<slug>/state.json`) and what's next. |
| `--reset` | Archive existing `./.autopsy/<slug>/` to `<slug>.archived-<timestamp>/` and start fresh. |
| `--slug NAME` | Override the auto-derived slug. |
| `--verify-claims` | (review skills) Web-check the doc's external claims — competitors, stats, exit comps. OFF by default; see Confidentiality. |
| `--validate` | (`strategize-from-verdict`) Web-check each proposed thesis's market and competitors. OFF by default. |

The full rules are in [`commands/autopsy.md`](./commands/autopsy.md).

## State files (the loop closure)

Each multi-step review writes to `./.autopsy/<slug>/` next to the doc:

```
./.autopsy/<slug>/
├── state.json                # { slug, doc_path, current_version, artifacts, history }
├── v1.md                     # snapshot of original
├── v1-stress-test.md         # stress-test-idea output
├── v1-change-plan.md         # iterate-to-v2 output
├── v2.md                     # founder's rewrite (you provide)
├── v2-stress-test.md         # optional re-test
├── v2-verdict.md             # evaluate-proposal-harsh output
└── v2-strategy.md            # strategize-from-verdict output (post-verdict)
```

This is what makes the loop auditable — every artifact is on disk, traceable to the prior step. The router uses state.json to figure out the next-logical step automatically. Add `./.autopsy/` to your `.gitignore` if the docs are confidential.

## Why this exists

Most LLM critiques default to encouraging-and-balanced when the user actually wants harsh-and-decisive. The skills are architected to force decisiveness — and, as of v1.2.0, to force *accuracy*:

- **`stress-test-idea`** runs three reviewers with complementary lenses in parallel (thinking-skills battery + devils-advocate dimension critique + silent-failure lens) and synthesizes their findings into consensus / unique / contradictions buckets. Parallel dispatch prevents cross-reviewer anchoring; the synthesizer weights cross-lens consensus heavily.
- **`iterate-to-v2`** enforces a *change-vs-hedge* rule via a required `Removes problematic claim by:` field on every recommendation. Hedging keeps bad content and apologizes for it; iteration removes or restructures it. Output is a section-by-section change plan, not an auto-rewrite — the founder owns the voice. Acceptance defaults are bucket-aware: when the input is a `stress-test-idea` output, only Consensus and real-Unique findings are auto-accepted (Unique-reach is auto-deferred).
- **`evaluate-proposal-harsh`** runs four parallel axis-specific reviewers, builds an issue × axis multiplicity table, then applies a four-way decision rule (Invest / Proceed with caution / Pivot / Skip). The verdict's flip-condition must name a specific artifact, a measurable threshold, and a date — vague "if the team validates demand" flip-conditions are forbidden.
- **`strategize-from-verdict`** is the constructive counterpart: it reads a verdict and generates ranked alternative theses, each tied to the team's stated assets and required to dodge the exact Criticals the verdict raised — turning "here's what's wrong" into "here's the strongest forward path."
- **Verification, everywhere it counts.** Before any finding drives a verdict or a recommendation, an *independent* subagent (which never saw the reviewer's reasoning) checks it against the document — CONFIRM / REFUTE / NEEDS-EVIDENCE. Refuted findings are dropped, unverifiable ones demoted, so a confident-but-wrong claim can't swing the result. Every finding is provenance-tagged, and a required convergence check flags when reviewers agree because they share a blind spot rather than because the idea is robustly weak.

The combination produces an auditable loop on disk: critique → change-plan → user rewrite → re-critique (or verdict) → … . You exit when the verdict says Invest (or when Pivot/Skip closes the door on this particular thesis).

## Install

### Via the ClaudesMods marketplace (recommended)

```bash
claude plugin marketplace add z0rd0n88/ClaudesMods
claude plugin install idea-autopsy@claudes-mods
```

To upgrade after a new release:

```bash
claude plugin marketplace update claudes-mods
claude plugin update idea-autopsy@claudes-mods
```

### Standalone (local clone)

```bash
git clone https://github.com/z0rd0n88/ClaudesMods.git
claude --plugin-dir ./ClaudesMods/idea-autopsy
```

## Use

```
> /autopsy ./my-pitch.md
Routing to `stress-test-idea` (slug: my-pitch, state: v1)…
[full review output, written to ./.autopsy/my-pitch/v1-stress-test.md]

> /autopsy --status ./my-pitch.md
Slug: my-pitch
Current: v1, stress-tested.
Next: iterate-to-v2 (or rewrite to v2.md and re-test/evaluate).

> /autopsy --loop ./my-pitch.md
[orchestrates the full cycle, prompting you to drop v2.md when ready]
```

Or just trigger the underlying skill by language:

```
> Tear this pitch apart: <paste>
> (stress-test-idea runs)

> Apply this critique to my pitch and tell me what to change for v2: <paste doc + critique>
> (iterate-to-v2 runs)

> Should I quit my job to build this? <paste doc>
> (evaluate-proposal-harsh runs)

> The verdict said pivot — now what should I build?
> (strategize-from-verdict runs, reading the verdict from state)
```

## Examples

Three worked examples ship with the plugin, one per main verdict path. Each has the input doc, illustrative outputs at each stage, and a `WALKTHROUGH.md` narrating what happened and why.

| Example | Verdict | Showcases |
|---|---|---|
| [`examples/consumer-app-pitch/`](./examples/consumer-app-pitch/) | **Proceed with caution** | Full three-skill loop end-to-end. Change-vs-hedge enforcement, bucket-aware acceptance, measurable flip-condition. |
| [`examples/b2b-saas-pivot/`](./examples/b2b-saas-pivot/) | **Pivot** | Strong team / wrong thesis pattern. New v1.1 Pivot verdict with two concrete alternative theses. |
| [`examples/unsupported-tam-skip/`](./examples/unsupported-tam-skip/) | **Skip** (no flip) | 4/4-axis Critical, structurally-broken proposal. "No plausible flip-condition exists" output. |

Start with [`examples/consumer-app-pitch/`](./examples/consumer-app-pitch/WALKTHROUGH.md) for the full loop; the others are short reads showcasing the verdict variety. See [`examples/README.md`](./examples/README.md) for an index.

## Layout

```
idea-autopsy/
├── .claude-plugin/plugin.json    # plugin metadata
├── README.md                     # this file
├── agents/                       # bundled specialist agents (web-capable)
│   ├── project-idea-validator.md # --verify-claims research agent
│   └── product-strategist.md     # strategize-from-verdict strategist
├── commands/
│   └── autopsy.md                # /autopsy router (--loop/--status/--reset/--verify-claims/--validate)
├── examples/                     # three worked examples (one per verdict path)
│   ├── README.md
│   ├── consumer-app-pitch/       # full loop → Proceed with caution
│   ├── b2b-saas-pivot/           # → Pivot
│   └── unsupported-tam-skip/     # → Skip (no plausible flip)
├── scripts/
│   ├── check-drift.py            # mirror-sync check (maintainers)
│   └── README.md
└── skills/
    ├── stress-test-idea/SKILL.md
    ├── iterate-to-v2/SKILL.md
    ├── evaluate-proposal-harsh/SKILL.md
    └── strategize-from-verdict/SKILL.md
```

## Mirror sync (maintainers)

The source of truth for this plugin is this repo (`z0rd0n88/ClaudesMods/idea-autopsy/`). When installed via the marketplace, a copy lives under `~/.claude/plugins/cache/claudes-mods/idea-autopsy/<version>/` (or wherever your install root puts it). The drift check covers `plugin.json`, `commands/`, `skills/`, `agents/`, and `examples/`. To verify the source and the install haven't drifted, run:

```bash
python3 scripts/check-drift.py <install-path>
```

Exit code 0 = no drift; 1 = drift detected (script prints what's different). Run before tagging a release or after merging upstream changes. See [`scripts/README.md`](./scripts/README.md) for details.

## License

[MIT](../LICENSE).
