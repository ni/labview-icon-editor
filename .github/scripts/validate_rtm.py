#!/usr/bin/env python3
import csv, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
RTM = ROOT / "docs" / "requirements" / "rtm.csv"


def main():
    missing_paths = []
    missing_models = []
    missing_procedures = []
    missing_coverage_items = []
    with open(RTM, newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        required = {
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
        if set(reader.fieldnames) != required:
            print(f"RTM header mismatch: {reader.fieldnames} != {sorted(required)}", file=sys.stderr)
            return 2
        for row in reader:
            priority = row.get("priority", "").strip().lower()
            if not row.get("model_id", "").strip():
                missing_models.append(row.get("id", "(missing id)"))
            if not row.get("procedure_path", "").strip():
                missing_procedures.append(row.get("id", "(missing id)"))
            if priority in {"high", "critical"} and not row.get("coverage_item_id", "").strip():
                missing_coverage_items.append(row.get("id", "(missing id)"))
            for key in ["code_path", "test_path", "procedure_path"]:
                rel = row[key].strip()
                if rel and not (ROOT / rel).exists():
                    missing_paths.append((row["id"], key, rel))
    if missing_paths or missing_models or missing_procedures or missing_coverage_items:
        if missing_paths:
            print("Missing RTM paths:", file=sys.stderr)
            for item in missing_paths:
                print(f"  {item[0]} -> {item[1]}: {item[2]}", file=sys.stderr)
        if missing_models:
            print("Missing RTM model_ids:", file=sys.stderr)
            for ident in missing_models:
                print(f"  {ident}", file=sys.stderr)
        if missing_procedures:
            print("Missing RTM procedure_paths:", file=sys.stderr)
            for ident in missing_procedures:
                print(f"  {ident}", file=sys.stderr)
        if missing_coverage_items:
            print("Missing RTM coverage_item_id for High/Critical:", file=sys.stderr)
            for ident in missing_coverage_items:
                print(f"  {ident}", file=sys.stderr)
        return 1
    print("RTM OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
