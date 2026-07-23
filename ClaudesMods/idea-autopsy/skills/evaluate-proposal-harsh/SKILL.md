---
name: evaluate-proposal-harsh
description: Run a hard-nosed multi-axis review of a proposal, pitch deck, spec, business plan, project brief, or any document describing something to potentially build or fund, and return an explicit Invest / Proceed-with-caution / Pivot / Skip verdict with graded findings and a measurable flip-condition. Use whenever the user asks to evaluate, critique, review, stress-test, or get an honest take on a proposal or strategic document — including phrases like "should I build this", "is this worth my time", "evaluate this idea", "give me a verdict", "should I invest in this", "go/no-go", or any request for decision-shaped feedback on whether to commit time or money to a project. Trigger even when the user doesn't explicitly say "evaluate" — if they share a doc and ask for honest feedback that will inform a go/no-go decision, this is the right tool. Scope is product/business proposals.
---

# Evaluate Proposal (Harsh)

Run an honest, decision-shaped review of a proposal document. The point is not a balanced analysis — it is to give the reader a clear verdict they can act on. The skill orchestrates four parallel reviewers, each applying a different lens, then synthesizes their findings into a graded report ending in an explicit verdict drawn from a four-way decision rule.

This skill exists because most LLM critiques default to encouraging-and-balanced when the user actually wants harsh-and-decisive. The architecture forces decisiveness: parallel reviewers, graded severity, a verdict block that must commit to one of four answers (Invest / Proceed with caution / Pivot / Skip), and a flip-condition the founder can measure.

## Scope

Designed for **product and business proposals** — pitches, decks, business plans, RFPs, project briefs, one-pagers. The four axes (Critical Thinking, Feasibility, Risk, ROI Signal) assume a doc that proposes something to build, ship, and monetize. For research proposals, internal architecture specs, OSS roadmaps, or creative-project briefs the axes will fire badly (the ROI axis on a research grant proposal produces nonsense). If the doc is non-business, the user should say so at invocation so the irrelevant axes can be downweighted — or use a different review tool.

## Confidentiality

Each axis reviewer is dispatched as a subagent via the Task tool with the **full document text in its prompt**. With four reviewers, the doc is replicated four times across subagent transcripts. For confidential decks, unannounced fundraising material, or anything with cap-table details, excerpt or anonymize before running. Mention this to the user once if the doc appears sensitive.

The internal verification pass (see Synthesis rules) adds one more subagent that receives the findings plus the document — same closed-world profile, no external calls. **`--verify-claims` is different:** it sends extracted factual claims (named competitors, cited stats, exit comps) to web search via a bundled research agent. It is OFF by default. Do not enable `--verify-claims` on confidential, unannounced, or cap-table-bearing material — treat turning it on as publishing those claims to a third-party search service.

## When to use

The user has a document — proposal, pitch deck, spec, business plan, project brief, RFP, one-pager, internal memo — describing a project they are considering committing time or money to. They want to know whether to pursue it.

Trigger this skill on direct asks ("evaluate this proposal"), implied asks ("here's my idea doc, what do you think?"), and decision-framed asks ("should I build this?"). When in doubt, prefer triggering — the cost of running this skill on a non-proposal is mild verbosity; the cost of not triggering when the user wanted it is wasted time.

## Inputs

Required: a document to evaluate. Accept any of:
- A file path the user provides (read it with the appropriate tool)
- Pasted text in the conversation
- A reference to a previously shared file

Optional, taken inline at invocation: investment context the user provides. Examples:
- Time budget: "I have 3 months of focused time"
- Money budget: "willing to put in $50k of my own money"
- Strategic fit: "must complement my existing crypto infrastructure"
- Constraints: "I have one other co-founder, no funding yet"
- `--slug <name>` to override the auto-derived state-directory name
- `--verify-claims` to additionally fact-check the doc's *external* claims (competitors, stats, exit comps) against the web. OFF by default; see Confidentiality. The internal doc-support verification pass always runs and needs no flag.

