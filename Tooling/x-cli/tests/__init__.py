"""Test package for x-cli.

This file enables relative imports within the ``tests`` package.
"""

from __future__ import annotations

import sys
from pathlib import Path

# Ensure repository and ``tests`` directories are importable without manual
# PYTHONPATH configuration. This allows helper modules like ``module_loader``
# to be imported when running tests from any location.
_TESTS_DIR = Path(__file__).resolve().parent
_REPO_ROOT = _TESTS_DIR.parent
for _path in (_TESTS_DIR, _REPO_ROOT):
    sys.path.insert(0, str(_path))

