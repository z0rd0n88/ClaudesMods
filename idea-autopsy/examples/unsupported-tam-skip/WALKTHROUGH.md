# Walkthrough: unsupported-tam-skip (Skip with no plausible flip)

This example shows the **strictest verdict the plugin produces** — Skip with an explicit "no plausible flip-condition exists." It demonstrates two important behaviors:

- The multiplicity-aware verdict rule firing at maximum severity (4/4-axis Critical).
- The honesty requirement: when no flip-condition is plausible, the verdict says so explicitly rather than inventing a vague "validate demand and tighten the model" non-condition.

> All outputs in this directory are **illustrative**, showing the format and shape the plugin produces.

## The cycle

| Stage | File | Skill | Outcome |
|---|---|---|---|
| 1 | `v1.md` | (input) | DeFi-yield-for-retirement-accounts via Chrome extension. Fantasy TAM ($13T retirement assets as the addressable market), zero regulatory path, founder is a growth marketer with 6 months of self-taught Solidity, no compliance counsel, no technical co-founder. |
| 2 | `v1-verdict.md` | `evaluate-proposal-harsh` | **Verdict: Skip.** Four distinct Criticals; three of them multi-axis at 3/4 or 4/4 coverage. The verdict explicitly states no plausible flip-condition exists and recommends the founder redeploy their skillset elsewhere. |

The user invoked `evaluate-proposal-harsh` directly with a verdict signal ("should I quit my job to build this?"). No stress-test or iterate step — the doc is structurally not viable, and any iteration would produce a fundamentally different company, not a flipped version of this one.

## What this example showcases

### The 4/4-axis Critical at the top of the multiplicity table

The verdict's multiplicity table opens with:

| Issue | Severity | Axes (N) | Primary |
|---|---|---|---|
| Product as described creates unregistered IA + ERISA exposure | Critical | Risk + Critical Thinking + Feasibility + ROI (4) | Risk |

When the same underlying issue surfaces across ALL FOUR axes, that's the strongest possible cross-lens consensus — every reviewer found a different angle on the same fact. The decision rule says: any Critical surfaced by ≥2 axes triggers Skip; surfacing on 4/4 makes Skip mechanical.

The other Criticals (3/4-axis on the wedge being non-existent, 3/4-axis on TAM-vs-SAM, 2/4-axis on team capability) compound: this isn't one fixable problem, it's four distinct structurally-broken parts.

### The "no plausible flip-condition exists" output

The verdict ends with:

> **Flip-condition:** *no plausible flip-condition exists.* The verdict is structural, not parametric. Each of the four Criticals would require a different team, a different product, and a different go-to-market — at which point this would be a different company, not a flipped version of this one.

This is what the plugin produces when the honest answer is "nothing this founder can do flips this." The previous version of the skill (v1.0.0) might have invented a soft flip ("if the team can secure regulatory clearance and a custody partnership"); v1.1 explicitly forbids that. **A flip-condition that requires becoming a different company is not a flip-condition.**

The verdict ends with constructive guidance — the founder's growth-marketing skillset is real, just deployed against the wrong problem. The plugin says so without softening the Skip.

### Why this isn't a Pivot

Compare against `examples/b2b-saas-pivot/`: that example's team had a deep technical-fit advantage they could redeploy against a different thesis. The verdict named two concrete alternative theses leveraging the team's actual capabilities.

Here, the founder's only relevant capability (growth marketing) is not redeployable AGAINST THE SAME PROBLEM SPACE in a different shape — DeFi-in-retirement is structurally hostile regardless of product shape. The verdict redirects the founder OUT of the problem space, not to a different angle inside it. That's the structural distinction:

- **Pivot:** team's advantage compounds in an adjacent problem inside the same space.
- **Skip:** team's advantage doesn't apply to the space; the founder should leave the space.

The decision rule encodes this by requiring Pivot to have Feasibility passing cleanly. Here Feasibility is a 2/4-axis Critical — the team is not the asset; there is no asset to redeploy inside this space.

### Honest sub-finding severities

Notice that the verdict still produces a multiplicity table with **High** findings underneath the Criticals (smart-contract bug risk, stablecoin reg misread, insurance-as-second-business). These would normally be the actionable feedback in a Proceed verdict. Here they're documented but not used to compute the verdict — they cluster around the same broken thesis and don't constitute an independent path.

If the founder later asks "what would I have to do to make this work?", the answer is in the Highs: each one names a concrete additional thing that would need to be solved. They cumulate into the "different company" conclusion.

## How to read it

Read in this order:

1. **`v1.md`** — note that the pitch reads competent on the surface; the citations are real (GENIUS Act, MiCA, BTC/ETH ETFs). The problem is not the prose; it's the math and the regulatory premise.
2. **`v1-verdict.md`** Executive summary — note that EVERY bullet is Critical and tagged with multi-axis multiplicity.
3. Multiplicity table — note three of four Criticals are ≥3-axis. This is what triggers Skip with no override.
4. The verdict paragraph — note the explicit "no plausible flip-condition exists" and the structural-vs-parametric distinction.

## When this pattern applies

The Skip-with-no-flip pattern fires when:

- The proposed product is in a regulated space the founder hasn't entered.
- TAM math is decoupled from any realistic SAM (the fantasy-multiplication pattern).
- Team capability gap is structural, not bridgeable with one hire.
- The regulatory / market / capability problems compound — each one alone might be addressable, but together they require a different company.

It's the verdict the plugin is most reluctant to produce (the decision rule errs toward Proceed/Pivot when there's any path forward), so when it does fire, the founder should treat it as load-bearing signal.

For other verdict shapes, see:
- `examples/consumer-app-pitch/` — full loop ending in **Proceed with caution** with a measurable flip-condition.
- `examples/b2b-saas-pivot/` — **Pivot** verdict with two alternative theses.
