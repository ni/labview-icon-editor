# Build Packed Library 📦

Call **`Build_lvlibp.ps1`** to compile the editor packed library using g-cli.

## Inputs
| Name | Required | Example | Description |
|------|----------|---------|-------------|
| `minimum_supported_lv_version` | **Yes** | `2021` | LabVIEW 2021 (21.0) to use. |
| `supported_bitness` | **Yes** | `32` or `64` | Target LabVIEW bitness. |
| `repo_root` | **Yes** | `${{ github.workspace }}` | Repository root on disk. |
| `major` | **Yes** | `1` | Major version component. |
| `minor` | **Yes** | `0` | Minor version component. |
| `patch` | **Yes** | `0` | Patch version component. |
| `build` | **Yes** | `1` | Build number component. |
| `commit` | **Yes** | `abcdef` | Commit identifier. |

## Quick-start
```yaml
- uses: ./.github/actions/build-lvlibp
  with:
    minimum_supported_lv_version: 2021
    supported_bitness: 64
    repo_root: ${{ github.workspace }}
    major: 1
    minor: 0
    patch: 0
    build: 1
    commit: ${{ github.sha }}
```

## License
This directory inherits the root repository’s license (MIT, unless otherwise noted).

