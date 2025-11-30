"""FGC-REQ-DEV-001: Verify ruamel.yaml version matches expectations."""

from ruamel.yaml import __version__ as ruamel_version


def test_ruamel_yaml_version():
    """ruamel.yaml shall match the pinned 0.18.x series."""
    assert ruamel_version.startswith("0.18."), ruamel_version
