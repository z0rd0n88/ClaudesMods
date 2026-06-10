---
name: iterate-to-v2
description: Translate a critique (from stress-test-idea, evaluate-proposal-harsh, or manual review notes) into a concrete change plan for v2 of an idea doc, proposal, pitch deck, or spec — section-by-section edits, things to cut, things to add, things only the founder can provide, and an explicit rejection log for findings the user disagrees with. Use this skill whenever the user has a critique in hand and wants to draft the next version of the doc — including phrases like "iterate this", "apply this critique", "draft v2", "rewrite based on this", "turn these findings into changes", "what should I actually change", "next version of this doc", "close the loop", or any request that combines a doc with feedback on that doc and asks for the resulting edits. The skill closes the loop on the stress-test-idea workflow but works with any critique input format.
---

# Iterate to v2

Translate a critique into a concrete change plan for the next version of a doc. The skill produces actionable edits — what to cut, what to rewrite, what to add — not a wholesale auto-rewrite. The founder owns the voice and the final text; this skill is the bridge between critique and the founder's keyboard.

This skill exists because the most common failure mode after a harsh critique is "patching" — sprinkling defensive language throughout v1 to acknowledge each weakness without actually resolving any of them. Patched docs get longer and weaker. Iterated docs get shorter and sharper. This skill is designed to push the user toward iteration, not patching.

## When to use

The user has two things: (1) a doc they wrote, and (2) a critique of that doc — from `stress-test-idea`, `evaluate-proposal-harsh`, a human reviewer, or their own notes. They want to know what to actually change in v2.

Triggers:
- "Apply this critique" / "iterate this" / "draft v2"
- "What should I actually change in this doc"
- "Turn these findings into edits"
- "Close the loop on this stress-test"
- Sharing a doc plus a critique and asking for next steps

If the user only has a doc and no critique, point them at `stress-test-idea` or `evaluate-proposal-harsh` first. This skill needs critique input — without it, there is nothing to translate.

## Inputs

Required:
- The original document (v1) — file path or pasted text
- A critique of that document — file path, pasted text, or inline list of findings

The critique can come in any format. Common formats:
- Output from `stress-test-idea` (consensus/unique/contradictions/iteration recommendations)
- Output from `evaluate-proposal-harsh` (axis findings + verdict)
- A human reviewer's notes
- The user's own bullet points
- A meeting transcript with feedback

Parse what you can. Do not enforce a specific critique format.

Optional, inline:
- Accept/reject decisions on specific findings ("reject the TAM finding — I have a reason to believe it")
- The user's own additional context ("I've decided to pivot to enterprise")
- Constraints on the rewrite ("must stay under 2 pages", "must keep the existing structure")

Do not ask follow-up questions before running. If the user has provided a doc and a critique, produce the change plan. If they have given accept/reject decisions, honor them. If they haven't, default to accepting every finding and let the rejection log be empty.

## The change-vs-hedge principle

This is the load-bearing rule. Read it before producing any output.

**A finding is "addressed" when the doc no longer makes the problematic claim, not when the doc acknowledges the problem.**

Examples:

| Finding | Hedge (wrong) | Change (right) |
|---|---|---|
| TAM is unsupported fantasy | Add caveat: "While our TAM estimate is preliminary..." | Delete the TAM section; replace with bottom-up sizing of one specific beachhead segment |
| No evidence users will pay | Add section: "User research is ongoing" | Cut the price-point claim; add: "Pricing TBD pending paid pilots" |
| Regulatory risk unaddressed | Add disclaimer: "We acknowledge regulatory complexity" | Either resolve the regulatory question or remove the feature that depends on it |
| Team lacks domain experience | Add line about "ongoing learning" | Reframe team section around the experience that IS relevant, or add an advisor who has it |
| Hockey-stick revenue projection | Add footnote: "Aggressive assumptions" | Replace the projection with a single conservative line item the founder can defend |

