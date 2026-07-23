export const meta = {
  name: 'deep-research',
  description: 'Deep research harness — fan-out web searches, fetch sources, adversarially verify claims, synthesize a cited report. Cost-guardrailed: cheap models on the high-volume stages, a token-budget ceiling, and depth presets.',
  whenToUse: 'When the user wants a deep, multi-source, fact-checked research report on any topic. BEFORE invoking, check if the question is specific enough to research directly — if underspecified (e.g., "what car to buy" without budget/use-case/region), ask 2-3 clarifying questions to narrow scope. Then pass the refined question as args (a string), or an object { question, depth, maxFetch, maxClaims, votes, models } to override the cost guardrails.',
  phases: [{"title":"Scope","detail":"Decompose question (from args) into search angles"},{"title":"Search","detail":"parallel WebSearch agents, one per angle (cheap model)"},{"title":"Fetch","detail":"URL-dedup, fetch capped sources, extract falsifiable claims (cheap model)"},{"title":"Verify","detail":"multi-vote adversarial verification per claim, budget-gated (cheap model)"},{"title":"Synthesize","detail":"Merge semantic dupes, rank by confidence, cite sources (strong model)"}],
}

// deep-research (guardrailed): Scope → pipeline(Search → URL-dedup → Fetch+Extract) → multi-vote Verify → Synthesize
// Ported from the original bughunter-derived harness. Guardrails added:
//   G1  per-agent model pins   — high-volume mechanical stages run on a CHEAP model; only Scope/Synthesize get a strong one.
//   G2  token-budget ceiling   — reads the `budget` global; trims caps up front and hard-gates the verify fan-out.
//   G3  depth presets + caps   — lower defaults, all overridable via an args object.
//   +   upfront cost estimate  — logs the worst-case agent count before spending anything (no silent truncation).
// Invoke: Workflow({ scriptPath: '<this file>', args: '<question>' })  — or args: { question, depth, ... }.

// ─── args: accept a bare question string OR an options object ───
const A = (args && typeof args === "object") ? args : {}
const QUESTION = ((typeof args === "string" ? args : A.question) || "").trim()

// ─── G3: depth presets (default "standard"; was fetch=15/claims=25/votes=3 with no floor) ───
const DEPTH = A.depth || "standard"
const PRESETS = {
  quick:    { fetch: 5,  claims: 6,  votes: 2 },
  standard: { fetch: 8,  claims: 12, votes: 3 },
  deep:     { fetch: 15, claims: 25, votes: 3 },
}
const P = PRESETS[DEPTH] || PRESETS.standard

// ─── G1: model pins — the single biggest cost lever ───
// Search/Fetch/Verify are mechanical, schema-constrained, and run in bulk (dozens of calls):
// sonnet handles them well without the frontier price. Only the final Synthesis gets opus.
const MODELS = Object.assign({
  scope:      "sonnet",
  search:     "sonnet",
  fetch:      "sonnet",
  verify:     "sonnet",
  synthesize: "opus",
}, A.models || {})

// ─── resolve caps (args override preset) ───
let MAX_FETCH         = A.maxFetch  ?? P.fetch
let MAX_VERIFY_CLAIMS = A.maxClaims ?? P.claims
let VOTES_PER_CLAIM   = A.votes     ?? P.votes
const REFUTATIONS_REQUIRED = 2  // ≥2 refuting votes kill a claim (also the min valid votes to adjudicate "survives")

// ─── G2: token-budget ceiling — trim caps up front if the turn's budget is tight ───
// budget.total is null when no "+N"-style target was set; then remaining() is Infinity and nothing is trimmed.
const TOKENS_PER_AGENT = 4000  // rough per-subagent output estimate, for a conservative pre-flight
function budgetTrim() {
  if (!budget.total) return
  const rem = budget.remaining()
  // Worst-case cost of the plan we're about to run, in estimated output tokens.
  const plannedAgents = 1 + 6 /*scope+search angles*/ + MAX_FETCH + MAX_VERIFY_CLAIMS * VOTES_PER_CLAIM + 1
  if (rem >= plannedAgents * TOKENS_PER_AGENT) return
  // Not enough headroom — scale the plan down to fit, keeping a hard floor.
  const affordable = Math.max(0, Math.floor(rem / TOKENS_PER_AGENT) - 8 /*scope+search+synth reserve*/)
  MAX_VERIFY_CLAIMS = Math.max(3, Math.min(MAX_VERIFY_CLAIMS, Math.floor(affordable / VOTES_PER_CLAIM)))
  MAX_FETCH = Math.max(3, Math.min(MAX_FETCH, affordable))
  if (rem < 60000) VOTES_PER_CLAIM = 2
  log("budget tight (" + Math.round(rem / 1000) + "k left) → trimmed to fetch≤" + MAX_FETCH + ", claims≤" + MAX_VERIFY_CLAIMS + ", votes=" + VOTES_PER_CLAIM)
}
budgetTrim()

