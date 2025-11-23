#!/usr/bin/env python3
import csv
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable, List, Tuple


ROOT = Path(__file__).resolve().parents[2]
RTM_PATH = ROOT / "docs" / "requirements" / "rtm.csv"
HIGH_OR_CRITICAL = {"high", "critical"}
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
MIN_HIGH_COVERAGE = 1.0  # 100%
MIN_TOTAL_COVERAGE = 0.75  # 75%


@dataclass
class CoverageStats:
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


def resolve_test_path(raw_path: str) -> Tuple[bool, str]:
    candidate = raw_path.strip()
    if not candidate:
        return False, "no test_path provided"

    path = Path(candidate)
    if not path.is_absolute():
        path = ROOT / path

    path = path.resolve()
    if not is_within_repo(path):
        return False, "test_path points outside repository"
    if not path.exists():
        return False, f"missing test path: {path.relative_to(ROOT)}"
    return True, ""


def load_rtm() -> List[dict]:
    with open(RTM_PATH, newline="", encoding="utf-8") as handle:
        reader = csv.DictReader(handle)
        ensure_header(reader.fieldnames)
        return list(reader)


def evaluate(rows: List[dict]) -> Tuple[CoverageStats, CoverageStats, List[str]]:
    high = CoverageStats()
    total = CoverageStats()
    missing: List[str] = []

    for row in rows:
        has_test, reason = resolve_test_path(row["test_path"])
        priority = row["priority"].strip().lower()

        total.total += 1
        if has_test:
            total.covered += 1

        if priority in HIGH_OR_CRITICAL:
            high.total += 1
            if has_test:
                high.covered += 1

        if not has_test:
            ident = row.get("id", "").strip() or "(missing id)"
            missing.append(f"{ident} [{row['priority']}]: {reason}")

    return high, total, missing


def print_summary(high: CoverageStats, total: CoverageStats, missing: List[str]) -> None:
    print("RTM test presence summary")
    print(
        f"  High/Critical: {high.covered}/{high.total} ({high.pct():.0%}) "
        f"(required >= {MIN_HIGH_COVERAGE:.0%})"
    )
    print(
        f"  Overall: {total.covered}/{total.total} ({total.pct():.0%}) "
        f"(required >= {MIN_TOTAL_COVERAGE:.0%})"
    )
    if missing:
        print("Missing coverage entries:")
        for item in missing:
            print(f"  - {item}")


def main() -> int:
    try:
        rows = load_rtm()
    except FileNotFoundError:
        print(f"RTM not found at {RTM_PATH}", file=sys.stderr)
        return 2
    except SystemExit as exc:
        print(exc, file=sys.stderr)
        return 2

    high, total, missing = evaluate(rows)
    print_summary(high, total, missing)

    high_ok = high.pct() >= MIN_HIGH_COVERAGE
    total_ok = total.pct() >= MIN_TOTAL_COVERAGE
    if high_ok and total_ok:
        print("Coverage gate satisfied.")
        return 0

    print("Coverage gate failed.", file=sys.stderr)
    if not high_ok:
        print(
            f"  High/Critical coverage below required {MIN_HIGH_COVERAGE:.0%}.",
            file=sys.stderr,
        )
    if not total_ok:
        print(
            f"  Overall coverage below required {MIN_TOTAL_COVERAGE:.0%}.",
            file=sys.stderr,
        )
    return 1


if __name__ == "__main__":
    sys.exit(main())
