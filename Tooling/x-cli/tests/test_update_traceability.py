"""Tests for traceability updater script (FGC-REQ-DEV-001)."""

import os
import sys
from pathlib import Path

from ruamel.yaml import YAML

from tests.TestUtil.run import run

SCRIPT_SRC = Path(__file__).resolve().parent.parent / "scripts" / "update_traceability.py"


def create_repo(tmp_path):
    repo = tmp_path / "repo"
    repo.mkdir()
    (repo / "scripts").mkdir()
    (repo / "docs" / "srs").mkdir(parents=True)
    (repo / "scripts" / "update_traceability.py").write_text(
        SCRIPT_SRC.read_text(encoding="utf-8"), encoding="utf-8"
    )
    spec = repo / "docs" / "srs" / "FGC-REQ-DEV-001.md"
    spec.write_text(
        "# FGC-REQ-DEV-001 — Traceability updater\nVersion: 1.0\nDummy.\n",
        encoding="utf-8",
    )
    trace = repo / "docs" / "traceability.yaml"
    trace.write_text("requirements: []\n", encoding="utf-8")
    run(["git", "init"], cwd=repo)
    run(["git", "config", "user.email", "test@example.com"], cwd=repo)
    run(["git", "config", "user.name", "Tester"], cwd=repo)
    run(["git", "add", "."], cwd=repo)
    run(["git", "commit", "-m", "init"], cwd=repo)
    return repo, trace


def test_updates_traceability(tmp_path):
    repo, trace = create_repo(tmp_path)
    (repo / "dummy.txt").write_text("x", encoding="utf-8")
    run(["git", "add", "dummy.txt"], cwd=repo)
    run(["git", "commit", "-m", "Ref FGC-REQ-DEV-001"], cwd=repo)
    commit_hash = run(["git", "rev-parse", "HEAD"], cwd=repo).stdout.strip()
    run([sys.executable, str(repo / "scripts" / "update_traceability.py")], cwd=repo)
    yaml = YAML(typ="rt")
    data = yaml.load(trace.read_text(encoding="utf-8"))
    entry = next(e for e in data["requirements"] if e["id"] == "FGC-REQ-DEV-001")
    assert commit_hash in entry["commits"]


def test_updates_traceability_from_pr_body(tmp_path):
    repo, trace = create_repo(tmp_path)
    run(["git", "commit", "--allow-empty", "-m", "no refs"], cwd=repo)
    commit_hash = run(["git", "rev-parse", "HEAD"], cwd=repo).stdout.strip()
    env = {**os.environ, "PR_BODY": "Implements FGC-REQ-DEV-001"}
    run(
        [sys.executable, str(repo / "scripts" / "update_traceability.py")],
        cwd=repo,
        env=env,
    )
    yaml = YAML(typ="rt")
    data = yaml.load(trace.read_text(encoding="utf-8"))
    entry = next(e for e in data["requirements"] if e["id"] == "FGC-REQ-DEV-001")
    assert commit_hash in entry["commits"]

