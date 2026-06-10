---
description: "Route to the right Idea Autopsy skill based on what you have"
argument-hint: "[doc-path] [optional: critique-path]"
---

# /autopsy — Idea Autopsy router

You are the entry point for the Idea Autopsy plugin. Your job is to read the
user's inputs and signals, pick exactly one of the three bundled skills, and
invoke it. You do not produce the review yourself — the chosen skill does.

The three skills, in the order they appear in the workflow:

```
stress-test-idea  →  iterate-to-v2  →  evaluate-proposal-harsh
   (find holes)      (change plan)        (verdict)
```

## Routing rules

Pick the FIRST rule that matches. Do not ask follow-up questions before routing
unless the input is genuinely ambiguous (see "Ambiguous case" below).

### Rule 1 — Two inputs provided → `iterate-to-v2`

If the user has supplied **both** a document AND a critique (two file paths,
or a doc plus pasted critique findings, or doc plus phrases like "apply this
critique", "draft v2", "rewrite based on this", "close the loop"), invoke the
`iterate-to-v2` skill.

Two-input detection:
- `$ARGUMENTS` contains two paths
- User message contains one doc + a clearly distinct critique block
- User references prior critique output ("apply the stress-test findings",
  "use the verdict from earlier")

### Rule 2 — Verdict intent → `evaluate-proposal-harsh`

If the user has one document and signals decision intent, invoke
`evaluate-proposal-harsh`. Signals:
- "should I build this" / "should I do this" / "is this worth my time"
- "give me a verdict" / "invest or skip" / "go/no-go"
- "should I invest in this" / "should I fund this"
- The doc is described as "final", "v2", "ready for review"

### Rule 3 — Iteration intent → `stress-test-idea`

If the user has one document and signals iteration intent, invoke
`stress-test-idea`. Signals:
- "tear this apart" / "find the holes" / "stress test this"
- "what should I fix" / "what's wrong with this"
- "harsh feedback" / "review before I commit"
- "v1" / "first draft" / "early draft" framing

### Ambiguous case — doc only, no signal

If the user has provided exactly one document with no iteration or verdict
signal, ask **once**, briefly:

> Do you want **iteration input** (specific changes for v2) or a **verdict**
> (invest/skip)? — I'll route to stress-test-idea or evaluate-proposal-harsh
> respectively.

Then route based on the answer. Do not ask more than this one question.

### No doc provided

If the user invoked `/autopsy` without any document — neither a file path nor
pasted text — ask once for the doc, briefly:

> I need a doc to work on — a file path, pasted text, or a reference to one
> shared earlier. What's the doc?

Each bundled skill needs substantive material to attack; verbal descriptions
produce thin reviews.

## Invocation

Once you have decided which skill to invoke, invoke it via the Skill tool with
the chosen skill's name. Pass through:
- The document(s) the user provided
- Any inline investment / iteration / accept-reject context
- The user's original framing (so the skill can match tone)

Do not summarize the doc or the routing decision back to the user — the chosen
skill will produce the output that matters. A one-line "Routing to
`stress-test-idea`…" is the only narration you should add before the skill
takes over.

## Workflow reminder

The three skills are designed to chain across multiple `/autopsy` calls:

1. v1 doc → `/autopsy` (Rule 3) → `stress-test-idea` produces critique
2. v1 doc + critique → `/autopsy` (Rule 1) → `iterate-to-v2` produces change plan
3. User rewrites → v2 doc
4. v2 doc → `/autopsy` (Rule 2) → `evaluate-proposal-harsh` produces verdict

The user is in control of the chain — they re-invoke `/autopsy` with whatever
they have at each step. The router doesn't auto-chain.
