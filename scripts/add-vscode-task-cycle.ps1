[CmdletBinding()]
param(
    # Cycle identifier, e.g., "2024-05-20 nightly" or "release-1.2".
    [string]$CycleName = (Get-Date -Format 'yyyy-MM-dd'),

    # Path to docs/vscode-tasks-traceability.md (default: repo-relative).
    [string]$DocPath = "$(Join-Path $PSScriptRoot '..' 'docs' 'vscode-tasks-traceability.md')"
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$doc = (Resolve-Path -LiteralPath $DocPath).Path
if (-not (Test-Path -LiteralPath $doc -PathType Leaf)) {
    throw "Document not found: $doc"
}

$section = @"

## Cycle: $CycleName

| Task label | 2020 64 | 2021 64 | 2021 32 | 2023 64 | 2023 32 | 2025 64 | 2025 32 | 2026 64 | Notes |
| - | - | - | - | - | - | - | - | - | - |
| 01 Verify / Apply dependencies | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] |  |
| 02 Build LVAddon (VI Package) | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] |  |
| 17 Build (isolated worktree) | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] |  |
| 03 Orchestration: Restore packaged sources | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] |  |
| 04 Orchestration: Close LabVIEW | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] |  |
| 06 DevMode: Bind (auto) | skip | [ ] | n/a | n/a | n/a | n/a | n/a | n/a | Auto resolves to 2021/64 |
| 06b DevMode: Unbind (auto) | skip | [ ] | n/a | n/a | n/a | n/a | n/a | n/a | Auto resolves to 2021/64 |
| 06c DevMode: Clear/Unbind all LabVIEW versions | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | One run sweeps all installs |
| 07 x-cli: VI Analyzer (raw) | n/a | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | Update request JSON per version |
| 21b VIPB: Override seed.vipb (repo) | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] |  |
| 06d DevMode: Bind (repo, 64-bit) | skip | [ ] | n/a | n/a | n/a | n/a | n/a | n/a | 64-bit only |
| 21c VIPB override + DevMode (repo) | [ ] | [ ] | n/a | [ ] | n/a | [ ] | n/a | [ ] | 64-bit only |
| 08 x-cli: VI Analyzer | n/a | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | Sequence bind/run/unbind |
| 20 Build: Source Distribution | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] |  |
| 21 Verify: Source Distribution | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] |  |
| 21 VIPB: Bump LabVIEW version | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] |  |
| 09 x-cli: VI History (vi-compare-run) | n/a | n/a | n/a | n/a | n/a | [ ] | [ ] | n/a |  |
| 10 Tests: run (TestsCli) | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] |  |
| 11 Tests: run (Orchestration CLI unit-tests) | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] |  |
| 12 Tests: run (isolated worktree) | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] |  |
| 13 Orchestration: VI Analyzer | n/a | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] |  |
| 14 Orchestration: VI Compare | n/a | n/a | n/a | n/a | n/a | [ ] | [ ] | n/a |  |
| 15 Orchestration: Missing-in-project check | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] |  |
| 16 Tests: VI Analyzer (Test.ps1) | n/a | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] | [ ] |  |

LV-agnostic items for this cycle:
- [ ] 05 Requirements summary (dotnet)
- [ ] 18 Tooling: Clear CLI cache entry
- [ ] 19 Tests: Probe helper smoke
"@

Add-Content -LiteralPath $doc -Value $section
Write-Host "Appended cycle checklist for '$CycleName' to $doc"
