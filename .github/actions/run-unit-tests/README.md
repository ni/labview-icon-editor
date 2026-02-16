# Run Unit Tests ✅

Invoke **`RunUnitTests.ps1`** to execute LabVIEW unit tests via **LabVIEWCLI** (primary) with optional **g-cli** fallback and output a result table.

## Inputs
| Name | Required | Example | Description |
|------|----------|---------|-------------|
| `labview_version` | No | `2021` | LabVIEW 2021 (21.0). Defaults to `.lvversion` and fails if it conflicts. |
| `supported_bitness` | **Yes** | `32` or `64` | Target LabVIEW bitness. |
| `project_path` | **Yes** | `${{ env.REPO_ROOT }}/lv_icon_editor.lvproj` | Absolute path to the LabVIEW project. |
| `enable_gcli_fallback` | No | `false` | Set `true`/`1`/`yes` to allow g-cli fallback when LabVIEWCLI fails. Default is disabled. |
| `lunit_backend` | No | `labviewcli` or `gcli` | Selects primary LUnit backend. Default is `labviewcli`. |

## Quick-start
```yaml
- uses: ./.github/actions/run-unit-tests
  with:
    supported_bitness: 64
    project_path: ${{ env.REPO_ROOT }}/lv_icon_editor.lvproj
```

## Prerequisites
- `LabVIEWCLI` is available on `PATH`.
- `g-cli` is available on `PATH` only if fallback mode is enabled.
- `astemes_lib_lunit` is installed for the selected LabVIEW bitness.
- `astemes_lib_lunit_cli` is installed for LabVIEWCLI mode.
- `sas_workshops_lib_lunit_for_g_cli` is installed for fallback mode.
- Apply `.github/actions/apply-vipc/runner_dependencies.vipc` to install required dependencies.

## Fallback Behavior
- By default, `RunUnitTests.ps1` does **not** fall back to g-cli.
- Enable fallback by passing `-EnableGcliFallback` (or action input `enable_gcli_fallback: true`).
- `ConnectTimeoutMs` applies only when g-cli execution is selected.

## Backend Selection Escape Hatch
`RunUnitTests.ps1` resolves backend mode in this order:
1. `LVIE_LUNIT_BACKEND` (`labviewcli` or `gcli`)
2. `LVIE_FORCE_GCLI_LUNIT` truthy (`1`/`true`/`yes`/`on`) => `gcli`
3. default `labviewcli`

When backend mode is `gcli`, the script skips all LabVIEWCLI path/port/operation resolution and executes `g-cli lunit` directly.

## LabVIEWCLI Port Resolution
`RunUnitTests.ps1` resolves `-PortNumber` in this order:
1. `LVIE_LUNIT_PORT_<BITNESS>` (`LVIE_LUNIT_PORT_64` or `LVIE_LUNIT_PORT_32`)
2. `LVIE_LUNIT_PORT`
3. `server.tcp.port` from `LabVIEW.ini` next to the resolved `LabVIEW.exe`
4. default `3363`

If `server.tcp.enabled` is explicitly false and no `LVIE_LUNIT_PORT*` override is set, the script fails unless g-cli fallback is enabled.

## LabVIEWCLI LUnit Operation Resolution
`RunUnitTests.ps1` resolves the `LUnit` operation root in this order:
1. `LVIE_LUNIT_OPERATION_DIR_<BITNESS>` (`LVIE_LUNIT_OPERATION_DIR_64` or `LVIE_LUNIT_OPERATION_DIR_32`)
2. `LVIE_LUNIT_OPERATION_DIR`
3. default LabVIEW CLI operations directory next to `LabVIEWCLI.exe`
4. candidates derived from VIPM `astemes_lib_lunit_cli/files-installed`

If the resolved root is not the default LabVIEW CLI operations directory, the script passes `-AdditionalOperationDirectory`.
If no usable `LUnit` operation directory is found, the script fails unless g-cli fallback is enabled.

## License
This directory inherits the root repository’s license (MIT, unless otherwise noted).

