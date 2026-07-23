# Specification Document Template

Structure the Phase 3 spec with these sections. Drop sections that genuinely
don't apply; never leave a section as a placeholder.

## 1. Executive Summary
2–4 sentences: what is being built, for whom, and the outcome it delivers.

## 2. Problem & Goals
- **Problem statement** — the pain being solved.
- **Goals** — measurable objectives.
- **Non-goals** — explicitly out of scope, to bound the work.
- **Success metrics** — how "done and working" is judged.

## 3. Users & Context
Target users/personas, their primary jobs-to-be-done, and the environment/
constraints the solution runs in.

## 4. Requirements
- **Functional** — numbered, testable statements (FR-1, FR-2, …).
- **Non-functional** — performance, security, scale, accessibility, compliance.

## 5. Architecture & Design
- Component/architecture map (diagram-in-prose or ASCII is fine).
- Data model / schema.
- Interfaces & contracts (APIs, events, function signatures).
- Dependencies and their pinned versions — each one verified.

## 6. Decision Records
One block per major decision:

```
### DR-<n>: <decision title>
- Decision: <what was chosen>
- Context: <forces at play — constraints, requirements>
- Rationale: <why — risk, feasibility, practicality, correctness>
- Alternatives considered:
  - <option A> — rejected because <reason>
  - <option B> — rejected because <reason>
- Consequences: <trade-offs accepted, follow-ups incurred>
```

## 7. Implementation Plan
Phased breakdown. For each phase: scope, deliverables, dependencies, and the
order of work. Small vertical slices over big-bang.

## 8. Risks & Mitigations
Table: risk → likelihood/impact → mitigation or contingency.

## 9. Testing & Validation
Test strategy — unit, integration, E2E — and the acceptance criteria that
close each requirement (map each back to a numbered FR).

## 10. Open Questions
Anything still unresolved. **The bar for a finished spec is this section being
empty** — every entry here is a clarifying question the implementation team
would otherwise have to ask.
