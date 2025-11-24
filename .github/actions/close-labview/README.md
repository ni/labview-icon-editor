# Close LabVIEW 💤

Run **`Close_LabVIEW.ps1`** to terminate a running LabVIEW instance via g-cli.

## Inputs
| Name | Required | Example | Description |
|------|----------|---------|-------------|
| `repository_path` | **Yes** | `${{ github.workspace }}` | Workspace root; used to resolve LabVIEW version from the repo VIPB. |
| `supported_bitness` | **Yes** | `32` or `64` | Target LabVIEW bitness. |

## Quick-start
```yaml
- uses: ./.github/actions/close-labview
  with:
    repository_path: ${{ github.workspace }}
    supported_bitness: 64
```

## License
This directory inherits the root repository’s license (MIT, unless otherwise noted).
