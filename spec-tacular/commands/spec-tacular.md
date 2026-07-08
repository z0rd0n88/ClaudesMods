---
description: "Turn a concept into an implementation-ready spec through three gated phases"
argument-hint: "<concept or feature idea...>"
---

Invoke the `spec-tacular` skill and follow it exactly.

Concept to spec out: `$ARGUMENTS`

The skill runs three phases in order and **does not advance until the current
phase is fully resolved**:

1. **Reconnaissance & Alignment** — explore the domain/architecture/constraints,
   identify goal, audience, and success metrics, research only where facts are
   missing, and clarify every ambiguity with targeted questions.
2. **Strategic Blueprint (GATE)** — present an executive summary + a zoomed-out
   section outline, then **stop** for the user to Approve or Adjust. No full
   draft happens before approval.
3. **Comprehensive Specification** — draft the full spec with decision records
   (choice + rejected alternatives), fact-checked claims/dependencies, and a
   final ambiguity-kill pass, so an implementation team can execute without a
   single clarifying question.

Common invocations:

```
spec-tacular a CLI that syncs Obsidian vaults to S3
spec-tacular add SSO to the admin dashboard
spec-tacular real-time collaborative cursor for our editor
```

Reach for a neighbor instead when:

- *Evaluating* an existing idea/proposal → `idea-autopsy:evaluate-proposal-harsh`.
- *Generating* candidate ideas → `idea-panel`.
- A **PM PRD** with metrics/personas → `write-spec`.
- A **PRD from the current conversation**, published to a tracker → `to-prd`.
- A **single architecture decision** (one ADR) → `engineering:architecture`.
- A **task-by-task implementation plan**, not a spec → `prp-plan`.

spec-tacular's niche vs. these: a *code-grounded engineering spec* with a
mid-draft outline-approval gate and embedded decision records — buildable by an
implementation team without follow-up questions.
