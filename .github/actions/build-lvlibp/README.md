# Build Packed Library 📦

Compatibility wrapper for packed-library builds.

Canonical entrypoint:
- Use **`build-project-spec`** action (`.github/actions/build-project-spec`), which calls `.github/actions/build-lvlibp/BuildProjectSpec.ps1`.

Behavior notes:
- A staged LabVIEWCLI `MassCompile` runs first against `Test\Templates` (or `TARGET_DIR` / `TARGET_DIR_REL`) with exclusions from `CONTAINER_PARITY_EXCLUDE_FILES` (default: `Polymorphic Template.vi`).
- Icon Editor sources are synchronized into the resolved LabVIEW install (`resource\plugins` and `vi.lib\LabVIEW Icon API`) before build-spec execution.
- `major`, `minor`, `patch`, and `build` are stamped into the `Editor Packed Library` build spec before execution.
- The script restores `lv_icon_editor.lvproj` from backup after the build step.
- LabVIEWCLI `-PortNumber` is resolved from `LVIE_LABVIEWCLI_PORT_<bitness>`, then `LVIE_LABVIEWCLI_PORT`, then `LabVIEW.ini` (`server.tcp.port`), then default `3363`.
- LabVIEWCLI captured logs are written under `builds/logs` using `labviewcli-masscompile-*` and `labviewcli-executebuildspec-*` names.
- `Build_lvlibp.ps1` is deprecated and retained for compatibility for two release cycles.

## Inputs
| Name | Required | Example | Description |
|------|----------|---------|-------------|
| `labview_version` | No | `2021` | LabVIEW 2021 (21.0) to use. Defaults to `.lvversion` and fails if it conflicts. |
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

