"""Tests for ruamel.yaml round-trip behavior (FGC-REQ-DEV-001)."""

from io import StringIO

import pytest
from ruamel.yaml import YAML, YAMLError


def test_ruamel_preserves_comments():
    """FGC-REQ-DEV-001: ruamel.yaml shall preserve comments during round-trip."""

    yaml = YAML(typ="rt")
    source = "# header\nkey: value  # inline\n"
    data = yaml.load(source)
    buf = StringIO()
    yaml.dump(data, buf)
    output = buf.getvalue()
    assert "# header" in output
    assert "# inline" in output


def test_ruamel_handles_basic_types():
    """FGC-REQ-DEV-001: ruamel.yaml shall preserve data types and comments."""

    yaml = YAML(typ="rt")
    source = (
        "# numbers and bool\n"
        "count: 1\n"
        "flag: true\n"
        "list:\n"
        "  - item\n"
        "  - 2\n"
    )
    data = yaml.load(source)
    assert data["count"] == 1
    assert data["flag"] is True
    assert data["list"] == ["item", 2]
    buf = StringIO()
    yaml.dump(data, buf)
    output = buf.getvalue()
    assert "# numbers and bool" in output
    assert "count: 1" in output
    assert "flag: true" in output


def test_ruamel_invalid_yaml_raises_error():
    """FGC-REQ-DEV-001: ruamel.yaml shall raise an error on malformed YAML."""

    yaml = YAML(typ="rt")
    with pytest.raises(YAMLError):
        yaml.load("key: value:")


def test_ruamel_handles_anchors_and_aliases():
    """FGC-REQ-DEV-001: ruamel.yaml shall retain anchors and aliases."""

    yaml = YAML(typ="rt")
    source = (
        "defaults: &defaults\n"
        "  a: 1\n"
        "config:\n"
        "  <<: *defaults\n"
        "  b: 2\n"
    )
    data = yaml.load(source)
    assert data["config"]["a"] == 1
    buf = StringIO()
    yaml.dump(data, buf)
    output = buf.getvalue()
    assert "&defaults" in output
    assert "*defaults" in output


def test_ruamel_handles_multi_documents():
    """FGC-REQ-DEV-001: ruamel.yaml shall parse multiple documents."""

    yaml = YAML(typ="rt")
    source = "---\nfirst: 1\n---\nsecond: 2\n"
    docs = list(yaml.load_all(source))
    assert docs[0]["first"] == 1
    assert docs[1]["second"] == 2
    buf = StringIO()
    yaml.dump_all(docs, buf)
    output = buf.getvalue()
    assert "first: 1" in output
    assert "second: 2" in output


def test_ruamel_disallows_duplicate_keys_by_default():
    """FGC-REQ-DEV-001: ruamel.yaml shall reject duplicate mapping keys."""

    yaml = YAML(typ="rt")
    source = "a: 1\na: 2\n"
    with pytest.raises(YAMLError):
        yaml.load(source)

    yaml = YAML(typ="rt")
    yaml.allow_duplicate_keys = True
    data = yaml.load(source)
    assert data["a"] == 1

