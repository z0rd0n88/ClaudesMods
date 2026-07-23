---
name: chiquita
description: 'Cuts fluff and padding from a doc, spec, plan, or response while keeping every fact, number, and decision — for "make this concise"/"trim this" requests; not code (use simplify) and not an ongoing conversation mode (use caveman)'
---

# Chiquita

Chiquita means small — cut fat, not muscle: strip filler and padding, keep
every fact, decision, number, and caveat. Applies to any prose target — a
file, a spec, a plan, a response draft, a pasted string.

## Steps

1. **Read the whole target** before touching it. Completion criterion: the full
   text is in view, not just the parts that look padded.

   **Output location:** a pasted-in string or chat response is trimmed and
   returned in chat. A file path target is edited in place (the file itself,
   not a chat copy) — say so before editing, and note the path afterward.

2. **Cut word- and sentence-level filler.** Hedging ("just", "really",
   "basically"), pleasantries, throat-clearing, restatement of what a heading
   already says. Run the no-op test per sentence: does removing it lose a fact,
   decision, number, or constraint? If no, delete the whole sentence — don't just
   trim its words. Completion criterion: every remaining sentence fails the no-op
   test.

3. **Cut structural padding.** Opening framing paragraphs ("This document
   describes…"), closing meta-sections ("Relation to X", recap-why-this-matters
   asides), transitional throat-clearing between sections. Completion criterion:
   every remaining paragraph states operative content, not commentary about the
   content.

4. **Verify nothing substantive was lost.** Reread the chiquita version against
   the original. Completion criterion: a side-by-side check finds every fact,
   number, decision, constraint, and caveat surviving somewhere in the result —
   zero drops. If a cut created ambiguity, that's a loss; restore or clarify it.

## Cut vs. keep

| Cut | Keep |
|---|---|
| Hedging, filler adjectives, pleasantries | Every number, date, name, decision |
| Framing openers ("In this document…") | Constraints and caveats ("only if X") |
| Closing meta-sections and recaps | Causal claims ("because Y") |
| Redundant restatement of a heading | Exceptions and edge cases |
| Transitional throat-clearing | Technical terms, code, quoted errors — verbatim |

## Failure mode to guard

Over-trimming, not under-trimming, is the risk here. The brief is "cut fluff,"
not "cut length." A sentence carrying even one fact, decision, or nuance
survives — even if that makes the result longer than a maximally compressed
draft would be. Preserved information outranks a shorter draft with a gap in it.
