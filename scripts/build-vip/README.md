# Build VI Package 📦

Runs **`build_vip.ps1`** to update a `.vipb` file's display info and build the VI Package via the vipm CLI.

## Inputs
| Name | Required | Example | Description |
|------|----------|---------|-------------|
| `supported_bitness` | **Yes** | `64` | Target LabVIEW bitness. |
| `repository_path` | **Yes** | `${{ github.workspace }}` | Repository root path (used to resolve LabVIEW version from the VIPB). |
| `vipb_path` | No (auto) | _auto-discovered_ | Path to the VIPB file. Leave blank to auto-discover a single `.vipb` under `repository_path`. |
| `labview_minor_revision` | No (defaults to `3`) | `3` | LabVIEW minor revision. |
| `major` | **Yes** | `1` | Major version component. |
| `minor` | **Yes** | `0` | Minor version component. |
| `patch` | **Yes** | `0` | Patch version component. |
| `build` | **Yes** | `1` | Build number component. |
| `commit` | **Yes** | `abcdef` | Commit identifier. |
| `release_notes_file` | **Yes** | `Tooling/deployment/release_notes.md` | Release notes file. |
| `display_information_json` | **Yes** | `'{}'` | JSON for VIPB display information. |

## Quick-start
```yaml
- uses: ./scripts/build-vip
  with:
    supported_bitness: 64
    repository_path: ${{ github.workspace }}
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

