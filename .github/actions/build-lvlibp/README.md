# Build Packed Library 📦

Call **`Build_lvlibp.ps1`** to compile the editor packed library using g-cli.

## Inputs
| Name | Required | Example | Description |
|------|----------|---------|-------------|
| `repository_path` | **Yes** | `${{ github.workspace }}` | Workspace root; version is resolved from the repo VIPB. |
| `supported_bitness` | **Yes** | `32` or `64` | Target LabVIEW bitness. |
| `major` | **Yes** | `1` | Major version component. |
| `minor` | **Yes** | `0` | Minor version component. |
| `patch` | **Yes** | `0` | Patch version component. |
| `build` | **Yes** | `1` | Build number component. |
| `commit` | **Yes** | `abcdef` | Commit identifier. |

## Quick-start
```yaml
- uses: ./.github/actions/build-lvlibp
  with:
    supported_bitness: 64
    repository_path: ${{ github.workspace }}
    major: 1
    minor: 0
    patch: 0
    build: 1
    commit: ${{ github.sha }}
```

## License
This directory inherits the root repository’s license (MIT, unless otherwise noted).
