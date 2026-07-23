# Walkthrough: b2b-saas-pivot (Pivot verdict)

This example showcases the **Pivot verdict** — added in v1.1 of the plugin — for the canonical pattern it was designed to surface: a strong team building the wrong product.

> All outputs in this directory are **illustrative**, showing the format and shape the plugin produces.

## The cycle

| Stage | File | Skill | Outcome |
|---|---|---|---|
| 1 | `v1.md` | (input) | Strong technical roster (ex-Airtable Interface Designer PM, ex-Retool data-sources eng, ex-Sheets API eng) building a Sheets-to-app generator. Comparison table is real; competitive positioning fights Airtable, Retool, Glide, and Bubble head-on with prosumer-shaped product at enterprise prices. |
| 2 | `v1-verdict.md` | `evaluate-proposal-harsh` | **Verdict: Pivot.** Multi-axis Critical on thesis (Critical Thinking + ROI agree); Feasibility passes cleanly; Risk only Mediums. Verdict suggests two alternative theses leveraging the same team. |

The user invoked `evaluate-proposal-harsh` directly (verdict intent: "should I build this?") rather than going through the stress-test → iterate path. The pitch was already at v1-final; the founder wanted a decision, not iteration input.

## What this example showcases

### The Pivot decision rule firing

From the multiplicity table in the verdict:

| Issue | Severity | Axes (N) | Primary |
|---|---|---|---|
| Wedge real but small; cohort can't afford the proposed price | Critical | Critical Thinking + ROI (2) | Critical Thinking |
| TAM is fantasy multiplication; realistic SAM ~$80M | Critical | ROI + Critical Thinking (2) | ROI |

Both Criticals are multi-axis AND both include Critical Thinking AND Feasibility passes AND Risk has no Critical — that's the Pivot trigger:

```
Pivot when:
  - exactly one Critical issue with ≥2-axis support
  - surfaced_by includes "Critical Thinking" (the thesis is wrong)
  - Feasibility-axis findings all Medium or absent
  - ROI-axis has no other Critical
```

Strictly the rule expects "exactly one" multi-axis Critical — here there are two but they're the same underlying issue (price-cohort mismatch from two angles). The synthesizer's judgment override applies; the verdict paragraph explains why.

### Alternative theses are concrete, not generic

Notice the two alternative theses suggested in the verdict don't say "consider a vertical SaaS approach" — they name specific verticals and specific advantages the team uniquely brings:

1. **Regulated industries** — maps the team's Sheets-API depth and Retool on-premise-connector experience to a real distribution channel (GCP marketplace + audit firms) at enterprise pricing the cohort actually pays.
2. **Vertical Sheets add-on** — names three candidate verticals (recruiting, construction ops, clinical trials) with concrete price benchmarks.

A Pivot verdict without concrete alternatives is just a Skip with extra steps. The verdict template requires naming 1–2 specific alternatives so the founder has somewhere to go.

### Measurable flip-condition for the current thesis

The verdict ends with:

> "≥ 12 signed annual contracts at ≥ $20,000 ARR each (i.e., 8-user teams at full Pro pricing) by 2026-12-31, with the 12 contracts spread across at least 3 industries to show the horizontal positioning works."

Three required elements: specific artifact (signed annual contracts), measurable thresholds (≥12 contracts, ≥$20k ARR each, ≥3 industries), date (2026-12-31). If the founder hits those numbers, the verdict flips to Invest because the price-cohort mismatch hypothesis was wrong. If they don't, the verdict stands.

### Feasibility passing is a Pivot prerequisite

Feasibility passing cleanly is what makes this a Pivot instead of a Skip. If the same Criticals had landed with Feasibility ALSO showing a Critical ("team has no shipping experience in this space"), the verdict would be Skip — there'd be nothing intact to pivot around.

The team-as-asset pattern matters: a Pivot verdict says "the founder has built something valuable (a team, a capability, a market presence) that should be redeployed against a different thesis."

## How to read it

Read in this order:

1. **`v1.md`** — note how plausible it is at first read. The comparison table looks compelling; the team is genuinely impressive.
2. **`v1-verdict.md`** — the multiplicity table is the key visual. Two Criticals stacking in Critical Thinking + ROI is what triggers Pivot, not Skip.
3. The verdict paragraph — note the explicit naming of "the team and capability are intact; the thesis is the broken part." That language is the Pivot tell.
4. The two alternative theses — note they're concrete and tied to the team's actual advantages.

## When this pattern applies

This is the verdict to look for when:

- The team is genuinely strong in a specific way.
- The market is real but the pricing/cohort/positioning is wrong.
- Feasibility is unambiguously fine.
- Risk has only addressable findings.

It's the most actionable verdict for a competent founder — Skip closes the door, Pivot says "you have an asset; aim it somewhere else." Most pitches that look like a Skip on first read are actually Pivots once Feasibility passes.

For other verdict shapes, see:
- `examples/consumer-app-pitch/` — full stress-test → iterate → re-evaluate loop ending in **Proceed with caution**.
- `examples/unsupported-tam-skip/` — **Skip** with no plausible flip.
