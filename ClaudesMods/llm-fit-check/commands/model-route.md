---
description: Recommend the best model tier and effort for the current task based on complexity, risk, and budget.
---

# Model Route Command

Recommend the best model **and effort** for the current task. The classification
verdict comes from the **shared llm-fit-check engine** — the *same* deterministic
heuristic the automatic `UserPromptSubmit` hook uses — so the command and the hook
never drift. Do **not** re-derive the routing rules in your head; shell out to the
engine and report what it returns.

## Usage

`/model-route [task-description] [--budget low|med|high] [--why]`

## Arguments

`$ARGUMENTS`:
- `[task-description]` — optional free-text task to classify. If omitted, use the
  current conversation's active task as the description.
- `--budget low|med|high` — optional. Nudges the *fallback* suggestion only (a low
  budget prefers a cheaper fallback; a high budget a stronger one). It does **not**
  override the engine's primary verdict.
- `--why` — explain mode. Print the **last hook decision** for this session from the
  debug log instead of classifying a new task (see `--why` below).

## How to run it (shell out — this is load-bearing)

Run the shared engine via the Bash tool. Never reimplement the heuristic in prose:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/llm-fit-check/hooks/lfc_classify.sh" "<task-description>"
```

It prints a parseable block:

```
band=heavy
desired_tier=3
desired_model=opus
desired_effort_rank=3
desired_effort=high
recommend=/model opus && /effort high
```

Read the **current** model + effort from the per-session sidecar
(`state/llm-fit-check/<sid>.model`, maintained by the hook). The freshest sidecar is
the current session's:

```bash
d="$HOME/.claude/state/llm-fit-check"
f="$(ls -t "$d"/*.model 2>/dev/null | head -1)"
[ -n "$f" ] && jq -r '"current_model=" + (.model // "unknown"), "current_effort=" + (.effort // "unknown")' "$f" 2>/dev/null
```

If no sidecar exists yet, treat the current setup as unknown and still report the
engine's recommendation.

## `--why` mode (explain the last hook decision)

The hook is silent on a match and terse on a block/warn. `--why` surfaces its
reasoning by printing the last `classify …` / `DECISION=…` lines from the debug log:

```bash
grep -E 'classify |DECISION=' "$HOME/.claude/state/llm-fit-check/debug.log" 2>/dev/null | tail -20
```

Summarise those lines: which band the hook assigned, the current vs desired tier/
effort, and whether it blocked, warned, or stayed silent. Do not classify a new task
in this mode.

## Required Output

Report, based on the engine block (not your own judgement):

- **Recommended setup** — the engine's `recommend=` string, i.e. `"/model X && /effort Y"`.
- **Confidence** — high when the band is `heavy` or `trivial` (unambiguous keyword
  match); moderate when the band is `moderate` (default/fallthrough).
- **Why this fits** — the `band=` and how it maps to tier/effort, plus the current
  setup from the sidecar (over-/under-powered on which axis).
- **Fallback** — the next-safest model if the first attempt struggles (adjust by
  `--budget`): from `opus`→`sonnet`, `sonnet`→`opus` (harder) or `haiku` (cheaper),
  `haiku`→`sonnet`.

## Routing reference (informational only — the engine decides)

- `haiku` / low effort — deterministic, low-risk mechanical changes.
- `sonnet` / medium effort — default for implementation and refactors.
- `opus` / high effort — architecture, security, concurrency, deep review, ambiguous
  requirements.
