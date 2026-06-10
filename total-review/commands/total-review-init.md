---
description: "Bootstrap the total-review pattern in this repo (detects stack, drafts a wrapper + config)"
---

Invoke the `total-review-scaffold` skill and follow it exactly. The skill will:

1. Sanity-check that you're at a git repo root on a non-`main` feature branch with `ARCH.md` present.
2. Detect your stack (Python / Kotlin / TypeScript / multi).
3. Read `ARCH.md` to suggest slice candidates aligned to your layer layout.
4. Activate the agents the default matrix references (or surface which ones are missing).
5. Write `<repo>/.claude/skills/<slug>-total-review/{SKILL.md, config.yml}` — a thin project wrapper that delegates to this plugin's `total-review` library skill with your project-specific slices, mode overrides, tracker commands, and invariants.

After it finishes, invoke `/<slug>-total-review <mode>` to run a review pass.
