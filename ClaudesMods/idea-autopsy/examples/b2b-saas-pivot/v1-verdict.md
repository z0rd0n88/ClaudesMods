# Proposal evaluation: Stellate — From spreadsheet to internal app in 60 seconds (v1)

State: `./.autopsy/b2b-saas-pivot/v1-verdict.md`

> **Note:** illustrative example showing a **Pivot** verdict — the verdict added in v1.1 of the plugin. Pivot fires when the thesis is wrong but the team/feasibility/market are intact.

## Executive summary

- **[Critical]** [2/4 axes] *Critical Thinking* — The "we're different because we don't require data migration" wedge is real but small; the cohort that values it most (sub-50-person ops teams) is the cohort least able to pay $30/user enterprise pricing.
- **[Critical]** [2/4 axes] *ROI* — TAM derivation ($3.6B) multiplies aspirational adoption × aspirational ARPU; bottom-up SAM for the actual wedge (US ops teams that already have a process-bearing sheet AND will pay $30/user) is closer to $80M.
- **[High]** [1/4 axes] *Critical Thinking* — Strategic positioning ("acquired by Google/Microsoft within 5 years") is a strategy depending on a buyer who has demonstrated declining interest in the category (AppSheet deprioritization is acknowledged but not addressed as a counter-signal).
- **[Medium]** [1/4 axes] *Risk* — Google can ship "Generate App" as a Sheets-native feature; the Chrome-extension surface is reversible by Google in a single Sheets release.

## Critical thinking

- **[Critical]** The wedge ("only product that doesn't leave the spreadsheet") is real but its value is asymmetric: it matters most to small ops teams that already use Sheets and can't afford to migrate. Those teams are also the ones least likely to pay $30/user/month for a Pro tier — they're using Sheets BECAUSE it's free. The doc's comparison table is technically accurate; the strategic conclusion ("therefore $3.6B TAM") does not follow.
  *Evidence:* the comparison table conflates "differentiation" (which is real) with "willingness to pay at our price" (which is unexamined). The 12/60 weekly-active beta users data is positive but tells us nothing about WTP at $30/user.

- **[High]** Strategic exit story rests on a 5-year acquisition by Google, Microsoft, or Notion. Google literally acquired AppSheet to solve this and deprioritized it. The doc acknowledges this as an opening, but the more honest read is that incumbents have looked at this market, made bets, and concluded the unit economics are weak.
  *Evidence:* doc cites AppSheet as the "wedge is open again" signal; the opposite read (incumbents tried this and walked away from it) is at least as defensible.

## Feasibility

- **[Medium]** Team can ship — ex-Airtable Interface Designer PM + ex-Retool data-sources eng + ex-Sheets API eng is a near-perfect technical roster for this exact problem.
  (No FAIL findings — feasibility passes cleanly.)

## Risk and red flags

- **[Medium]** Google can collapse the differentiation in one Sheets release: "File → Generate App." This isn't speculative — Google has shipped exactly this kind of feature inside Sheets (Smart Fill, Smart Cleanup, Connected Sheets). The Chrome-extension surface is also revocable by Google for any reason.
  *Evidence:* doc mentions AppSheet but doesn't model the response from Google shipping the same feature in-product.

- **[Medium]** Sub-50-person ops teams have high churn at the bottom of the market: budget owners change, processes get formalized into proper IT systems, sheets get retired. CHM (customer-hour-month) economics in this segment are typically poor.
  *Evidence:* doc doesn't model churn at the relevant cohort size.

## ROI signal

- **[Critical]** TAM math: 50M Workspace users × 20% × $30/mo × 12 = $3.6B is the same fantasy multiplication pattern flagged in many proposals. Bottom-up: US ops teams with ≥10 employees and an active Sheets-driven process ≈ ~800K. WTP at $30/user/month for the *whole team* (not just one builder) clears for maybe 10% = 80K teams × average 8 users × $30 × 12 ≈ $230M global SAM at the optimistic end; the realistic addressable in year 1–3 is closer to $80M.
  *Evidence:* TAM is calculated as users × ARPU × 100% adoption; SAM is never computed.

- **[High]** Pro tier ($30/user/month) and Enterprise tier ($250+/user/month) pricing requires the customer to value Stellate as enterprise software, but the wedge (Chrome extension, 60-second-app generation) is consumer-prosumer-shaped. Pricing-product mismatch is a common kill mode in this category (e.g., Coda, Notion's enterprise journey was 5+ years).
  *Evidence:* doc lists Enterprise tier without naming any signal that beta users would pay enterprise prices.

---

## Issue multiplicity table

| Issue | Severity | Axes (N) | Primary |
|---|---|---|---|
| Wedge real but small; cohort can't afford the proposed price | Critical | Critical Thinking + ROI (2) | Critical Thinking |
| TAM is fantasy multiplication; realistic SAM ~$80M | Critical | ROI + Critical Thinking (2) | ROI |
| Strategic exit depends on declining buyer interest | High | Critical Thinking (1) | Critical Thinking |
| Google can collapse the wedge in one Sheets release | Medium | Risk (1) | Risk |
| Sub-50 ops teams have poor CHM economics | Medium | Risk (1) | Risk |
| Pricing-product mismatch (enterprise pricing on prosumer wedge) | High | ROI (1) | ROI |

---

## Verdict: Pivot

The central thesis — "build the spreadsheet-native app generator and sell it as a $30–$250/user/month enterprise product" — is the multi-axis Critical: it surfaces in both Critical Thinking (the wedge is real but the price-cohort match is broken) and ROI (the SAM is a fraction of the claimed TAM at this pricing). Feasibility is exceptional (team is uniquely qualified) and Risk has only Mediums, both addressable. **This is the canonical shape for a Pivot:** the team and capability are intact; the thesis is the broken part.

**Two alternative theses worth exploring**, both leveraging the team's specific advantage (deep no-code-in-spreadsheet inference experience + Google Workspace integration depth):

1. **Stellate for regulated industries** — Pivot the target from "ops teams in general" to "compliance, audit, and risk teams in financial services, healthcare, and regulated industrials." These teams DO maintain process-bearing sheets, they CANNOT migrate them to Airtable/Bubble (data residency, SOC2 boundaries, vendor approval cycles), and they pay enterprise software prices ($150–$500/user/month) for tools that work inside their existing Workspace stack. Distribution: GCP marketplace + audit-firm channel partnerships. The team's specific advantage (Google Sheets API depth + Retool data-sources experience with on-premise connectors) maps directly to the regulated-data-residency requirement.

2. **Stellate as a Sheets-native add-on for a specific vertical** — Pick one of: (a) recruiting agencies running pipelines in Sheets, (b) construction ops teams running material tracking in Sheets, (c) clinical trial coordinators running participant tracking in Sheets. Each vertical has dedicated buyers ($50–$200/user/month is normal in vertical SaaS), and each has known incumbent SaaS that they DON'T like (the Sheets-stayers are stayers for a reason). The team's "60-second appification" wedge is a sales hook into a vertical, not a horizontal product line.

Neither alternative requires throwing away the technical work. Both reposition the product to a price-cohort that matches the wedge.

**Flip-condition (current thesis → Invest):** ≥ 12 signed annual contracts at ≥ $20,000 ARR each (i.e., 8-user teams at full Pro pricing) by 2026-12-31, with the 12 contracts spread across at least 3 industries to show the horizontal positioning works. Without those, the current thesis is not viable; pivoting to one of the alternatives above is the recommended path.
