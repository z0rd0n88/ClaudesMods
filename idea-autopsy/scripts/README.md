# scripts/

Maintainer-only utilities for the `idea-autopsy` plugin.

## `check-drift.py`

Compares the source tree (this repo's `idea-autopsy/`) against an installed copy of the plugin and reports any drift. Run from the repo root:

```bash
python3 scripts/check-drift.py <install-path>
```

The script compares only the load-bearing surface — `.claude-plugin/plugin.json`, `commands/`, and `skills/` — and ignores source-only docs (README.md) and install wrapper files (marketplace.json, outer README). Line endings are LF-normalized before hashing.

Exit codes:
- `0` — source and install match
- `1` — drift detected (script prints which files differ)
- `2` — usage error (wrong arg count, bad paths)

Typical install path for a `claude marketplace add` install:

```
~/.claude/skills/idea-autopsy-plugin/plugin
```

Run before tagging a release or after merging upstream changes. Stdlib-only Python 3 — no dependencies.