The pattern: **hedging keeps the bad content and apologizes for it; change removes or restructures the bad content.** A v2 that addresses critique through hedging is worse than v1, because it now contains the same weaknesses plus more text.

Every change recommendation in the output must be a real change, not a hedge. If a finding can only be addressed by hedging, the right answer is usually to cut the affected claim entirely.

## Workflow

Five steps: read, parse, classify, plan, format.

### Step 1 — Read both inputs

Read v1 and the critique. Note in working memory:
- v1's section structure
- v1's central thesis and supporting claims
- The critique's findings, organized by what they target in v1

### Step 2 — Parse findings into a normalized list

Regardless of critique format, normalize each finding to:
- What it claims is wrong
- Where in v1 it lives (which section/claim/number)
- Severity if stated (Critical / High / Medium); otherwise infer

If two findings target the same v1 element, merge them.

### Step 3 — Apply user accept/reject decisions

If the user has given decisions inline, honor them. If they haven't, default to accepting all findings.

A "reject" decision should include the user's reason. If they rejected without a reason, the skill should not invent one — note the rejection in the rejection log with `(user did not state reason)`.

### Step 4 — Classify each accepted finding into a change type

Five types, in rough order from most disruptive to least:

1. **Cut** — delete the affected content. Used when a section, claim, or number is so unsupported that no rewrite saves it.
2. **Pivot** — restructure around a different positioning, beachhead, or thesis. Used when the critique reveals the doc is making the wrong argument.
3. **Replace** — swap the affected content for something defensible. E.g., replace fantasy TAM with bottom-up sizing; replace projected ARR with a single committed pilot.
4. **Add** — introduce new content that v1 was missing. Used when the critique exposes an unaddressed risk or unaccounted-for cost.
5. **Refine** — sharpen existing content without changing the substance. Used only for medium-severity findings where v1 is mostly right but needs precision.

If a finding could be addressed by any of these, default to the most disruptive option that resolves it. Cut beats Pivot beats Replace beats Add beats Refine. Erring toward disruption produces shorter, sharper docs.

### Step 5 — Render the change plan

Use the output format below.

## Output format

Use this structure exactly. Do not add sections, do not change headings.

```markdown
# v2 change plan: [doc title or filename]

## Acceptance summary

- Accepted: N findings
- Rejected: M findings
- Deferred (low-impact or out of scope for v2): K findings

## Changes by section

### [Section name from v1]

- **Type:** Cut | Pivot | Replace | Add | Refine
- **Change:** one-sentence description of what to do
- **Addresses:** finding citation(s) from the critique
- **Proposed text or structure:** (only if useful — short draft, outline fragment, or numbers framework. Otherwise omit.)
- **Needs your input:** (only if applicable — specifically what the founder must provide that the skill cannot generate, e.g., a real customer name, a verified number, a chosen pricing tier)

(repeat for each affected v1 section)

## Sections to cut from v2

- **[Section name]** — which finding(s) made it obsolete; one-sentence rationale

## New sections needed in v2

- **[Section name]** — what it covers, which finding(s) made it necessary, what the founder needs to fill in

## Rejection log

- **[Finding]** — rejected because: [user's reason, or "user did not state reason"]
- **In v2, this means:** how (if at all) the doc should acknowledge or defend the rejected position. If no acknowledgment needed, write "no change to v2 from this rejection."

(repeat for each rejected finding; omit section entirely if nothing was rejected)

## Suggested v2 outline

A numbered list of sections in the order they should appear in v2. Mark each section as:
- *[unchanged]* — keep v1 content as-is
- *[edit]* — apply changes from "Changes by section" above
- *[new]* — write from scratch per "New sections needed"
- *[cut]* — section is removed

This is the founder's checklist for the rewrite.

## Next step

After v2 is drafted, run `stress-test-idea` (or `evaluate-proposal-harsh` if approaching a decision) on v2 to verify the changes resolved the findings without introducing new weaknesses. The loop closes when a stress-test pass returns mostly Medium findings or empty critical findings.
```

