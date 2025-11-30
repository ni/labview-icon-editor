#!/usr/bin/env python3
"""Populate commit message from `.codex/metadata.json`.

Usage: prepare-commit-msg.py <path-to-commit-message>

The metadata file should provide `summary`, `change_type`, `srs_ids`, and
optionally `issue`.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path
import re

# Commit metadata must reference registered FGC-REQ-* identifiers.
# TEST-REQ-* IDs are reserved for tests and rejected here.
SRS_ID_RE = r"FGC[\u2011-]REQ[\u2011-][A-Z]+[\u2011-]\d{3}"


def normalize_id(id_: str) -> str:
    return "-".join(part.upper() for part in id_.replace("\u2011", "-").split("-"))


def _version_key(ver: str) -> tuple[int, ...]:
    return tuple(int(p) for p in ver.split("."))


def _load_srs_registry(root: Path) -> dict[str, list[tuple[str, str]]]:
    specs: dict[str, list[tuple[str, str]]] = {}
    trace = root / "docs" / "traceability.yaml"
    if trace.exists():
        current_id: str | None = None
        for line in trace.read_text(encoding="utf-8").splitlines():
            m_id = re.match(rf"\s*- id:\s*({SRS_ID_RE})", line)
            if m_id:
                current_id = normalize_id(m_id.group(1))
                continue
            m_src = re.match(r"\s*source:\s*(\S+)", line)
            if m_src and current_id:
                rel = m_src.group(1)
                path = root / rel
                version = ""
                if path.exists():
                    text = path.read_text(encoding="utf-8")
                    vm = re.search(r"Version:\s*\*{0,2}\s*(\S+)", text)
                    version = vm.group(1).strip() if vm else ""
                specs.setdefault(current_id, [])
                if (rel, version) not in specs[current_id]:
                    specs[current_id].append((rel, version))
                current_id = None

    srs_dir = root / "docs" / "srs"
    if srs_dir.exists():
        for path in srs_dir.glob("*.md"):
            text = path.read_text(encoding="utf-8")
            version_match = re.search(r"Version:\s*\*{0,2}\s*(\S+)", text)
            version = version_match.group(1).strip() if version_match else ""
            for id_raw in set(re.findall(SRS_ID_RE, text)):
                id_ = normalize_id(id_raw)
                rel = path.relative_to(root).as_posix()
                specs.setdefault(id_, [])
                if (rel, version) not in specs[id_]:
                    specs[id_].append((rel, version))

    return specs


def main(argv: list[str]) -> int:
    if len(argv) < 2:
        # Some environments may invoke the hook without arguments; treat as no-op
        return 0

    msg_path = Path(argv[1])
    repo_root = Path(__file__).resolve().parent.parent
    meta_path = repo_root / ".codex" / "metadata.json"
    if not meta_path.exists():
        return 0

    data = json.loads(meta_path.read_text(encoding="utf-8"))
    summary = data.get("summary", "").strip()
    change_type = data.get("change_type", "").strip()
    srs_ids = data.get("srs_ids", [])
    issue = data.get("issue")

    spec_map = _load_srs_registry(repo_root)
    resolved_ids: list[str] = []
    for raw in srs_ids:
        id_ = normalize_id(raw)
        specs = spec_map.get(id_, [])
        versions = [v for _, v in specs if v]
        if versions:
            ver = max(versions, key=_version_key)
            resolved_ids.append(f"{id_}@{ver}")
        else:
            resolved_ids.append(id_)

    meta_line = f"codex: {change_type} | SRS: {', '.join(resolved_ids)}"
    if issue is not None and str(issue).strip():
        issue_str = str(issue)
        if not issue_str.startswith("#"):
            issue_str = f"#{issue_str}"
        meta_line += f" | issue: {issue_str}"

    msg = f"{summary}\n\n{meta_line}\n"
    msg_path.write_text(msg, encoding="utf-8")
    return 0


if __name__ == "__main__":  # pragma: no cover - entry point
    raise SystemExit(main(sys.argv))
