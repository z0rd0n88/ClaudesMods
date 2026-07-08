# edit-agents

Enable, disable, and list Claude Code agents by moving their `.md` files. Works at project scope (`<repo>/.claude/agents/`) or user scope (`~/.claude/agents/`).

## The gotcha this skill exists for

Claude Code scans the `agents/` directory **recursively** at session start. So a `agents/disabled/` subfolder does **not** hide the agents inside it — they still load into the active roster, still consume context, and still count against name-collision detection. To actually park an agent you must move its file *out* of the `agents/` tree entirely — the convention this skill uses is a sibling `agents-parked/` directory next to `agents/`, at the same scope.

(This differs from **skills**, which are scanned only one level deep. `skills/disabled/` works for skills; the equivalent does not work for agents. Confusing this is the single most common mistake, hence a skill dedicated to doing it right.)

## Usage

The skill is user-invoked in response to natural-language requests. Common triggers:

- "Disable the `kotlin-specialist` agent" → moves `<scope>/agents/kotlin-specialist.md` → `<scope>/agents-parked/kotlin-specialist.md`.
- "Enable `security-reviewer`" → the reverse.
- "List all my agents" → prints active + parked, per scope.
- "Park the whole review category" → bulk move by category tag in the agent's frontmatter.

## Bundled script

`skills/edit-agents/edit-agents.sh` does the actual moves. Invoke directly if you prefer a shell interface:

```
bash <plugin-install-root>/skills/edit-agents/edit-agents.sh list
bash <plugin-install-root>/skills/edit-agents/edit-agents.sh disable kotlin-specialist
bash <plugin-install-root>/skills/edit-agents/edit-agents.sh enable security-reviewer
bash <plugin-install-root>/skills/edit-agents/edit-agents.sh --scope user disable-category review
```

Auto-detects project vs user scope based on whether `$PWD/.claude/agents/` exists. Override with `--scope project|user` or `--dir <path>`.

## Composition

Standalone. Does not require any other plugin.