// ─── Schemas ───
const SCOPE_SCHEMA = {
  type: "object", required: ["question", "angles", "summary"],
  properties: {
    question: { type: "string" },
    summary: { type: "string" },
    angles: { type: "array", minItems: 3, maxItems: 6, items: {
      type: "object", required: ["label", "query"],
      properties: {
        label: { type: "string" },
        query: { type: "string" },
        rationale: { type: "string" },
      },
    }},
  },
}
const SEARCH_SCHEMA = {
  type: "object", required: ["results"],
  properties: {
    results: { type: "array", maxItems: 6, items: {
      type: "object", required: ["url", "title", "relevance"],
      properties: {
        url: { type: "string" },
        title: { type: "string" },
        snippet: { type: "string" },
        relevance: { enum: ["high", "medium", "low"] },
      },
    }},
  },
}
const EXTRACT_SCHEMA = {
  type: "object", required: ["claims", "sourceQuality"],
  properties: {
    sourceQuality: { enum: ["primary", "secondary", "blog", "forum", "unreliable"] },
    publishDate: { type: "string" },
    claims: { type: "array", maxItems: 5, items: {
      type: "object", required: ["claim", "quote", "importance"],
      properties: {
        claim: { type: "string" },
        quote: { type: "string" },
        importance: { enum: ["central", "supporting", "tangential"] },
      },
    }},
  },
}
const VERDICT_SCHEMA = {
  type: "object", required: ["refuted", "evidence", "confidence"],
  properties: {
    refuted: { type: "boolean" },
    evidence: { type: "string" },
    confidence: { enum: ["high", "medium", "low"] },
    counterSource: { type: "string" },
  },
}
const REPORT_SCHEMA = {
  type: "object", required: ["summary", "findings", "caveats"],
  properties: {
    summary: { type: "string" },
    findings: { type: "array", items: {
      type: "object", required: ["claim", "confidence", "sources", "evidence"],
      properties: {
        claim: { type: "string" },
        confidence: { enum: ["high", "medium", "low"] },
        sources: { type: "array", items: { type: "string" } },
        evidence: { type: "string" },
        vote: { type: "string" },
      },
    }},
    caveats: { type: "string" },
    openQuestions: { type: "array", items: { type: "string" } },
  },
}

// ─── Phase 0: Scope — decompose question into search angles ───
phase("Scope")
if (!QUESTION) {
  return { error: "No research question provided. Pass it as args: Workflow({ scriptPath, args: '<question>' }) or args: { question: '...' }." }
}
const estAgents = 1 + 6 + MAX_FETCH + MAX_VERIFY_CLAIMS * VOTES_PER_CLAIM + 1
log("depth=" + DEPTH + " · caps: fetch≤" + MAX_FETCH + ", claims≤" + MAX_VERIFY_CLAIMS + ", votes=" + VOTES_PER_CLAIM +
    " · models: search/fetch/verify=" + MODELS.verify + ", synth=" + MODELS.synthesize +
    " · est. ≤" + estAgents + " agents" + (budget.total ? " · budget " + Math.round(budget.remaining() / 1000) + "k left" : ""))

