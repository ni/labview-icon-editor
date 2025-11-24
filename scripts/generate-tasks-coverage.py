#!/usr/bin/env python3
"""
Generate docs/tasks-catalog.md from scripts/tasks-coverage.json.
"""
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DATA_PATH = ROOT / "scripts" / "tasks-coverage.json"
OUT_PATH = ROOT / "docs" / "tasks-catalog.md"


def load_data() -> dict:
    if not DATA_PATH.exists():
        raise SystemExit(f"Coverage data not found at {DATA_PATH}")
    return json.loads(DATA_PATH.read_text(encoding="utf-8"))


def render_table(tasks: list[dict], years: list[int], oss: list[str]) -> str:
    header = ["Task"] + [f"{y} {os_}" for y in years for os_ in oss]
    rows = []
    for task in tasks:
        cells = [task["name"]]
        for y in years:
            for os_ in oss:
                status = task.get("coverage", {}).get(str(y), {}).get(os_, "")
                mark = "[x]" if status.lower() in {"x", "pass", "true"} else "[ ]"
                cells.append(mark)
        rows.append(cells)

    def row_line(cols):
        return "| " + " | ".join(cols) + " |"

    lines = [row_line(header), row_line(["---"] * len(header))]
    for r in rows:
        lines.append(row_line(r))
    return "\n".join(lines)


def render(tasks: list[dict]) -> str:
    years = [2020, 2021, 2022, 2023, 2024, 2025, 2026]
    oss = ["win", "linux"]

    lines = [
        "# VS Code Tasks Catalog",
        "",
        "Generated from `scripts/tasks-coverage.json`. Run `python scripts/generate-tasks-coverage.py` to refresh.",
        "",
        "## Task List",
    ]
    for t in tasks:
        lines.append(f"- {t['name']} — {t['description']}")

    lines += [
        "",
        "## Coverage Matrix",
        "Mark cells by setting coverage entries in `scripts/tasks-coverage.json` (e.g., `\"pass\"`).",
        "",
        render_table(tasks, years, oss),
        "",
        "_Test cases_: Dev-mode tasks map to `TC-DEV-BIND-WIN/LNX`; intent tasks map to `TC-DEV-INTENT-WIN/LNX`; others use their own IDs.",
    ]
    return "\n".join(lines) + "\n"


def main() -> None:
    data = load_data()
    tasks = data.get("tasks", [])
    OUT_PATH.write_text(render(tasks), encoding="utf-8")
    print(f"Wrote {OUT_PATH}")


if __name__ == "__main__":
    main()
