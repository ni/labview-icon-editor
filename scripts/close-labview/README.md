# Close LabVIEW (script)

Gracefully shuts down a LabVIEW instance via **g-cli** so builds/tests can release file locks.

## Inputs
- `Package_LabVIEW_Version` (required): LabVIEW version to close (for example `2024`).
- `SupportedBitness` (required): `32` or `64`.

## Quick start (workflow snippet)
```yaml
steps:
  - uses: actions/checkout@v4
  - name: Close LabVIEW
    shell: pwsh
    run: |
      $lvVer = pwsh -File scripts/get-package-lv-version.ps1 -RepositoryPath "${{ github.workspace }}"
      pwsh -File scripts/close-labview/Close_LabVIEW.ps1 `
        -Package_LabVIEW_Version $lvVer `
        -SupportedBitness 64
```

## Local run
```powershell
pwsh -File scripts/close-labview/Close_LabVIEW.ps1 `
  -Package_LabVIEW_Version 2024 `
  -SupportedBitness 64
```

Requires `g-cli` to be available in `PATH`; the script exits cleanly if LabVIEW is already closed.