Do not ask follow-up clarifying questions. If the user gave you a doc, run the evaluation. If investment context is missing, assume a generic founder/operator with limited time and money.

If the user did not actually share a document — only described an idea verbally in chat — ask once for the doc, briefly. Do not run the skill on a verbal description; the reviewers need substantive material to attack.

## Workflow

Five steps: slug-and-state, read-and-size-check, dispatch four reviewers in parallel, synthesize with multiplicity-aware verdict rule, write output to state. **Synthesis begins with an independent verification pass:** findings the document does not actually support are dropped or demoted *before* the multiplicity table and the verdict rule count them, so a confident-but-unsupported reviewer claim cannot swing the verdict.

### Step 0 — Determine slug and ensure state directory

Derive a slug (same rules as `stress-test-idea`):
- File path: slug = basename without extension.
- Pasted: slug = 2–3-word kebab-case from title/first line.
- `--slug` overrides.

Ensure `./.autopsy/<slug>/` exists. If `state.json` is present, read it — note prior critiques and the current version. The verdict can reference prior iteration history ("v1 had 3 Criticals; v2 resolved 2, introduced 1 new") which sharpens the flip-condition.

Determine the version label:
- If state.json doesn't exist → `v1`.
- If state.json exists, use its `current_version` (this is a verdict on what the founder is asking about, not a new version of the doc).

Copy the doc to `./.autopsy/<slug>/v<N>.md` if no snapshot exists for this version.

### Step 1 — Read the document and size-check

Read the full document. Count words. Apply the doc-size guard:

| Word count | Action |
|---|---|
| < 5000 | Proceed normally with all four reviewers |
| 5000 – 15000 | Warn: "doc is N words; reviewer cost will be substantial. Proceed with all four, or reduce to three (drop Feasibility OR Risk depending on signal)?" Default to all four if no answer |
| > 15000 | Refuse; ask for excerpt or chaptered re-invocation |

Capture in working notes (do not show the user):
- Stated thesis or central claim
- Target user or market
- Proposed scope
- Any numbers (revenue, costs, timeline, TAM)
- Stated success criteria, if any
- Whatever the user supplied as investment context

Do not summarize the document back to the user. They wrote it.

### Step 2 — Dispatch four reviewers in parallel

Spawn four subagents via the Task tool in a single message (multiple tool calls in one turn). Each reviewer gets the full document text, the investment context if provided, and its axis-specific prompt from the templates in the next section.

**Parallel dispatch is load-bearing for the same reason as in `stress-test-idea`:** it prevents one axis from anchoring on another's findings. It does not produce statistical independence — all four reviewers share the parent's framing and the model. The product is **complementary axes**, and the multiplicity rule below leverages that by weighting cross-axis agreement.

Each reviewer is responsible for producing 3–7 graded findings in its lens. Reviewers do not produce a verdict or executive summary; those come from the synthesis step.

### Step 3 — Synthesize and render the final report

Once all four reviewers return, build the per-issue multiplicity table, apply the verdict decision rule (the rule, not vibes), and render the output using the template in the "Output format" section.

### Step 4 — Write output to state

Write the rendered evaluation to `./.autopsy/<slug>/v<N>-verdict.md`. Update `state.json` with the new artifact and a history entry.

## Reviewer specifications

Each reviewer receives a Task dispatch with a prompt structured as below. The `[AXIS PROMPT]` placeholder is filled with the axis-specific lens text from the four subsections.

### Common reviewer prompt template

