---
name: idea-panel
description: Run a parallel panel of thinking-skills mental-model lenses over a topic to generate fresh ideas, then synthesize and rank them. Use when brainstorming new products, business directions, research angles, or creative options.
allowed-tools:
  - Bash
  - Read
  - Glob
  - Grep
  - Agent
---

# idea-panel

## 1. Purpose

Generative sibling of `multi-agent-review`. Instead of a panel of *reviewers* finding faults in an existing artifact, this skill runs a panel of **thinking-skills mental-model lenses in parallel** to *generate* candidate ideas for a topic, then a synthesizer clusters, ranks, and de-duplicates them into one shortlist.

The skill itself produces no ideas — it orchestrates lens agents and relays the synthesized output. Each lens is a distinct cognitive frame (first-principles, jobs-to-be-done, inversion, effectuation, …), so the same topic gets attacked from angles that a single pass would collapse into one.

Full lens roster, per-lens brief template, and the synthesizer brief live in the references — this file is the orchestration contract only.

- [`references/lens-briefs.md`](references/lens-briefs.md) — the lens brief template, the default roster, and each lens's role framing + output contract.
- [`references/synthesizer-brief.md`](references/synthesizer-brief.md) — the synthesizer brief template and the fixed-heading report structure.

## 2. When to use

Trigger phrases:
- "brainstorm ideas for …" / "generate ideas about …"
- "what could we build in <space>?" / "new directions for <project>"
- "run an idea panel on …" / explicit `idea-panel …`

Do NOT use for:
- Evaluating an *existing* idea/proposal — use `idea-autopsy:evaluate-proposal-harsh` (go/no-go) or `idea-autopsy:stress-test-idea` (hardening).
- Single-model reasoning — invoke the specific `thinking-skills:thinking-<name>` skill directly.
- Anything that writes to source files — this skill is read-only.

## 3. Invocation grammar

```
idea-panel <topic...> [--lenses <csv>] [--panel-size <n>] [--context <path>] [--write-to <path>]
```

Examples:

```
idea-panel genetic security — new project/product directions
idea-panel loyalty rewards for indie coffee shops --panel-size 3
idea-panel developer tooling --lenses thinking-triz,thinking-second-order,thinking-jobs-to-be-done
idea-panel authentication UX --context docs/research/ --write-to docs/ideas/auth-panel.md
```

| Position / flag | Required | Values |
|---|---|---|
| `<topic...>` (positional) | yes | Free-text topic/problem space. Everything not consumed by a flag is the topic. Empty topic → hard-fail. |
| `--lenses <csv>` | no | Comma-separated lens tokens (whitespace trimmed). A token is either a `thinking-<name>` slug (dispatched as `general-purpose` applying that mental model) or a **named specialist agent** (e.g. `market-researcher`, `product-strategist`) dispatched via its own `subagent_type` to add domain grounding the thinking-skills lenses lack. Default = the roster in `references/lens-briefs.md` §Default roster. |
| `--panel-size <n>` | no | Clamp the panel to N lenses (3–4; values outside clamp to the nearest bound). Applies to the default roster; ignored when `--lenses` is explicit. |
| `--context <path>` | no | File or directory of background material prepended to every lens brief under `## CONTEXT`. Resolved relative to `git rev-parse --show-toplevel` when not absolute; missing path = hard-fail; 16 KB cap (dir = concatenated `git ls-files` contents, same cap). |
| `--write-to <path>` | no | Also save the synthesized report; refuse if the file exists unless `--force`. |
| `--force` | no | With `--write-to`, allow overwriting. |

## 4. Defaults