const scope = await agent(
  "Decompose this research question into complementary search angles.\n\n" +
  "## Question\n" + QUESTION + "\n\n" +
  "## Task\n" +
  "Generate 5 distinct web search queries that together cover the question from different angles. Pick angles that suit the question's domain. Examples:\n" +
  "- broad/primary  · academic/technical  · recent news  · contrarian/skeptical  · practitioner/implementation\n" +
  "- For medical: anatomy · common causes · serious differentials · authoritative refs · red flags\n" +
  "- For tech: state-of-art · benchmarks · limitations · industry adoption · cost/tradeoffs\n\n" +
  "Make queries specific enough to surface high-signal results. Avoid redundancy.\n" +
  "Return: the question (verbatim or lightly normalized), a 1-2 sentence decomposition strategy, and the angles.\n\nStructured output only.",
  { label: "scope", schema: SCOPE_SCHEMA, model: MODELS.scope }
)
if (!scope) {
  return { error: "Scope agent returned no result — cannot decompose the research question." }
}
log("Q: " + QUESTION.slice(0, 80) + (QUESTION.length > 80 ? "…" : ""))
log("Decomposed into " + scope.angles.length + " angles: " + scope.angles.map(a => a.label).join(", "))

// ─── Dedup state — accumulates across searchers as they complete ───
const normURL = u => {
  try {
    const p = new URL(u)
    return (p.hostname.replace(/^www\./, "") + p.pathname.replace(/\/$/, "")).toLowerCase()
  } catch { return u.toLowerCase() }
}
const seen = new Map()
const dupes = []
const budgetDropped = []
const relRank = { high: 0, medium: 1, low: 2 }
let fetchSlots = MAX_FETCH

// ─── Prompts ───
const SEARCH_PROMPT = (angle) =>
  "## Web Searcher: " + angle.label + "\n\n" +
  "Research question: \"" + QUESTION + "\"\n\n" +
  "Your angle: **" + angle.label + "** — " + (angle.rationale || "") + "\n" +
  "Search query: `" + angle.query + "`\n\n" +
  "## Task\nUse WebSearch with the query above (or a refined version). Return the top 4-6 most relevant results.\n" +
  "Rank by relevance to the ORIGINAL question, not just the search query. Skip obvious SEO spam/content farms.\n" +
  "Include a short snippet capturing why each result is relevant.\n\nStructured output only."

const FETCH_PROMPT = (source, angle) =>
  "## Source Extractor\n\n" +
  "Research question: \"" + QUESTION + "\"\n\n" +
  "Fetch and extract key claims from this source:\n" +
  "**URL:** " + source.url + "\n**Title:** " + source.title + "\n**Found via:** " + angle + " search\n\n" +
  "## Task\n1. Use WebFetch to retrieve the page content.\n" +
  "2. Assess source quality: primary research/institution? secondary reporting? blog/opinion? forum? unreliable?\n" +
  "3. Extract 2-5 FALSIFIABLE claims that bear on the research question. Each claim must:\n" +
  "   - be a concrete, checkable statement (not vague generalities)\n" +
  "   - include a direct quote from the source as support\n" +
  "   - be rated central/supporting/tangential to the research question\n" +
  "4. Note publish date if available.\n\n" +
  "If the fetch fails or the page is irrelevant/paywalled, return claims: [] and sourceQuality: \"unreliable\".\n\nStructured output only."

const VERIFY_PROMPT = (claim, v) =>
  "## Adversarial Claim Verifier (voter " + (v + 1) + "/" + VOTES_PER_CLAIM + ")\n\n" +
  "Be SKEPTICAL. Try to REFUTE this claim. ≥" + REFUTATIONS_REQUIRED + "/" + VOTES_PER_CLAIM + " refutations kill it.\n\n" +
  "## Research question\n" + QUESTION + "\n\n" +
  "## Claim under review\n\"" + claim.claim + "\"\n\n" +
  "**Source:** " + claim.sourceUrl + " (" + claim.sourceQuality + ")\n" +
  "**Supporting quote:** \"" + claim.quote + "\"\n\n" +
  "## Checklist\n" +
  "1. Is the claim actually supported by the quote, or is it an overreach/misread?\n" +
  "2. WebSearch for contradicting evidence — does any credible source dispute or heavily qualify this?\n" +
  "3. Is the source quality sufficient for the claim's strength? (extraordinary claims need primary sources)\n" +
  "4. Is the claim outdated? (check dates — old claims about fast-moving fields are suspect)\n" +
  "5. Is this a marketing claim / press release / cherry-picked benchmark / forum speculation?\n\n" +
  "**refuted=true** if: unsupported by quote / contradicted / low-quality source for strong claim / outdated / marketing fluff.\n" +
  "**refuted=false** ONLY if: claim is well-supported, current, and source quality matches claim strength.\n" +
  "Default to refuted=true if uncertain.\n\nStructured output only. Evidence MUST be specific."

