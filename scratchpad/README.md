# scratchpad

User-invoked `/scratchpad` capture for a long-running **experiment & research backlog** — a single GitHub checkbox issue you keep open forever.

```
/scratchpad obsidian dual-mind plugin
  → appends "- [ ] **Obsidian dual-mind plugin**" under the best-fitting ## section

/scratchpad done: figure out how npx works
  → flips that item from "- [ ]" to "- [x]"

/scratchpad                       (no args)
  → prints the current issue body so you can see what's on it
```

## Why a single issue?

A pinned checkbox issue is a frictionless backlog: it shows up in your repo, GitHub renders the checkboxes, and the URL is shareable. No Notion, no Linear, no app. The skill is intentionally **user-invoked only** — it never auto-fires off general talk about "things to try," so the issue stays curated, not noisy.

## One-time setup

1. Pick (or create) a GitHub issue with checkbox items as its body. Suggested seed:

   ```markdown
   > [!NOTE]
   > Living backlog. Add via `/scratchpad <item>`, check off via `/scratchpad done: <item>`.

   ## New ideas (append below)
   ```

2. Note its `OWNER/REPO#NUMBER` (e.g. `you/notes#42`).

3. Configure the target (any one of these — checked in order):

   ```bash
   # one-shot (current shell only):
   export SCRATCHPAD_TARGET=you/notes#42

   # per-project (committed):
   echo '{"target": "you/notes#42"}' > .scratchpad.json

   # user-scope (all projects, recommended default):
   mkdir -p ~/.config/scratchpad
   echo '{"target": "you/notes#42"}' > ~/.config/scratchpad/config.json
   ```

4. Make sure `gh auth status` shows you're logged in.

5. Try it: `/scratchpad test item` — should append a `- [ ]` line and report the issue URL.

## How items get placed

When you add an item, the skill reads the existing `##` section headers in the issue body and drops your item under the section whose theme best matches it. No clear fit → it goes under `## New ideas (append below)`. A clear new theme spanning 2+ items → the skill creates a new `## <Theme>` section.

Duplicate detection is case-insensitive and reports back ("already on the list") instead of silently re-adding.

## Rules the skill follows

- **Preserve the whole body** on every edit — fetches it, changes only the relevant line/section, writes it back.
- **Issue stays open** forever — never closes.
- **Ambiguous "check off X"** (2+ matches) → asks which one; never guesses.
- **No auto-triggering** — only fires when you type `/scratchpad` or say "scratchpad" explicitly.

## Install

```bash
/plugin marketplace add z0rd0n88/ClaudesMods
/plugin install scratchpad@claudes-mods
```