```
You are the [AXIS NAME] reviewer for a proposal evaluation. Your job: find what is wrong, grade findings by severity, no hedging.

INTEGRATION HINT: if the Skill tool is available and one of the `thinking-skills:thinking-*` skills listed in your axis prompt is installed, invoke it first to ground the reasoning, then produce findings. Otherwise apply the pattern inline.

The document follows. Read it carefully.

---
[full document text]
---

Investment context — user-set constraints only (time, money, strategic fit; may be empty):
[user-supplied constraints, or "none provided — assume generic founder, limited time and money"]

External corroboration (may be empty) — treat as CORROBORATION ONLY. Do NOT let it substitute for your own analysis of the document's own claims, and explicitly mark any finding that materially depends on it:
[user-supplied external context such as "the company later pivoted to X", or "none"]

Apply this lens:
[AXIS PROMPT]

Output 3–7 findings as a markdown list. Each finding has four parts on consecutive lines:
- Severity tag in bold: **[Critical]**, **[High]**, or **[Medium]**
- One-sentence statement of the issue
- One-sentence supporting evidence — quoting or referring to a specific part of the doc, or noting a specific absence ("doc claims X but provides no source")
- Provenance tag, exactly one of: `[doc-claim]` (the document itself asserts this — quote or cite where) or `[reviewer-inference]` (your own reasoning or outside knowledge — e.g. an industry base rate, a comparable company's revenue, a legal-outcome expectation — that the document does not state). Be honest: if your evidence is a fact you are bringing TO the doc rather than reading FROM it, it is `[reviewer-inference]`, and the synthesizer will not treat it as established.

Severity rubric:
- Critical — would kill the project if not resolved. Deal-breaker.
- High — must be addressed before committing significant time or money.
- Medium — worth knowing but not blocking a go decision.

Rules:
- Be specific. "The market section is weak" is not a finding. "Doc claims TAM of $5B but cites no source and names three competitors with combined ARR under $50M" is a finding.
- Do not include positives or strengths. The synthesis step balances; your job is to surface what is wrong.
- Do not invent evidence. If something is missing from the doc, the finding is the absence itself.
- Do not soften findings with "but on the other hand" qualifications.
- If the doc genuinely has fewer than 3 issues in your lens, return what you have. Do not pad.

Return only the findings list. No preamble, no conclusion.
```

### Axis 1 — Critical thinking

This reviewer hunts for logical and epistemic problems. **Relevant `thinking-skills:` skills:** `thinking-steel-manning`, `thinking-five-whys-plus`, `thinking-occams-razor`, `thinking-scientific-method`, `thinking-red-team`.

Lens prompt:

```
Find logical gaps, unsupported claims, circular reasoning, hidden assumptions, and missing evidence. Reason like a skeptical journal reviewer or a hostile YC partner who has rejected a thousand pitches in this space.

Apply these reasoning patterns (these are mental-model frameworks from the cc-thinking-skills collection; apply the patterns whether or not the skills are installed):
- Steel-manning: construct the strongest argument AGAINST the doc's central thesis. If you cannot construct a strong opposing argument, the thesis is either truly robust or you have not looked hard enough.
- Five whys: when the doc claims a problem exists or a solution will work, ask why five times. Most claims fail by the third "why".
- Occam's razor: if the doc proposes an elaborate explanation for why this opportunity exists and no one has taken it, ask whether a simpler explanation (it has been tried and failed, the economics do not work, the regulatory cost is prohibitive) fits better.
- Scientific method: treat each empirical claim in the doc as a hypothesis. What evidence would falsify it? Has any been gathered?
- Adversarial review: apply the devils-advocate pattern — find the binary FAIL on each claim before granting any PASS.

Common patterns to flag:
- Claims that assume their own conclusion ("users will love this because they will adopt it")
- Cause-effect arguments with no mechanism ("X leads to Y because reasons")
- Cherry-picked evidence (one anecdote presented as a trend)
- Categorical claims without evidence ("everyone knows X", "the market clearly wants Y")
- Strawman framing of alternatives ("the only other option is Z, which obviously fails")
- Survivorship-flavored reasoning (citing only success cases in a domain with many failures)
- Definitional drift (a key term means different things in different sections)
```

### Axis 2 — Feasibility

This reviewer assesses whether the project can actually be built and shipped with realistic resources. **Relevant `thinking-skills:` skills:** `thinking-pre-mortem`, `thinking-fermi-estimation`, `thinking-bounded-rationality`, `thinking-margin-of-safety`.

