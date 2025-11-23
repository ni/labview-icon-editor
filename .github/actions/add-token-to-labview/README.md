# Add LabVIEW INI Token ⚙️

Invoke **`AddTokenToLabVIEW.ps1`** through a composite action to add a `Localhost.LibraryPaths` token to the LabVIEW INI file via **g-cli**.

## Inputs
| Name | Required | Example | Description |
|------|----------|---------|-------------|
| `supported_bitness` | **Yes** | `32` or `64` | Target LabVIEW bitness. |
| `repository_path` | **Yes** | `${{ github.workspace }}` | Repository root on disk; version is resolved from the repo VIPB. |

## Quick-start
```yaml
- uses: ./.github/actions/add-token-to-labview
  with:
    supported_bitness: 64
    repository_path: ${{ github.workspace }}
```

## License
This directory inherits the root repository’s license (MIT, unless otherwise noted).
