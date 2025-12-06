"""Tests model version control guidelines (FGC-REQ-DEV-007)."""
from pathlib import Path


def test_model_version_control_doc_present_and_valid() -> None:
    """Ensure version-control guidance exists and uses MiB units."""
    repo_root = Path(__file__).resolve().parents[1]
    doc_path = repo_root / "docs" / "model-version-control.md"
    text = doc_path.read_text(encoding="utf-8")

    # SRS reference and threshold phrases
    assert "FGC-REQ-DEV-007" in text
    assert "Small metadata" in text
    assert "≤1 MiB" in text
    assert "Large artifacts" in text
    assert "100 MiB" in text

    # Example section is present
    assert "Example" in text or "Examples" in text

    # Language hygiene: forbid decimal MB units
    assert " MB" not in text and "(MB" not in text

