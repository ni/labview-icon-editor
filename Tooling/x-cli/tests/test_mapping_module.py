import json
import sys
import types

from codex_rules.mapping import ComponentMapping


def test_component_mapping_uses_yaml_when_available(tmp_path, monkeypatch):
    mapping_path = tmp_path / "components.yml"
    mapping_path.write_text("ignored", encoding="utf-8")

    fake_yaml = types.ModuleType("yaml")

    def safe_load(_):
        return {
            "components": {
                "api": {
                    "globs": ["src/api/*.py"],
                    "default_preempt_command": "pytest -m api",
                },
                "docs": {"globs": ["docs/**"]},
            }
        }

    fake_yaml.safe_load = safe_load

    monkeypatch.setitem(sys.modules, "yaml", fake_yaml)

    mapping = ComponentMapping(mapping_path)

    assert mapping.component_for_path("src/api/service.py") == "api"
    assert mapping.component_for_path("docs/guide.md") == "docs"
    assert mapping.component_for_path("unknown/file.txt") == "unknown"
    assert mapping.default_command_for("api") == "pytest -m api"


def test_component_mapping_json_fallback(tmp_path, monkeypatch):
    if "yaml" in sys.modules:
        monkeypatch.delitem(sys.modules, "yaml", raising=False)

    mapping_path = tmp_path / "components.yml"
    mapping_path.write_text(
        json.dumps(
            {
                "components": {
                    "core": {"globs": ["src/core/*"]},
                }
            }
        ),
        encoding="utf-8",
    )

    mapping = ComponentMapping(mapping_path)

    assert mapping.component_for_path("src/core/main.c") == "core"
    assert mapping.default_command_for("core") is None
