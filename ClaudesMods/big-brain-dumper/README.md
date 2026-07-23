# big-brain-dumper

User-invoked `/big-brain-dumper` capture for a **daily brain-dump** — one append-only Markdown file per day per project that every session pours key points, decisions, and action items into.

```
/big-brain-dumper
  → resolves today's file (docs/brain-dumps/YYYY-MM-DD-brain-dump.md), seeds it if new,
    and appends a timestamped, session-labeled block summarizing the session so far.
    Then keeps appending for the rest of the session.

/big-brain-dumper decided to ship user-invoked; concurrency via >> append
  → dumps exactly those points as this block.
```

## Why one file per day per project

A brain-dump is a low-friction running log: activate once, and the agent keeps offloading the substance of the session — decisions, findings, action items — so nothing important evaporates when context compacts or the session ends. Because it is **one file per day per project**, every session you run in that repo today writes to the same file, giving you a single chronological record of the day's thinking.

## Concurrency & append-only

The doc is a flat chronological log. Every entry is a timestamped, session-labeled block appended in one `printf` call (one `write(2)` syscall on the append-mode fd) — the skill never opens the file for editing. That means:

- **Multiple sessions, safely.** Two Claude sessions in the same repo today append to the same file; their blocks stay intact and interleave only by time, since each block is written in a single syscall rather than several. No read-before-edit races. The file is seeded once via a `noclobber` create, so two sessions starting at the same instant can't both truncate it.
- **Append-only.** Existing entries are never rewritten, reordered, or deleted.
- **Session-tagged.** Each block carries a short session label so you can tell concurrent sessions apart.

## Where the file lives

Directory precedence (first hit wins):

```bash
# one-shot (current shell only):
export BRAINDUMP_DIR=/some/path

# per-project (committed):
echo '{"dir": "docs/brain-dumps"}' > .braindump.json

# default (no config):
docs/brain-dumps/
```

File name is always `YYYY-MM-DD-brain-dump.md` under that directory. Point `$BRAINDUMP_DIR` or `.braindump.json` at an untracked/absolute path if you don't want the dump under version control; otherwise commit it at session end.

## What gets dumped

- **Key points** — decisions and discoveries, phrased to stand alone weeks later.
- **Action items** — as `- [ ]` checkboxes.
- Dense bullets, not a transcript. Greetings, tool mechanics, and points already logged today are skipped.

## Install

```bash
/plugin marketplace add z0rd0n88/ClaudesMods
/plugin install big-brain-dumper@claudes-mods
```
