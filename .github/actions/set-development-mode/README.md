# Set Development Mode 🔧

Execute **`Set_Development_Mode.ps1`** to prepare the repository for active development.

## Inputs
| Name | Required | Example | Description |
|------|----------|---------|-------------|
| `labview_version` | No | `2021` | LabVIEW version (year or numeric). Defaults to `.lvversion` and fails if it conflicts. |
| `supported_bitness` | **Yes** | `64` | LabVIEW bitness (32 or 64). |
| `repo_root` | No | `${{ github.workspace }}` | Repository root path (optional). |
| `use_labview` | No | `false` | Use LabVIEW + g-cli instead of the no-LabVIEW path. |

## Quick-start
```yaml
- uses: ./.github/actions/set-development-mode
  with:
    supported_bitness: 64
    repo_root: ${{ github.workspace }}
    use_labview: false
```

## License
This directory inherits the root repository’s license (MIT, unless otherwise noted).
