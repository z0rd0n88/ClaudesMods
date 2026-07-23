# Chiquita

A Claude Code plugin that makes a piece of writing **chiquita** — small — by
cutting fluff and structural padding while preserving every fact and decision.
Works on a file, a spec, a plan, a response draft, or a pasted string.

## What it cuts

- Hedging, filler adjectives, pleasantries, throat-clearing
- Opening framing paragraphs ("This document describes…")
- Closing meta-sections and "why this matters" recaps
- Redundant restatement of what a heading already says

## What it never cuts

Every number, date, name, decision, constraint, caveat, exception, and
technical term survives. The brief is "cut fluff," not "cut length" — a
sentence carrying even one fact stays, even if that makes the result longer
than a maximally compressed draft would be.

## Install

```bash
claude marketplace add github:z0rd0n88/ClaudesMods
claude plugin install chiquita
```

## Use

```bash
/chiquita path/to/doc.md
```

Or paste text inline, or just ask Claude to make something more concise — the
skill triggers on that phrasing too.

## Relation to other skills

- **`simplify`** — code changes only (reuse, simplification, efficiency). Use
  that for a diff; use `chiquita` for prose.
- **`caveman`** — an ongoing terse *conversation mode*. `chiquita` is a one-shot
  edit applied to an existing piece of writing, not a standing mode.

## Layout

```
chiquita/
├── .claude-plugin/plugin.json
├── README.md                     # this file
├── commands/
│   └── chiquita.md               # /chiquita entry point
└── skills/
    └── chiquita/SKILL.md         # the editing logic
```

## License

[MIT](../../LICENSE).
