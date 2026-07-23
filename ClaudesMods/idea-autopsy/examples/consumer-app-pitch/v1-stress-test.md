# Stress test: GigPurse — Budgeting for the 1099 economy (v1)

State: `./.autopsy/consumer-app-pitch/v1-stress-test.md`

> **Note:** this is an illustrative example showing the format and shape of `stress-test-idea` output. Real runtime outputs will differ in wording but share this structure.

## Reviewer A (thinking-skills battery)

### Jobs-to-be-done
- **[High]** The doc names "gig workers" as one segment but Uber drivers, DoorDash drivers, and freelance creatives have meaningfully different jobs-to-be-done — drivers want runway prediction, creatives want tax+invoice tooling.
  *Evidence:* doc treats all four cohorts as one segment with one feature set; no mention of which job each cohort hires the app to do.
- **[Medium]** The displacement story is "vs. spreadsheet or nothing" which is plausible but the doc never explains what would make a Mint-or-Copilot user switch.
  *Evidence:* "80% of waitlist uses no app" leaves 20% who do — those users' switching cost is undiscussed.

### Fermi estimation
- **[Critical]** TAM derivation is top-down and inflated. Bottom-up: 18M gig-majority workers × 5% serviceable (those who'll pay anything for finance tooling) × $8/mo × 12 = $86M SAM, not the implied $1.7B.
  *Evidence:* doc derives "$1.7B TAM" by multiplying segment size × ARPU × 100% adoption — that's not a TAM, that's a fantasy ceiling.
- **[High]** No CAC assumption. At $8/mo and presumed ~15% annual churn, LTV is ~$55. Consumer fintech CAC in this category runs $25–$80; the unit economics work only at the bottom of that range.
  *Evidence:* doc has no CAC line item.

### Pre-mortem
- **[Critical]** Most likely cause of death at 18 months: free-tier conversion is < 3% and the team runs out of runway before getting to repeatable acquisition. The doc has no monetization-validation plan.
  *Evidence:* "5,000 paying users by month 12" is asserted with no path; the waitlist hasn't paid anything yet.
- **[High]** Second-most-likely: Plaid's gig-income detection has gaps (independent contractors paid via Stripe, Square, or direct deposit aren't caught), and "auto-categorization" silently mislabels enough income that workers stop trusting the app.

### Steel-manning
- **[High]** Strongest opposing case: gig workers who actually want budgeting tooling are a much smaller slice than the doc implies, and the cohort that wants it has already solved it (a spreadsheet + a separate savings account is good enough). The remaining cohort doesn't want budgeting tooling at all — they want more income, and an app that doesn't help with that is a nice-to-have they'll churn from in three months.
  *Argument:* the budgeting-app graveyard (Level Money, Penny, Albert pivot) is long; consumer budgeting has a known retention problem; gig workers' marginal dollar goes to acquiring more work, not optimizing what they have.
  *Why it grades High:* the doc doesn't address consumer-fintech retention as a structural risk; the team will need to either find a behavioral hook or accept that LTV is much shorter than they assume.

## Reviewer B (devils-advocate)

| Dimension | PASS / FAIL | Severity if FAIL | Reasoning |
|---|---|---|---|
| Problem reality | PASS | — | Variable-income budgeting is genuinely under-served; doc is right about this. |
| Solution differentiation | PASS | — | Weekly rolling buffer + tax autopilot are real differentiators vs. Mint/YNAB. |
| Distribution path | FAIL | High | One Reddit post is not a distribution strategy. No paid-acquisition plan, no creator-economy partnership, no employer-channel angle. |
| Moat | FAIL | High | Plaid integration is table-stakes; tax autopilot can be copied in a quarter; the only durable moat is brand+habit. |
| Business model | FAIL | Critical | $8/mo at expected churn and CAC produces negative contribution margin at the high-CAC end of the range. Tax-prep referral fees are seasonal and small. |
| Execution risk | PASS | — | Team has shipped consumer fintech before; 12 months for a v1 of this complexity is realistic. |
| Regulatory / legal exposure | PASS | — | Bank-account read-only via Plaid; not custody; tax autopilot is software-only. |
| Hidden assumptions | FAIL | High | Doc assumes (a) gig workers want a budgeting app, (b) free-to-paid conversion works, (c) tax-set-aside is a strong enough hook to pull users into Pro. None tested. |

**Fix suggestions:**
- *Distribution path:* commit to one acquisition channel before raising (e.g., partnership with one gig platform, or content channel with measured CPM).
- *Moat:* identify the data/network effect that compounds with users (e.g., "after 1000 users, our tax-set-aside estimates beat TurboTax for gig income because we have the labeled data").
- *Business model:* validate WTP with 20 paid pilots from the waitlist BEFORE the raise, at $8/mo or whatever price clears. If they won't pay, ARPU thesis is wrong.
- *Hidden assumptions:* run the 20-paid-pilots test; the result IS the assumption test.

## Reviewer C (silent-failure lens)

### Silent failures
- **[High]** Tax autopilot will silently mis-set-aside for users in states with non-standard rules (CA tiered, NY local tax, TX no income tax). First failure mode: user gets a tax bill they didn't expect; second: word-of-mouth damage.
  *Evidence:* doc says "federal+state" set-aside but doesn't say which states are supported at launch or how user is notified when their state isn't.

