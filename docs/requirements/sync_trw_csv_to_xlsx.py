#!/usr/bin/env python3
"""
Regenerate the TRW verification XLSX from the CSV source while preserving
all other workbook parts (styles, themes, properties).

Usage:
  python3 docs/requirements/sync_trw_csv_to_xlsx.py \
    --csv docs/requirements/TRW_Verification_Checklist.csv \
    --xlsx docs/requirements/TRW_Verification_Checklist.xlsx
"""

from __future__ import annotations

import argparse
import csv
import shutil
import zipfile
from pathlib import Path
from typing import Dict, List, Tuple
from xml.etree import ElementTree as ET

NS = {"x": "http://schemas.openxmlformats.org/spreadsheetml/2006/main"}
XML_NS = "http://www.w3.org/XML/1998/namespace"


def col_letter(index: int) -> str:
    if index < 1:
        raise ValueError("Column index must be >= 1")
    letters: List[str] = []
    while index:
        index, rem = divmod(index - 1, 26)
        letters.append(chr(65 + rem))
    return "".join(reversed(letters))


def load_csv(path: Path) -> List[List[str]]:
    rows: List[List[str]] = []
    with path.open("r", encoding="utf-8", newline="") as f:
        reader = csv.reader(f)
        rows.extend(reader)
    if not rows:
        raise SystemExit("CSV is empty; aborting.")
    return rows


def build_shared_strings_and_sheet(rows: List[List[str]]) -> Tuple[bytes, bytes]:
    strings: List[str] = []
    index: Dict[str, int] = {}
    occurrences = 0

    def ensure_string(text: str) -> int:
        nonlocal occurrences
        occurrences += 1
        if text in index:
            return index[text]
        idx = len(strings)
        strings.append(text)
        index[text] = idx
        return idx

    # Worksheet
    ET.register_namespace("", NS["x"])
    worksheet = ET.Element(f"{{{NS['x']}}}worksheet")

    last_col_idx = max(len(r) for r in rows)
    last_col_letter = col_letter(last_col_idx)
    ET.SubElement(worksheet, f"{{{NS['x']}}}dimension", {"ref": f"A1:{last_col_letter}{len(rows)}"})

    sheet_data = ET.SubElement(worksheet, f"{{{NS['x']}}}sheetData")
    for r_idx, row in enumerate(rows, start=1):
        row_el = ET.SubElement(sheet_data, f"{{{NS['x']}}}row", {"r": str(r_idx)})
        for c_idx, cell_value in enumerate(row, start=1):
            if cell_value == "":
                continue
            cell_ref = f"{col_letter(c_idx)}{r_idx}"
            cell = ET.SubElement(row_el, f"{{{NS['x']}}}c", {"r": cell_ref, "t": "s"})
            v = ET.SubElement(cell, f"{{{NS['x']}}}v")
            v.text = str(ensure_string(cell_value))

    # Shared strings
    sst = ET.Element(f"{{{NS['x']}}}sst", {"count": str(occurrences), "uniqueCount": str(len(strings))})
    for text in strings:
        si = ET.SubElement(sst, f"{{{NS['x']}}}si")
        t = ET.SubElement(si, f"{{{NS['x']}}}t")
        if text.startswith(" ") or text.endswith(" ") or "\n" in text:
            t.set(f"{{{XML_NS}}}space", "preserve")
        t.text = text

    shared_strings_bytes = ET.tostring(sst, encoding="utf-8", xml_declaration=True)
    worksheet_bytes = ET.tostring(worksheet, encoding="utf-8", xml_declaration=True)
    return shared_strings_bytes, worksheet_bytes


def regenerate_xlsx(csv_path: Path, xlsx_path: Path) -> None:
    rows = load_csv(csv_path)
    shared_strings_bytes, worksheet_bytes = build_shared_strings_and_sheet(rows)

    tmp_path = xlsx_path.with_suffix(".xlsx.tmp")
    backup_path = xlsx_path.with_suffix(".xlsx.bak")

    with zipfile.ZipFile(xlsx_path, "r") as zin, zipfile.ZipFile(tmp_path, "w", compression=zipfile.ZIP_DEFLATED) as zout:
        for item in zin.infolist():
            data = zin.read(item.filename)
            if item.filename == "xl/sharedStrings.xml":
                data = shared_strings_bytes
            elif item.filename == "xl/worksheets/sheet1.xml":
                data = worksheet_bytes
            zout.writestr(item, data)

    # Swap in regenerated workbook with a backup for safety.
    shutil.move(xlsx_path, backup_path)
    shutil.move(tmp_path, xlsx_path)
    backup_path.unlink(missing_ok=True)


def main() -> None:
    parser = argparse.ArgumentParser(description="Regenerate XLSX from CSV for the TRW verification checklist.")
    parser.add_argument("--csv", type=Path, default=Path("docs/requirements/TRW_Verification_Checklist.csv"))
    parser.add_argument("--xlsx", type=Path, default=Path("docs/requirements/TRW_Verification_Checklist.xlsx"))
    args = parser.parse_args()

    regenerate_xlsx(args.csv, args.xlsx)
    print(f"Regenerated {args.xlsx} from {args.csv}.")


if __name__ == "__main__":
    main()
