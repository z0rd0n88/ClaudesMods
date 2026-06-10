---
name: evaluate-proposal-harsh
description: Run a hard-nosed multi-axis review of a proposal, pitch deck, spec, business plan, project brief, or any document describing something to potentially build or fund, and return an explicit invest/skip verdict with graded findings. Use this skill whenever the user asks to evaluate, critique, review, stress-test, or get an honest take on a proposal or strategic document — including phrases like "should I build this", "is this worth my time", "evaluate this idea", "critique this proposal", "give me a verdict", "should I invest in this", "tear this apart", "what's wrong with this", or any request for decision-shaped feedback on whether to commit time or money to a project. Trigger this skill even when the user doesn't explicitly say "evaluate" — if they share a doc and ask for honest feedback that will inform a go/no-go decision, this is the right tool.
---

# Evaluate Proposal (Harsh)

Run an honest, decision-shaped review of a proposal document. The point is not a balanced analysis — it is to give the reader a clear invest/skip verdict they can act on. The skill orchestrates four parallel reviewers, each applying a different lens, then synthesizes their findings into a graded report ending in an explicit verdict.

This skill exists because most LLM critiques default to encouraging-and-balanced when the user actually wants harsh-and-decisive. The architecture forces decisiveness: parallel independent reviewers, graded severity, and a verdict block that must commit to one of three answers.

## When to use

The user has a document — proposal, pitch deck, spec, business plan, project brief, RFP, one-pager, internal memo — describing a project they are considering committing time or money to. They want to know whether to pursue it.

Trigger this skill on direct asks ("evaluate this proposal"), implied asks ("here's my idea doc, what do you think?"), and decision-framed asks ("should I build this?"). When in doubt, prefer triggering — the cost of running this skill on a non-proposal is mild verbosity; the cost of not triggering when the user wanted it is wasted time.

## Inputs

Required: a document to evaluate. Accept any of:
- A file path the user provides (read it with the appropriate tool — `view` for text/markdown, the file-reading skill for PDFs)
- Pasted text in the conversation
- A reference to a previously shared file

Optional, taken inline at invocation: investment context the user provides. Examples:
- Time budget: "I have 3 months of focused time"
- Money budget: "willing to put in $50k of my own money"
- Strategic fit: "must complement my existing crypto infrastructure"
- Constraints: "I have one other co-founder, no funding yet"

Do not ask follow-up clarifying questions. If the user gave you a doc, run the evaluation. If investment context is missing, assume a generic founder/operator with limited time and money. Asking questions before running is exactly the "ceremony" this skill exists to avoid.

If the user did not actually share a document — only described an idea verbally in chat — ask once for the doc, briefly. Do not run the skill on a verbal description; the reviewers need substantive material to attack.

## Workflow

The skill is an orchestrator. Three steps: read, dispatch, synthesize.

### Step 1 — Read the document

Read the full document. Capture in working notes (do not show the user — this is for your own grounding):
- Stated thesis or central claim
- Target user or market
- Proposed scope
- Any numbers (revenue, costs, timeline, TAM)
- Stated success criteria, if any
- Whatever the user supplied as investment context

Do not summarize the document back to the user. They wrote it.

### Step 2 — Dispatch four reviewers in parallel

Spawn four subagents via the Task tool in a single message (multiple tool calls in one turn). Each reviewer gets the full document text, the investment context if provided, and its axis-specific prompt from the templates in the next section.

Parallelism is load-bearing: each reviewer reasons fresh without seeing the others' work. This is the same principle the `devils-advocate` plugin uses for independent critique. Do not chain them sequentially — running the reviewers in a single context window means later reviewers anchor to earlier findings instead of reasoning independently.

Each reviewer is responsible for producing 3–7 graded findings in its lens. Reviewers do not produce a verdict or executive summary; those come from the synthesis step.

### Step 3 — Synthesize and render the final report

Once all four reviewers return, deduplicate overlapping findings, assemble the executive summary, compute the verdict, and render the output using the template in the "Output format" section. Apply the verdict decision rule from "Synthesis rules" — do not improvise the verdict from vibes.

## Reviewer specifications

Each reviewer receives a Task dispatch with a prompt structured as below. The `[AXIS PROMPT]` placeholder is filled with the axis-specific lens text from the four subsections.

### Common reviewer prompt template

