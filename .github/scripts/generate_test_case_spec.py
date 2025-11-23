#!/usr/bin/env python3
"""Generate ISO 29119-3 §8.3 test case specifications from RTM and model docs."""

from __future__ import annotations

import argparse
import re
import sys
from collections import defaultdict
from pathlib import Path
from typing import Dict, Iterable, List, Tuple

from rtm_utils import ROOT, load_rtm

MODELS_DIR = ROOT / "docs" / "testing" / "models"
DEFAULT_OUTPUT_DIR = ROOT / "docs" / "testing" / "specs"


def slugify(value: str) -> str:
    """Return filesystem-safe, lower-case slug."""
    value = re.sub(r"[^A-Za-z0-9]+", "-", value).strip("-")
    value = re.sub(r"-{2,}", "-", value)
    return value.lower() or "spec"


def find_title(text: str, fallback: str) -> str:
    """Return the first H1 heading or a fallback."""
    for line in text.splitlines():
        if line.startswith("# "):
            return line[2:].strip()
    return fallback


def parse_model_files() -> Dict[str, dict]:
    """Index model files by UID (model_id)."""
    index: Dict[str, dict] = {}
    for path in MODELS_DIR.glob("*.md"):
        text = path.read_text(encoding="utf-8")
        uid_match = re.search(r"UID:\s*`([^`]+)`", text, re.IGNORECASE)
        if not uid_match:
            continue
        model_id = uid_match.group(1).strip()
        title = find_title(text, model_id)
        coverage_items = extract_coverage_items(text)
        index[model_id] = {"path": path, "title": title, "coverage": coverage_items}
    return index


def extract_coverage_items(text: str) -> List[Tuple[str, str]]:
    """Extract coverage item labels/descriptions from model markdown."""
    items: List[Tuple[str, str]] = []
    seen = set()
    lines = text.splitlines()
    for line in lines:
        stripped = line.strip()

        # Bullet format: "- P1: description" or "- R1 description"
        bullet = re.match(r"[-*]\s*([PR]\d+[A-Za-z0-9-]*)[:\s-]+\s*(.+)", stripped)
        if bullet:
            label, desc = bullet.group(1), bullet.group(2).strip()
            if label not in seen:
                items.append((label, desc))
                seen.add(label)
            continue

        # Table rows starting with "| P1 ..." (skip alignment/header rows)
        if stripped.startswith("|") and not re.match(r"^\|\s*-", stripped):
            cells = [c.strip() for c in stripped.strip("|").split("|")]
            if len(cells) < 2:
                continue
            first_token = cells[0].split()[0]
            if re.match(r"[PR]\d+[A-Za-z0-9-]*", first_token):
                desc_cells = [c for c in cells[1:] if c]
                desc = " | ".join(desc_cells).strip()
                label = first_token
                if label not in seen:
                    items.append((label, desc))
                    seen.add(label)
    return items


def group_rows_by_model(rows: Iterable[dict]) -> Dict[str, List[dict]]:
    grouped: Dict[str, List[dict]] = defaultdict(list)
    for row in rows:
        model_id = str(row.get("model_id", "")).strip()
        if not model_id:
            continue
        grouped[model_id].append(row)
    return grouped


def build_case_id(requirement_id: str, counter: Dict[str, int]) -> str:
    counter[requirement_id] += 1
    return f"{requirement_id}-TC{counter[requirement_id]}"


def write_spec(model_id: str, model_meta: dict, requirements: List[dict], output_dir: Path) -> Path:
    coverage_items: List[Tuple[str, str]] = model_meta.get("coverage", [])
    model_path: Path | None = model_meta.get("path")
    title: str = model_meta.get("title", model_id)
    slug_source = model_path.stem if model_path else model_id
    slug = slugify(slug_source.replace("-model", ""))
    output_path = output_dir / f"{slug}-tcs.md"

    requirement_summaries = [f"{r['id']} ({r['priority']})" for r in requirements]
    test_assets = sorted({r["test_path"].strip() or "(missing test_path)" for r in requirements})
    procedure_assets = sorted({r.get("procedure_path", "").strip() or "(missing procedure_path)" for r in requirements})

    lines: List[str] = []
    lines.append(f"# {title} Test Case Specification (§8.3)")
    lines.append("")
    lines.append(f"- Model ID: `{model_id}`")
    lines.append(f"- Model source: `{model_path.relative_to(ROOT)}`" if model_path else "- Model source: (not found)")
    lines.append(f"- Related requirements: {', '.join(requirement_summaries)}")
    lines.append(f"- Test assets: {', '.join(f'`{t}`' for t in test_assets)}")
    lines.append(f"- Procedures: {', '.join(f'`{p}`' for p in procedure_assets)}")
    lines.append("")
    lines.append("## Coverage Items")
    if coverage_items:
        lines.append("| ID | Description |")
        lines.append("| --- | --- |")
        for label, desc in coverage_items:
            lines.append(f"| {label} | {desc} |")
    else:
        lines.append("- None found in model; add partitions or decision rules to the model document.")
    lines.append("")
    lines.append("## Test Cases")
    lines.append("| Case ID | Requirement | Priority | Test Path | Procedure | Coverage Items |")
    lines.append("| --- | --- | --- | --- | --- | --- |")
    req_counter: Dict[str, int] = defaultdict(int)
    coverage_labels = ", ".join(label for label, _ in coverage_items) if coverage_items else "Pending model coverage"
    for row in requirements:
        case_id = build_case_id(row["id"], req_counter)
        test_path = row["test_path"].strip() or "(missing test_path)"
        procedure_path = row.get("procedure_path", "").strip() or "(missing procedure_path)"
        lines.append(
            f"| {case_id} | {row['id']} | {row['priority']} | `{test_path}` | `{procedure_path}` | {coverage_labels} |"
        )

    output_dir.mkdir(parents=True, exist_ok=True)
    output_path.write_text("\n".join(lines), encoding="utf-8")
    return output_path


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate §8.3 test case specs from RTM/model documents.")
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=DEFAULT_OUTPUT_DIR,
        help="Directory where generated specs will be written (default: docs/testing/specs)",
    )
    args = parser.parse_args()

    try:
        rows = load_rtm()
    except Exception as exc:
        print(f"Failed to load RTM: {exc}", file=sys.stderr)
        return 2

    model_index = parse_model_files()
    grouped = group_rows_by_model(rows)
    if not grouped:
        print("No RTM rows contained a model_id; nothing to generate.", file=sys.stderr)
        return 1

    generated: List[Path] = []
    for model_id in sorted(grouped.keys()):
        meta = model_index.get(model_id, {"title": model_id, "coverage": []})
        spec_path = write_spec(model_id, meta, grouped[model_id], args.output_dir)
        generated.append(spec_path)

    print("Generated test case specifications:")
    for path in generated:
        rel = path.relative_to(ROOT)
        print(f" - {rel}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
