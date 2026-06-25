# v2 change plan: GigPurse (from v1)

State: `./.autopsy/consumer-app-pitch/v1-change-plan.md`

> **Note:** illustrative example of `iterate-to-v2` output. The `Removes problematic claim by:` field is the enforcement mechanism for the change-vs-hedge rule.

## Acceptance summary

- Critique format detected: `stress-test-idea`
- Accepted: 5 findings (4 Consensus, 1 Unique-Reviewer-A `(real)`)
- Deferred (bucket-defaults): 1 finding (Reviewer A medium "displacement story" — addressable in v3, not blocking v2)
- Rejected by user: 0

## Changes by section

### Market

- **Type:** Replace
- **Change:** Delete the 70M / 18M / $1.7B TAM derivation. Replace with a bottom-up SAM for the rideshare-driver beachhead: ~2M US drivers earning gig-majority income × 5% adoption ceiling × $8/mo × 12 = $9.6M annual SAM. State the load-bearing assumption: "5% adoption assumes Mint-comparable conversion in a smaller, more pain-aligned cohort."
- **Removes problematic claim by:** deleting paragraph 2 of the Market section (the "70M × 25% × $8 × 1% = $1.7B" derivation) and the implied TAM line; replacing with one paragraph of bottom-up math.
- **Addresses:** Consensus [Critical] (TAM fantasy), Unique to A `(real)` (segment too broad).
- **Proposed structure:** "Beachhead: US rideshare drivers earning ≥50% gig income. Population: ~2M. SAM at 5% adoption: $9.6M annual. We expand to delivery and creative gig workers after rideshare validates."
- **Needs your input:** confirm rideshare is the right beachhead (alternative: delivery is faster to acquire via DashPass partnerships).

### Traction

- **Type:** Cut + Replace
- **Change:** Cut the "5,000 paying users by month 12, $40k MRR" projection entirely. Replace with whatever paid-pilot data you can gather before the raise: number of paid pilots from the waitlist, price paid, weeks retained, what they actually used.
- **Removes problematic claim by:** deleting the "5,000 paying users / $40k MRR" line from the Ask section; replacing with a "Validation status: N paid pilots at $X price, retained Y weeks" line.
- **Addresses:** Consensus [Critical] (no WTP evidence), Reviewer A pre-mortem [Critical], Reviewer C unnamed assumption [Critical].
- **Needs your input:** RUN THE PAID-PILOT TEST. Pick 20 waitlist users, charge them $8/mo for 60 days, report the data. Without this you cannot defensibly make any revenue claim.

### (NEW SECTION) Distribution

- **Type:** Add
- **Change:** Add a section naming one acquisition channel with a measured CAC ceiling. Three credible options:
  (a) Partnership pilot with one gig platform (DoorDash / Instacart partner-perks bundle).
  (b) Paid content channel: TikTok creator partnerships, target CAC ≤$15 (test budget $5k).
  (c) Tax-prep partnership: bundle with FreeTaxUSA, share referral economics.
- **Removes problematic claim by:** N/A — this is net-new content. The IMPLIED claim being removed is "we'll figure out distribution later"; the new section makes the strategy explicit.
- **Addresses:** Consensus [High] (one Reddit post is not a plan).
- **Needs your input:** pick ONE channel and commit. Naming all three reads as undecided.

### (NEW SECTION) Operational scope

- **Type:** Add
- **Change:** Add a section listing operational scope at launch:
  - Tax states supported at launch (5 max: CA, TX, NY, FL, IL).
  - Plaid COGS: $0.50/connection/month × 5000 users = $2,500/mo.
  - Support model: founder-staffed for first 12 months; expected ticket volume in March/April spikes 4×.
  - User off-ramp: 1-click CSV export of all data; account closure deletes within 30 days.
- **Removes problematic claim by:** N/A — net-new. The IMPLIED claim being removed is "operational reality is solved"; the new section is the honest scope.
- **Addresses:** Consensus [High] (operational silence), Reviewer C 3 findings.

### Solution

- **Type:** Refine
- **Change:** Add one paragraph naming the retention/habit hook. The current product description lists features; v2 should name the weekly behavioral loop (e.g., "Sunday evening text: 'You have $X buffer, M weeks of expenses covered.'").
- **Removes problematic claim by:** restructuring the Solution section so the habit hook is feature #1 — not adding a caveat or footnote about retention.
- **Addresses:** Unique to A `(real)` (steel-manning consumer-budgeting retention).

## Sections to cut from v2

- **(none — all changes are in-place edits or additions)**

## New sections needed in v2

- **Distribution** — see above.
- **Operational scope** — see above.

## Deferred findings (bucket-defaults)

- **[Medium] Displacement story (Mint refugees switching cost)** — deferred because: Medium severity, no axis cluster. Re-evaluate after v2 paid-pilot data is in; the displacement question becomes urgent if conversion is bottlenecked on switching from existing tools.

## Suggested v2 outline

1. *[unchanged]* The problem
2. *[edit]* The solution (refine: lead with the habit hook)
3. *[edit]* Market (replace: bottom-up SAM for rideshare beachhead)
4. *[unchanged]* Business model
5. *[unchanged]* Team
6. *[edit]* Traction (cut: drop the 5000-users projection; replace with paid-pilot data)
7. *[new]* **Distribution**
8. *[new]* **Operational scope**
9. *[edit]* Ask (revise: 12-month milestones tied to paid-pilot data, not unvalidated MRR)
10. *[unchanged]* Why now

## Next step

Draft v2 as `./.autopsy/consumer-app-pitch/v2.md`, then run `stress-test-idea` on v2 to verify the changes resolve the findings without introducing new weaknesses, OR (if you're approaching the raise) skip to `evaluate-proposal-harsh` for a verdict.
