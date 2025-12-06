import runpy

import pytest

from codex_rules.providers import __all__ as provider_all
from codex_rules.providers import none


def test_run_module_invokes_cli(monkeypatch):
    called = []

    def fake_main() -> None:
        called.append(True)

    monkeypatch.setattr("codex_rules.cli.main", fake_main)

    runpy.run_module("codex_rules.__main__", run_name="__main__")

    assert called == [True]


def test_none_provider_is_no_op():
    assert provider_all == ["none"]
    assert none.post_comment("anything") is None
