# Walkthrough: consumer-app-pitch (full loop → Proceed with caution)

This example shows the **full three-skill loop** end-to-end on a consumer fintech pitch. It demonstrates:

- How `stress-test-idea` exposes Criticals on a plausible-looking v1.
- How `iterate-to-v2` translates findings into a change plan with enforced `Removes problematic claim by:` fields.
- How `evaluate-proposal-harsh` renders a Proceed-with-caution verdict (the most common outcome for a tightened v2 from a competent team) with a measurable flip-condition.

> All outputs in this directory are **illustrative** — they show the format and shape of what the plugin produces, not literal runtime traces.

## The cycle

| Stage | File | Skill | Outcome |
|---|---|---|---|
| 1 | `v1.md` | (input) | Plausible budgeting-app pitch; team has shipped consumer fintech before; waitlist exists; TAM is fantasy multiplication, WTP is unvalidated. |
| 2 | `v1-stress-test.md` | `stress-test-idea` | 3-reviewer parallel critique. **Consensus Criticals:** no WTP evidence, TAM fantasy. **Consensus Highs:** distribution = one Reddit post, operational silence. |
| 3 | `v1-change-plan.md` | `iterate-to-v2` | Bucket-aware accept (4 Consensus + 1 Unique-real). Every change recommendation declares what it *removes*. Notes which sections to cut, which are net-new, and which findings need founder data (the paid-pilot test). |
| 4 | `v2.md` | (founder rewrite) | Beachhead'd TAM, real paid-pilot data instead of projections, named distribution channel with CAC ceiling, explicit operational scope. |
| 5 | `v2-verdict.md` | `evaluate-proposal-harsh` | Zero Criticals; three Highs cluster on acquisition-economics risk. **Verdict: Proceed with caution.** Flip-condition names the TikTok CAC test + retention threshold + 2026-10-01 deadline. |

## What this example showcases

### Change-vs-hedge in action

Look at `v1-change-plan.md` → "Market" section change recommendation. The `Removes problematic claim by:` field says:

> "deleting paragraph 2 of the Market section (the '70M × 25% × $8 × 1% = $1.7B' derivation) and the implied TAM line; replacing with one paragraph of bottom-up math."

This is the enforcement mechanism. A hedge version would have said "Removes problematic claim by: *adding a caveat that the TAM estimate is preliminary*" — that's forbidden and would be revised before output.

### Bucket-aware acceptance

The change plan's acceptance summary shows `5 findings (4 Consensus, 1 Unique-Reviewer-A (real))`. The `(real)` annotation came from `stress-test-idea`'s synthesis judgment. `iterate-to-v2` honored that judgment instead of blanket-accepting every finding. A v1 "What none caught" speculative addition would have been auto-deferred, not auto-accepted.

### Measurable flip-condition

The verdict's flip-condition is:

> "TikTok creator-partnership pilot completes by 2026-10-01 with blended CAC ≤ $18 across ≥ 200 attributed paying-user acquisitions, AND paid-pilot cohort retention reaches ≥ 60% at 90 days."

Three required elements present: specific artifact (TikTok pilot data), measurable thresholds (≤$18 CAC, ≥200 acquisitions, ≥60% retention), date (2026-10-01). The founder can tell whether they've satisfied it.

The forbidden vague version would have been: "if the team validates demand and tightens the acquisition model, this could be an Invest." The skill refuses that and rewrites.

### Loop closure on disk

Every artifact lives under `./.autopsy/consumer-app-pitch/`. The router's state-aware Rule 2 reads what's on disk and routes to the next-logical step. After `v2-verdict.md` lands, `--status` reports "loop closed with Proceed; flip-condition pending" and does not auto-invoke another skill.

## How to read it

Read in this order:

1. **`v1.md`** — the input. Note it looks credible at first read.
2. **`v1-stress-test.md`** — note the Consensus column. Cross-lens agreement is the highest-signal critique surface.
3. **`v1-change-plan.md`** — note the `Removes problematic claim by:` field on every recommendation. That's the hedge-vs-change enforcement.
4. **`v2.md`** — compare section-by-section against v1. See which sections were cut, replaced, or added.
5. **`v2-verdict.md`** — note the issue multiplicity table and the measurable flip-condition format.

## When this pattern applies

This is the **most common** path through the plugin: a competent-but-flawed pitch → iteration → tightened version that still has real risks → Proceed with caution with concrete acquisition tests as the flip-gate.

For the other two paths through the plugin, see:
- `examples/b2b-saas-pivot/` — strong team, wrong thesis → **Pivot** verdict.
- `examples/unsupported-tam-skip/` — fantasy market + no domain experience → **Skip** with no plausible flip.
