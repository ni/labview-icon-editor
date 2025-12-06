#!/usr/bin/env python3
"""Validate commit message against template defined in commit-template.snippet.md.

Usage:
    check-commit-msg.py <path-to-commit-message>

The script reads commit-template.snippet.md and ensures
that the provided commit message matches it:
    1. Summary line present and <=50 characters.
    2. Second line blank.
    3. Third line matches "codex: <change_type> | SRS: <comma-separated-srs-ids>".
"""
from __future__ import annotations

import os
import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(REPO_ROOT))

from scripts.lib.telemetry import record_telemetry_entry


# Commit metadata must reference registered FGC-REQ-* identifiers.
# TEST-REQ-* IDs are reserved for tests and rejected by this check.
SRS_ID_RE = r"FGC[\u2011-]REQ[\u2011-][A-Z]+[\u2011-]\d{3}"
VER_RE = r"\d+(?:\.\d+)*"


def normalize_id(id_: str) -> str:
    return "-".join(part.upper() for part in id_.replace("\u2011", "-").split("-"))


def _load_template(root: Path) -> str:
    return (root / "commit-template.snippet.md").read_text(encoding="utf-8").strip()


def _pattern_from_template(template: str) -> re.Pattern[str]:
    lines = [line.strip() for line in template.splitlines()]
    if len(lines) < 3:
        raise RuntimeError("Commit message template must have at least three lines")
    third = lines[2]
    escaped = re.escape(third)
    escaped = escaped.replace(re.escape("<change_type>"), "(spec|impl|both)")
    ids_pattern = f"{SRS_ID_RE}(?:@{VER_RE})?(, {SRS_ID_RE}(?:@{VER_RE})?)*"
    combined = "<comma-separated-srs-ids>@<spec-version>"
    if combined in third:
        escaped = escaped.replace(re.escape(combined), ids_pattern)
    else:
        escaped = escaped.replace(re.escape("<comma-separated-srs-ids>"), ids_pattern)
    if "<issue-number>" in third:
        # Support both legacy optional form and required form
        opt_marker = "[ | issue: #<issue-number>]"
        req_marker = " | issue: #<issue-number>"
        if opt_marker in third:
            escaped = escaped.replace(
                re.escape(opt_marker),
                r"(?: \| (?:[Ii]ssue: )?#\d+)?",
            )
        else:
            escaped = escaped.replace(
                re.escape(req_marker),
                r"(?: \| (?:[Ii]ssue: )?#\d+)",
            )
    pattern_str = escaped
    return re.compile(f"^{pattern_str}$")


def _version_key(ver: str) -> tuple[int, ...]:
    return tuple(int(p) for p in ver.split("."))


def _load_srs_registry(root: Path) -> tuple[set[str], dict[str, list[tuple[str, str]]]]:
    """Return known IDs and mapping of IDs to spec locations."""
    ids: set[str] = set()
    specs: dict[str, list[tuple[str, str]]] = {}

    trace = root / "docs" / "traceability.yaml"
    if trace.exists():
        current_id: str | None = None
        for line in trace.read_text(encoding="utf-8").splitlines():
            m_id = re.match(rf"\s*- id:\s*({SRS_ID_RE})", line)
            if m_id:
                current_id = normalize_id(m_id.group(1))
                ids.add(current_id)
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
                ids.add(id_)
                rel = path.relative_to(root).as_posix()
                specs.setdefault(id_, [])
                if (rel, version) not in specs[id_]:
                    specs[id_].append((rel, version))

    return ids, specs


