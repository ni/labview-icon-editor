import json
import sys
import types

from codex_rules import config


def test_load_config_returns_defaults_when_missing(tmp_path, monkeypatch):
    missing = tmp_path / "rules.yml"
    monkeypatch.chdir(tmp_path)

    result = config.load_config(str(missing))

    assert result["window_days"] == 30
    assert result["docs"]["file"] == "AGENTS.md"
    assert result["provider"]["type"] == "none"


def test_load_config_merges_json_overrides(tmp_path, monkeypatch):
    overrides = {
        "window_days": 14,
        "docs": {"open_pr": True},
        "provider": {"type": "sqlite"},
    }
    cfg = tmp_path / "rules.json"
    cfg.write_text(json.dumps(overrides), encoding="utf-8")
    monkeypatch.chdir(tmp_path)

    result = config.load_config(str(cfg))

    assert result["window_days"] == 14
    assert result["docs"]["open_pr"] is True
    assert result["min_confidence"] == 0.25  # default preserved
    assert result["provider"]["type"] == "sqlite"


def test_load_config_falls_back_to_pyyaml(tmp_path, monkeypatch):
    cfg = tmp_path / "rules.yml"
    cfg.write_text("window_days: 21\ndocs:\n  bot_name: helper\n", encoding="utf-8")
    monkeypatch.chdir(tmp_path)

    # Simulate ruamel.yaml import present but failing at load()
    fake_ruamel = types.ModuleType("ruamel")
    fake_ruamel_yaml = types.ModuleType("ruamel.yaml")

    class ExplodingYAML:
        def __init__(self, *_, **__):
            pass

        def load(self, _):
            raise RuntimeError("boom")

    def yaml_factory(*_, **__):
        return ExplodingYAML()

    fake_ruamel_yaml.YAML = yaml_factory
    fake_ruamel.yaml = fake_ruamel_yaml

    fake_yaml = types.ModuleType("yaml")

    def safe_load(text):
        return {"window_days": 21, "docs": {"bot_email": "bot@example.com"}}

    fake_yaml.safe_load = safe_load

    monkeypatch.setitem(sys.modules, "ruamel", fake_ruamel)
    monkeypatch.setitem(sys.modules, "ruamel.yaml", fake_ruamel_yaml)
    monkeypatch.setitem(sys.modules, "yaml", fake_yaml)

    result = config.load_config(str(cfg))

    assert result["window_days"] == 21
    assert result["docs"]["bot_email"] == "bot@example.com"
    assert result["min_occurrences"] == 3
