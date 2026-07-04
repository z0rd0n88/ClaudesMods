---
name: strategize-from-verdict
description: Turn an idea-autopsy verdict into ranked constructive strategy — alternative theses, wedge-to-platform sequencing, and a go-to-market shape grounded in the team's stated assets.
---

# Strategize from Verdict

The three critique skills (`stress-test-idea`, `iterate-to-v2`, `evaluate-proposal-harsh`) tear a doc down or translate a critique into edits. None of them build forward. This skill is the constructive counterpart: it takes a **verdict** — especially a Pivot, a Proceed-with-caution, or a Skip that still has a flip-condition — and produces a ranked strategy the founder can act on: alternative theses, a wedge, the sequencing, and the first thing to validate.

It exists because the most useful move after a harsh verdict is not "here's what's wrong" (the verdict already said that) but "here's the strongest forward path your actual assets support." That work is generative, and it must dodge the exact Criticals the verdict raised — otherwise it is just optimism.

## Scope

Designed for **product and business proposals** that have already been through `evaluate-proposal-harsh` (or carry an equivalent verdict + findings). It reads the verdict from on-disk state. It is **not** a generic brainstormer — every option it produces must be tied to (a) the team's stated assets and (b) the specific findings that sank the original thesis. For open-ended idea generation with no verdict to anchor to, use a brainstorming tool such as `xan-idea-panel` instead.

## Confidentiality

The strategist agent receives the document (or its key assets) plus the verdict. If web validation of the proposed theses is requested, the bundled research agent sends the proposed theses and the doc's competitor/market claims to web search — do not enable web validation on confidential or unannounced material. The default (no web) keeps everything closed-world.

## When to use

Trigger after a verdict exists and the user wants forward motion:
- "now what" / "how do I fix this" / "what should I pivot to"
- "help me de-risk this" / "what's the strongest version of this"
- "give me the pivot and the sequencing"
- A `Pivot` or `Proceed with caution` verdict just landed and the user wants the alternative theses fleshed out.

If no verdict exists yet, route the user to `evaluate-proposal-harsh` first — this skill needs a verdict + findings to anchor to. If the verdict was a clean `Invest`, say so: the constructive need is smaller, and the skill should produce only a go-to-market sequencing pass rather than pivot alternatives.

## Inputs

Required — one of:
- A slug whose `./.autopsy/<slug>/state.json` points to a `v<N>-verdict.md` (preferred — read verdict, findings, and flip-condition from there).
- A pasted verdict + findings, if no state exists.

Optional, inline:
- Team assets the doc understates ("our real edge is a warm network into X"). Strategy quality depends heavily on knowing the actual assets.
- `--validate` to web-check each proposed thesis's market and competitors via the bundled research agent (OFF by default; see Confidentiality).
- `--slug <name>` to override the auto-derived state-directory name.

Do not ask follow-up questions before running if a verdict is available. If the team's assets are thin in the doc, note that the strategy is only as good as the asset inventory and proceed with what is stated.

## Workflow

Five steps: locate the verdict, extract the anchors, generate ranked strategy, (optionally) validate, synthesize and write to state.

### Step 0 — Locate the verdict and slug

Derive the slug (same rules as the other skills). Read `./.autopsy/<slug>/state.json` and the latest `v<N>-verdict.md`. If neither exists and the user pasted no verdict, stop and route to `evaluate-proposal-harsh`.

### Step 1 — Extract the anchors (do not skip — these constrain everything)

From the verdict and its findings, capture:
- **The verdict** and, if Pivot/Skip, the specific multi-axis Criticals that sank the thesis.
- **The flip-condition** (artifact + threshold + date) — the strategy's job is to make this reachable or to replace it with a better-targeted one.
- **The team's assets** — from the doc's team/traction sections plus any inline additions the user gave. These are what every proposed thesis must reuse.
- **What must be dodged** — each Critical the new thesis has to *not* reinherit (e.g. "wrong buyer for the team's network", "market hasn't arrived").

### Step 2 — Generate ranked strategy (bundled strategist agent)

Dispatch the bundled `subagent_type: product-strategist` (it carries the positioning/GTM/sequencing frameworks). If that agent type is not registered at runtime, fall back to a `general-purpose` subagent with the inline prompt below. Give it: the doc (or the extracted assets + thesis), the verdict, the Criticals to dodge, and the team's assets. Ask it to return **2–3 ranked alternative theses**, each with:

> - **Thesis** — one sentence: what to build, for whom.
> - **Why it fits THIS team** — the specific stated asset it reuses (a network, a framework, a channel). A thesis that does not reuse a named asset is disqualified.
> - **Which Criticals it dodges** — cite the verdict's findings by name; a thesis that reinherits a sinking Critical is disqualified.
> - **The wedge** — the smallest beachhead that proves the motion, with a rough bottom-up size.
> - **Sequencing (Now / Next / Later)** — wedge → expansion → platform, gated on what.
> - **Riskiest assumption + first test** — the one thing to validate first, and the concrete artifact that would validate it (this is the flip-condition, re-aimed at the new thesis).

Rank the theses by (asset-fit × how cleanly they dodge the Criticals × wedge reachability).

### Step 3 — Validate the theses (`--validate`, optional — OFF by default)

