#!/usr/bin/env python3
"""Compare the source plugin tree against an installed copy.

Run from the repo root:
    python3 scripts/check-drift.py <install-path>

Exits 0 if the install matches source on the files that MUST be identical;
exits 1 if any drift is found.

The check is restricted to the load-bearing surface of the plugin:
    .claude-plugin/plugin.json
    commands/**
    skills/**

Source-only files (README.md, scripts/) and install-only wrapper files
(marketplace.json, outer README) are intentionally ignored.
"""

from __future__ import annotations

import hashlib
import sys
from pathlib import Path


# Subdirectories and files that must match byte-for-byte across source and install.
TRACKED_SUBPATHS = (
    ".claude-plugin/plugin.json",
    "commands",
    "skills",
    "examples",
)

# Path fragments to ignore inside the tracked subdirectories.
IGNORE_FRAGMENTS = (
    "__pycache__",
    ".DS_Store",
    ".pytest_cache",
)


def sha256_normalized(path: Path) -> str:
    """SHA-256 of file contents with LF-normalized line endings."""
    data = path.read_bytes().replace(b"\r\n", b"\n").replace(b"\r", b"\n")
    return hashlib.sha256(data).hexdigest()


def collect_files(root: Path) -> dict[str, str]:
    """Walk root and return {relative_path: sha256} for every tracked file."""
    out: dict[str, str] = {}
    for subpath in TRACKED_SUBPATHS:
        base = root / subpath
        if not base.exists():
            continue
        if base.is_file():
            out[subpath] = sha256_normalized(base)
            continue
        for path in sorted(base.rglob("*")):
            if not path.is_file():
                continue
            if any(frag in path.parts for frag in IGNORE_FRAGMENTS):
                continue
            rel = path.relative_to(root).as_posix()
            out[rel] = sha256_normalized(path)
    return out


def find_source_root() -> Path:
    """Resolve the plugin source root from this script's location."""
    here = Path(__file__).resolve()
    candidate = here.parent.parent
    if not (candidate / ".claude-plugin" / "plugin.json").exists():
        sys.stderr.write(
            f"error: cannot find plugin.json under {candidate}\n"
            "is this script at idea-autopsy/scripts/check-drift.py ?\n"
        )
        sys.exit(2)
    return candidate


def main(argv: list[str]) -> int:
    if len(argv) != 2:
        sys.stderr.write(f"usage: {argv[0]} <install-path>\n")
        return 2

    install_root = Path(argv[1]).resolve()
    if not install_root.is_dir():
        sys.stderr.write(f"error: install path is not a directory: {install_root}\n")
        return 2

    source_root = find_source_root()

    if not (install_root / ".claude-plugin" / "plugin.json").exists():
        sys.stderr.write(
            f"error: install path has no .claude-plugin/plugin.json — "
            f"did you point at the right directory?\n  install_root: {install_root}\n"
            "hint: marketplace installs may nest the plugin under a 'plugin/' "
            "subdirectory.\n"
        )
        return 2

    src_files = collect_files(source_root)
    inst_files = collect_files(install_root)

    only_source = sorted(set(src_files) - set(inst_files))
    only_install = sorted(set(inst_files) - set(src_files))
    mismatched = sorted(p for p in src_files if p in inst_files and src_files[p] != inst_files[p])

    if not (only_source or only_install or mismatched):
        print(f"OK: source and install match ({len(src_files)} files compared)")
        print(f"  source:  {source_root}")
        print(f"  install: {install_root}")
        return 0

    print("DRIFT detected:")
    print(f"  source:  {source_root}")
    print(f"  install: {install_root}")
    print()
    if only_source:
        print(f"  Only in source ({len(only_source)}):")
        for p in only_source:
            print(f"    + {p}")
    if only_install:
        print(f"  Only in install ({len(only_install)}):")
        for p in only_install:
            print(f"    - {p}")
    if mismatched:
        print(f"  Content differs ({len(mismatched)}):")
        for p in mismatched:
            print(f"    ~ {p}")
            print(f"      source  : {src_files[p]}")
            print(f"      install : {inst_files[p]}")
    return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
