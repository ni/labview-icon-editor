# Modify VIPB Display Info 📝

Execute **`ModifyVIPBDisplayInfo.ps1`** to merge metadata into a `.vipb` file before packaging.

## Inputs
| Name | Required | Example | Description |
|------|----------|---------|-------------|
| `supported_bitness` | **Yes** | `64` | Target LabVIEW bitness. |
| `repo_root` | **Yes** | `${{ github.workspace }}` | Repository root path. |
| `vipb_path` | **Yes** | `Tooling/deployment/NI Icon editor.vipb` | Path to the VIPB file. |
| `labview_version` | **Yes** | `2021` | LabVIEW 2021 (21.0). |
| `labview_minor_revision` | No (defaults to `0`) | `0` | LabVIEW minor revision. |
| `major` | **Yes** | `1` | Major version component. |
| `minor` | **Yes** | `0` | Minor version component. |
| `patch` | **Yes** | `0` | Patch version component. |
| `build` | **Yes** | `1` | Build number component. |
| `commit` | **Yes** | `abcdef` | Commit identifier. |
| `release_notes_file` | **Yes** | `Tooling/deployment/release_notes.md` | Release notes file. |
| `display_information_json` | **Yes** | `'{}'` | JSON for display information. |

## Quick-start
```yaml
- uses: ./.github/actions/modify-vipb-display-info
  with:
    supported_bitness: 64
    repo_root: ${{ github.workspace }}
    vipb_path: Tooling/deployment/NI Icon editor.vipb
    labview_version: 2021
    major: 1
    minor: 0
    patch: 0
    build: 1
    commit: ${{ github.sha }}
    release_notes_file: Tooling/deployment/release_notes.md
    display_information_json: '{}'
```

## License
This directory inherits the root repository’s license (MIT, unless otherwise noted).