Only if the user passed `--validate`. Dispatch the bundled `subagent_type: project-idea-validator` (WebFetch/WebSearch; fall back to `general-purpose` + inline web prompt if unregistered) to web-check each proposed thesis: does the target market exist, who are the real competitors, is the wedge occupied. Fold results in: a thesis whose market is already saturated or whose "white space" is occupied gets demoted or dropped, with the source noted.

### Step 4 — Synthesize and write to state

Produce the strategy memo (format below). Recommend ONE path and say why it beats the runners-up. Write to `./.autopsy/<slug>/v<N>-strategy.md` and update `state.json` (new artifact + history entry). Do not overwrite the verdict.

## Output format

Use this structure. Every option must be concrete — no "explore adjacent markets".

```markdown
# Strategy from verdict: [title] (v[N])

State: `./.autopsy/[slug]/v[N]-strategy.md`
From verdict: [Invest | Proceed with caution | Pivot | Skip] — one-line recap of what sank the original thesis (or, for Invest, what to sequence).

## The anchors

- **Assets in play:** [the specific team/traction assets every option below reuses]
- **Criticals to dodge:** [the verdict findings a new thesis must not reinherit]
- **Flip-condition to reach or replace:** [artifact + threshold + date from the verdict]

## Ranked strategic options

### Option 1 — [Thesis name] (recommended / runner-up)
- **Thesis:** one sentence.
- **Why it fits this team:** the named asset it reuses.
- **Dodges:** which verdict Criticals it avoids reinheriting.
- **Wedge:** smallest beachhead + rough bottom-up size.
- **Sequencing:** Now [0–3mo] → Next [3–9mo] → Later [platform].
- **Riskiest assumption + first test:** the one thing to validate, and the artifact that validates it.
- **Validation (`--validate`):** market/competitor check result + source, or "not run".

(repeat for 2–3 options, ranked)

## Recommended path

One paragraph: which option, and why it beats the runners-up on asset-fit, Critical-dodging, and wedge reachability. Name the single most important thing to do in the next 30 days.

## Flip-condition, re-aimed

> [Specific artifact] at [measurable threshold] by [date] — targeting the recommended path's riskiest assumption, not the dead thesis's.

## Next step

Draft the recommended path as a v[N+1] doc and run `stress-test-idea` or `evaluate-proposal-harsh` on it to confirm the pivot resolved the Criticals without introducing new ones. State is in `./.autopsy/[slug]/`.
```

## Examples

**Good option — grounded and Critical-dodging**

> ### Option 1 — Community-guardian bot (recommended)
> - **Thesis:** ship the behavioral-eval engine as a co-branded bot inside crypto communities, not as an enterprise API.
> - **Why it fits this team:** reuses the CEO's DeFi/DAO network (MakerDAO/Aave/1inch) — the *actual* warm channel, which the enterprise thesis did not.
> - **Dodges:** "wrong buyer for the team's network" (Critical), "moat contingent on enterprise data-sharing" (the bot generates first-party data directly), "market hasn't arrived" (communities exist now).
> - **Wedge:** 5–10 partner communities at $15k–$50k grants = $75k–$500k non-dilutive; bottom-up, not a $150M fantasy.
> - **Sequencing:** Now: one co-built bot + data loop → Next: 5 communities, compounding dataset → Later: the API the enterprise thesis wanted, now with data behind it.
> - **Riskiest assumption + first test:** that one community will co-build. Test: one signed community partner with a deployed bot by [date].

**Bad option (disqualified)**

> "Explore enterprise healthcare as an adjacent market." — No named asset reused, reinherits the regulated-buyer Critical, no wedge, no test. Do not produce options like this.

## Edge cases

- **No verdict on disk and none pasted:** stop; route to `evaluate-proposal-harsh` first. This skill needs a verdict to anchor to.
- **Verdict was Invest:** skip pivot alternatives; produce only a go-to-market sequencing pass (Now/Next/Later + the first validation artifact).
- **Verdict was Skip with "no plausible flip-condition exists":** be honest — if the space is genuinely dead for this team, say the strongest move may be to redeploy the assets elsewhere, and name where, rather than manufacture a thesis.
- **Team assets are thin in the doc:** note that strategy quality is capped by the asset inventory; ask once for the real assets if the user is present, else proceed with what is stated and flag the gap.
- **Bundled agent not registered at runtime:** fall back to a `general-purpose` subagent with the inline strategist/validator prompts. Functionality is the same; the persona grounding is weaker.

## What not to do

- Do not generate a thesis that does not reuse a named team asset. Ungrounded strategy is the failure mode this skill exists to avoid.
- Do not propose a thesis that reinherits a Critical the verdict already raised. The whole point is to dodge them.
- Do not produce vague options ("go upmarket", "explore adjacent markets"). Every option needs a wedge, a sequence, and a first test.
- Do not overwrite or contradict the verdict. This skill builds on it; it does not relitigate it.
- Do not duplicate `xan-idea-panel`. This is verdict-anchored and asset-constrained, not open-ended ideation.
- Do not enable `--validate` (web) on confidential or unannounced material.
- Do not skip writing to `./.autopsy/<slug>/`. The strategy memo is part of the loop's on-disk trail.