// ─── Pipeline: search → dedup → fetch+extract (no barrier) ───
const searchResults = await pipeline(
  scope.angles,

  angle => agent(SEARCH_PROMPT(angle), {
    label: "search:" + angle.label, phase: "Search", schema: SEARCH_SCHEMA, model: MODELS.search
  }).then(r => {
    if (!r) return null
    log(angle.label + ": " + r.results.length + " results")
    return { angle: angle.label, results: r.results }
  }),

  searchResult => {
    const sorted = [...searchResult.results].sort((a, b) => relRank[a.relevance] - relRank[b.relevance])
    const novel = sorted.filter(r => {
      const key = normURL(r.url)
      if (seen.has(key)) {
        dupes.push({ ...r, angle: searchResult.angle, dupOf: seen.get(key) })
        return false
      }
      if (fetchSlots <= 0) {
        // Hard fetch cap — record what we dropped so the ceiling is never silent.
        budgetDropped.push({ ...r, angle: searchResult.angle })
        return false
      }
      seen.set(key, { angle: searchResult.angle, title: r.title })
      fetchSlots--
      return true
    })
    if (novel.length < searchResult.results.length) {
      log(searchResult.angle + ": " + novel.length + " novel (" + (searchResult.results.length - novel.length) + " filtered)")
    }
    return parallel(
      novel.map(source => () => {
        let host = "unknown"
        try { host = new URL(source.url).hostname.replace(/^www\./, "") } catch {}
        return agent(FETCH_PROMPT(source, searchResult.angle), {
          label: "fetch:" + host,
          phase: "Fetch",
          schema: EXTRACT_SCHEMA,
          model: MODELS.fetch,
        }).then(ext => {
          // User-skip → null; drop it (filtered by searchResults.flat().filter(Boolean))
          // rather than throwing into .catch() and mislabeling it "unreliable".
          if (!ext) return null
          return {
            url: source.url, title: source.title, angle: searchResult.angle,
            sourceQuality: ext.sourceQuality, publishDate: ext.publishDate,
            claims: ext.claims.map(c => ({ ...c, sourceUrl: source.url, sourceQuality: ext.sourceQuality })),
          }
        }).catch(e => {
          log("fetch failed: " + source.url + " — " + (e.message || e))
          return { url: source.url, title: source.title, angle: searchResult.angle, sourceQuality: "unreliable", claims: [] }
        })
      })
    )
  }
)

const allSources = searchResults.flat().filter(Boolean)
const allClaims = allSources.flatMap(s => s.claims)
const impRank = { central: 0, supporting: 1, tangential: 2 }
const qualRank = { primary: 0, secondary: 1, blog: 2, forum: 3, unreliable: 4 }

// ─── G2: re-check budget before the verify fan-out (the most expensive phase) ───
// The pool is now known; trim the verify count to whatever budget remains so a big
// claim pool can't blow the ceiling. Trimmed claims are logged, never silently dropped.
let verifyCap = MAX_VERIFY_CLAIMS
if (budget.total) {
  const affordableClaims = Math.floor(budget.remaining() / (TOKENS_PER_AGENT * VOTES_PER_CLAIM)) - 2 /*synth reserve*/
  if (affordableClaims < verifyCap) {
    verifyCap = Math.max(0, affordableClaims)
    log("budget gate: verifying ≤" + verifyCap + " claims (" + Math.round(budget.remaining() / 1000) + "k left)")
  }
}

const rankedClaims = [...allClaims]
  .sort((a, b) => (impRank[a.importance] - impRank[b.importance]) || (qualRank[a.sourceQuality] - qualRank[b.sourceQuality]))
  .slice(0, verifyCap)

const claimsDropped = Math.max(0, allClaims.length - rankedClaims.length)
log("Fetched " + allSources.length + " sources → " + allClaims.length + " claims → verifying top " + rankedClaims.length +
    (claimsDropped > 0 ? " (" + claimsDropped + " lower-priority claims not verified — cap)" : ""))

if (rankedClaims.length === 0) {
  return {
    question: QUESTION,
    summary: "No claims verified. " + allSources.length + " sources fetched, " + allClaims.length + " claims extracted; " +
      (budget.total && verifyCap === 0 ? "token budget exhausted before verification." : "all empty/failed.") +
      " " + dupes.length + " URL dupes, " + budgetDropped.length + " over-cap sources.",
    findings: [], refuted: [], unverified: [],
    sources: allSources.map(s => ({ url: s.url, quality: s.sourceQuality })),
    stats: { angles: scope.angles.length, sources: allSources.length, claims: allClaims.length, verified: 0, dupes: dupes.length, overCapSources: budgetDropped.length, unverifiedClaims: claimsDropped },
  }
}