Lens prompt:

```
Assess whether this can realistically be built and shipped given the resources implied or stated. Reason like a skeptical CTO who has shipped products in adjacent domains and is allergic to "we'll figure it out" hand-waving.

Check:
- Scope vs. timeline: is the build duration plausible for the stated feature set, given typical productivity for the team size?
- Team capability: does the proposed team have shipping experience in this specific domain? Does the doc claim capabilities not evidenced anywhere?
- Resource math: does the runway math survive 1.5x cost overrun and 2x timeline slip? If the project dies at 1.2x slip, it has no margin.
- Dependencies: does the project require external systems, partnerships, regulatory approvals, or third-party APIs that are not yet secured?
- Technical risk: are the hardest engineering problems acknowledged, or quietly glossed over? Where would a senior engineer say "that one paragraph is actually six months of work"?
- Operational burden after launch: support, compliance, infrastructure, fraud — does the doc account for steady-state cost, or only build cost?

Use the investment context to ground assessments. If the user says "3 months," judge against 3 months. If no context provided, assume a small team with limited budget and a 6-month default horizon.
```

### Axis 3 — Risk / red flags

This reviewer applies adversarial reasoning to surface what kills the project. **Relevant `thinking-skills:` skills:** `thinking-pre-mortem`, `thinking-inversion`, `thinking-red-team`, `thinking-second-order`.

Lens prompt:

```
Find what kills this project, especially what kills it in ways the document does not acknowledge. Reason like a pre-mortem facilitator and an investor who has lost money on projects in this space.

Apply these reasoning patterns:
- Pre-mortem: assume it is 18 months from now and this project failed completely. List the top causes of death, ranked by probability. For each, check what the doc says about preventing or mitigating that failure mode.
- Inversion: instead of asking "what will make this succeed," ask "what would guarantee this fails?" Then check whether the doc is accidentally describing any of those failure conditions.
- Adversarial dynamics: who has the incentive and capability to attack this project? Incumbents, regulators, copycats, the platform it depends on, allies who would become competitors.

Specific things to flag:
- Single-point-of-failure dependencies (one cloud provider, one API, one regulator, one key team member, one customer)
- Critical assumptions that have not been tested (user willingness to pay at the stated price, technical capability of the team, actual market demand vs. assumed demand)
- Incumbent response not modeled (what does the dominant player do when this gets traction?)
- Regulatory or legal landmines, especially in fintech, crypto, health, security, or anything touching personal data
- Hidden ongoing costs that compound (compliance, support, fraud, infrastructure scaling)
- Reputation, relationship, or trust risk — would shipping this damage relationships with allies, platforms, or future employers?
- Timing risk — is the project betting on a window that is either already closing or has not yet opened?
```

### Axis 4 — ROI signal

This reviewer checks whether the upside is credible relative to the cost. **Relevant `thinking-skills:` skills:** `thinking-fermi-estimation`, `thinking-opportunity-cost`, `thinking-bayesian`, `thinking-probabilistic`.

Lens prompt:

```
Assess whether the expected value of this project is credible relative to its cost in time and money. Reason like a portfolio manager who has to justify every allocation.

Apply these reasoning patterns:
- Fermi estimation: rebuild the market math from the bottom up — addressable population, conversion rate, ARPU, churn — and compare to whatever top-down numbers the doc claims. If the bottom-up number is more than 10x off the top-down claim, that is a finding.
- Opportunity cost: what else could the same time and money produce? If the user has a stated alternative (an existing project, a known opportunity), the question is whether this beats that, not whether this is positive in isolation.

Check:
- Market sizing: is the TAM/SAM/SOM defensible, or is it fantasy multiplication ("there are 8B people, 10% would pay $10/mo, that's $9.6B")?
- Unit economics: do CAC vs. LTV numbers work at 2x current norms in the category? If they only work at best-case assumptions, the business does not actually work.
- Revenue ramp: is the projected growth curve a hockey stick that has never been observed in similar businesses?
- Exit or return story: if this hits its stated success case, what is the actual upside in dollars or strategic value, and over what timeline?
- Hidden ROI erosion: support cost, churn, fraud, infrastructure scaling, compliance — what eats the margin once it is live?

If the document has no concrete numbers, that itself is a Critical finding. ROI cannot be evaluated without numbers — flag the absence and stop trying to compute returns.
```