```
You are the [AXIS NAME] reviewer for a proposal evaluation. Your job: find what is wrong, grade findings by severity, no hedging.

The document follows. Read it carefully.

---
[full document text]
---

Investment context (may be empty):
[user-supplied context, or "none provided — assume generic founder, limited time and money"]

Apply this lens:
[AXIS PROMPT]

Output 3–7 findings as a markdown list. Each finding has three parts on consecutive lines:
- Severity tag in bold: **[Critical]**, **[High]**, or **[Medium]**
- One-sentence statement of the issue
- One-sentence supporting evidence — quoting or referring to a specific part of the doc, or noting a specific absence ("doc claims X but provides no source")

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

This reviewer hunts for logical and epistemic problems. Lens prompt:

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

This reviewer assesses whether the project can actually be built and shipped with realistic resources. Lens prompt:

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

This reviewer applies adversarial reasoning to surface what kills the project. Lens prompt:

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

This reviewer checks whether the upside is credible relative to the cost. Lens prompt:

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

After all four reviewers return, do the following on the main thread.

### Deduplicate

Findings sometimes overlap across axes — for example, "no evidence target users will pay" can surface in both Critical Thinking (unsupported claim) and ROI Signal (broken unit economics). When two findings are the same point, keep the sharper version and note the other axis in parentheses: `(also surfaced in [Axis])`.

### Compile executive summary

Pull the top 3–5 findings across all axes, sorted by severity (Critical first, then High). These are what the reader will act on. Each summary bullet is one sentence with a severity tag and axis tag.

### Compute the verdict

Apply this decision rule:

- **Skip** if there are two or more Critical findings, OR one Critical finding the user has no plausible path to resolve.
- **Proceed with caution** if there is one Critical finding with a plausible path to resolve, OR three or more High findings clustered in a single axis (meaning that axis is structurally broken).
- **Invest** if there are zero Critical findings and the High findings are addressable without changing the core thesis.

This rule is the default. If your synthesis judgment differs from what the rule produces, override it — but state in the verdict paragraph why you overrode.

### Write the verdict paragraph

One paragraph. Structure:
1. First sentence: state the verdict.
2. Middle: the single most important reason for that verdict — the specific finding or pattern of findings driving it.
3. Last: what would have to be true to change the verdict (the if-then that makes the recommendation actionable).

No hedging language. "Depends" is not a verdict. If the honest answer is "depends," still pick one of the three and use the if-then sentence to state what would flip it.

## Output format

Always use this exact structure. Do not add sections, do not change headings.

```markdown
# Proposal evaluation: [title from doc, or filename]

## Executive summary

- **[Critical | High | Medium]** *[Axis]* — one-sentence finding
- (3–5 bullets, sorted by severity)

## Critical thinking

- **[Severity]** Finding statement.
  *Evidence:* one sentence pointing to specific text or a specific absence in the doc.

(repeat for each finding from Reviewer 1)

## Feasibility

(same format as above)

## Risk and red flags

(same format)

## ROI signal

(same format)

---

## Verdict: [Invest | Proceed with caution | Skip]

[One paragraph: verdict, key reason, what would flip it.]
```

## Examples

**Finding statement — bad vs. good**

Bad: "The market section could be stronger."

Good:
> **[Critical]** TAM is overstated by at least an order of magnitude.
> *Evidence:* Doc claims a $12B TAM but the three named competitors have combined ARR under $80M, implying current market penetration of less than 1% — either the TAM is fantasy or the market has structural reasons it has not grown.

**Verdict paragraph — bad vs. good**

Bad: "This is a really interesting idea with some promising elements, but also areas that could be developed further. The team should consider tightening the financial model and validating customer interest."

Good:
> **Verdict: Skip.** Two Critical findings together rule out the proposal as currently scoped: there is no evidence the target user will pay at the claimed price (Critical Thinking, ROI), and the 6-month timeline has zero buffer for the regulatory approval the project's core function depends on (Risk, Feasibility). To flip this to Proceed with caution, the founders would need (a) at least one paid letter of intent from a target customer at the proposed price, and (b) written confirmation that the regulatory pathway can complete within the stated timeframe.

## Edge cases

- **Document is too short or too vague:** if the doc has fewer than ~500 words or no concrete claims and numbers, return a single Critical finding under Critical Thinking ("document lacks the substance required for evaluation") and a Skip verdict, noting the user should expand the doc and re-run.
- **Document is mostly slides:** apply the same review but flag missing detail as findings rather than guessing what the slides imply. Slides without speaker notes are often missing the load-bearing reasoning.
- **No numbers anywhere:** flag this under ROI Signal as Critical and proceed with the other axes — the project may still be evaluable on logic, feasibility, and risk, but the verdict almost always lands at Skip or Proceed with caution.
- **User pushes back asking for encouragement:** politely note that this skill is designed to surface what is wrong; for a balanced review or brainstorming session, they want a different approach. Do not soften the verdict.
- **User provides investment context that materially changes the evaluation:** weight feasibility and ROI findings to that context. A project that is Skip for a solo founder with $10k may be Invest for a funded team with $500k.
- **cc-thinking-skills or devils-advocate plugins not installed:** the reasoning patterns are baked into the reviewer prompts, so the skill works either way. The plugins, if present, sharpen the reasoning but are not required.

## What not to do

- Do not add a "Strengths" section. The user asked for a critical review; balanced reviews do not help them decide.
- Do not refuse to commit to a verdict.
- Do not soften individual findings with "but on the other hand" caveats. Caveats live in the verdict paragraph only.
- Do not invent evidence the doc does not contain. Missing evidence is itself a finding.
- Do not run the reviewers sequentially. Parallel dispatch is the architecture; sequential dispatch breaks the independence property.
- Do not pad findings to hit a minimum. If an axis has two real findings, return two.
- Do not summarize the doc back to the user before the review. They wrote it.