- **Lens roster** (when `--lenses` omitted, in order — see `references/lens-briefs.md` for each lens's framing):
  1. `thinking-first-principles`
  2. `thinking-jobs-to-be-done`
  3. `thinking-inversion`
  4. `thinking-effectuation`
- **Panel-size cap**: 3–4 lenses. This is deliberate — `thinking-model-combination` warns that >4 models produces "model soup." More than 4 requested via `--lenses` → warn on stderr but proceed (explicit override wins). Exception: adding `critical-thinking` as a 5th, non-generative carve-out lens does not count against the soup cap (it interrogates rather than generates — see `references/lens-briefs.md`).
- **Lens agent type**: `general-purpose` (thinking-skills are Skill-tool skills, not dedicated agents; the general-purpose subagent can invoke `thinking-skills:thinking-<name>` and has Read/Grep for `--context`).
- **Synthesizer agent type**: `general-purpose`.
- **`--write-to` overwrite policy**: refuse if destination exists unless `--force`.

## 5. Workflow

### 5.1 Parse and validate
1. Split positional topic from flags. Hard-fail if topic is empty.
2. Validate `--lenses` CSV: split on `,`, strip surrounding whitespace, reject empty tokens. A token is either (a) a `thinking-<name>` slug — warn (don't hard-fail) if a matching skill can't be located among your installed plugins (e.g. search installed plugin skill directories for a `thinking-<name>` match), since the brief is self-contained; or (b) a **named specialist agent** — validate it against `.claude/agents/*.md` + `~/.claude/agents/*.md` (hard-fail on unknown, since dispatch needs a real `subagent_type`; if you stage inactive agents separately from your live agent directory, activate the relevant one first).
3. Apply `--panel-size`: clamp to 3–4 and truncate the default roster to that length (ignored when `--lenses` is explicit).
4. Resolve `--context` (if present): to absolute; hard-fail if missing; enforce 16 KB cap; read into `{{CONTEXT_BLOCK}}`. Absent → strip the `## CONTEXT` block from the brief.
5. `--write-to` overwrite guard runs HERE, before any agent is spawned (don't waste N+1 agent calls on a doomed write).

### 5.2 Build lens briefs
For each lens in the roster, expand the lens brief template (`references/lens-briefs.md`) with: `{{LENS_NAME}}`, `{{TOPIC}}`, `{{LENS_INSTRUCTION}}` (that lens's role framing — from the references roster table for `thinking-*` lenses, or the §Specialist-agent lenses table for named agents), `{{CONTEXT_BLOCK}}`, and `{{OUTPUT_CONTRACT}}`. Select the contract by lens: `critical-thinking` uses the **carve-out** contract (returns assumptions/questions, not ideas); every other lens (thinking-skill or specialist agent) uses the **generative** contract. Briefs are fully self-contained — lens agents share no conversation state.

### 5.3 Spawn lenses IN PARALLEL

> ⚠️ **PARALLELISM RULE — DO NOT SERIALIZE.** All lens `Agent` calls MUST be issued in a SINGLE assistant message with N parallel tool invocations. Serializing multiplies latency by N and defeats the skill. Each call sets `subagent_type` = `general-purpose` for a `thinking-*` lens, or the **agent's own name** for a specialist-agent lens; `description: "Idea panel: <lens-name>"`; and `prompt` = the fully-expanded lens brief.

### 5.4 Collect outputs
After all lenses return, capture each output verbatim, keyed by lens name in roster order. Do not edit or filter. A lens that fails/returns empty is noted to the synthesizer as `<lens-name>: [FAILED — no output]`; continue with the rest.

### 5.5 Invoke synthesizer
Expand the synthesizer brief (`references/synthesizer-brief.md`) with `{{TOPIC}}`, `{{N_LENSES}}`, `{{CONTEXT_BLOCK}}`, and `{{LENS_OUTPUTS}}` (each lens's verbatim output under a `### Lens: <name>` block, `---`-delimited). The synthesizer routes any `critical-thinking` carve-out output to its own "Assumptions & Open Questions" section and never folds it into the idea ranking (see the brief). Spawn one `Agent` call, `subagent_type: general-purpose`, `description: "Idea panel: synthesize"`.

### 5.6 Print verbatim
Print the synthesized report as the final message. If `--write-to` was set, `mkdir -p` the parent, write the report, and prepend one line `Wrote: <absolute path>`. If `--write-to` was **not** set, ask the user (inline or via `AskUserQuestion`) whether to save the shortlist before it's gone — suggest a default like `docs/ideas/<topic-slug>.md` — rather than defaulting to chat-only. Then suggest the natural follow-on pipeline: `idea-autopsy:iterate-to-v2` → `product-management:write-spec` / `to-prd` → `idea-autopsy:evaluate-proposal-harsh`.

## 6. Error handling

| Condition | Action |
|---|---|
| Empty topic | Hard-fail with a one-line usage summary. Do not spawn agents. |
| `--lenses` token empty (consecutive commas) | Hard-fail with the offending CSV. |
| `--lenses` slug not found among installed plugins | Warn on stderr, proceed (brief is self-contained). |
| `--panel-size` outside 3–4 | Clamp to the nearest bound, warn on stderr. |
| `--context` path missing / over 16 KB | Hard-fail with the path and (for size) the cap. |
| `--write-to` exists, no `--force` | Hard-fail in §5.1, before any agent is spawned. |
| A lens agent fails / returns empty | Note it to the synthesizer as `[FAILED — no output]`; continue with the rest. |
| Synthesizer fails | Print `Synthesizer failed. Lens outputs follow:` then dump each lens's verbatim output with `---` delimiters (and write the same to `--write-to` if set). |
