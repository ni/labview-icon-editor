import importlib
import os
import shutil
import sys
import time
from pathlib import Path

import pytest

pytest_plugins = ("tests.telemetry_plugin",)

_REPO_ROOT = Path(__file__).resolve().parents[1]
_PYTEST_TMP_ROOT: Path | None = None
_CACHE_DIR: Path | None = None

if "PYTEST_DEBUG_TEMPROOT" in os.environ:
    _PYTEST_TMP_ROOT = Path(os.environ["PYTEST_DEBUG_TEMPROOT"])
else:
    candidate = _REPO_ROOT / ".pytest_tmp"
    try:
        candidate.mkdir(parents=True, exist_ok=True)
    except PermissionError:
        _PYTEST_TMP_ROOT = None
    else:
        os.environ["PYTEST_DEBUG_TEMPROOT"] = str(candidate)
        _PYTEST_TMP_ROOT = candidate

if _PYTEST_TMP_ROOT is not None:
    cache_candidate = _PYTEST_TMP_ROOT / "cache"
    try:
        cache_candidate.mkdir(parents=True, exist_ok=True)
    except PermissionError:
        _CACHE_DIR = None
    else:
        _CACHE_DIR = cache_candidate


def _repo_root() -> Path:
    """Return repository root (tests/ is one level below)."""
    return _REPO_ROOT


def pytest_configure(config):
    config.addinivalue_line(
        "markers",
        "external_dep(name): marks test as requiring external dependency 'name'",
    )
    if _CACHE_DIR is not None:
        cache = getattr(config, "cache", None)
        if cache is not None:
            cache._cachedir = _CACHE_DIR


@pytest.fixture(autouse=True)
def isolated_cwd(tmp_path_factory, monkeypatch):
    """
    Per-test isolation:
    - chdir into a unique tmp dir
    - copy repo docs/ into tmp so tests can read/write sandboxed documentation
    - export FAKEG_REPO_ROOT=tmp (propagates to subprocesses)
    """
    repo_root = _repo_root()
    tmp_path = tmp_path_factory.mktemp("cwd")
    monkeypatch.chdir(tmp_path)
    # prepare sandboxed docs
    src_docs = repo_root / "docs"
    if src_docs.exists():
        for _ in range(3):
            try:
                shutil.copytree(
                    src_docs,
                    tmp_path / "docs",
                    dirs_exist_ok=True,
                    ignore=shutil.ignore_patterns("_template.md", "core.md"),
                )
                break
            except (FileNotFoundError, shutil.Error):
                time.sleep(0.1)
    # keep pyproject for tests that read it
    pyproject = repo_root / "pyproject.toml"
    if pyproject.exists():
        shutil.copy2(pyproject, tmp_path / "pyproject.toml")
    # env for code/tests that honor FAKEG_REPO_ROOT
    monkeypatch.setenv("FAKEG_REPO_ROOT", str(tmp_path))
    # helpful debug breadcrumb
    print(f"[isolation] tmp cwd: {tmp_path}")
    yield


@pytest.fixture
def reset_modules():
    """
    Reset historically stateful modules before/after the test.
    Add this fixture in tests that touch CLI or memory subsystems.
    """
    targets = []
    for name in ("codex_rules.memory", "cli"):
        if name in sys.modules:
            targets.append(sys.modules[name])
    try:
        for mod in targets:
            importlib.reload(mod)
        yield
    finally:
        for mod in targets:
            importlib.reload(mod)


@pytest.fixture
def restore_repo_telemetry(monkeypatch):
    repo_root = _repo_root()
    monkeypatch.chdir(repo_root)
    monkeypatch.setenv("FAKEG_REPO_ROOT", str(repo_root))
    telemetry = repo_root / ".codex" / "telemetry.json"
    if not telemetry.exists():
        yield
        return
    orig = telemetry.read_text(encoding="utf-8")
    yield
    telemetry.write_text(orig, encoding="utf-8")


@pytest.fixture
def temp_dir(tmp_path_factory) -> Path:
    """Return a unique temporary directory for test isolation."""
    return tmp_path_factory.mktemp("tmp")
