from __future__ import annotations

from pathlib import Path


def test_doc_008_render_scripts_present() -> None:
    """FGC-REQ-DOC-008: Publish SRS as HTML and PDF.
    Verify renderer scripts exist and contain expected behaviors.
    """
    repo = Path(__file__).resolve().parents[1]
    html = repo / "scripts/render_srs_html.py"
    pdf = repo / "scripts/render_srs_pdf.py"
    assert html.exists(), "render_srs_html.py missing"
    assert pdf.exists(), "render_srs_pdf.py missing"
    t_html = html.read_text(encoding="utf-8")
    t_pdf = pdf.read_text(encoding="utf-8")
    assert "render_site()" in t_html or "render_site" in t_html
    assert "wkhtmltopdf" in t_pdf and "srs.pdf" in t_pdf


def test_gov_010_srs_maintenance_workflow_keys() -> None:
    """FGC-REQ-GOV-010: SRS maintenance automation exists with key steps."""
    repo = Path(__file__).resolve().parents[1]
    wf = repo / ".github/workflows/srs-maintenance.yml"
    assert wf.exists(), "srs-maintenance workflow missing"
    t = wf.read_text(encoding="utf-8")
    for snippet in (
        "Build SRS index",
        "Generate VCRM",
        "Compute 29148 compliance",
        "Smoke test (objective checks)",
        "Upload artifacts",
    ):
        assert snippet in t, f"Expected step '{snippet}' in srs-maintenance workflow"


def test_doc_009_pr_template_has_reflection_section() -> None:
    """FGC-REQ-DOC-009: PR template prompts reflection and is non-blocking."""
    repo = Path(__file__).resolve().parents[1]
    pr_tpl = repo / ".github/PULL_REQUEST_TEMPLATE.md"
    assert pr_tpl.exists(), "PR template missing"
    text = pr_tpl.read_text(encoding="utf-8")
    assert "Session Reflection" in text, "PR template missing Reflection section"
    assert ("non-blocking" in text or "nonblocking" in text), "Reflection must be noted non-blocking"
    assert "Cross-Agent Telemetry Recommendation" in text


def test_doc_009_adr_accepted() -> None:
    """FGC-REQ-DOC-009: ADR-0024 exists and is Accepted."""
    repo = Path(__file__).resolve().parents[1]
    adr = repo / "docs/adr/0024-cross-agent-session-reflection.md"
    assert adr.exists(), "ADR 0024 missing"
    text = adr.read_text(encoding="utf-8")
    assert "Status: Accepted" in text, "ADR 0024 not marked Accepted"
    assert "Cross-Agent Session Reflection" in text
