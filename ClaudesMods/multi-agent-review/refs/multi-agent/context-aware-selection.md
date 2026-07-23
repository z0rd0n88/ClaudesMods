# Context-Aware Default Selection

Shared selection algorithm for `multi-agent-review` (reviewer roster) and
`multi-agent-developer` (Phase 3 dev team). Used **only when no explicit
`--reviewers` / `--agents` roster is supplied**. Upgrades the "Default Roster
Selection" hierarchy in [`agent-catalog-lookup.md`](agent-catalog-lookup.md)
from a fixed baseline→overlay→lens list into a signal-driven, lane-diverse
selection with deterministic agent resolution.

Two components, cleanly divided:
- **This file** decides *which lanes are active* from context, and *how many*.
- [`lane-agent-table.md`](lane-agent-table.md) deterministically decides *which
  agent fills each lane*. The semantic matcher here is the fallback for lanes
  the table doesn't map or whose mapped agent isn't in the pool.

## 1. Selection precedence (highest wins)

1. Explicit `--reviewers` / `--agents` CSV → used verbatim (validated, then spawned).
2. **Context-aware selection** (this file) → the default when the roster flag is omitted.
   a. Active lanes come from §3 below.
   b. Each lane's agent comes from the deterministic table (per-repo → canonical),
      then the semantic matcher for anything unmapped.
3. Static safety-net roster → only if selection cannot run (no signals resolvable):
   - review: `architect-review, critical-thinking, ecc-silent-failure-hunter, ecc-security-reviewer`
   - build: `code-reviewer, ecc-security-reviewer, ecc-tdd-guide, critical-thinking`

## 2. Pool discovery (unchanged from agent-catalog-lookup)

Scan both tiers; match by the internal `name:` field, never filename:
- Project: `<repo>/.claude/agents/*.md`
- Parked: `~/.claude/agents-parked/CATALOG.md` (candidate; surfaced in a footnote,
  activated by the user with `activate <slug>` / `cp`).

Exclude the framework agents `ecc-code-explorer` and `ecc-code-architect` — they are
Phase-0 bootstrap deps, not selectable specialists. No tier penalty (Decision #13):
the best candidate wins regardless of activation status; parked picks get a footnote.

## 3. Cover lanes, not agents

A team is a set of **coverage lanes** with one best-fit agent each — this is what
makes "distinct lanes only" (Phase 3 Step C) structural rather than hoped-for.

**Floor lanes (always on):**
- `L-ADVERSARIAL` — challenge assumptions before committing (`critical-thinking`).
- `L-BASELINE` — stack-agnostic catch-all, owns whatever no specialist claims (`code-reviewer`).

**Signal-activated lanes:**

| Lane | Fires on |
|---|---|
| `L-APPSEC` | auth, user input, secrets, network I/O, deserialization, injection/SSRF |
| `L-CRYPTO` | private keys, signing, custody, wallet, on-chain submit, delegation |
| `L-FINANCE` | money movement, ledger, order/trade, notional, fees, regulatory/compliance |
| `L-WEB3` | programs, PDAs/CPIs, EVM/Solana, tx building, DEX/venue integration |
| `L-NUMERIC` | decimals, financial math, BigDecimal/Decimal, rounding, precision |
| `L-LANG` | the primary language(s) of the diff (Python, TS, Kotlin, SQL, …) |
| `L-ARCH` | new module, cross-cutting refactor, boundary/interface change |
| `L-DATA` | migrations, schema, ORM parity, query plans |
| `L-API` | REST/GraphQL/OpenAPI, WS, versioning, wire format |
| `L-PERF` | hot path, large N, memory, latency, streaming |
| `L-RESILIENCE` | error handling, fallbacks, retries, swallowed exceptions |
| `L-TEST` | new logic without tests, TDD discipline, flaky/e2e |
| `L-EXPLORE` | claims to verify against real code, legacy tracing (`ecc-code-explorer` is framework-excluded — use the mapped explorer specialist, not the bootstrap agent) |
| `L-MOBILE` | iOS/Android, App-Store surface, mobile UX |
| `L-DOCS` | public API docs, reference material |

## 4. Signals

From the target and context, extract: `languages[]`; `domains[]` (finance, crypto,
web3, mobile, api, data); `layers[]` (db, api, ws, ui, infra); `change_type`
(feature / refactor / bugfix / spec); and `risk_flags[]` (moves money, touches
keys/signing, irreversible action, external I/O, data-loss).

Signal sources in priority order — stop when the picture is confident:
1. The resolved target/diff (`pr|dir|file|spec|diff|slices`) — changed paths, extensions, deps.
2. The task / spec / issue text (and any `--prompt-prelude` spec).
3. Repo invariants — `CLAUDE.md` / ADRs / `CONTEXT.md`. **These become forced lanes.**
4. Path & filename cues — `db/migration/`, `openapi.yaml`, `*.sol`, `signer`, `wallet`, `*.tsx`.

## 5. Scoring & assembly (mirrors Phase 3 Step B, generalized)

```
score(lane) = (# distinct signals hitting the lane)
              × 2   if any hitting signal is also a risk_flag
FLOORS  = {L-ADVERSARIAL, L-BASELINE}         # score → ∞, always kept
FORCED  = lanes made mandatory by a risk_flag or a repo invariant:
            keys/signing   → L-CRYPTO
            money/decimals → L-NUMERIC (+ L-FINANCE)
            on-chain       → L-WEB3
            db migration   → L-DATA
            + any lane the repo's CLAUDE.md/ADR demands
CAP     = review: soft 6 per slice     build: hard 4  (== --max-agents, [1,4])
```

Assembly:
1. Reserve FLOORS. Add all FORCED (priority: keys > money > data > api > perf).
2. Rank remaining active lanes by score; add highest-first until CAP.
3. Resolve each chosen lane to an agent via [`lane-agent-table.md`](lane-agent-table.md):
   per-repo table → canonical table → semantic matcher (best role-text match in the
   pool for the lane + concrete signals). Cross-cutting baselines from Phase 3 still
   apply: a security lane scores +6 (not +4) when the task touches auth/input/secrets/APIs;
   `L-TEST` is baseline-present for build tasks (TDD is the default discipline).
4. One agent per lane; specialists beat generalists; ECC-flavored and project-scoped
   win ties (Phase 3 tie-breaker).

## 6. Safety repair (apply before emitting)

- ≥1 security lane (`L-APPSEC`/`L-CRYPTO`) present whenever any `risk_flag` fired.
- ≥1 `L-LANG`/domain specialist present when there is a clear primary language/domain.
- If CAP < FLOORS + FORCED, drop the lowest-risk **optional** lane only — never a
  floor or forced lane — and record what was dropped.
- **Degrade loudly.** If a chosen lane has no matching pool agent, fall back to
  `L-BASELINE` and say so in the rationale. If a FORCED lane is uncoverable, state
  that gap explicitly rather than shipping the team without it.

## 7. Output contract

Emit, in priority order (floors + forced first):
1. The roster as a comma-separated agent-name list (validated against the pool).
2. A table: `agent | lane | one-line reason`.
3. A parked-alternatives footnote when a better candidate sits in `agents-parked`
   (per Decision #13), so the user can `activate <slug>` and re-run.

Deterministic for the same context. Log the roster + reasons so a human can see why
this team was chosen and override with `--reviewers` / `--agents` next run.
