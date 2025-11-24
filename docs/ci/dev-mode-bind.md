# Dev Mode Bind/Unbind Helper (BIND)

The bind/unbind composite (`.github/actions/bind-development-mode`) and helper script (`BindDevelopmentMode.ps1`) provide a deterministic way to:
- Point LabVIEW at the repo source via `LocalHost.LibraryPaths`.
- Clear packed libraries so edits/builds use source.
- Unbind cleanly to avoid cross-repo side effects.
- Emit JSON status for CI/tasks (see BIND-001..BIND-014).

## Usage
### Local (PowerShell)
```pwsh
pwsh .github/actions/bind-development-mode/BindDevelopmentMode.ps1 `
  -RepositoryPath "$PWD" `
  -Mode bind `              # bind | unbind | status
  -Bitness both `           # 32 | 64 | both
  -Force `                  # optional: overwrite other-path tokens
  -DryRun `                 # optional: report only
  -JsonOutputPath "reports/dev-mode-bind.json"
```

### Composite action (CI/task)
```yaml
- uses: ./.github/actions/bind-development-mode
  with:
    repository_path: ${{ github.workspace }}
    mode: bind       # or unbind/status
    bitness: both
    force: false
    dry_run: false
    json_output_path: reports/dev-mode-bind.json
# json_path output is always set (even on failure)
```

## Outputs
- JSON summary (default `reports/dev-mode-bind.json`) with per-bitness entries:
  - `bitness`, `expected_path`, `current_path`, `post_path`
  - `action`, `status`, `message`
- Console summary per bitness for quick inspection.

## Failure modes (and how to resolve)
- **Missing g-cli / Create_LV_INI_Token.vi**: fails precheck; install g-cli and ensure `Tooling/deployment/Create_LV_INI_Token.vi` exists.
- **LabVIEW.ini not found (bitness)**: status=skip; install the bitness or set `ALLOW_NONCANONICAL_LV_INI_PATH`/`TEST_LV_INI_PATH` for tests only.
- **Token points to another repo**: unbind/bind fails unless `-Force`/`force: true` is set; use force intentionally to overwrite.
- **Packed libs still present after bind**: treated as mismatch; reruns dev-mode prep to clear them.
- **Bind failure mid-run**: attempts revert; JSON status will be `fail` with diagnostics.

## Notes
- Default JSON path is under `reports/`; adjust if CI uploads artifacts from another directory.
- Use `status` mode to inspect current state without changing INI or files.
- Force only when you intend to overwrite tokens belonging to other paths.
