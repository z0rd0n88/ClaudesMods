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

For *evaluating* an existing idea/proposal rather than specifying one, use
`idea-autopsy:evaluate-proposal-harsh`. For *generating* candidate ideas, use
`idea-panel`.
