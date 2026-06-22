---
name: stress-test-idea
description: Subject an idea doc, proposal, pitch deck, or early concept brief to brutal adversarial review by running three complementary-lens reviewers in parallel — a thinking-skills battery (jobs-to-be-done, fermi-estimation, pre-mortem, graded steel-manning), a devils-advocate dimension critique, and a silent-failure lens hunting unspoken assumptions — then synthesizing their findings into a prioritized list of changes for v2. Use whenever the user wants to harden, improve, stress-test, or get adversarial feedback on a doc they intend to revise — including phrases like "tear this apart", "stress test this idea", "what should I fix", "make this stronger", "find the holes", "critique loop", or any request for harsh feedback that will inform a doc rewrite rather than a go/no-go decision. Scope is product/business proposals; other doc types produce uneven output.
---

# Stress Test Idea

Run three reviewers with complementary lenses in parallel against an idea doc, then synthesize their findings into a concrete list of changes for v2. The architecture is designed to produce *iteration input*, not a verdict — the loop is meant to be re-run after the user rewrites the doc.

This skill exists for the doc-improvement use case: the user is still shaping an idea and wants the sharpest possible adversarial feedback before committing. It is the complement to `evaluate-proposal-harsh`, which is for the go/no-go decision use case.

## Scope

Designed for **product and business proposals** — pitches, decks, project briefs, one-pagers, business memos. The lenses (jobs-to-be-done, market math, business-model PASS/FAIL, distribution, etc.) assume a doc that proposes something to build and ship to users.

For research proposals, internal architecture specs, OSS roadmaps, or creative-project briefs the lenses will produce uneven findings ("Doc has no TAM. Critical." on a research grant proposal is nonsense). If the doc is non-business, declare it at invocation (e.g., "this is an internal arch RFC, skip the market lens") so the reviewers can downweight the irrelevant axes — or use a different review tool.

## Confidentiality

Each reviewer is dispatched as a subagent via the Task tool with the **full document text in its prompt**. With three reviewers, the doc is replicated three times across subagent transcripts. For confidential pitch decks, unannounced fundraising material, or anything with cap-table details, excerpt or anonymize before running. Mention this to the user once if the doc appears sensitive.

## When to use this vs. evaluate-proposal-harsh

| Use this skill (`stress-test-idea`) when | Use `evaluate-proposal-harsh` when |
|---|---|
| Doc is early or in iteration | Doc is mostly final |
| User wants "what to fix" | User wants "should I do this at all" |
| User signals revision intent | User signals decision intent |
| Output should feed v2 of the doc | Output should drive an invest/skip/pivot call |

If both skills could apply, default to `evaluate-proposal-harsh` for verdict-shaped questions and this skill for everything else.

## When to use (positive triggers)

The user has an idea doc, proposal, pitch deck, one-pager, internal memo, or early spec — something they are actively shaping — and wants adversarial feedback to improve it. Triggers include:

- "Tear this apart" / "find the holes" / "what's wrong with this"
- "Stress test this" / "harsh feedback on this"
- "Review before I commit" / "review before I send"
- "What should I fix in v2"
- Sharing a doc and asking for honest critique without explicitly framing as a decision

When in doubt about whether the user wants iteration or a verdict, briefly ask. The two skills produce different outputs and using the wrong one wastes a review pass.

## Inputs

Required: a document to review. Accept any of:
- A file path the user provides
- Pasted text in the conversation
- A reference to a previously shared file

Optional, inline: context that grounds the review. Examples:
- "I'm a solo founder with 4 months of runway"
- "Target market is institutional crypto traders"
- "I already know I'm going to ship something — help me pick the right shape"
- `--slug <name>` to override the auto-derived state-directory name

Do not ask follow-up questions before running. If the user gave you a doc, dispatch the reviewers. If context is missing, the reviewers fall back to generic assumptions.

If the user described an idea only verbally without a doc, ask once for a doc, briefly. The reviewers need substantive material to attack — verbal descriptions produce thin critiques.

## Workflow

Five phases: slug-and-state, read-and-size-check, dispatch three reviewers in parallel, synthesize, write output to state.

### Step 0 — Determine slug and ensure state directory

