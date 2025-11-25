# Dev Mode Bind/Unbind Helper (BIND)

The bind/unbind helper script (`scripts/bind-development-mode/BindDevelopmentMode.ps1`) provides a deterministic way to:
- Point LabVIEW at the repo source via `LocalHost.LibraryPaths`.
- Clear packed libraries so edits/builds use source.
- Unbind cleanly to avoid cross-repo side effects.
- Emit JSON status for CI/tasks (see BIND-001..BIND-014).

## Usage
### Local (PowerShell)
```pwsh
pwsh scripts/bind-development-mode/BindDevelopmentMode.ps1 `
  -RepositoryPath "$PWD" `
  -Mode bind `              # bind | unbind | status
  -Bitness both `           # 32 | 64 | both
  -Force `                  # optional: overwrite other-path tokens
  -DryRun `                 # optional: report only
  -JsonOutputPath "reports/dev-mode-bind.json"
```

## Outputs
- JSON summary (default `reports/dev-mode-bind.json`) with per-bitness entries:
  - `bitness`, `expected_path`, `current_path`, `post_path`
  - `action`, `status`, `message`
- Console summary per bitness for quick inspection.

## Failure modes (and how to resolve)
- **Missing g-cli / Create_LV_INI_Token.vi**: fails precheck; install g-cli and ensure `Tooling/deployment/Create_LV_INI_Token.vi` exists.
- **LabVIEW.ini not found (bitness)**: status=skip; install the required LabVIEW bitness so the canonical `Program Files` INI exists.
- **Token points to another repo**: unbind/bind fails unless `-Force`/`force: true` is set; use force intentionally to overwrite.
- **Packed libs still present after bind**: treated as mismatch; reruns dev-mode prep to clear them.
- **Bind failure mid-run**: attempts revert; JSON status will be `fail` with diagnostics.
- **Dev-mode anomalies**: if the bind output calls out suspicious token paths or missing `LocalHost.LibraryPaths` entries, rerun Dev Mode bind with **Force** (`pwsh scripts/bind-development-mode/BindDevelopmentMode.ps1 -RepositoryPath . -Mode bind -Bitness both -Force`) and review `reports/dev-mode-bind.json` for per-bitness details.

## Notes
- Default JSON path is under `reports/`; adjust if CI uploads artifacts from another directory.
- Use `status` mode to inspect current state without changing INI or files.
- Force only when you intend to overwrite tokens belonging to other paths.
- Automation shim: natural-language dev-mode intents are parsed/executed by `Tooling/dotnet/DevModeAgentCli/Program.cs`; keep it in sync with binder flags/behavior.
