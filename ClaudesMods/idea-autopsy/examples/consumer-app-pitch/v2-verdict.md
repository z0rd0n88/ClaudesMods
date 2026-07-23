# Proposal evaluation: GigPurse v2 (v2)

State: `./.autopsy/consumer-app-pitch/v2-verdict.md`

> **Note:** illustrative example of `evaluate-proposal-harsh` output after a full loop. Compare to `v1-stress-test.md` to see how v2 resolved the v1 Criticals.

## Executive summary

- **[High]** [2/4 axes] *ROI* — TikTok CAC ceiling is asserted but untested; if blended CAC exceeds $18, unit economics break.
- **[High]** [1/4 axes] *Risk* — single-channel acquisition concentration; TikTok algorithm risk is unhedged.
- **[High]** [1/4 axes] *Feasibility* — March/April support spike plan relies on one contracted hire; capacity math is tight.
- **[Medium]** [1/4 axes] *Critical Thinking* — "5% adoption ceiling" assumption is asserted but not benchmarked against a comparable consumer-fintech wedge.

## Critical thinking

- **[Medium]** "5% adoption in pain-aligned cohort" is benchmarked to Mint, but Mint had W-2 mass-market reach; rideshare-specific adoption could be higher (drivers actively seek tooling) or much lower (rideshare income is declining post-2024, reducing the population).
  *Evidence:* doc names the assumption but doesn't cite a comparable wedge (e.g., Catch Money for freelancers reached ~3% of TAM before being acquired).

## Feasibility

- **[High]** Tax-season support staffing math is "founders + 1 contractor" for an expected 4× spike. At 5k users, ~50 weekly tickets baseline → ~200/week in March-April. One contractor handling 200/week is plausible only if 80% of tickets are self-serve via the buffer-text auto-response. The doc asserts this but doesn't reference a tested deflection rate.
  *Evidence:* "1 contracted support hire for tax season" line.

## Risk and red flags

- **[High]** TikTok creator partnerships as the sole primary channel is single-point-of-failure. Algorithm shifts or creator-account suspensions can collapse acquisition overnight. The doc acknowledges "if TikTok-CAC test fails, v3 pauses for re-strategy" — that pause IS the risk if it lands at month 5 with depleted runway.
  *Evidence:* Distribution section names one channel; no fallback acquisition plan named.

## ROI signal

- **[High]** CAC ceiling of $18 is asserted (matches 3× LTV/CAC at $55 LTV) but untested. Consumer-fintech TikTok CAC commonly lands $25–$40. If actual CAC is $30, LTV/CAC drops to 1.8× and the business does not work without an LTV improvement.
  *Evidence:* doc names the ceiling and the test budget but treats "CAC ≤ $18" as a target, not a validated number.

---

## Issue multiplicity table

| Issue | Severity | Axes (N) | Primary |
|---|---|---|---|
| TikTok CAC ceiling untested | High | ROI + Risk (2) | ROI |
| Single-channel acquisition concentration | High | Risk (1) | Risk |
| Tax-season support spike capacity | High | Feasibility (1) | Feasibility |
| 5% adoption benchmark thin | Medium | Critical Thinking (1) | Critical Thinking |

---

## Verdict: Proceed with caution

The v1→v2 iteration resolved both v1 Criticals: paid-pilot data (18/22 month-1, 15/22 month-2) established willingness-to-pay; TAM was replaced with a defensible bottom-up SAM. Zero Criticals remain. Three Highs cluster around the same underlying risk: **acquisition unit economics are asserted but not yet validated**. The team has the right pieces (validated WTP, a beachhead, an acquisition test plan, operational honesty about support); they have not yet survived the acquisition-cost gauntlet that kills most consumer fintech. Proceed with the raise, but the raise's first 4 months should be entirely about the TikTok CAC test, not feature work.

**Flip-condition (Proceed → Invest):** TikTok creator-partnership pilot completes by 2026-10-01 with blended CAC ≤ $18 across ≥ 200 attributed paying-user acquisitions, AND paid-pilot cohort retention reaches ≥ 60% at 90 days. Both conditions met flips this to Invest.
