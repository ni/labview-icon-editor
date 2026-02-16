# Restore LabVIEW Setup ↩️

Run **`RestoreSetupLVSource.ps1`** to restore packaged LabVIEW sources and remove INI tokens.

## Inputs
| Name | Required | Example | Description |
|------|----------|---------|-------------|
| `labview_version` | No | `2021` | LabVIEW 2021 (21.0). Defaults to `.lvversion` and fails if it conflicts. |
| `supported_bitness` | **Yes** | `32` or `64` | Target LabVIEW bitness. |
| `repo_root` | No | `${{ github.workspace }}` | Repository root path (optional). |

## Quick-start
```yaml
- uses: ./.github/actions/restore-setup-lv-source
  with:
    supported_bitness: 64
    repo_root: ${{ github.workspace }}
```

## License
This directory inherits the root repository’s license (MIT, unless otherwise noted).

