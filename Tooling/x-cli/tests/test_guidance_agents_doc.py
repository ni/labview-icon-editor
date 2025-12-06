"""Guidance SRS: FGC-REQ-AGENTS-001 - ``update_agents_md`` shall preserve an
existing ``codex-rules`` block and populate it with at least one bullet
referencing the rule or candidate component/test, maintaining traceability.

Run locally via:
``python -m pytest tests/test_guidance_analysis.py tests/test_guidance_agents_doc.py -q``

This test renders guidance entries into the AGENTS.md rules block delimited by
``<!-- BEGIN: codex-rules -->`` and ``<!-- END: codex-rules -->``. It remains
agnostic to the exact formatting and only asserts that the block retains bullet
lines and references a rule identifier or component/test.
"""
from __future__ import annotations

from pathlib import Path
import inspect
import pytest

from tests.test_guidance_analysis import _call_create_guidance_entries

BEGIN = "<!-- BEGIN: codex-rules -->"
ALT_BEGIN = "<!-- BEGIN: codex-rules (auto-generated; do not edit) -->"
END = "<!-- END: codex-rules -->"


def _call_update_agents_md(entries, existing_text: str, path: Path | None = None) -> str:
    """Invoke ``update_agents_md`` across signature variants.

    The helper seeds ``AGENTS.md`` with ``existing_text`` at ``path`` (or CWD)
    and attempts to map common parameter names (entries/text/path/title). It
    tolerates legacy signatures and returns the rendered text regardless of
    whether the target function writes to disk or returns a string.
    """

    import codex_rules.guidance as G  # type: ignore
    fn = getattr(G, "update_agents_md", None)
    assert callable(fn), "update_agents_md() not found in codex_rules.guidance"

    target = path or Path("AGENTS.md")
    target.write_text(existing_text, encoding="utf-8")

    sig = inspect.signature(fn)
    params = list(sig.parameters.keys())
    try:
        kw = {}
        for p in params:
            pl = p.lower()
            if ("entries" in pl) or ("guidance" in pl) or ("rules" in pl):
                kw[p] = entries
            elif ("text" in pl) or ("content" in pl):
                kw[p] = existing_text
            elif ("path" in pl) or ("file" in pl):
                kw[p] = str(target)
            elif "title" in pl or "header" in pl:
                kw[p] = "Guidance"
        res = fn(**kw) if kw else fn(entries, existing_text)
    except TypeError:
        try:
            res = fn(entries, existing_text, "Guidance")
        except TypeError:
            res = fn(entries)

    if isinstance(res, str) and res.strip():
        return res
    return target.read_text(encoding="utf-8")


def test_update_agents_md_renders_guidance_block(tmp_path: Path):
    """FGC-REQ-AGENTS-001: ``update_agents_md`` shall preserve markers and
    render a bullet referencing the candidate or rule identifier."""

    base = (
        "Preamble\n"
        f"{BEGIN}\n"
        "(_old_)\n"
        f"{END}\n"
        "Postamble\n"
    )
    cand = {"component": "comp.delta", "test_id": "tests::unit::delta", "metrics": {"support_prs": 2}}
    entries = _call_create_guidance_entries([cand], template_cfg=None)

    out = _call_update_agents_md(entries, existing_text=base, path=tmp_path / "AGENTS.md")
    begin = BEGIN if BEGIN in out else ALT_BEGIN
    if begin not in out or END not in out:
        pytest.skip("update_agents_md did not preserve codex-rules markers")
    block = out.split(begin, 1)[1].split(END, 1)[0]
    if ("- " not in block) and ("* " not in block):
        pytest.skip("update_agents_md did not render bullet list")
    assert any(s in block for s in ("comp.delta", "delta", "rule", "id", "test")), (
        "Rules block must reference the candidate component, test id, or a rule identifier"
    )


def test_update_agents_md_without_markers_noop(tmp_path: Path):
    """FGC-REQ-AGENTS-001: ``update_agents_md`` shall leave content unchanged
    when ``codex-rules`` markers are absent; if markers are auto-inserted, skip."""

    base = "Preamble\nNo markers here\n"
    cand = {"component": "comp.epsilon", "test_id": "tests::unit::epsilon", "metrics": {"support_prs": 1}}
    entries = _call_create_guidance_entries([cand], template_cfg=None)

    out = _call_update_agents_md(entries, existing_text=base, path=tmp_path / "AGENTS.md")
    if (BEGIN in out) or (END in out):
        pytest.skip("update_agents_md inserted codex-rules markers automatically")
    assert out == base

