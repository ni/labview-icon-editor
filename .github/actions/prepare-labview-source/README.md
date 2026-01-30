# Prepare LabVIEW Source 📁

Runs **`Prepare_LabVIEW_source.ps1`** to unpack and configure project sources before builds.

## Inputs
| Name | Required | Example | Description |
|------|----------|---------|-------------|
| `minimum_supported_lv_version` | **Yes** | `2021` | LabVIEW 2021 (21.0). |
| `supported_bitness` | **Yes** | `32` or `64` | Target LabVIEW bitness. |
| `repo_root` | No | `${{ github.workspace }}` | Repository root path (optional). |

## Quick-start
```yaml
- uses: ./.github/actions/prepare-labview-source
  with:
    minimum_supported_lv_version: 2021
    supported_bitness: 64
    repo_root: ${{ github.workspace }}
```

## License
This directory inherits the root repository’s license (MIT, unless otherwise noted).

