# Prepare LabVIEW Source 📁

Runs **`Prepare_LabVIEW_source.ps1`** to unpack and configure project sources before builds.

## Inputs
| Name | Required | Example | Description |
|------|----------|---------|-------------|
| `supported_bitness` | **Yes** | `32` or `64` | Target LabVIEW bitness. |
| `repository_path` | **Yes** | `${{ github.workspace }}` | Repository root path (used to resolve LabVIEW version from the VIPB). |
| `labview_project` | **Yes** | `lv_icon_editor` | Project name (no extension). |
| `build_spec` | **Yes** | `Editor Packed Library` | Build specification name. |

## Quick-start
```yaml
- uses: ./scripts/prepare-labview-source
  with:
    supported_bitness: 64
    repository_path: ${{ github.workspace }}
    labview_project: lv_icon_editor
    build_spec: "Editor Packed Library"
```

## License
This directory inherits the root repository’s license (MIT, unless otherwise noted).

