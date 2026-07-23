# Lane → Agent Table (deterministic resolver)

Companion to [`context-aware-selection.md`](context-aware-selection.md). The
selection algorithm decides **which lanes are active**; this table
deterministically decides **which agent fills each lane** — no model judgment,
stable across runs. The semantic matcher is used only for a lane this table does
not map, or when a mapped agent is absent from the pool.

## Resolution order per lane

1. **Per-repo override table** (if present) — `<repo>/.claude/agent-lanes.md`, or a
   `## LANE MAP` block injected via `--prompt-prelude`, or a `lane_map:` key in the
   project's `config.yml`. Highest precedence; lets each repo bind lanes to its own
   agent names.
2. **Canonical default table** (below) — the ecosystem-standard names.
3. **Semantic matcher** — best role-text match in the pool (from
   `context-aware-selection.md` §5, Assembly step 3). Only reached when neither table
   resolves to a pool agent.

For any lane, walk the ordered candidate list and pick the **first name that exists
in the discovered pool** (project ∪ activated-parked). If none exist, degrade to the
lane's fallback lane (usually `L-BASELINE`) and flag the gap loudly.

## Canonical default table

Names are the ClaudesMods-native canonical `name:` values. `→` marks the ordered
preference chain; earlier wins if present in the pool.

| Lane | Candidate agents (ordered) | Trigger keywords |
|---|---|---|
| `L-ADVERSARIAL` | `critical-thinking` | (floor — always) |
| `L-BASELINE` | `code-reviewer` → `ecc-code-reviewer` | (floor — always) |
| `L-APPSEC` | `ecc-security-reviewer` → `security-reviewer` → `penetration-tester` | auth, input, secrets, ssrf, injection, token |
| `L-CRYPTO` | `crypto-security-reviewer` → `smart-contract-auditor` → `ecc-security-reviewer` | key, sign, wallet, custody, delegation, kms |
| `L-FINANCE` | `fintech-engineer` → `payment-integration` → `compliance-auditor` → `quant-analyst` | payment, ledger, order, notional, fee, settlement |
| `L-WEB3` | `web3-integration-specialist` → `smart-contract-specialist` → `blockchain-developer` | onchain, pda, cpi, evm, solana, tx, dex, venue |
| `L-NUMERIC` | `numeric-precision-reviewer` | decimal, bigdecimal, rounding, precision, float |
| `L-LANG:python` | `python-reviewer` → `python-pro` → `code-reviewer` | `.py`, python, pip, pytest |
| `L-LANG:typescript` | `typescript-reviewer` → `typescript-pro` → `react-specialist` | `.ts`, `.tsx`, node, npm |
| `L-LANG:kotlin` | `kotlin-specialist` → `ecc-kotlin-reviewer` | `.kt`, ktor, gradle, coroutine |
| `L-LANG:sql` | `sql-pro` → `postgres-pro` | `.sql`, query, index, schema |
| `L-ARCH` | `architect-review` → `ecc-code-architect` | module, boundary, refactor, layering |
| `L-DATA` | `database-optimizer` → `postgres-pro` → `ecc-database-reviewer` | migration, schema, orm, query-plan |
| `L-API` | `api-architect` → `api-designer` → `websocket-engineer` | rest, graphql, openapi, endpoint, ws |
| `L-PERF` | `performance-optimizer` → `ecc-performance-optimizer` → `chaos-engineer` | latency, throughput, memory, hotpath |
| `L-RESILIENCE` | `ecc-silent-failure-hunter` → `silent-failure-hunter` → `error-detective` | fallback, retry, swallow, error-handling |
| `L-TEST` | `ecc-tdd-guide` → `test-automator` → `qa-expert` | tdd, coverage, e2e, flaky |
| `L-EXPLORE` | `ecc-code-explorer`* → `code-tour` | trace, legacy, spec-vs-reality (*review only; excluded from build teams) |
| `L-MOBILE` | `mobile-app-developer` → `react-specialist` | ios, android, app-store, mobile |
| `L-DOCS` | `api-documenter` → `technical-writer` | docs, reference, changelog |

`L-LANG:<language>` is selected by the diff's primary language; if the language has
no row, `L-LANG` degrades to `L-BASELINE` and the rationale notes "no <lang>
specialist in pool".

## Per-repo override format

Drop this at `<repo>/.claude/agent-lanes.md` (auto-read during pool discovery) or
inject it via `--prompt-prelude`. Only list the lanes you want to rebind — unlisted
lanes fall through to the canonical table.

```markdown
## LANE MAP
L-ARCH: architect-reviewer          # this repo renamed architect-review
L-LANG:kotlin: kotlin-specialist, ecc-kotlin-reviewer
L-NUMERIC: numeric-precision-reviewer
L-DATA: flyway-exposed-parity-reviewer, ecc-database-reviewer
L-CRYPTO: crypto-security-reviewer
# forced lanes this repo mandates regardless of signals:
FORCE: L-NUMERIC, L-CRYPTO          # e.g. Prime Directive §1 + custody
```

Format: one `L-*: name[, fallback...]` per line; an optional `FORCE:` line adds
repo-mandated forced lanes. Names are validated against the pool at parse time
(unknown → hard-fail, same as `--reviewers`).

## Worked instantiation — a Kotlin/Solana custody repo (e.g. VistaMobileBE)

Its pool renamed `architect-review`→`architect-reviewer` and carries
`numeric-precision-reviewer`, `crypto-security-reviewer`,
`flyway-exposed-parity-reviewer`, `kotlin-specialist`. Its `## LANE MAP` (above)
plus `FORCE: L-NUMERIC, L-CRYPTO` means a task touching a signing executor with
BigDecimal amounts deterministically yields, for a build team (cap 4):

| Agent | Lane | Source |
|---|---|---|
| `crypto-security-reviewer` | `L-CRYPTO` | forced (repo) + keys signal → table |
| `numeric-precision-reviewer` | `L-NUMERIC` | forced (repo) + decimals → table |
| `critical-thinking` | `L-ADVERSARIAL` | floor |
| `kotlin-specialist` | `L-LANG:kotlin` | per-repo override |

`L-BASELINE` (`code-reviewer`) is the first thing dropped at cap 4 because both
forced security/numeric lanes plus the adversarial floor already consume 3 slots and
the language specialist outscores a generic catch-all here — recorded in the drop
note per §6.

## Worked instantiation — the user's Python crypto example (no per-repo table)

`languages=[python]`, `risk_flags=[keys, money]`, review cap 6. Canonical table only:

| Agent | Lane | Source |
|---|---|---|
| `crypto-security-reviewer` | `L-CRYPTO` | forced (keys) → canonical |
| `numeric-precision-reviewer` | `L-NUMERIC` | forced (money) → canonical |
| `web3-integration-specialist` | `L-WEB3` | on-chain signal → canonical |
| `critical-thinking` | `L-ADVERSARIAL` | floor |
| `code-reviewer` | `L-BASELINE` | floor |
| `python-reviewer` *(or `python-pro`)* | `L-LANG:python` | language → canonical; if absent, note gap |

The last row is the deterministic answer to "is language expertise covered?" — the
table names the exact agent, and if neither `python-reviewer` nor `python-pro` is in
the pool it degrades loudly to the baseline instead of silently pretending.
