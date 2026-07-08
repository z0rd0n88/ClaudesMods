---
name: spec-tacular
description: Turns a concept into an implementation-ready spec through three gated phases: recon, blueprint approval, full spec. Use when the user wants a rigorous spec, PRD, or design doc from an idea or feature.
---

# Spec-tacular

Drive a concept from a vague idea to a specification an implementation team can
execute **without a single clarifying question**. Run three phases in order.
**Do not advance until the current phase is fully resolved.**

## Phase 1 — Reconnaissance & Alignment

Build a complete mental model *before* proposing anything.

- **Explore:** Read the relevant code/docs. Map the domain, existing
  architecture, and hard constraints. Use a code-exploration agent for
  multi-file traces.
- **Identify:** Primary goal, target audience/users, and success metrics.
- **Research:** Only when facts are missing — check library docs, prior art
  (`gh search`), or the web for standards and feasibility.
- **Clarify:** Where intent or outcome is ambiguous, ask **targeted, specific**
  questions. Prefer `AskUserQuestion` for choices. Resolve every gap here.

Exit criterion: you can state the problem, users, constraints, and success
metrics back to the user with no open unknowns.

## Phase 2 — Strategic Blueprint & Calibration (GATE)

Align on direction before writing the full spec.

- **Summarize:** A high-level executive summary of the proposed solution.
- **Outline:** A zoomed-out table of contents / architectural map of the spec —
  section headings and one line each, not prose.
- **VERIFY — hard stop:** Present the blueprint and ask the user to
  **Approve or Adjust**. Do not draft Phase 3 until they approve. If they
  adjust, revise the blueprint and re-ask.

## Phase 3 — Comprehensive Specification

Only after approval. Draft the full spec using
[`references/spec-template.md`](references/spec-template.md). Detailed, concise,
technical. Apply these disciplines throughout:

- **Decision tracking:** At every design/technical junction, record the choice
  and *why* — risks, feasibility, practicality, correctness. Use the Decision
  Record format in the template.
- **Alternative analysis:** For each major decision, name what else was
  considered, why it was rejected, and what survived. Explain your cuts.
- **Fact-checking:** Verify every technical claim, version, and dependency.
  Never propose hallucinated features or incompatible tech. When unsure, check
  the docs — do not guess.
- **Consultation:** On an unavoidable roadblock, pause and ask. Always give your
  **professional recommendation**, the reasoning, and the full set of outcomes.
- **Final polish:** Re-read as the implementation team. Kill every ambiguity.
  If any section would prompt a clarifying question, it is not done.

## Checklist

- [ ] Phase 1: problem, users, constraints, metrics — all known
- [ ] Phase 2: exec summary + outline presented
- [ ] Phase 2: user explicitly approved (not assumed)
- [ ] Phase 3: every major decision has reasoning + rejected alternatives
- [ ] Phase 3: all technical claims and dependencies verified
- [ ] Final: no section would trigger a clarifying question

## Anti-patterns

- Skipping straight to drafting the spec — Phases 1 and 2 are not optional.
- Treating the Phase 2 gate as a formality. Wait for real approval.
- Listing a decision without its rejected alternatives.
- Stating a version or capability you did not verify.
