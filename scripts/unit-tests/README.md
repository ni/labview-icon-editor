# Unit Tests Wrapper 🧪

Use **`unit_tests.ps1`** to orchestrate setup and LabVIEW unit testing for both bitnesses.

## Inputs
| Name | Required | Example | Description |
|------|----------|---------|-------------|
| `repository_path` | **Yes** | `${{ github.workspace }}` | Repository root path. |

## Quick-start
```yaml
- uses: ./scripts/unit-tests
  with:
    repository_path: ${{ github.workspace }}
```

## License
This directory inherits the root repository’s license (MIT, unless otherwise noted).