// ─── Verify: multi-vote adversarial ───
// Barrier here is intentional — claim pool must be fully assembled before ranking/verification.
phase("Verify")
const voted = (await parallel(
  rankedClaims.map(claim => () =>
    parallel(
      Array.from({ length: VOTES_PER_CLAIM }, (_, v) => () =>
        agent(VERIFY_PROMPT(claim, v), {
          label: "v" + v + ":" + claim.claim.slice(0, 40),
          phase: "Verify",
          schema: VERDICT_SCHEMA,
          model: MODELS.verify,
        })
      )
    ).then(verdicts => {
      // A vote can be null (user-skip or agent error) — treat as no vote cast.
      //   survives  — quorum of valid votes AND fewer than REFUTATIONS_REQUIRED refuting
      //   isRefuted — ≥REFUTATIONS_REQUIRED refute votes (adjudicated against on merit)
      //   otherwise — unverified: too few valid votes to adjudicate (verifier agents errored)
      const valid = verdicts.filter(Boolean)
      const refuted = valid.filter(v => v.refuted).length
      const errored = VOTES_PER_CLAIM - valid.length
      const survives = valid.length >= REFUTATIONS_REQUIRED && refuted < REFUTATIONS_REQUIRED
      const isRefuted = refuted >= REFUTATIONS_REQUIRED
      const mark = survives ? "✓" : isRefuted ? "✗" : "?"
      log("\"" + claim.claim.slice(0, 50) + "…\": " + (valid.length - refuted) + "-" + refuted + (errored > 0 ? " (" + errored + " errored)" : "") + " " + mark)
      return { ...claim, verdicts: valid, refutedVotes: refuted, erroredVotes: errored, survives, isRefuted }
    })
  )
)).filter(Boolean)

const confirmed = voted.filter(c => c.survives)
const killed = voted.filter(c => c.isRefuted)
const unverified = voted.filter(c => !c.survives && !c.isRefuted)
log("Verify done: " + voted.length + " claims → " + confirmed.length + " confirmed, " + killed.length + " refuted, " + unverified.length + " unverified")

const toRefuted = c => ({ claim: c.claim, vote: (c.verdicts.length - c.refutedVotes) + "-" + c.refutedVotes, source: c.sourceUrl })
const toUnverified = c => ({ claim: c.claim, erroredVotes: c.erroredVotes, validVotes: c.verdicts.length, source: c.sourceUrl })

if (confirmed.length === 0) {
  // Distinguish "refuted on merit" from "could not verify (infra error)". A run
  // where every verifier agent failed (rate-limit / API error) is an infra
  // failure, not a research finding — report it as such so the user knows to
  // retry rather than concluding the research found nothing.
  let summary
  if (killed.length === 0 && unverified.length > 0) {
    summary = "Could not verify any claims — all " + unverified.length + " verifier panels failed (likely rate-limiting or API errors). This is an infrastructure failure, not a research finding. Raw extracted claims returned below; retry or verify manually."
  } else if (unverified.length > 0) {
    summary = killed.length + " claims refuted by adversarial verification; " + unverified.length + " could not be verified (verifier agents failed). No claims survived. Research inconclusive."
  } else {
    summary = "All " + killed.length + " claims refuted by adversarial verification. Research inconclusive — sources may be low-quality or claims overstated."
  }
  return {
    question: QUESTION,
    summary,
    findings: [],
    refuted: killed.map(toRefuted),
    unverified: unverified.map(toUnverified),
    sources: allSources.map(s => ({ url: s.url, quality: s.sourceQuality, claimCount: s.claims.length })),
    stats: { angles: scope.angles.length, sources: allSources.length, claims: allClaims.length, verified: voted.length, confirmed: 0, killed: killed.length, unverified: unverified.length },
  }
}