## Examples

**Change recommendation — good**

> ### Market sizing
>
> - **Type:** Replace
> - **Change:** Delete the $12B TAM claim and the chart that derives it. Replace with a bottom-up estimate for the institutional crypto trader beachhead: count of US institutional desks (~200), realistic addressable share at year 1 (~5%), monthly ARPU at proposed price ($2k), implied year-1 ARR ($240k).
> - **Addresses:** Consensus [Critical] finding — TAM unsupported (Reviewer A fermi mismatch + Reviewer B business-model FAIL)
> - **Proposed structure:** One paragraph stating the beachhead segment, the math, and the single most important assumption the math depends on.
> - **Needs your input:** The actual institutional desk count for your geographic focus, and the proposed monthly price — both should be researched/decided before drafting v2.

**Change recommendation — bad (this would be a hedge)**

> ### Market sizing
>
> - **Type:** Refine
> - **Change:** Add a caveat to the TAM section acknowledging it is preliminary and based on top-down assumptions.
> - **Addresses:** [Critical] TAM unsupported.

The bad version keeps the broken claim and adds an apology. The good version removes the broken claim and replaces it with something the founder can defend.

**Rejection log entry — good**

> - **[High] Doc assumes regulatory pathway is feasible without naming the specific approval needed** — rejected because: I have a verbal confirmation from a regulator that the existing exemption applies; I did not include this in v1 because the source is confidential.
> - **In v2, this means:** Add one line stating that "regulatory pathway has been validated with counsel" without naming the source. Do not provide more detail. If a reviewer asks for evidence, that question is answered offline.

## Edge cases

- **Critique format is non-standard or messy:** parse what you can, normalize into the internal finding list, proceed. Do not ask the user to re-format their critique.
- **Critique contradicts itself:** flag the contradiction at the top of the output (before "Acceptance summary") and ask the user to resolve it before running again. Do not produce a change plan based on contradictory inputs.
- **Findings recommend opposite changes (e.g., one says cut a section, another says expand it):** treat as a contradiction, flag, ask user to choose.
- **User rejects all findings:** produce a rejection log only, note that v2 = v1, and gently suggest that if every finding feels wrong, the critique may have been miscalibrated or the user may not be ready to iterate yet.
- **Critique has no actionable findings (e.g., entirely abstract praise or vague concerns):** flag that the critique is insufficient input; ask for a sharper critique or recommend running `stress-test-idea` to generate one.
- **User wants a wholesale rewritten v2, not a change plan:** comply, but include a header note: "This draft is a starting point. The founder should own final voice and verify all claims." Apply the same change-vs-hedge principle throughout the rewrite.
- **Doc is short (<500 words) and critique is also thin:** the right output is usually "expand v1 with concrete claims first, then critique-and-iterate." Surface this rather than producing a thin change plan.
- **User has run multiple critiques (e.g., both stress-test-idea and evaluate-proposal-harsh):** synthesize across them. Consensus findings across critiques are strongest signal — treat them as the highest-priority changes.

## What not to do

- Do not produce hedges. Re-read the change-vs-hedge principle if tempted.
- Do not auto-write v2 unless explicitly asked. The default output is a change plan; founders own the rewrite.
- Do not fill in "Needs your input" fields with invented data. If the founder needs to provide a real customer name, leave the field for them.
- Do not bury rejected findings. The rejection log is part of the output; the user's "no" matters as much as their "yes."
- Do not soften severity. If the critique flagged something as Critical, the change plan treats it as Critical.
- Do not pad the change plan to look thorough. If only 3 sections need changes, the output has 3 sections.
- Do not include a "Strengths" or "What's working" section. The user is iterating; positives don't drive v2.
- Do not summarize the doc or the critique back to the user before the plan. Both inputs are in their context already.
- Do not invent findings that weren't in the critique. The skill is a translator, not a critic.