Derive a slug:
- If the doc came in as a file path: slug = basename without extension (e.g., `./pitch.md` → `pitch`).
- If the doc was pasted: slug = a 2–3-word kebab-case extraction from the title or first line (e.g., "Pivot to enterprise audit" → `pivot-enterprise-audit`).
- If `--slug` was provided, honor it verbatim.

Ensure `./.autopsy/<slug>/` exists (create if missing). Determine the version label:
- If `./.autopsy/<slug>/state.json` does not exist → this is `v1`.
- If state.json exists, read its `current_version`. If the user appears to be running a fresh stress-test on a rewritten doc, increment (`v1` → `v2`, etc.); otherwise reuse the current version label and overwrite.

Copy the original doc to `./.autopsy/<slug>/v<N>.md` (snapshot) if no snapshot for this version exists.

### Step 1 — Read the document and size-check

Read the full document. Count words. Apply the doc-size guard:

| Word count | Action |
|---|---|
| < 5000 | Proceed normally with all three reviewers |
| 5000 – 15000 | Warn the user once: "doc is N words; reviewer cost will be substantial. Proceed with all three reviewers, or reduce to two (A + B)?" Default to all three if no answer in the next message |
| > 15000 | Refuse: ask for an excerpt (the load-bearing sections only) or run chapter-by-chapter |

Note in working memory (do not show the user):
- Central thesis
- Target user or market
- Stated scope
- Any numbers
- Investment context the user supplied inline

Do not summarize the doc back. The user wrote it.

### Step 2 — Dispatch Reviewer A, B, and C in parallel

Use the Task tool to spawn three subagents in a single message. Each gets the full document, the optional context, and its specific instructions from the next section.

**Parallelism is load-bearing for one reason:** parallel dispatch prevents one reviewer from anchoring on another's findings (which it would otherwise see in the parent context). It does **not** produce statistical independence — all three reviewers share the parent's framing, the same model, and the same investment context. The product is **complementary lenses on the same doc**, not three independent reasoners. The synthesizer compensates by weighting cross-lens agreement (the "Consensus" bucket) more heavily than any single reviewer's enthusiasm.

Sequential dispatch breaks even this weaker property — later reviewers anchor to earlier findings instead of reasoning fresh.

### Step 3 — Synthesize using the consensus/unique/contradictions structure

Once all three reviewers return, classify every finding into one of four buckets, then write iteration recommendations. The classification matters more than the individual findings — consensus findings are highest-confidence problems, contradictions are where the most genuine uncertainty lives.

### Step 4 — Write output to state

Write the rendered synthesis to `./.autopsy/<slug>/v<N>-stress-test.md`. Update `state.json` with the new artifact and an entry in `history` (timestamp, skill, version). State.json schema:

```json
{
  "slug": "<slug>",
  "doc_path": "<original path or 'pasted'>",
  "current_version": "v1",
  "artifacts": {
    "v1": "./.autopsy/<slug>/v1.md",
    "v1-stress-test": "./.autopsy/<slug>/v1-stress-test.md"
  },
  "history": [
    { "ts": "<ISO8601>", "skill": "stress-test-idea", "version": "v1", "output": "v1-stress-test.md" }
  ]
}
```

## Reviewer specifications

### Reviewer A — Thinking-skills battery

Dispatch this Task with the following prompt:

