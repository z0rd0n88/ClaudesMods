# Spec-tacular ✨

Turn a vague concept into a specification an implementation team can execute
**without a single clarifying question** — through three gated phases that
refuse to skip ahead.

Where a normal "write me a spec" prompt sprints straight to a 2000-line document
in whatever direction it guessed, spec-tacular front-loads a reconnaissance pass
and a hard approval gate. You don't pay for a full draft until you've signed off
on the shape.

## The skill

| Skill | What it does | Command |
|---|---|---|
| [`spec-tacular`](./skills/spec-tacular/SKILL.md) | Drives a concept from recon → approved blueprint → fully-detailed spec, with decision records, alternative analysis, and fact-checking throughout. | `/spec-tacular` |

## The three phases

1. **Reconnaissance & Alignment** — explore the domain, architecture, and hard
   constraints; identify goal, audience, and success metrics; research only
   where facts are missing; clarify every ambiguity. Exit only when there are no
   open unknowns.
2. **Strategic Blueprint (GATE)** — an executive summary plus a zoomed-out
   section outline, then a **hard stop**: Approve or Adjust. No full draft
   happens before approval.
3. **Comprehensive Specification** — the full document, built on a 10-section
   [template](./skills/spec-tacular/references/spec-template.md): requirements,
   architecture, **Decision Records** (each choice with its rejected
   alternatives), risks, testing, and an Open Questions section whose emptiness
   is the "done" bar.

## Install

```bash
claude marketplace add github:z0rd0n88/ClaudesMods
claude plugin install spec-tacular
```

## Use

```bash
/spec-tacular a CLI that syncs Obsidian vaults to S3
/spec-tacular add SSO to the admin dashboard
/spec-tacular real-time collaborative cursor for our editor
```

## Composition with other skills

- **Before** — [`idea-panel`](https://github.com/z0rd0n88/ClaudesMods/tree/main/idea-panel)
  to generate candidate directions, or
  [`idea-autopsy`](https://github.com/z0rd0n88/ClaudesMods/tree/main/idea-autopsy)
  to pressure-test whether the idea is worth specifying at all.
- **After** — hand the finished spec to
  [`multi-agent-developer`](https://github.com/z0rd0n88/ClaudesMods/tree/main/multi-agent-developer)
  or [`code-rinse-repeat`](https://github.com/z0rd0n88/ClaudesMods/tree/main/code-rinse-repeat)
  to build it.
