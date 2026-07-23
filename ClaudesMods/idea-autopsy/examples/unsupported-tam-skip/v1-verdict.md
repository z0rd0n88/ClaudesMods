# Proposal evaluation: YieldVault — DeFi yield for your retirement account (v1)

State: `./.autopsy/unsupported-tam-skip/v1-verdict.md`

> **Note:** illustrative example showing a **Skip** verdict with no plausible flip-condition — the strictest output the plugin produces. Used when the proposal is structurally not viable.

## Executive summary

- **[Critical]** [4/4 axes] *Risk* — The product as described creates an unregistered investment adviser + unregistered custodian + ERISA-violating arrangement; the legal surface is the dominant fact and would require ~$5M+ and 2+ years before a single user could be onboarded compliantly.
- **[Critical]** [3/4 axes] *Critical Thinking* — The wedge ("DeFi yield routed to retirement accounts via Chrome extension") is not a product that can legally exist; it conflates self-directed custody (already legal but limited), broker-dealer custody (regulated), and DeFi yield routing (not approved by any retirement custodian).
- **[Critical]** [2/4 axes] *Feasibility* — Team has zero financial-services compliance experience, zero smart-contract production experience (founder is self-taught since early 2025), and no technical co-founder. Building a SOC2-audited custody bridge is not 18 months of work for this team — it's not a project this team can complete.
- **[Critical]** [3/4 axes] *ROI* — The TAM ($13T retirement assets) is unrelated to the SAM (zero — there is no legal product to sell); the 0.1% × 2% × 8% math multiplies values together that have no shared denominator.

## Critical thinking

- **[Critical]** The product description assumes a custodian relationship that doesn't exist. Fidelity / Schwab / Vanguard do NOT permit third-party Chrome extensions to "route" a portion of an IRA balance — there is no API for this, and the few self-directed IRA custodians (Alto, Rocket Dollar) that do permit alternative assets require a structured legal arrangement, not a browser extension. The doc presents a non-existent product as if it's a configuration question.
  *Evidence:* "Our smart contract custodies the DeFi-eligible portion" — this requires the smart contract address to be the custodian on the IRA, which Fidelity et al. do not allow; only specialized self-directed IRA custodians do, and those carry $300+/year in setup fees per account.

- **[Critical]** "0.1% adoption × 2% allocation × 8% yield differential = massive value capture" is a four-decimal-place fantasy. 0.1% of $13T = $13B addressable; 2% allocation = $260M; 8% yield differential = $20.8M annual yield generated; 1% performance fee = $208K annual revenue at the modeled penetration. That's a side project, not a $1.5M-seed business. The "9-figure revenue line" is unsupported by the doc's own math.

- **[High]** "Stablecoin regulation creates compliance scaffolding" misreads the regulatory trajectory. GENIUS Act + MiCA regulate stablecoin issuers, not consumer routing of stablecoins through DeFi protocols inside retirement accounts. The proposed product is in the gap between two regulatory regimes (securities + ERISA), not enabled by either.

## Feasibility

- **[Critical]** Team has no shipping experience in any relevant domain. Founder is a growth marketer with 6 months of self-taught Solidity. There is no smart-contract engineer, no compliance counsel, no broker-dealer relationship. The advisor (unpaid CFA friend) is not a substitute for any of these. Building a SOC2-audited custody bridge with regulatory clearance is not achievable in 18 months by this team at any budget.
  *Evidence:* "Looking for a technical co-founder" + "self-taught Solidity since early 2025" + no compliance hire planned.

- **[High]** Smart contract bugs in production custody systems have historically cost $50M–$600M per incident (Poly Network, Wormhole, Ronin, Curve). For retirement-account custody, a single exploit is end-of-company. The doc has no audit budget, no bug bounty, no formal verification plan. "Smart-contract engineer" alone does not solve this.

## Risk and red flags

