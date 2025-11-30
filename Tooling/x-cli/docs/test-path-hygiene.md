# Test Path Hygiene

Tests must resolve paths from the repository root instead of the current working directory when reading from the `docs/` directory. The `scripts/check_test_path_hygiene.py` script scans for CWD-based references such as `Path("docs/...")`, `open("docs/...")`, or `open(Path("docs/..."))`, and it detects nested or symlink-based `docs/` references.

To access documentation in tests, compute the repository root from the test file:

```python
from pathlib import Path
repo_root = Path(__file__).resolve().parents[1]
repo_root / "docs" / "file.txt"
```

The CI workflow `.github/workflows/test-path-hygiene.yml` shall run this check on pull requests that modify tests.
