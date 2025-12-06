#!/usr/bin/env python3
import json, sys
from pathlib import Path

REPORT = Path("docs/compliance/report.json")

def main():
    if not REPORT.exists():
        print("Gate: docs/compliance/report.json not found. Run your compliance job first.")
        sys.exit(2)
    info = json.loads(REPORT.read_text(encoding="utf-8"))
    pct = float(info.get("compliance_percent") or info.get("compliance", 0.0))
    if pct < 100.0:
        print(f"Gate failed: Compliance {pct}% < 100%.")
        sys.exit(1)
    print(f"Release gate OK: compliance {pct}%.")
    sys.exit(0)

if __name__ == "__main__":
    main()