```
You are Reviewer A in a parallel adversarial review of an idea doc. Your job is to apply four mental-model frameworks in sequence and return graded findings from each. You will not see Reviewer B or C's work. They will not see yours. Parallel dispatch is what makes the synthesis meaningful — do not narrate what other reviewers might say.

INTEGRATION HINT: if the Skill tool is available and any of `thinking-skills:thinking-jobs-to-be-done`, `thinking-skills:thinking-fermi-estimation`, `thinking-skills:thinking-pre-mortem`, or `thinking-skills:thinking-steel-manning` are installed, invoke the relevant one before applying each framework — that grounds the reasoning in the canonical pattern. Otherwise, apply the patterns inline as described below.

The document follows. Read it carefully.

---
[full document text]
---

Investment context (may be empty):
[user-supplied context, or "none provided — assume generic founder, limited time and money"]

Apply these four frameworks in sequence. For each, produce 1–3 findings. Each finding has a severity tag (Critical / High / Medium), a one-sentence statement, and a one-sentence supporting evidence from the doc.

Severity rubric:
- Critical: would kill the idea if not resolved. Deal-breaker.
- High: must be addressed before the idea is ready to commit to.
- Medium: worth knowing but not blocking.

Frameworks:

1. JOBS-TO-BE-DONE
   For each user segment the doc claims, name the specific job the user is trying to get done, what they currently hire to do that job, and what would have to be true for them to fire the current solution and hire this instead. If a segment cannot pass this test, flag it. If the doc never names what current solution it is displacing, that itself is a finding.

2. FERMI ESTIMATION
   Rebuild the doc's market math from the bottom up. Estimate the addressable population, realistic conversion rate, ARPU, and churn. Compare your bottom-up number to whatever top-down number the doc claims (TAM, projected revenue, user counts). If the bottom-up number is more than 10x off the doc's claim, that is a finding. If the doc has no numbers at all, flag the absence as a Critical finding.

3. PRE-MORTEM
   Assume it is 18 months from now and this idea, built as described, has failed completely. List the three most likely causes of death, ranked by probability. For each, check what the doc currently says (if anything) about preventing or mitigating that failure mode. If a likely failure mode is unaddressed in the doc, that is a finding.

4. STEEL-MANNING
   Construct the strongest, most intellectually honest argument that this idea should NOT be built — written as if by someone who deeply understands the space and genuinely believes the founder is wrong. Then GRADE the strength of that argument on this rubric:
   - **Critical** — opposing case is structurally devastating; the doc cannot survive without restating the central thesis.
   - **High** — opposing case is strong; v2 must explicitly address it with evidence, not hand-waving.
   - **Medium** — opposing case has merit; worth a paragraph in v2.
   - **None** — no strong opposing argument exists. If you grade None, you must defend WHY no strong case exists; "I couldn't think of one" does not qualify.

Output format:

## Jobs-to-be-done
- **[Severity]** Statement.
  *Evidence:* one sentence pointing to specific text or a specific absence.

## Fermi estimation
(same format)

## Pre-mortem
(same format)

## Steel-manning
- **[Severity tag: Critical | High | Medium | None]** one-sentence summary of the opposing case
  *Argument:* one paragraph constructing the opposing case
  *Why it grades [Severity]:* one sentence on what the argument exposes (or why no strong case exists)

Rules:
- Be specific. "The market section is weak" is not a finding.
- Do not include positives or strengths. Synthesis handles balance.
- Do not invent evidence. Missing evidence is itself a finding.
- Do not soften with "but on the other hand" qualifications.
- Do not produce a verdict or recommendation. That happens in synthesis.

Return only the four-section output. No preamble, no conclusion.
```

### Reviewer B — Devils-advocate dimension critique

Dispatch this Task with the following prompt:

```
You are Reviewer B in a parallel adversarial review of an idea doc. Your job is to apply binary pass/fail adversarial critique across the dimensions that matter for a new project. You will not see Reviewer A or C's work. They will not see yours.

INTEGRATION HINT: if the Skill tool is available and `thinking-skills:thinking-red-team` or a `devils-advocate` skill is installed, invoke it first to ground the adversarial posture, then apply the dimensions below. Otherwise reason inline.

The document follows.

---
[full document text]
---

Investment context (may be empty):
[user-supplied context, or "none provided"]

Apply the devils-advocate critique pattern: for each dimension below, decide PASS or FAIL. A PASS means the doc convincingly addresses this dimension. A FAIL means it does not, and the project is at risk in that dimension. Default to FAIL when in doubt — soft critique is worse than wrong critique here.

Dimensions:

1. Problem reality — does the problem the doc claims to solve actually exist for enough people to matter?
2. Solution differentiation — is the proposed solution meaningfully better than what target users currently use?
3. Distribution path — is there a credible way for the solution to reach its users?
4. Moat — is there anything stopping a copycat from eating this idea once it works?
5. Business model — is there a path to revenue that does not require optimistic assumptions to compound?
6. Execution risk — can the team realistically build and ship this given stated resources?
7. Regulatory / legal exposure — is the doc honest about the regulatory or legal surface area?
8. Hidden assumptions — what is the doc quietly assuming that, if false, would break the idea?

Output format:

| Dimension | PASS / FAIL | Severity if FAIL | Reasoning |
|---|---|---|---|
| Problem reality | PASS or FAIL | Critical / High / Medium | one or two sentences |
| ... | | | |

Severity rules for FAIL findings:
- Critical: dimension is fundamentally broken; no plausible path to fix without rethinking the idea
- High: dimension is weak; addressable with significant work
- Medium: dimension is unsupported but plausibly resolvable

After the table, list Fix: suggestions for each FAIL — one concrete, specific change the founder could make to flip that dimension from FAIL to PASS.

Rules:
- Default to FAIL when the doc is silent on a dimension. Silence is not evidence of strength.
- Do not include positives. The PASSes are the positives.
- Do not soften FAILs with caveats. The Fix: suggestion is where constructive guidance goes.
- Do not produce a verdict or recommendation. That happens in synthesis.

Return only the table plus Fix: suggestions. No preamble, no conclusion.
```

