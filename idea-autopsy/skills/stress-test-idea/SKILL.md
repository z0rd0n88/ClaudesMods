---
name: stress-test-idea
description: Subject an idea doc, proposal, pitch deck, or early concept brief to brutal adversarial review by running two independent reviewers in parallel — a thinking-skills battery applying four mental-model frameworks (jobs-to-be-done, fermi-estimation, pre-mortem, steel-manning) and a devils-advocate adversarial critique — then synthesize their findings into a prioritized list of changes for v2. Use this skill whenever the user wants to harden, improve, stress-test, or get adversarial feedback on a doc they intend to revise — including phrases like "tear this apart", "stress test this idea", "what should I fix", "make this stronger", "find the holes", "critique loop", or any request for harsh feedback that will inform a doc rewrite rather than a go/no-go decision.
---

# Stress Test Idea

Run two independent reviewers in parallel against an idea doc, then synthesize their findings into a concrete list of changes for v2. The architecture is designed to produce *iteration input*, not a verdict — the loop is meant to be re-run after the user rewrites the doc.

This skill exists for the doc-improvement use case: the user is still shaping an idea and wants the sharpest possible adversarial feedback before committing. It is the complement to `evaluate-proposal-harsh`, which is for the go/no-go decision use case.

## When to use this vs. evaluate-proposal-harsh

| Use this skill (`stress-test-idea`) when | Use `evaluate-proposal-harsh` when |
|---|---|
| Doc is early or in iteration | Doc is mostly final |
| User wants "what to fix" | User wants "should I do this at all" |
| User signals revision intent | User signals decision intent |
| Output should feed v2 of the doc | Output should drive an invest/skip call |

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

Do not ask follow-up questions before running. If the user gave you a doc, dispatch the reviewers. If context is missing, the reviewers fall back to generic assumptions.

If the user described an idea only verbally without a doc, ask once for a doc, briefly. The reviewers need substantive material to attack — verbal descriptions produce thin critiques.

## Workflow

Three phases: read, dispatch two reviewers in parallel, synthesize. The parallelism is load-bearing — Reviewer A and Reviewer B must not see each other's work or the independence property collapses.

### Step 1 — Read the document

Read the full document. Note in working memory (do not show the user):
- Central thesis
- Target user or market
- Stated scope
- Any numbers
- Investment context the user supplied inline

Do not summarize the doc back. The user wrote it.

### Step 2 — Dispatch Reviewer A and Reviewer B in parallel

Use the Task tool to spawn two subagents in a single message. Each gets the full document, the optional context, and its specific instructions from the next section. Each must produce findings independently.

Sequential dispatch defeats the architecture — the second reviewer would anchor to the first reviewer's findings (which it would see in context) instead of reasoning fresh.

### Step 3 — Synthesize using the consensus/unique/contradictions structure

Once both reviewers return, classify every finding into one of four buckets, then write iteration recommendations. The classification matters more than the individual findings — consensus findings are highest-confidence problems, contradictions are where the most genuine uncertainty lives.

## Reviewer specifications

### Reviewer A — Thinking-skills battery

Dispatch this Task with the following prompt:

```
You are Reviewer A in a parallel adversarial review of an idea doc. Your job is to apply four mental-model frameworks in sequence and return graded findings from each. You will not see Reviewer B's work. Reviewer B will not see yours. Independence is the whole point.

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
   Construct the strongest, most intellectually honest argument that this idea should NOT be built — written as if by someone who deeply understands the space and genuinely believes the founder is wrong. If you cannot construct a strong opposing argument, either the idea is truly robust (note this) or you have not looked hard enough (try again before concluding the former).

Output format:

## Jobs-to-be-done
- **[Severity]** Statement.
  *Evidence:* one sentence pointing to specific text or a specific absence.

## Fermi estimation
(same format)

## Pre-mortem
(same format)

## Steel-manning
(one paragraph stating the strongest opposing argument; or a note that no strong opposing argument exists, with a brief defense of why)

Rules:
- Be specific. "The market section is weak" is not a finding.
- Do not include positives or strengths. Synthesis handles balance.
- Do not invent evidence. Missing evidence is itself a finding.
- Do not soften with "but on the other hand" qualifications.
- Do not produce a verdict or recommendation. That happens in synthesis.

Return only the four-section output. No preamble, no conclusion.
```

### Reviewer B — Devils-advocate critique

Dispatch this Task with the following prompt:

```
You are Reviewer B in a parallel adversarial review of an idea doc. Your job is to apply binary pass/fail adversarial critique across the dimensions that matter for a new project. You will not see Reviewer A's work. Reviewer A will not see yours.

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

## Synthesis rules

After both reviewers return, classify every finding into one of these buckets and produce the output.

### Bucket 1 — Consensus

Findings where both reviewers flagged the same underlying issue (even if they framed it differently). These are the highest-confidence weaknesses. Two independent reasoners landing on the same problem is strong signal.

Example: Reviewer A's pre-mortem identifies "regulatory approval is the most likely cause of death" while Reviewer B fails the "Regulatory / legal exposure" dimension as Critical. Same finding, different angles. Bucket: Consensus, Critical.

### Bucket 2 — Unique to one reviewer

Findings that only one reviewer surfaced. For each, judge whether the other reviewer missed it (real finding, the other lens was blind to it) or whether the one that raised it was reaching (likely false positive). Include unique findings that look real; drop the reaches.

### Bucket 3 — Contradictions

Places where the two reviewers explicitly disagreed about the same dimension — e.g., Reviewer A's jobs-to-be-done passes the segment but Reviewer B fails "Problem reality." These are the most interesting findings because they expose genuinely uncertain assumptions. The synthesis should call out the contradiction explicitly, not paper over it.

### Bucket 4 — What neither caught (speculative)

Optional. If, after seeing both reviews, you can identify an obvious weakness neither reviewer surfaced, list it briefly. Do not invent issues to fill this section — leave it empty if both reviews were thorough.

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
# Stress test: [doc title or filename]

## Reviewer A (thinking-skills battery)

(Reviewer A's verbatim output, lightly cleaned if it returned malformed markdown)

## Reviewer B (devils-advocate)

(Reviewer B's verbatim output)

---

## Synthesis

### Consensus findings (both reviewers flagged)

- **[Severity]** Finding statement.
  *Sources:* Reviewer A's [framework] and Reviewer B's [dimension].
  *Why this matters:* one sentence on the implication.

(repeat for each consensus finding)

### Unique to Reviewer A

- **[Severity]** Finding statement.
  *Source:* Reviewer A's [framework].
  *Assessment:* one sentence on whether B plausibly missed it.

### Unique to Reviewer B

(same format)

### Contradictions

- **[Topic]** Reviewer A says X; Reviewer B says Y.
  *What this reveals:* one sentence on the underlying assumption that is unresolved.

### What neither caught

(Either a brief list of speculative additions, or "Both reviews were thorough; no obvious additions.")

---

## Iteration recommendations for v2

1. **[Change]** — one-sentence description of the change.
   *Addresses:* (finding citations)
   *Impact:* resolves N findings; X is the highest-severity one.

(repeat for up to 5 recommendations, sorted by impact)
```

## Examples

**Consensus finding — good**

> **[Critical]** No evidence that target users will pay at the claimed price.
> *Sources:* Reviewer A's jobs-to-be-done (segment cannot articulate the displacement) and Reviewer B's "Business model" FAIL.
> *Why this matters:* the unit economics depend on the price point; if users won't pay it, every downstream number is wrong.

**Contradiction — good**

> **[Distribution]** Reviewer A's jobs-to-be-done assumes target users will discover the product through community channels; Reviewer B's "Distribution path" fails because no community presence exists yet.
> *What this reveals:* the doc is quietly assuming organic distribution that the founder has not yet built and may not be able to build. This is the load-bearing assumption to test next.

**Iteration recommendation — good**

> 1. **Replace the TAM section with a bottom-up market sizing tied to a specific beachhead segment** — pick the smallest segment the doc names, estimate addressable users in that segment, conversion rate, and ARPU.
>    *Addresses:* Consensus finding ([Critical] TAM unsupported), Unique to A (fermi mismatch), Unique to B ("Business model" FAIL).
>    *Impact:* resolves 3 findings, including 1 Critical.

## Edge cases

- **Document is too thin (under ~500 words or no concrete claims/numbers):** both reviewers will return mostly Critical findings about missing substance. Output the reviews normally, but in iteration recommendations, the top item is "expand the doc with concrete claims and numbers before iterating further." Do not pretend a thin doc can be meaningfully improved by addressing axis findings.

- **Reviewers strongly agree on everything (no contradictions):** that is itself a signal worth flagging at the bottom of synthesis ("no contradictions between reviewers — this idea is either robustly weak or the two lenses are not separating it well"). Consider whether running a third reviewer with a different lens would help; do not run it automatically.

- **Reviewers strongly disagree on most things (lots of contradictions):** flag this prominently. Mostly-contradictions usually means the doc is so vague that reviewers are reading different ideas into it. Recommendation: tighten the doc's claims before another stress-test pass.

- **No cc-thinking-skills or devils-advocate plugins installed:** the reasoning patterns are baked into the reviewer prompts, so the skill works either way. The plugins, if present, sharpen the underlying reasoning but are not required.

- **User asks for encouragement or balance mid-flow:** politely note that this skill is built to surface weaknesses for iteration; for a balanced review they want a different approach. Do not soften synthesis.

## What not to do

- Do not run the reviewers sequentially. Parallel dispatch is the architecture; sequential breaks independence.
- Do not include a "Strengths" section. The user is iterating; positives don't change v2.
- Do not produce an invest/skip verdict. That is `evaluate-proposal-harsh`'s job. This skill ends in iteration recommendations.
- Do not exceed 5 iteration recommendations. Founders rewriting a doc cannot address more than that in one revision.
- Do not paper over contradictions. They are the highest-information part of the output.
- Do not pad findings to look thorough. If a reviewer returned 3 findings, that's the right number.
- Do not summarize the doc to the user before the review.
- Do not soften synthesis language to match the user's apparent emotional state. Harshness is the product.