### What the doc is silent on
- **[Critical]** Doc is silent on support/customer service. Tax-set-aside questions WILL generate panicked support emails in March/April. No mention of support staffing or escalation path.
- **[High]** No mention of off-ramps: how does a user export their data and leave? Important for trust in a financial tool.
- **[Medium]** Plaid costs $0.30–$1.00/connection/month at consumer-fintech volume. At 5,000 users that's $1,500–$5,000/mo in COGS that doesn't appear in the model.

### Optimism gaps
- **[High]** "5,000 paying users by month 12" — no breakdown of monthly user growth, no CAC × paid-acquisition spend assumption, no organic growth model. Reader is asked to assume the funnel converts.
  *Evidence:* the only data point is "400-person waitlist"; the doc never says what conversion rate from waitlist → paying it expects.

### Unnamed load-bearing assumption
- **[Critical]** The unnamed assumption is that **gig workers will pay $8/mo for budgeting at all**. The waitlist signed up for a free app; nothing in the doc demonstrates willingness to pay. If that assumption is false, the entire revenue model fails.
  *Why it's load-bearing:* every downstream number depends on conversion to paid. The team has not done one paid pilot.

---

## Synthesis

### Consensus findings (two or more reviewers flagged)

- **[Critical]** No evidence that target users will pay at the proposed price.
  *Sources:* Reviewer A's pre-mortem (most-likely cause of death) + Reviewer B's "Business model" FAIL + Reviewer C's Unnamed load-bearing assumption.
  *Why this matters:* every downstream number (LTV, growth model, runway) collapses if WTP is wrong. The waitlist is not a paying-user signal.

- **[Critical]** TAM is fantasy ceiling, not addressable market.
  *Sources:* Reviewer A's Fermi + Reviewer B's "Business model" FAIL (partial).
  *Why this matters:* a 20× overstated TAM makes the raise look easy in a way that misleads founders and investors both.

- **[High]** Distribution path is one Reddit post.
  *Sources:* Reviewer B's "Distribution path" FAIL + Reviewer C's Optimism gap (no growth model).
  *Why this matters:* user acquisition is the dominant risk for consumer fintech; the doc has no plan.

- **[High]** Doc silent on operational reality (support, tax-state coverage, Plaid COGS).
  *Sources:* Reviewer C's "What the doc is silent on" (3 findings) + Reviewer B's Hidden assumptions FAIL.
  *Why this matters:* operational burden is what kills consumer apps post-launch; the doc accounts for build cost, not run cost.

### Unique to Reviewer A `(real)`
- **[High]** Segment is too broad — drivers vs. creatives are different jobs.
  *Source:* Jobs-to-be-done.
  *Assessment:* the other reviewers didn't separate cohorts; this is real and addressable in v2 by picking a beachhead. `(real)`

### Unique to Reviewer C `(real)`
- **[High]** Steel-manning grades the consumer-budgeting retention problem as a structural risk.
  *Source:* Steel-manning [High].
  *Assessment:* B's "Moat" FAIL touches the same nerve but from a different angle; this elevates it. `(real)`

### Contradictions
- **[Solution differentiation]** Reviewer A's Jobs-to-be-done flags the displacement story as weak (no plan to convert Mint refugees); Reviewer B's "Solution differentiation" PASSes the same dimension.
  *What this reveals:* the FEATURES are differentiated; the SWITCHING-COST story is not. Both can be true. v2 should sharpen the switching narrative.

### What none caught

All three reviews covered the doc thoroughly; no obvious additions.

---

## Iteration recommendations for v2

1. **Replace the TAM section with a bottom-up SAM tied to one beachhead segment** — pick rideshare drivers (largest cohort, most income variability), estimate addressable in US (~2M serviceable), realistic 5% adoption at year 2, ARPU $8/mo → $9.6M SAM. Stop using $1.7B.
   *Addresses:* Consensus [Critical] (TAM fantasy), Unique to A `(real)` (segment too broad).
   *Impact:* resolves 2 findings, 1 Critical.

2. **Replace "we'll get to 5000 paying users" with "we've validated WTP with N paid pilots at $X price"** — cut the projected user count entirely until validated; run 20 paid pilots from the waitlist before the raise; report what they paid and what they used.
   *Addresses:* Consensus [Critical] (no WTP evidence), Reviewer A pre-mortem [Critical], Optimism gap.
   *Impact:* resolves 3 findings, 2 Critical.

3. **Add a distribution-channel commitment** — name one channel with measured CPM/CPA, e.g., a partnership conversation with one gig platform, or a paid acquisition test with a specific budget and CAC ceiling. Cut "Reddit post" as the implied plan.
   *Addresses:* Consensus [High] (distribution), Reviewer B "Distribution" FAIL.
   *Impact:* resolves 2 findings.

4. **Add an operational-cost section** — Plaid per-connection cost, support staffing, tax-state coverage at launch (5 states max for v1), off-ramp for users. Be explicit about what is NOT supported.
   *Addresses:* Consensus [High] (operational silence), Reviewer C 3 findings.
   *Impact:* resolves 4 findings.

5. **Add a retention/habit hook** — directly address the consumer-budgeting retention problem. Either name the behavioral hook (e.g., "weekly text on Sunday with the buffer view") or acknowledge it as a risk with a mitigation plan.
   *Addresses:* Unique to A `(real)` (steel-manning).
   *Impact:* resolves 1 finding.

---

## Next step

Run `iterate-to-v2` with this critique to produce a section-by-section change plan, or rewrite directly and re-invoke `stress-test-idea` on v2. State at `./.autopsy/consumer-app-pitch/`.
