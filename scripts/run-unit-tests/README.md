# Run Unit Tests ✅

Invoke **`RunUnitTests.ps1`** to execute LabVIEW unit tests and output a result table.

## Inputs
| Name | Required | Example | Description |
|------|----------|---------|-------------|
| `repository_path` | **Yes** | `${{ github.workspace }}` | Workspace root; used to locate the `.lvproj`. |
| `supported_bitness` | **Yes** | `32` or `64` | Target LabVIEW bitness. |
| `labview_version` | **No** | `${{ needs.resolve-labview-version.outputs.minimum_supported_lv_version }}` | LabVIEW version **must** be provided either via this input or the `LABVIEW_VERSION` environment variable. The action fails early when neither is set. |

## Quick-start
```yaml
- uses: ./scripts/run-unit-tests
  with:
    repository_path: ${{ github.workspace }}
    supported_bitness: 64
    labview_version: ${{ needs.resolve-labview-version.outputs.minimum_supported_lv_version }}
```

## How version resolution flows through CI

1. The `resolve-labview-version` job normalizes the minimum LabVIEW version from `scripts/get-package-lv-version.ps1` and exposes it as `needs.resolve-labview-version.outputs.minimum_supported_lv_version`.
2. Downstream jobs export that value to `LABVIEW_VERSION` and pass it explicitly into this action’s `labview_version` input (see `ci.yml`).
3. `RunUnitTests.ps1` consumes only the supplied version; it does **not** recalculate the version and throws if the workflow omits it.

## License
This directory inherits the root repository’s license (MIT, unless otherwise noted).

