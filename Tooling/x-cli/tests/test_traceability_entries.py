from __future__ import annotations

from pathlib import Path


def test_traceability_includes_new_specs() -> None:
    """Lightweight guard to ensure newly added spec IDs stay mapped.

    This complements scripts/verify_traceability.py by asserting the specific
    IDs we recently introduced remain present with their expected sources.
    """
    repo = Path(__file__).resolve().parents[1]
    trace = (repo / "docs/traceability.yaml").read_text(encoding="utf-8")

    required = {
        "FGC-REQ-QA-002": "docs/srs/FGC-REQ-QA-002.md",
        "FGC-REQ-QA-003": "docs/srs/FGC-REQ-QA-003.md",
        "FGC-REQ-TEL-002": "docs/srs/FGC-REQ-TEL-002.md",
        "FGC-REQ-TEL-003": "docs/srs/FGC-REQ-TEL-003.md",
        "FGC-REQ-DOC-001": "docs/srs/FGC-REQ-DOC-001.md",
    }

    for rid, source in required.items():
        assert rid in trace, f"missing mapping for {rid} in docs/traceability.yaml"
        assert (
            source in trace
        ), f"missing source path for {rid}: expected '{source}'"

