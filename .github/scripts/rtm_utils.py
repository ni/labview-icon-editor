#!/usr/bin/env python3
"""Shared RTM utilities for coverage and reporting."""

from __future__ import annotations

import csv
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable, List, Tuple

ROOT = Path(__file__).resolve().parents[2]
RTM_PATH = ROOT / "docs" / "requirements" / "rtm.csv"
EXPECTED_HEADER = {
    "id",
    "title",
    "priority",
    "code_path",
    "test_path",
    "model_id",
    "coverage_item_id",
    "procedure_path",
    "verification",
    "owner",
    "status",
}
HIGH_OR_CRITICAL = {"high", "critical"}
MIN_HIGH = 1.0  # 100%
MIN_TOTAL = 0.75  # 75%


@dataclass
class Coverage:
    total: int = 0
    covered: int = 0

    def pct(self) -> float:
        return 1.0 if self.total == 0 else self.covered / self.total


def ensure_header(fieldnames: Iterable[str]) -> None:
    fields = set(fieldnames or [])
    if fields != EXPECTED_HEADER:
        raise SystemExit(
            f"RTM header mismatch: {sorted(fields)} != {sorted(EXPECTED_HEADER)}"
        )


def is_within_repo(path: Path) -> bool:
    try:
        path.relative_to(ROOT)
    except ValueError:
        return False
    return True


def resolve_test_path(raw_path: str) -> Tuple[bool, Path]:
    candidate = raw_path.strip()
    if not candidate:
        return False, Path()
    path = Path(candidate)
    if not path.is_absolute():
        path = ROOT / path
    path = path.resolve()
    if not is_within_repo(path):
        return False, path
    return path.exists(), path


def load_rtm() -> List[dict]:
    with open(RTM_PATH, newline="", encoding="utf-8") as handle:
        reader = csv.DictReader(handle)
        ensure_header(reader.fieldnames)
        return list(reader)


def compute_coverage(rows: List[dict]) -> Tuple[Coverage, Coverage, List[str]]:
    high = Coverage()
    total = Coverage()
    missing: List[str] = []
    for row in rows:
        has_test, path = resolve_test_path(row["test_path"])
        priority = row["priority"].strip().lower()

        total.total += 1
        if has_test:
            total.covered += 1

        if priority in HIGH_OR_CRITICAL:
            high.total += 1
            if has_test:
                high.covered += 1

        if not has_test:
            reason = "missing test path" if not path else f"missing file: {path.relative_to(ROOT)}"
            missing.append(f"{row.get('id','')} [{row['priority']}]: {reason}")
    return high, total, missing


def detect_suites(rows: List[dict]) -> List[str]:
    suites = set()
    for row in rows:
        path_str = row["test_path"].strip()
        if not path_str:
            continue
        parts = Path(path_str).parts
        suite = path_str
        try:
            idx = parts.index("Unit Tests")
            if idx + 1 < len(parts):
                suite = parts[idx + 1]
        except ValueError:
            suite = Path(path_str).parent.name or path_str
        suites.add(suite)
    return sorted(suites)
