# Missing-In-Project (scripted)

Validate that every file on disk that should live in the LabVIEW project actually appears in the `.lvproj`. These scripts launch `MissingInProjectCLI.vi` via g-cli and report any missing files.

## Inputs
- `LVVersion` (required): LabVIEW major version, e.g., `2021`.
- `Arch` (required): `32` or `64`.
- `ProjectFile` (required): Full path to the `.lvproj` to inspect.

## Quick start (workflow snippet)
```yaml
steps:
  - uses: actions/checkout@v4
  - name: Verify project membership
    shell: pwsh
    run: |
      pwsh -File scripts/missing-in-project/Invoke-MissingInProjectCLI.ps1 `
        -LVVersion 2024 `
        -Arch 64 `
        -ProjectFile "$env:GITHUB_WORKSPACE/lv_icon_editor.lvproj"
```

## Local run
```powershell
pwsh -File scripts/missing-in-project/Invoke-MissingInProjectCLI.ps1 `
  -LVVersion 2024 `
  -Arch 64 `
  -ProjectFile C:\path\to\repo\lv_icon_editor.lvproj
```

If missing files are detected, they are listed in `scripts/missing-in-project/missing_files.txt` and the script exits non-zero. Logs from g-cli are written to `missing_in_project_gcli.log`.
