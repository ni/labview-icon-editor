import json

from codex_rules import compliance


def test_load_manifest_from_json_object(tmp_path):
    manifest = tmp_path / "commands.json"
    manifest.write_text(json.dumps({"ran": ["  dotnet build ", "pytest -q"]}), encoding="utf-8")

    result = compliance.load_manifest(str(manifest))

    assert result == ["dotnet build", "pytest -q"]


def test_load_manifest_from_ndjson_and_text(tmp_path):
    manifest = tmp_path / "commands.ndjson"
    manifest.write_text(
        "\n".join(
            [
                json.dumps({"cmd": "DotNet Build"}),
                json.dumps({"cmd": "dotnet test"}),
                "# ignore",
                "pytest -q",
            ]
        ),
        encoding="utf-8",
    )

    result = compliance.load_manifest(str(manifest))

    assert result == ["dotnet build", "dotnet test", "pytest -q"]


def test_check_all_and_any_modes():
    required = ["dotnet build", "npm test"]
    executed = ["dotnet build -c Release", "npm ci", "npm test --watch"]

    compliant, missing = compliance.check(required, executed)
    assert compliant is True
    assert missing == []

    compliant_any, missing_any = compliance.check(required, ["npm ci"], mode="any")
    assert compliant_any is False
    assert missing_any == required
