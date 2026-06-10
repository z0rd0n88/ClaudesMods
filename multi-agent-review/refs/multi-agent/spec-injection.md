# Spec / requirement injection

Shared primitive for ensuring multi-agent reviewers and developers measure their output against the *originating intent*, not just the diff in isolation. Cited by `total-review`, `multi-agent-review`, `xan-multi-agent-developer`, `baton-runner-multi-agent`.

## The failure this prevents

Without the originating spec in-prompt, multi-agent review answers "is this code well-written?" but never "does this code do what was asked?" The result is a polished implementation of the wrong feature. No amount of axis fan-out, debate-round looping, or severity calibration catches this — every reviewer is anchored on the diff, not the requirement.

## What counts as a spec

In order of preference:

1. **The originating issue/PRD/spec markdown** that triggered the work (path: typically `docs/specs/<name>.md`, `docs/prd/<name>.md`, or a GitHub issue body).
2. **The acceptance criteria block** from a phase/run plan (the `Acceptance` section of a phase spec, or the issue's checklist).
3. **The user's exact request text** when no written spec exists (passed through as a verbatim block).

If none of (1)–(3) exists, the skill should pause and ask for one before fan-out. Do not synthesize a spec from the diff — that bakes the "build the wrong thing" failure into the review's ground truth.

## Injection contract

Inject the spec into reviewer/specialist prompts under a fixed heading:

```markdown
## ORIGINATING SPEC — the change MUST satisfy this:
<verbatim spec contents>
```

Reviewers are then instructed (one line in the rubric): "Raise a CRITICAL finding if any acceptance criterion is materially unmet by the diff, even if the code itself is correct in isolation."

This makes "you built the wrong thing" a first-class finding category rather than something nobody is asked to look for.

## Per-skill wiring

| Skill | How to inject |
|---|---|
| `multi-agent-review` | Pass spec path via `--prompt-prelude <path>`. The skill already prepends prelude contents to every reviewer brief — this is the right hook; no schema change needed. |
| `xan-multi-agent-developer` | The spec IS the target (positional arg `file <path>` or `issue <N>`); already injected into specialist briefs. Verify the brief template carries it under the canonical heading rather than paraphrasing. |
| `total-review` | For `pre-pr` mode, accept an optional `--spec <path>` argument; for recurring full-codebase modes (`code`, `architecture`, etc.), spec injection is N/A — those don't have a single originating spec. |
| `baton-runner-multi-agent` | Each phase has its own spec (from the phase list parsed at pre-flight). The review-unit invocation of `multi-agent-review` MUST pass `--prompt-prelude <phase-spec-path>` so the per-phase reviewers measure against that phase's acceptance criteria, not the cumulative diff. |

## Spec budget

Specs can be long; reviewer context isn't free. Hard cap injected spec at 16 KB (matches `multi-agent-review`'s `--prompt-prelude` cap). If the spec exceeds this:

1. Prefer the acceptance-criteria block alone over the full spec.
2. If that's still over budget, truncate the body but **always preserve the acceptance criteria verbatim** — those are what reviewers must check against.
3. Never silently truncate the criteria themselves — fail-loud and ask the caller to slim the spec or extract the criteria explicitly.

## Failure modes

- **Spec drifted from the implementation.** The diff implements what the user verbally asked for in the conversation, but the written spec is stale. Reviewers will flag the diff as not meeting the spec — correctly. Resolve by updating the spec before review, not by skipping injection.
- **No spec exists.** Multi-agent review of ad-hoc work falls back to "code quality" mode only; surface this in the verdict so the user knows the "matches requirement" axis was not checked.
- **Spec is in a different repo / private system.** Fetch it once into a local path and inject by path. Do not embed it inline in the skill's invocation args — `--prompt-prelude <path>` keeps the argv clean and lets the prelude be re-used across phases.
