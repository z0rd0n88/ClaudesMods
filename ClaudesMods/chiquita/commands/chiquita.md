---
description: "Cut fluff and structural padding from a doc, spec, plan, or response"
argument-hint: "[file path, or paste text inline]"
---

Invoke the `chiquita` skill and follow it exactly.

Arguments forwarded: `$ARGUMENTS`

The skill will:

1. Read the full target text (a file, spec, plan, or response draft).
2. Cut word- and sentence-level filler using the no-op test.
3. Cut structural padding — framing openers, closing meta-sections, throat-clearing.
4. Verify every fact, decision, number, and caveat still survives before finishing.
