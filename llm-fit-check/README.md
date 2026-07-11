# llm-fit-check

Right-sizes the **model** and **effort** to each prompt — so you don't grind a
trivial edit on max reasoning, or quietly under-power a security refactor.

Two front-ends over **one shared classification engine** (`lfc_classify.sh`) — no
drift between them:

- **Automatic (push):** a `UserPromptSubmit` hook classifies every prompt and acts
  asymmetrically —
  - **BLOCK** when under-powered on a heavy/risky task (refactor, security,
    concurrency, architecture…), with a `/model X && /effort Y` fix to run and resend;
  - **WARN** (non-blocking) when over-powered on a trivial task, suggesting a cheaper setup;
  - **SILENT** on a match.
- **Manual (pull):** the **`/model-route`** command gives an on-demand recommendation
  (model + effort + confidence + why + fallback) from the same engine, and
  **`/model-route --why`** explains the hook's last decision.

Everything **fails open**: any error path exits 0 and never wedges a session.

## Install

```
/plugin marketplace add z0rd0n88/ClaudesMods
/plugin install llm-fit-check@claudes-mods
```

Reload hooks (or restart) after install so the hooks register.

## How it decides

`lfc_classify.sh` is the single source of truth: a keyword regex (`HEAVY`/`TRIVIAL`)
plus word-count thresholds map a prompt to a band (`trivial` / `moderate` / `heavy`,
with `borderline` resolved), and the band maps to a desired model tier + effort. The
hook compares that against the current model (a per-session sidecar) and effort, and
only **heavy/risky** tasks are eligible to block.

## Components

| Path | Role |
|------|------|
| `hooks/hooks.json` | Registers the three hooks via `${CLAUDE_PLUGIN_ROOT}` |
| `hooks/classify.sh` | `UserPromptSubmit` — block / warn / silent decision |
| `hooks/lfc_classify.sh` | Shared classification engine (sourced lib + CLI) |
| `hooks/lib.sh` | Sidecar state, model/effort ranking, rotating debug log |
| `hooks/session-init.sh` | `SessionStart` — seed the model/effort sidecar |
| `hooks/cleanup.sh` | `SessionEnd` — remove the sidecar |
| `hooks/track-model.sh` | Shipped but **unwired** (undocumented `ConfigChange` event) |
| `hooks/test.sh` | 43-assertion path-coverage suite |
| `commands/model-route.md` | `/model-route` recommendation + `--why` |

## Configuration (environment variables)

| Var | Default | Effect |
|-----|---------|--------|
| `LLM_FIT_CHECK_USE_LLM` | unset (off) | When set, escalate `borderline` prompts to a `claude -p --model haiku` second opinion |
| `LLM_FIT_CHECK_STATE_DIR` | `$HOME/.claude/state/llm-fit-check` | Sidecar + debug-log location |
| `LLM_FIT_CHECK_LOG_MAX` | `262144` | Debug-log rotation threshold in bytes |
| `LLM_FIT_CHECK_VERBOSE` | unset | Echo log lines to stderr |

## Testing

```
bash hooks/test.sh    # → SUMMARY: PASS=43 FAIL=0, exit 0
```

## Notes

- **State is user-global** (`$HOME/.claude/state/llm-fit-check`), intentionally outside
  the plugin dir — session sidecars and the debug log survive plugin updates.
- The `ConfigChange` event is undocumented, so `track-model.sh` ships **unwired**;
  `classify.sh` self-heals the current model by reading the transcript instead.