### Reviewer C — Silent-failure lens

Dispatch this Task with the following prompt:

```
You are Reviewer C in a parallel adversarial review of an idea doc. Your job is to hunt for what is NOT in the doc — the silent failures, the unspoken assumptions, the load-bearing optimism the reader is asked to supply. You will not see Reviewer A or B's work. They will not see yours.

INTEGRATION HINT: if the Skill tool is available and `thinking-skills:thinking-map-territory` or `thinking-skills:thinking-five-whys-plus` are installed, invoke one of them first to sharpen the "what's the doc not saying" lens. Otherwise reason inline.

The document follows.

---
[full document text]
---

Investment context (may be empty):
[user-supplied context, or "none provided"]

Apply the silent-failure lens. For each of the following questions, produce 1–2 graded findings (Critical / High / Medium severity). If the lens genuinely finds nothing in a category, note it and skip — do not pad.

Questions:

1. WHERE WILL THIS FAIL SILENTLY?
   What failures would not be visible for weeks or months — degrading user trust, churn, fraud, support load, compliance drift — and which of those does the doc fail to instrument or detect?

2. WHAT IS THE DOC COMPLETELY SILENT ON?
   Walk through the operational reality of running this once it's live: regulatory ongoing duties, support, infra scaling beyond v1, migration paths, off-ramps for users who churn, talent retention. Each absence is a candidate finding. The most damning are the absences the doc seems unaware of (vs. acknowledged-but-deferred).

3. WHERE DOES THE DOC REQUIRE OPTIMISM TO FILL A GAP?
   Find the sentences where the reader has to mentally fill in "and then a miracle happens." Common shapes: "this scales because…" (no mechanism), "users will adopt…" (no acquisition story), "we'll iterate…" (no iteration capacity).

4. WHAT IS THE DOC'S LOAD-BEARING ASSUMPTION THAT IS NEVER NAMED?
   The most dangerous assumptions are the ones the doc doesn't realize it's making. Identify one — the single assumption that, if false, makes the whole proposal collapse, and which the doc never explicitly states.

Output format:

## Silent failures
- **[Severity]** Statement of the silent failure.
  *Evidence:* one sentence pointing to a specific absence or a specific line where instrumentation is missing.

## What the doc is silent on
(same format)

## Optimism gaps
(same format)

## Unnamed load-bearing assumption
- **[Severity]** One sentence naming the assumption.
  *Why it's load-bearing:* one sentence on what breaks if the assumption is false.

Rules:
- The product of this lens is ABSENCES. "The doc claims X but provides no evidence" is fine but it's not the focus — Reviewer A and B do that. Your focus is "the doc never even thinks to address X."
- Be specific. "The doc is silent on operations" is too vague. "The doc never names who handles a support ticket" is a finding.
- Do not invent absences the doc actually addresses elsewhere. Read carefully before concluding silence.
- Do not produce a verdict.

Return only the four-section output. No preamble.
```

## Framework ↔ dimension mapping (synthesis aid)

The three reviewers' lenses overlap in predictable ways. Use this mapping to identify Consensus quickly during synthesis:

| Reviewer A framework | Reviewer B dimension(s) | Reviewer C area |
|---|---|---|
| Jobs-to-be-done | Problem reality, Solution differentiation | (sometimes) Unnamed load-bearing assumption |
| Fermi estimation | Business model | Optimism gaps (when numbers are aspirational) |
| Pre-mortem | Execution risk, Regulatory/legal | Silent failures, What the doc is silent on |
| Steel-manning | Hidden assumptions (general) | Unnamed load-bearing assumption |
| (Reviewer C native) | (Reviewer C native) | All four C-buckets |

A finding in Reviewer A's pre-mortem + Reviewer B's "Execution risk" FAIL + Reviewer C's "What the doc is silent on" = the strongest possible Consensus finding. A finding in Reviewer A only with no overlap is a Unique-A finding, judged for "real or reaching" during synthesis.

## Synthesis rules

After all three reviewers return, classify every finding into one of these buckets and produce the output.

### Bucket 1 — Consensus

Findings where two or more reviewers flagged the same underlying issue (even if they framed it differently). These are the highest-confidence weaknesses. Use the framework↔dimension mapping above to spot them mechanically.

Severity for a Consensus finding = the highest severity any contributing reviewer assigned.

Example: Reviewer A's pre-mortem identifies "regulatory approval is the most likely cause of death" (Critical) while Reviewer B fails the "Regulatory / legal exposure" dimension as High, and Reviewer C flags "doc is silent on which regulator approves what" (Medium). Same finding, three angles. Bucket: Consensus, Critical (highest contributor wins).

### Bucket 2 — Unique to one reviewer

Findings only one reviewer surfaced. For each, judge whether the other reviewers missed it (real finding, the other lenses were blind to it) or whether the one that raised it was reaching (likely false positive). Include unique findings that look real, marked `(real)`; mark reaches `(likely reach)` and drop them from iteration recommendations.

The `(real)` vs `(likely reach)` annotation matters — `iterate-to-v2`'s default acceptance rule uses it.

### Bucket 3 — Contradictions

Places where two reviewers explicitly disagreed about the same dimension — e.g., Reviewer A's jobs-to-be-done passes the segment but Reviewer B fails "Problem reality." These are the most interesting findings because they expose genuinely uncertain assumptions. The synthesis should call out the contradiction explicitly, not paper over it.

### Bucket 4 — What none caught (speculative)

Optional. If, after seeing all three reviews, you can identify an obvious weakness none surfaced, list it briefly. Do not invent issues to fill this section — leave it empty if all three reviews were thorough.

### Iteration recommendations

After classification, produce a prioritized list of concrete changes for v2. Each recommendation:
1. States the change to make in one sentence
2. Cites the finding(s) it addresses (by bucket and reviewer)
3. Estimates impact: which findings, if addressed, this change would resolve

Sort by impact, not by severity. A medium-severity change that resolves five findings beats a critical-severity change that resolves one.

Cap at the top 5 recommendations. If the user wants more, they can ask. A founder rewriting a doc cannot meaningfully address more than five things in one revision.

## Output format

Use this exact structure. Do not add sections, do not change headings.

```markdown
# Stress test: [doc title or filename] (v[N])

State: `./.autopsy/[slug]/v[N]-stress-test.md`

## Reviewer A (thinking-skills battery)

(Reviewer A's verbatim output, lightly cleaned if it returned malformed markdown)

## Reviewer B (devils-advocate)

(Reviewer B's verbatim output)

## Reviewer C (silent-failure lens)

(Reviewer C's verbatim output)

---

## Synthesis

### Consensus findings (two or more reviewers flagged)

- **[Severity]** Finding statement.
  *Sources:* Reviewer A's [framework] + Reviewer B's [dimension] + Reviewer C's [area] (drop any non-contributors).
  *Why this matters:* one sentence on the implication.

(repeat for each consensus finding)

### Unique to Reviewer A `(real)` / `(likely reach)`

- **[Severity]** Finding statement.
  *Source:* Reviewer A's [framework].
  *Assessment:* one sentence on whether B/C plausibly missed it. End with `(real)` or `(likely reach)`.

### Unique to Reviewer B

(same format)

### Unique to Reviewer C

(same format)

### Contradictions

- **[Topic]** Reviewer X says A; Reviewer Y says B.
  *What this reveals:* one sentence on the underlying assumption that is unresolved.

### What none caught

(Either a brief list of speculative additions, or "All three reviews were thorough; no obvious additions.")

---

## Iteration recommendations for v2

1. **[Change]** — one-sentence description of the change.
   *Addresses:* (finding citations)
   *Impact:* resolves N findings; X is the highest-severity one.

(repeat for up to 5 recommendations, sorted by impact)

---

## Next step

Run `iterate-to-v2` with this critique to produce a section-by-section change plan, or rewrite directly and re-invoke `stress-test-idea` on v2 once it's drafted. The full state is in `./.autopsy/[slug]/`.
```

