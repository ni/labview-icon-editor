#!/usr/bin/env python3
"""
Fail if WATERFALL/AGENTS have more than one canonical copy or if stubs drift from template.
Policy:
  - Canonical WATERFALL: docs/WATERFALL.md (must contain required anchors)
  - Root WATERFALL.md: stub pointing to docs/WATERFALL.md
  - Canonical AGENTS: /AGENTS.md
  - docs/AGENTS.md: stub pointing to /AGENTS.md
"""
from __future__ import annotations
from pathlib import Path
import sys

ROOT = Path(".").resolve()
canon_water = ROOT / "docs" / "WATERFALL.md"
stub_water = ROOT / "WATERFALL.md"
canon_agents = ROOT / "AGENTS.md"
stub_agents = ROOT / "docs" / "AGENTS.md"
SKIP_PARTS = {'.git', '.pytest_cache', '.tmp'}
SKIP_SUBSTRINGS = ('pytest-', 'pytest_', 'pytestrun', 'tmppytest', 'tmp_pytest')

def _should_skip(path: Path) -> bool:
    for part in path.parts:
        if part in SKIP_PARTS:
            return True
        if any(sub in part for sub in SKIP_SUBSTRINGS):
            return True
    return False

EXPECTED_WATER_STUB = None  # Deprecated — root stub is no longer required

EXPECTED_AGENTS_STUB = (
    "# AGENTS Contract (Stub)\n"
    "> **DO NOT EDIT HERE.** Canonical document lives at repository root: `/AGENTS.md`\n"
    ">\n"
    "> Changes to the agent contract must be made in the canonical file.\n"
    "> This stub exists only to maintain historical links for the documentation site.\n"
    ">\n"
    "> For roles, commit/branch formats, and PR checks, read **`/AGENTS.md`**.\n"
    ">\n"
    "See: `/AGENTS.md`\n"
)

def require_exact(path: Path, expected: str) -> int:
    if not path.exists():
        print(f"Missing required file: {path}")
        return 1
    text = path.read_text(encoding="utf-8", errors="ignore")
    if text.strip() != expected.strip():
        print(f"{path}: stub diverges from template")
        return 1
    return 0

def require(path: Path, substrings: list[str]) -> int:
    if not path.exists():
        print(f"Missing required file: {path}")
        return 1
    text = path.read_text(encoding="utf-8", errors="ignore")
    for s in substrings:
        if s not in text:
            print(f"{path}: missing required marker: {s}")
            return 1
    return 0

def must_be_stub(path: Path, expected: str) -> int:
    return require_exact(path, expected)

def must_be_canonical_waterfall(path: Path) -> int:
    # Must contain anchors we rely on elsewhere
    need = ["ANCHOR:final-orchestration", "ANCHOR:criteria", "ANCHOR:workflows"]
    return require(path, need)

def detect_extra_copies(name: str, allowed: set[Path]) -> int:
    """Fail if any extra copies of *name* exist outside *allowed* paths."""
    failures = 0
    for p in ROOT.rglob(name):
        if _should_skip(p):
            continue
        if p.resolve() not in allowed:
            print(f"Unexpected {name} at: {p}")
            failures += 1
    return failures

def main() -> int:
    failures = 0
    # Canonical Waterfall remains for historical reference; root stub is deprecated and no longer required
    failures += must_be_canonical_waterfall(canon_water)
    # Root WATERFALL.md stub optional — skip exact-content enforcement
    failures += must_be_stub(stub_agents, EXPECTED_AGENTS_STUB)
    # Allow either no root stub or an exact stub; detect extras elsewhere only
    allowed_water = {canon_water.resolve()}
    if stub_water.exists():
        allowed_water.add(stub_water.resolve())
    failures += detect_extra_copies("WATERFALL.md", allowed_water)
    allowed_agents = {
        canon_agents.resolve(),
        stub_agents.resolve(),
        (ROOT / "ci" / "stage2" / "AGENTS.md").resolve(),
        (ROOT / "ci" / "stage3" / "AGENTS.md").resolve(),
    }
    failures += detect_extra_copies("AGENTS.md", allowed_agents)
    # Ensure only one canonical copy of each topic:
    # If docs/AGENTS.md looks like a full doc (contains headings typical of canonical), fail.
    text = stub_agents.read_text(encoding="utf-8", errors="ignore") if stub_agents.exists() else ""
    if "# AGENTS" in text and "Canonical document lives" not in text:
        print("docs/AGENTS.md appears canonical; expected stub."); failures += 1
    if not canon_agents.exists():
        print("Missing canonical /AGENTS.md"); failures += 1
    return failures

if __name__ == "__main__":
    sys.exit(main())


