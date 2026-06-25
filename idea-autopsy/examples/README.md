# Examples

Three worked examples showing the plugin's three main verdict paths. Each example directory contains the input doc, the artifacts the plugin produces at each stage, and a `WALKTHROUGH.md` that narrates what happened and why.

> All output files in these examples are **illustrative** — they show the format and shape the plugin produces, not literal runtime traces. Real outputs will differ in wording but share the structure.

| Example | Path | Verdict | What it showcases |
|---|---|---|---|
| Consumer app pitch | [`consumer-app-pitch/`](./consumer-app-pitch/) | **Proceed with caution** | Full three-skill loop: stress-test → iterate → re-evaluate. Demonstrates change-vs-hedge enforcement, bucket-aware acceptance, measurable flip-condition. |
| B2B SaaS pivot | [`b2b-saas-pivot/`](./b2b-saas-pivot/) | **Pivot** | Strong team, wrong thesis. Showcases the Pivot verdict added in v1.1 — multi-axis Critical on the thesis with Feasibility passing cleanly. Verdict names two concrete alternative theses. |
| Unsupported TAM | [`unsupported-tam-skip/`](./unsupported-tam-skip/) | **Skip** (no plausible flip) | The strictest verdict. 4/4-axis Critical, structurally-broken proposal. Demonstrates the "no plausible flip-condition exists" output for honest no-go calls. |

## Suggested reading order

1. **`consumer-app-pitch/`** first — it's the longest and walks the full loop end-to-end.
2. **`b2b-saas-pivot/`** next — short (verdict-only) and showcases the headline v1.1 feature.
3. **`unsupported-tam-skip/`** last — short and shows the strict edge.

Each walkthrough is self-contained; you can read them in any order.

## Adapting an example to your own doc

The simplest way to use an example as a template:

1. Copy the input doc (`v1.md`) shape — section structure, depth of claims, where the numbers go.
2. Rewrite the content to match your idea.
3. Run `/autopsy ./your-doc.md` to get real critique on your version.
4. The artifacts under `./.autopsy/<your-slug>/` will mirror the structure of these example directories.
