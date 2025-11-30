from codex_rules.warnings import build_warnings


def test_build_warnings_matches_components():
    guidance = [
        {"component": "cli", "command": "dotnet test", "test_id": "CI-101"},
        {"component": "api", "command": "pytest", "test_id": "PY-10"},
    ]

    warnings = build_warnings(["cli", "docs", "api"], guidance)

    assert len(warnings) == 2
    assert "codex-rules" in warnings[0]
    assert "dotnet test" in warnings[0]
    assert "pytest" in warnings[1]