- **[Critical]** Regulatory exposure: this product as described requires SEC registration as an investment adviser (1940 Act), likely broker-dealer registration with FINRA, ERISA fiduciary status, and probably money transmitter licenses in 49 states. None of this is mentioned in the doc. Each is multi-year + multi-million-dollar. "File Form ADV if required" suggests the founder doesn't know what registration is required.
  *Evidence:* doc says "file Form ADV if required" with no qualified counsel cited.

- **[Critical]** Fiduciary liability under ERISA: routing 401(k) funds (employer-sponsored plans covered by ERISA) into DeFi yield without participant-by-participant disclosure and a co-fiduciary structure exposes the founder to personal liability for any loss. This is not patchable; ERISA fiduciary duty is structural, not contractual.

- **[High]** Smart-contract custody on retirement money has reputational risk that extends past the founder. First exploit creates regulatory action that closes the entire experimental category and damages every adjacent founder.

- **[High]** Distribution risk: Fidelity/Schwab/Vanguard will block this technically (extension detection) and legally (terms of service violations on their portals). The Chrome-extension surface is hostile to the incumbents' explicit terms.

## ROI signal

- **[Critical]** The TAM is unrelated to the SAM. $13T in retirement assets is a market sizing for *retirement services*, not for the product proposed. The SAM for "browser-extension-mediated DeFi yield routing for IRA-with-Fidelity users" is zero, because the product cannot be legally sold to Fidelity-custodied accounts.
  *Evidence:* the TAM derivation assumes existing retirement accounts can be a substrate for this product; they cannot.

- **[High]** Even on self-directed IRA custodians (the only cohort where this is *possible*), the addressable population is ~500K accounts, the per-account setup fee ($300+/year) is a steep barrier, and the cohort that wants DeFi yield + self-directed IRA + Chrome extension is well below 5% of that base. Realistic SAM is < $1M ARR at maturity, charging 1% of yield.

- **[High]** Insurance product layered on top is mentioned as long-term revenue but requires being a licensed insurance producer in each state — an entire second regulated business added to the stack with no plan or expertise.

---

## Issue multiplicity table

| Issue | Severity | Axes (N) | Primary |
|---|---|---|---|
| Product as described creates unregistered IA + ERISA exposure | Critical | Risk + Critical Thinking + Feasibility + ROI (4) | Risk |
| Wedge is a non-existent product (custodian relationship doesn't exist) | Critical | Critical Thinking + Risk + ROI (3) | Critical Thinking |
| Team has no relevant shipping experience | Critical | Feasibility + Risk (2) | Feasibility |
| TAM is unrelated to SAM (SAM = ~zero) | Critical | ROI + Critical Thinking + Risk (3) | ROI |
| Smart contract bug = company-ending event | High | Feasibility + Risk (2) | Feasibility |
| Stablecoin reg misread | High | Critical Thinking (1) | Critical Thinking |
| Insurance product = entire second regulated business | High | ROI (1) | ROI |

---

## Verdict: Skip

Four distinct Critical issues, three of them multi-axis at 3/4 or 4/4 coverage. The proposal does not survive scrutiny on a single axis. The dominant fact is regulatory: the product as described is not a thing that can be built and sold to the claimed market without 2+ years and $5M+ of compliance work that the team has neither the capital nor the expertise to undertake. The TAM math is fantasy; the team has no shipping experience in any relevant domain; the technical surface (smart-contract custody of retirement money) is the highest-stakes category in fintech and the team has 6 months of self-taught Solidity experience to bring to it.

**Flip-condition:** *no plausible flip-condition exists.* The verdict is structural, not parametric. Each of the four Criticals would require a different team, a different product, and a different go-to-market — at which point this would be a different company, not a flipped version of this one. The honest recommendation: the founder should redeploy the growth-marketing skillset into a problem space where their experience compounds (a consumer or B2B SaaS adjacent to crypto, without the custody/ERISA load), or join an existing licensed firm in this space (Alto, Rocket Dollar, iTrust) to learn the regulatory surface before founding in it.
