"""Tests for canonical documentation stubs and anchors."""

from pathlib import Path
import importlib.util
import subprocess, sys


def test_waterfall_canonical_exists_and_has_required_anchors():
    repo_root = Path(__file__).resolve().parents[1]
    canon = repo_root / "docs" / "WATERFALL.md"
    assert canon.exists()
    t = canon.read_text(encoding="utf-8")
    for anchor in ("ANCHOR:final-orchestration", "ANCHOR:criteria", "ANCHOR:workflows"):
        assert anchor in t


def test_root_waterfall_stub_is_optional():
    repo_root = Path(__file__).resolve().parents[1]
    stub = repo_root / "WATERFALL.md"
    # Either absent or present as an exact stub is acceptable
    if stub.exists():
        t = stub.read_text(encoding="utf-8").strip()
        # Accept any stub content that clearly points to docs/WATERFALL.md
        assert "docs/WATERFALL.md" in t


def test_agents_stub_points_to_root():
    repo_root = Path(__file__).resolve().parents[1]
    stub = repo_root / "docs" / "AGENTS.md"
    t = stub.read_text(encoding="utf-8").strip()
    mod = _load_module(repo_root)
    assert t == mod.EXPECTED_AGENTS_STUB.strip()


def test_canonical_check_script_succeeds():
    repo_root = Path(__file__).resolve().parents[1]
    script = repo_root / "scripts" / "check_docs_canonical.py"
    result = subprocess.run([sys.executable, str(script)], capture_output=True, cwd=repo_root)
    assert result.returncode == 0, result.stdout.decode() + result.stderr.decode()


def _load_module(repo_root: Path):
    spec = importlib.util.spec_from_file_location(
        "check_docs_canonical", repo_root / "scripts" / "check_docs_canonical.py"
    )
    mod = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(mod)
    return mod