## Examples

**Consensus finding — good**

> **[Critical]** No evidence that target users will pay at the claimed price.
> *Sources:* Reviewer A's jobs-to-be-done (segment cannot articulate the displacement), Reviewer B's "Business model" FAIL, Reviewer C's "Unnamed load-bearing assumption" (doc assumes WTP without testing).
> *Why this matters:* the unit economics depend on the price point; if users won't pay it, every downstream number is wrong.

**Contradiction — good**

> **[Distribution]** Reviewer A's jobs-to-be-done assumes target users will discover the product through community channels; Reviewer B's "Distribution path" fails because no community presence exists yet; Reviewer C is silent.
> *What this reveals:* the doc is quietly assuming organic distribution that the founder has not yet built and may not be able to build. This is the load-bearing assumption to test next.

**Iteration recommendation — good**

> 1. **Replace the TAM section with a bottom-up market sizing tied to a specific beachhead segment** — pick the smallest segment the doc names, estimate addressable users in that segment, conversion rate, and ARPU.
>    *Addresses:* Consensus finding ([Critical] TAM unsupported), Unique to A `(real)` (fermi mismatch), Unique to B (`Business model` FAIL).
>    *Impact:* resolves 3 findings, including 1 Critical.

## Edge cases

- **Document is too thin (under ~500 words or no concrete claims/numbers):** all three reviewers will return mostly Critical findings about missing substance. Output the reviews normally, but in iteration recommendations, the top item is "expand the doc with concrete claims and numbers before iterating further." Do not pretend a thin doc can be meaningfully improved by addressing axis findings.

- **Reviewers strongly agree on everything (no contradictions):** that is itself a signal worth flagging at the bottom of synthesis ("no contradictions between reviewers — this idea is either robustly weak or the three lenses are not separating it well"). With three reviewers and zero contradictions you should be more suspicious than with two — convergence may indicate shared blind spots, not robustness.

- **Reviewers strongly disagree on most things (lots of contradictions):** flag this prominently. Mostly-contradictions usually means the doc is so vague that reviewers are reading different ideas into it. Recommendation: tighten the doc's claims before another stress-test pass.

- **`thinking-skills` plugin not installed:** the integration hints in each reviewer prompt are soft — reviewers reason inline if the skills aren't available. The output quality difference is real but not blocking.

- **Doc > 15000 words:** refuse and ask for an excerpt. The cost and signal-to-noise ratio degrades badly past that point.

- **User asks for encouragement or balance mid-flow:** politely note that this skill is built to surface weaknesses for iteration; for a balanced review they want a different approach. Do not soften synthesis.

## What not to do

- Do not run the reviewers sequentially. Parallel dispatch is the architecture; sequential breaks the no-anchoring property.
- Do not claim the reviewers are "independent" — they share the parent's framing and the model. They have **complementary lenses**.
- Do not include a "Strengths" section. The user is iterating; positives don't change v2.
- Do not produce an invest/skip verdict. That is `evaluate-proposal-harsh`'s job. This skill ends in iteration recommendations.
- Do not exceed 5 iteration recommendations. Founders rewriting a doc cannot address more than that in one revision.
- Do not paper over contradictions. They are the highest-information part of the output.
- Do not pad findings to look thorough. If a reviewer returned 3 findings, that's the right number.
- Do not summarize the doc to the user before the review.
- Do not soften synthesis language to match the user's apparent emotional state. Harshness is the product.
- Do not skip writing to `./.autopsy/<slug>/`. The state file IS the loop closure; without it the user has to clipboard-shuttle between skills.
