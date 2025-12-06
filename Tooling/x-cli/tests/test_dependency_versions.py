import tomllib
from pathlib import Path
from importlib import metadata
from packaging.requirements import Requirement


def test_pyproject_dependencies_installed_and_pinned():
    data = tomllib.loads(Path('pyproject.toml').read_text())
    deps = data.get('project', {}).get('dependencies', [])
    missing = []
    mismatched = []
    for dep in deps:
        req = Requirement(dep)
        try:
            installed = metadata.version(req.name)
        except metadata.PackageNotFoundError:
            missing.append(req.name)
            continue
        if installed not in req.specifier:
            mismatched.append((req.name, installed, str(req.specifier)))
    assert not missing, f"Missing dependencies: {', '.join(missing)}"
    assert not mismatched, \
        'Version mismatches: ' + ', '.join(f"{n} {v} !{s}" for n, v, s in mismatched)
