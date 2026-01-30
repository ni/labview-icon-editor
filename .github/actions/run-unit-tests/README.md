# Run Unit Tests ✅

Invoke **`RunUnitTests.ps1`** to execute LabVIEW unit tests and output a result table.

## Inputs
| Name | Required | Example | Description |
|------|----------|---------|-------------|
| `minimum_supported_lv_version` | **Yes** | `2021` | LabVIEW 2021 (21.0). |
| `supported_bitness` | **Yes** | `32` or `64` | Target LabVIEW bitness. |
| `project_path` | **Yes** | `${{ github.workspace }}/lv_icon_editor.lvproj` | Path to the LabVIEW project. |

## Quick-start
```yaml
- uses: ./.github/actions/run-unit-tests
  with:
    minimum_supported_lv_version: 2021
    supported_bitness: 64
    project_path: ${{ github.workspace }}/lv_icon_editor.lvproj
```

## License
This directory inherits the root repository’s license (MIT, unless otherwise noted).