// ─── Synthesize ───
phase("Synthesize")
const confRank = { high: 0, medium: 1, low: 2 }
const block = confirmed.map((c, i) => {
  const best = c.verdicts.filter(v => !v.refuted).sort((a, b) => confRank[a.confidence] - confRank[b.confidence])[0]
  return "### [" + i + "] " + c.claim + "\n" +
    "Vote: " + (c.verdicts.length - c.refutedVotes) + "-" + c.refutedVotes + " · Source: " + c.sourceUrl + " (" + c.sourceQuality + ")\n" +
    "Quote: \"" + c.quote + "\"\nVerifier evidence (" + best.confidence + "): " + best.evidence + "\n"
}).join("\n")

const killedBlock = killed.length > 0
  ? "\n## Refuted claims (for transparency)\n" +
    killed.map(c => "- \"" + c.claim + "\" (" + c.sourceUrl + ", vote " + (c.verdicts.length - c.refutedVotes) + "-" + c.refutedVotes + ")").join("\n")
  : ""

const unverifiedBlock = unverified.length > 0
  ? "\n## Unverified claims (" + unverified.length + " — verifier agents failed; neither confirmed nor refuted)\n" +
    unverified.map(c => "- \"" + c.claim + "\" (" + c.sourceUrl + ", " + c.erroredVotes + "/" + VOTES_PER_CLAIM + " votes errored)").join("\n") +
    "\n\nMention in caveats that " + unverified.length + " claim(s) could not be verified due to infrastructure errors."
  : ""

const report = await agent(
  "## Synthesis: research report\n\n" +
  "**Question:** " + QUESTION + "\n\n" +
  confirmed.length + " claims survived " + VOTES_PER_CLAIM + "-vote adversarial verification. Merge semantic duplicates and synthesize.\n\n" +
  "## Confirmed claims\n" + block + "\n" + killedBlock + unverifiedBlock + "\n\n" +
  "## Instructions\n" +
  "1. Identify claims that say the same thing — merge them, combine their sources.\n" +
  "2. Group related claims into coherent findings. Each finding should directly address the research question.\n" +
  "3. Assign confidence per finding: high (multiple primary sources, unanimous votes), medium (secondary sources or split votes), low (single source or blog-quality).\n" +
  "4. Write a 3-5 sentence executive summary answering the research question.\n" +
  "5. Note caveats: what's uncertain, what sources were weak, what time-sensitivity applies" +
  (claimsDropped > 0 ? ", and that " + claimsDropped + " lower-priority claim(s) were not verified due to the cost cap" : "") + ".\n" +
  "6. List 2-4 open questions that emerged but weren't answered.\n\nStructured output only.",
  { label: "synthesize", schema: REPORT_SCHEMA, model: MODELS.synthesize }
)

if (!report) {
  // Synthesis skipped/errored — salvage the verified claims raw rather
  // than throwing on report.findings and discarding the whole run.
  return {
    question: QUESTION,
    summary: "Synthesis step was skipped or failed — returning " + confirmed.length + " verified claims unmerged.",
    findings: [],
    confirmed: confirmed.map(c => ({ claim: c.claim, source: c.sourceUrl, quote: c.quote, vote: (c.verdicts.length - c.refutedVotes) + "-" + c.refutedVotes })),
    refuted: killed.map(toRefuted),
    unverified: unverified.map(toUnverified),
    sources: allSources.map(s => ({ url: s.url, quality: s.sourceQuality, claimCount: s.claims.length })),
    stats: { angles: scope.angles.length, sources: allSources.length, claims: allClaims.length, verified: voted.length, confirmed: confirmed.length, killed: killed.length, unverified: unverified.length, afterSynthesis: 0 },
  }
}

return {
  question: QUESTION,
  ...report,
  refuted: killed.map(toRefuted),
  unverified: unverified.map(toUnverified),
  sources: allSources.map(s => ({ url: s.url, quality: s.sourceQuality, angle: s.angle, claimCount: s.claims.length })),
  stats: {
    depth: DEPTH,
    angles: scope.angles.length,
    sourcesFetched: allSources.length,
    claimsExtracted: allClaims.length,
    claimsVerified: voted.length,
    confirmed: confirmed.length,
    killed: killed.length,
    unverified: unverified.length,
    afterSynthesis: report.findings.length,
    urlDupes: dupes.length,
    overCapSources: budgetDropped.length,
    unverifiedByCap: claimsDropped,
    agentCalls: 1 + scope.angles.length + allSources.length + (voted.length * VOTES_PER_CLAIM) + 1,
  },
}