def main(argv: list[str]) -> int:
    if len(argv) != 2:
        print("Usage: check-commit-msg.py <path-to-commit-message>", file=sys.stderr)
        return 1

    try:
        msg_path = Path(argv[1])
        msg_text = msg_path.read_text(encoding="utf-8")
        lines = [line for line in msg_text.splitlines() if not line.startswith("#")]

        # Allow well-known exceptions that are auto-generated or squashed later
        first = lines[0] if lines else ""
        lowered = first.lower()
        if first.startswith("Merge ") or first.startswith("Revert ") or lowered.startswith("fixup!") or lowered.startswith("squash!"):
            record_telemetry_entry(
                {
                    "source": "commit-msg",
                    "modules_inspected": [],
                    "checks_skipped": ["commit-template"],
                    "skip_reason": "merge_or_fixup",
                },
                command=argv,
                exit_status=0,
                srs_ids=[],
            )
            return 0

        if len(lines) < 3:
            record_telemetry_entry(
                {
                    "source": "commit-msg",
                    "failure_reason": "commit message must have at least three lines",
                    "modules_inspected": [],
                    "checks_skipped": [],
                },
                command=argv,
                exit_status=1,
                srs_ids=[],
            )
            print(
                "ERROR: commit message must have at least three lines",
                file=sys.stderr,
            )
            return 1

        summary, blank, meta = lines[0], lines[1], lines[2]
        if not summary or len(summary) > 50:
            record_telemetry_entry(
                {
                    "source": "commit-msg",
                    "failure_reason": "summary line must be 1-50 characters",
                    "modules_inspected": [],
                    "checks_skipped": [],
                },
                command=argv,
                exit_status=1,
                srs_ids=[],
            )
            print(
                "ERROR: summary line must be 1-50 characters",
                file=sys.stderr,
            )
            return 1
        if blank.strip():
            record_telemetry_entry(
                {
                    "source": "commit-msg",
                    "failure_reason": "second line must be blank",
                    "modules_inspected": [],
                    "checks_skipped": [],
                },
                command=argv,
                exit_status=1,
                srs_ids=[],
            )
            print("ERROR: second line must be blank", file=sys.stderr)
            return 1

        repo_root = REPO_ROOT
        template = _load_template(repo_root)
        pattern = _pattern_from_template(template)
        if not pattern.match(meta):
            os.chdir(repo_root)
            record_telemetry_entry(
                {
                    "source": "commit-msg",
                    "modules_inspected": [],
                    "checks_skipped": [],
                },
                command=argv,
                exit_status=1,
                srs_ids=[],
            )
            print(
                "ERROR: third line must match commit message template",
                file=sys.stderr,
            )
            return 1

        found_raw = re.findall(fr"({SRS_ID_RE})(?:@({VER_RE}))?", meta)
        known_ids, spec_map = _load_srs_registry(repo_root)
        updated: list[tuple[str, str]] = []
        for raw_id, ver in found_raw:
            id_ = normalize_id(raw_id)
            specs = spec_map.get(id_, [])
            version = ver
            if not version:
                versions = [v for _, v in specs if v]
                if versions:
                    version = max(versions, key=_version_key)
            updated.append((id_, version))

        meta_match = re.match(
            r"(codex:\s*(?:spec|impl|both)\s*\|\s*SRS:\s*)([^|]*)(\|\s.*)?",
            meta,
        )
        if meta_match:
            prefix, _, suffix = meta_match.groups()
            suffix = f" {suffix}" if suffix else ""
            new_ids = [f"{i}@{v}" if v else i for i, v in updated]
            new_meta = prefix + ", ".join(new_ids) + suffix
            if new_meta != meta:
                updated_text = msg_text.replace(meta, new_meta, 1)
                msg_path.write_text(updated_text, encoding="utf-8")
                meta = new_meta
                msg_text = updated_text

        errors: list[str] = []
        for id_, ver in updated:
            specs = spec_map.get(id_, [])
            if id_ not in known_ids:
                errors.append(f"unknown SRS ID: {id_}")
            elif len(specs) > 1:
                if ver:
                    if not any(v == ver for _, v in specs):
                        locs = ", ".join(f"{p}@{v}" if v else p for p, v in specs)
                        errors.append(
                            f"SRS ID {id_}@{ver} not found; available: {locs}"
                        )
                else:
                    locs = ", ".join(f"{p}@{v}" if v else p for p, v in specs)
                    errors.append(
                        f"SRS ID {id_} maps to multiple specs: {locs}; specify version"
                    )
            elif ver and specs:
                spec_ver = specs[0][1]
                if spec_ver and ver != spec_ver:
                    errors.append(
                        f"SRS ID {id_}@{ver} version mismatch; spec version {spec_ver}"
                    )

        if errors:
            os.chdir(repo_root)
            record_telemetry_entry(
                {
                    "source": "commit-msg",
                    "modules_inspected": [],
                    "checks_skipped": [],
                },
                command=argv,
                exit_status=1,
                srs_ids=[],
            )
            for err in errors:
                print("ERROR:", err, file=sys.stderr)
            return 1

        return 0
    except Exception as exc:
        record_telemetry_entry(
            {
                "source": "commit-msg",
                "modules_inspected": [],
                "checks_skipped": [],
            },
            command=argv,
            exit_status=1,
            srs_ids=[],
            exception_type=type(exc).__name__,
            exception_message=str(exc),
        )
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))