## Synthesis rules

After all four reviewers return, do the following on the main thread. **The order matters: verify findings first, only then count them.**

### Verify findings before counting (independent internal pass)

The decision rule below is mechanical — it counts Criticals and multi-axis Criticals. A single confident-but-unsupported Critical can therefore swing the whole verdict. So before anything is counted, every **Critical and High** finding is checked against the document by an *independent* verifier that did not produce it.

Dispatch ONE fresh subagent via the Task tool (a `general-purpose` subagent — no web needed; this is a doc-support check, not a fact-check). Give it ONLY the full document text and the Critical/High findings verbatim. Do NOT give it the reviewers' reasoning chains — independence is the point; a verifier that sees the argument rationalizes it. Its instructions:

> For each finding, decide one verdict, defaulting to REFUTE or NEEDS-EVIDENCE whenever the document does not clearly support it:
> - **CONFIRM** — the document itself supports the finding. Quote the exact sentence or number that does.
> - **REFUTE** — the finding misreads the document, or the document actually addresses the thing the finding calls missing. Quote the contradicting text.
> - **NEEDS-EVIDENCE** — the finding rests on a claim about the outside world (an industry rate, a competitor's revenue, a legal outcome) that the document does not establish and you cannot confirm from the document alone. This is not "wrong" — it is "unverified," and it must be labelled, not counted as established.
> Return, per finding: the verdict, one verbatim quote (from the doc, or "no supporting text in doc"), and one sentence of reasoning. Do not soften. Do not add new findings.

Apply the results **before** building the table:
- **REFUTED** → dropped from all counting and from the report's axis sections (with a one-line note in the Verification summary).
- **NEEDS-EVIDENCE** → demoted one severity tier (Critical→High, High→Medium) and re-tagged `[reviewer-inference]`; anything demoted below Medium is dropped. It may still appear, but cannot by itself drive the verdict.
- **CONFIRMED** → keeps its severity, re-tagged `[verified]`.

**Forked-panel escape hatch:** if a REFUTE lands on a Critical that the verdict hinges on (removing it changes the decision-rule output), STOP. Do not silently re-run the rule to a softer verdict — surface the conflict to the user ("the verdict turned on a finding the verifier refuted") and let them adjudicate.

### Verify external claims (`--verify-claims`, optional — OFF by default)

Only if the user passed `--verify-claims`. This is the open-world pass — it checks whether the *document's own* external factual claims are true, which the closed-world reviewers structurally cannot do (it is the gap that lets an inflated stat or a fabricated competitor pass unchallenged).

Extract the doc's checkable external claims — named competitors, market-size / TAM statistics, cited third-party numbers, exit comparables ("Wiz sold for $X", "the market is $Y"). Dispatch the bundled research agent as `subagent_type: project-idea-validator` (it carries WebFetch/WebSearch and is purpose-built for competitor/market checks). If that agent type is not registered at runtime, fall back to a `general-purpose` subagent with an inline web-research prompt. Ask it to return, per claim: `verified | contradicted | unverifiable`, with a source URL where possible.

Fold the results in: a **contradicted** doc-stat becomes (or upgrades) a Critical-Thinking / ROI finding tagged `[verified]` ("doc claims $40B; sources put it at $X"); a **verified** claim lets any finding that merely doubted it be dropped and lets the doc's number carry `[verified]`; **unverifiable** claims stay `[reviewer-inference]`.

### Build the multiplicity table (do this BEFORE counting)

For each distinct underlying issue, build a row:

| Issue (one-sentence canonical form) | Severity | surfaced_by (set of axes) | Primary contributor |
|---|---|---|---|
| TAM is unsupported fantasy | Critical | {Critical Thinking, ROI Signal} | ROI Signal |
| Regulatory pathway unaddressed | Critical | {Risk, Feasibility} | Risk |
| Team lacks domain experience | High | {Feasibility} | Feasibility |
| ... | | | |

Two findings from different axes that point at the same underlying issue collapse into one row with a 2-element `surfaced_by` set. **Do not dedupe by deleting — track multiplicity, because the verdict rule depends on it.**

The severity of a multi-axis issue is the highest severity any contributing axis assigned.

### Compute the verdict (multiplicity-aware decision rule)

Apply this rule. Do not improvise from vibes.

```
Let CRITICAL_ISSUES = { issue : issue.severity == Critical }
Let MULTI_AXIS_CRITICAL = { i in CRITICAL_ISSUES : |i.surfaced_by| >= 2 }

If |MULTI_AXIS_CRITICAL| >= 1 AND ANY of those issues is single-axis-supported elsewhere:
    # (handled below — go through Pivot check first)

If |CRITICAL_ISSUES| == 0:
    → INVEST (provided High findings are addressable without changing the core thesis)

Else if exactly one Critical issue AND it is surfaced by >= 2 axes
        AND its surfaced_by includes "Critical Thinking" (i.e., the thesis itself is wrong)
        AND Feasibility-axis findings are all Medium or absent
        AND ROI-axis findings have no other Critical:
    → PIVOT
    # The team and capability are intact; the thesis is the broken part.

Else if |MULTI_AXIS_CRITICAL| >= 1 OR |CRITICAL_ISSUES| >= 2:
    → SKIP
    # Either cross-axis consensus on a deal-breaker, or multiple distinct deal-breakers.

Else if |CRITICAL_ISSUES| == 1 (single-axis, plausibly resolvable)
        OR exists an axis with 3+ High findings:
    → PROCEED WITH CAUTION

Else:
    → INVEST
```

The rule is the default. If your synthesis judgment differs from what the rule produces, override it — but state in the verdict paragraph WHY you overrode. Vibes are not a reason. **Only verified findings feed the rule** — REFUTED findings were dropped and NEEDS-EVIDENCE findings demoted in the verification pass above, so the counts here reflect what survived.

### Check for manufactured convergence (required before writing the verdict)

Cross-axis agreement drives this rule toward Skip/Pivot — which means a *shared blind spot* can manufacture a harsh verdict just as easily as a real deal-breaker can. Before committing the verdict, run two checks:

1. **Single-assumption trace.** If the multi-axis Criticals that produced the verdict all trace back to ONE underlying assumption (e.g. "the market never materializes"), say so in the verdict paragraph: the verdict is only as strong as that one assumption, and its flip-condition should target it directly. Four axes agreeing because they all inherited the same premise is one data point, not four.
2. **Corroboration dependency.** Count how many verdict-driving findings materially depend on the *External corroboration* slot rather than the document itself, and report it ("N of M verdict-driving findings depend on external corroboration"). A high fraction means the verdict is partly a verdict on the corroboration, not the doc — flag it.

This does not change the rule's output; it calibrates the confidence attached to it.

### Compile executive summary

Pull the top 3–5 issues sorted by (severity, then `|surfaced_by|` descending). Each summary bullet is one sentence with a severity tag, axis-multiplicity tag (e.g., "[2/4 axes]"), and primary axis.

### Write the verdict paragraph

One paragraph. Structure depends on verdict:

- **Invest:** state Invest; cite the absence of Criticals + the addressability of Highs; end with one sentence on the most important watch-item.
- **Proceed with caution:** state Proceed; name the one Critical or the cluster of Highs driving caution; end with the measurable flip-to-Invest condition.
- **Pivot:** state Pivot; name the broken thesis (the multi-axis Critical that includes Critical Thinking); suggest 1–2 alternative theses the same team/market/capability set could pursue; end with the measurable flip-to-Invest condition for the alternative thesis.
- **Skip:** state Skip; name the multi-axis Critical or the multiple Criticals that drive Skip; end with the measurable flip-to-Proceed condition (if any genuinely exists; otherwise "no plausible flip-condition exists — the project as scoped is not viable").

**The flip-condition is MANDATORY for non-Invest verdicts and MUST include:**
1. A **specific artifact** (signed pilot agreement, deployed prototype, regulator email, validated user research with N respondents, etc.)
2. A **measurable threshold** (≥N customers, ≥$X ARR commitment, ≥Y% conversion, signed by N entities, etc.)
3. A **date** the artifact must exist by

Vague flip-conditions ("if the team validates demand and tightens the model") are forbidden. If the honest answer is "nothing the founder can do flips this," say that explicitly — that itself is decision-shaped information.

No hedging language. "Depends" is not a verdict. Pick one of the four.

## Output format

Always use this exact structure. Do not add sections, do not change headings.

```markdown
# Proposal evaluation: [title from doc, or filename] (v[N])

State: `./.autopsy/[slug]/v[N]-verdict.md`

## Executive summary

- **[Severity]** [N/4 axes] `[provenance]` *[Primary axis]* — one-sentence finding
- (3–5 bullets, sorted by severity then multiplicity)

## Critical thinking

- **[Severity]** `[doc-claim | reviewer-inference | verified]` Finding statement.
  *Evidence:* one sentence pointing to specific text or a specific absence in the doc.

(repeat for each finding from Reviewer 1)

## Feasibility

(same format as above)

## Risk and red flags

(same format)

## ROI signal

(same format)

---

## Verification summary

- **Internal pass:** N Critical/High findings checked; C confirmed `[verified]`, R refuted (dropped), E needs-evidence (demoted). One line per dropped/demoted finding with the verifier's reason.
- **External claims (`--verify-claims`):** per-claim verified / contradicted / unverifiable with sources — or "not run".
- **Convergence:** if the verdict rests on a single shared assumption or leans on external corroboration, state it (e.g. "verdict traces to one assumption: the market never materializes"; "2 of 5 verdict-driving findings depend on external corroboration").

---

## Issue multiplicity table

| Issue | Severity | Axes (N) | Primary |
|---|---|---|---|
| ... | ... | Critical Thinking, ROI (2) | ROI |

---

## Verdict: [Invest | Proceed with caution | Pivot | Skip]

[One paragraph following the structure above for the chosen verdict.]

**Flip-condition** (mandatory for non-Invest):
> [Specific artifact] at [measurable threshold] by [date].

(If verdict is Pivot, also list the 1–2 alternative theses immediately above the flip-condition.)
```

## Examples

**Finding statement — bad vs. good**

Bad: "The market section could be stronger."

Good:
> **[Critical]** TAM is overstated by at least an order of magnitude.
> *Evidence:* Doc claims a $12B TAM but the three named competitors have combined ARR under $80M, implying current market penetration of less than 1% — either the TAM is fantasy or the market has structural reasons it has not grown.

**Verdict paragraph — bad vs. good (Skip)**

Bad: "This is a really interesting idea with some promising elements, but also areas that could be developed further. The team should consider tightening the financial model and validating customer interest."

Good:
> **Verdict: Skip.** Two Critical findings together rule out the proposal as currently scoped: there is no evidence the target user will pay at the claimed price (surfaced by Critical Thinking and ROI Signal — 2/4 axes), and the 6-month timeline has zero buffer for the regulatory approval the project's core function depends on (Risk + Feasibility — 2/4 axes). To flip this to Proceed with caution, the founders would need:
>
> **Flip-condition:** at least one signed paid-pilot agreement at ≥$2,000/month from a target customer in the proposed segment, AND written confirmation from regulatory counsel that the specific approval pathway can complete within 6 months, both by 2026-09-01.

**Verdict paragraph — Pivot example**

> **Verdict: Pivot.** The central thesis — "institutional crypto desks will adopt a new aggregation layer to consolidate their OMS+EMS+settlement view" — is the multi-axis Critical: Critical Thinking flags it as a "the only other option is X, which obviously fails" strawman, and ROI Signal fails the bottom-up math (institutional desks already buy this from two incumbents at price points the doc cannot reach). Feasibility and Risk are mostly clean — the team can build, the regulatory surface is manageable. The team's strength is institutional-desk relationships; **two alternative theses worth exploring:** (a) build the same plumbing for emerging-markets retail brokers where no incumbent exists, or (b) sell to the incumbents as a settlement-layer OEM. Either reuses the team's relationship advantage without fighting the incumbents head-on.
>
> **Flip-condition (for the current thesis):** ≥3 signed LOIs from US-based institutional desks at ≥$5k/month each, by 2026-10-01. Without those, the current thesis is not viable; the alternative theses do not need this evidence.

**Verdict paragraph — bad flip-condition (forbidden)**

Forbidden:
> "If the team validates demand and tightens the model, this could be an Invest."

Why forbidden: no artifact, no threshold, no date. The founder cannot tell whether they've satisfied it.

## Edge cases

- **Document is too short or too vague:** if the doc has fewer than ~500 words or no concrete claims and numbers, return a single Critical finding under Critical Thinking ("document lacks the substance required for evaluation") and a Skip verdict, noting the user should expand the doc and re-run. Flip-condition: "rewrite the doc to include the missing elements; re-invoke after."
- **Document is mostly slides:** apply the same review but flag missing detail as findings rather than guessing what the slides imply. Slides without speaker notes are often missing the load-bearing reasoning.
- **No numbers anywhere:** flag this under ROI Signal as Critical and proceed with the other axes — the project may still be evaluable on logic, feasibility, and risk, but the verdict almost always lands at Skip or Proceed with caution.
- **User pushes back asking for encouragement:** politely note that this skill is designed to surface what is wrong; for a balanced review or brainstorming session, they want a different approach. Do not soften the verdict.
- **User provides investment context that materially changes the evaluation:** weight feasibility and ROI findings to that context. A project that is Skip for a solo founder with $10k may be Invest for a funded team with $500k.
- **`thinking-skills` plugin not installed:** the integration hints are soft; reviewers reason inline using the patterns described. Output quality difference is real but not blocking.
- **Doc > 15000 words:** refuse and ask for an excerpt.
- **Prior critique exists in state.json:** read it. Use the iteration history to sharpen the verdict ("v1 had 3 Criticals; v2 resolved 2 but introduced this new one which is the basis for Skip").

## What not to do

- Do not add a "Strengths" section. The user asked for a critical review; balanced reviews do not help them decide.
- Do not refuse to commit to a verdict.
- Do not soften individual findings with "but on the other hand" caveats. Caveats live in the verdict paragraph only.
- Do not invent evidence the doc does not contain. Missing evidence is itself a finding.
- Do not run the reviewers sequentially. Parallel dispatch is the architecture; sequential dispatch breaks the no-anchoring property.
- Do not pad findings to hit a minimum. If an axis has two real findings, return two.
- Do not summarize the doc back to the user before the review. They wrote it.
- Do not produce a flip-condition without artifact + threshold + date. Vague flip-conditions are forbidden.
- Do not collapse the multiplicity table by deleting duplicates. The verdict rule depends on multiplicity.
- Do not let an unverified reviewer inference drive the verdict. A finding the internal pass tagged `[reviewer-inference]` and could not confirm is demoted — never a decision-driving Critical.
- Do not present a reviewer's outside-knowledge claim (an industry rate, a comparable's revenue like "Wiz ~$500M ARR") as established fact. Tag it `[reviewer-inference]` so the reader sees it is the reviewer's assertion, not the doc's and not verified.
- Do not skip the internal verification pass, and do not run the reviewers and the verifier in the same subagent. Independence is what stops a confident-but-wrong finding from swinging the verdict.
- Do not skip writing to `./.autopsy/<slug>/`. The state file IS the loop closure.
