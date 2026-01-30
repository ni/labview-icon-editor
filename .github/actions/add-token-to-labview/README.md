# Add LabVIEW INI Token ⚙️

Invoke **`AddTokenToLabVIEW.ps1`** through a composite action to add a `Localhost.LibraryPaths` token to the LabVIEW INI file via **g-cli**.

## Status
This action depends on `Tooling/deployment/Create_LV_INI_Token.vi`, which is not present in this repository. It is not used by the development-mode toggle automation. The dev-mode workflow relies only on `PrepareIESource.vi` and `RestoreSetupLVSource.vi`, which encapsulate the INI token changes.

## Inputs
| Name | Required | Example | Description |
|------|----------|---------|-------------|
| `minimum_supported_lv_version` | **Yes** | `2021` | LabVIEW 2021 (21.0) used by g-cli. |
| `supported_bitness` | **Yes** | `32` or `64` | Target LabVIEW bitness. |
| `repo_root` | **Yes** | `${{ github.workspace }}` | Repository root on disk. |

## Quick-start
```yaml
- uses: ./.github/actions/add-token-to-labview
  with:
    minimum_supported_lv_version: 2021
    supported_bitness: 64
    repo_root: ${{ github.workspace }}
```

## License
This directory inherits the root repository’s license (MIT, unless otherwise noted).

