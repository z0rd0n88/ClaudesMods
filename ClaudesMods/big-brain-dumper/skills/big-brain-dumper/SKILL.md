---
name: big-brain-dumper
description: User-invoked only. Maintains one append-only brain-dump doc per day per project; every session dumps key points, decisions, and action items into the same day's file.
disable-model-invocation: true
---

# Big Brain Dumper

> [!IMPORTANT]
> **User-invoked only.** Run when the user types `/big-brain-dumper` or says "brain dump" / "start dumping".
> Once activated, hold the standing discipline in Step 5 for the rest of the session — no re-invocation needed.

Offload the session's thinking into a **brain-dump**: one append-only Markdown file **per day per project**. This session, other sessions running today, and future sessions all **dump** into the same day's file. Entries are only ever added — never rewrite, reorder, or delete what is already there.

## Step 1 — Resolve today's dump file

Run this to fix `FILE` for the session (directory precedence: `$BRAINDUMP_DIR` → `.braindump.json` → default `docs/brain-dumps`):

```bash
root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cfg="$root/.braindump.json"
dir="$BRAINDUMP_DIR"
[ -z "$dir" ] && [ -f "$cfg" ] && dir="$(jq -r '.dir // empty' "$cfg")"
[ -z "$dir" ] && dir="docs/brain-dumps"
case "$dir" in /*) ;; *) dir="$root/$dir";; esac
mkdir -p "$dir"
FILE="$dir/$(date +%F)-brain-dump.md"
```

Completion: the absolute `FILE` path is known and its directory exists.

## Step 2 — Seed the file only if it is absent

Another session today may already own the file. Create it only when missing; otherwise leave its header untouched. Use `noclobber` rather than a `[ ! -f ]` check — the check-then-create pattern has a race window where two sessions starting at the same instant can both see the file absent and both truncate it; `noclobber` makes the create atomic (the shell's `>` fails instead of truncating if the file already exists in between):

```bash
(
  set -o noclobber
  cat > "$FILE" <<EOF
# Brain Dump — $(date +%F)

**Executive summary:** append-only running log of key points, decisions, and action items across every session working in $(basename "$root") today. Newest entries at the bottom.

## Log
EOF
) 2>/dev/null
```

Completion: `FILE` exists and contains a `## Log` section (whichever session's create call won the race — the others' calls harmlessly fail closed).

## Step 3 — Fix a session label

Pick one short label for THIS session and reuse it on every entry so parallel sessions stay distinguishable: the session's rename/topic (e.g. `skill-crte`), else `sess-$(date +%H%M)`. Set it as `LABEL`. Completion: `LABEL` is fixed and won't change this session.

## Step 4 — Dump the conversation so far

Append one block capturing every key point, decision, and open action item established up to now — dense bullets, standalone-readable, not a transcript. Read the file's tail first (`tail -n 40 "$FILE"`) and skip anything already logged today. Use the [append recipe](#append-recipe). Completion: this session's first block is in the file.

## Step 5 — Keep dumping (standing discipline)

For the rest of the session, after each meaningful decision, finding, or action item lands, append a fresh block with the append recipe. Capture substance; leave out greetings, tool mechanics, and points already dumped today. This continues until the session ends.

## Append recipe

Appending is the **only** write path — never open `FILE` for editing. This is what keeps parallel sessions safe and the log append-only. Build the block in a variable first, then append it with a **single** `printf` call — one `write(2)` syscall on an `O_APPEND` fd is what actually keeps a block intact against interleaving from another session; a `{ printf; cat; } >>` group issues multiple `write(2)` calls and can interleave with another session's block in between them:

```bash
block=$(cat <<'EOF'
- <key point, phrased to stand alone weeks later>
- <decision: ... and why>
- [ ] <action item>
EOF
)
printf '\n### %s · %s\n%s\n' "$(date +%H:%M)" "$LABEL" "$block" >> "$FILE"
```

- The single-quoted `<<'EOF'` keeps backticks and `$` in your content literal — safe for code snippets and paths.
- One `printf` call writes the whole block in one syscall, so blocks from concurrent sessions stay intact (for normal dump-entry sizes) and only interleave by time — the guarantee a multi-command `{ … } >>` group can't make.
- Name provenance inline when a point comes from a doc, link, or tool run.

## Config & version control

The dump lives under `docs/brain-dumps/` (tracked) by default. To keep it out of version control, point `$BRAINDUMP_DIR` or `.braindump.json` `{"dir": "..."}` at an ignored/absolute path; otherwise commit it at session end.
