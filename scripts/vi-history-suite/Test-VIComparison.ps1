<#
.SYNOPSIS
    Pester regression suite for the VI comparison engine and report generator.
.DESCRIPTION
    Constructs lightweight VI fixtures with metadata overrides, invokes
    Compare-VIHistory.ps1 and Generate-VIHistoryReport.ps1, and asserts that
    connector, dependency, deprecated-API diff helpers, and LV 2025.3 report
    payloads are produced as expected.
#>

Set-StrictMode -Version Latest
$temporaryRoot = Join-Path ([System.IO.Path]::GetTempPath()) "vi-history-suite-test"
$comparisonReport = $null
$comparisonReportPath = $null
$reportHtmlPath = $null
$baseViPath = $null
$compareViPath = $null

function global:New-SimulatedVi {
    param(
        [string]$Path,
        [uint32]$FormatVersion
    )

    $bytes = New-Object byte[](16)
    $magic = [System.Text.Encoding]::ASCII.GetBytes('RSRC')
    $magic.CopyTo($bytes, 0)

    $versionBytes = [BitConverter]::GetBytes($FormatVersion)
    $versionBytes.CopyTo($bytes, 8)

    [System.IO.File]::WriteAllBytes($Path, $bytes)
}

function global:Write-MetadataOverride {
    param(
        [string]$ViPath,
        [hashtable]$Metadata
    )

    $metadataPath = [System.IO.Path]::ChangeExtension($ViPath, '.metadata.json')
    $Metadata | ConvertTo-Json -Depth 10 | Set-Content -Path $metadataPath -Encoding UTF8
}

Describe 'Compare-VIHistory integration' {
    BeforeAll {
        $script:temporaryRoot = Join-Path ([System.IO.Path]::GetTempPath()) 'vi-history-suite-test'
        if (Test-Path $script:temporaryRoot) {
            Remove-Item $script:temporaryRoot -Recurse -Force -ErrorAction SilentlyContinue
        }

        New-Item -ItemType Directory -Path $script:temporaryRoot -Force | Out-Null

        $baseViPath = Join-Path $script:temporaryRoot 'BaseExample.vi'
        $compareViPath = Join-Path $script:temporaryRoot 'CompareExample.vi'

        New-SimulatedVi -Path $baseViPath -FormatVersion 0x0F000000
        New-SimulatedVi -Path $compareViPath -FormatVersion 0x10000000

        $baseMetadata = [ordered]@{
            connector_pane = [ordered]@{
                input_count = 1
                output_count = 2
                terminals = @(
                    [pscustomobject]@{ direction = 'input';  name = 'ControlA' }
                    [pscustomobject]@{ direction = 'output'; name = 'Result' }
                    [pscustomobject]@{ direction = 'output'; name = 'Telemetry' }
                )
                has_error_terminals = $false
            }
            dependencies = @(
                [pscustomobject]@{ vi = 'BaseDep.vi'; version = '1.0.0' }
                [pscustomobject]@{ vi = 'Shared.vi'; version = '1.0.0' }
                [pscustomobject]@{ vi = 'RemovedDep.vi'; version = '0.2.3' }
            )
            deprecated_apis = @('LegacyFn.vi')
        }
        Write-MetadataOverride -ViPath $baseViPath -Metadata $baseMetadata

        $compareMetadata = [ordered]@{
            connector_pane = [ordered]@{
                input_count = 2
                output_count = 1
                terminals = @(
                    [pscustomobject]@{ direction = 'input';  name = 'ControlA' }
                    [pscustomobject]@{ direction = 'input';  name = 'ControlB' }
                    [pscustomobject]@{ direction = 'output'; name = 'Result' }
                )
                has_error_terminals = $true
            }
            dependencies = @(
                [pscustomobject]@{ vi = 'BaseDep.vi'; version = '1.1.0' }
                [pscustomobject]@{ vi = 'Shared.vi'; version = '1.0.0' }
                [pscustomobject]@{ vi = 'NewDep.vi'; version = '0.4.2' }
            )
            deprecated_apis = @('LegacyFn.vi', 'DeprecatedFn.vi')
        }
        Write-MetadataOverride -ViPath $compareViPath -Metadata $compareMetadata

        $comparisonReportPath = Join-Path $temporaryRoot 'comparison-report.json'
        $reportHtmlPath = Join-Path $temporaryRoot 'comparison-report.html'

        $script:compareScript = Join-Path $PSScriptRoot 'Compare-VIHistory.ps1'
        if (-not (Test-Path $script:compareScript)) {
            throw "Comparison script not found at $script:compareScript"
        }

        $null = & $script:compareScript -BaseVI $baseViPath -CompareVI $compareViPath -OutputFormat lv2025 -OutputPath $comparisonReportPath
        $comparisonReport = Get-Content -Path $comparisonReportPath -Raw | ConvertFrom-Json

        $generatorScript = Join-Path $PSScriptRoot 'Generate-VIHistoryReport.ps1'
        if (-not (Test-Path $generatorScript)) {
            throw "Report generator script not found at $generatorScript"
        }
        & $generatorScript -ComparisonDataPath $comparisonReportPath -OutputPath $reportHtmlPath | Out-Null
    }

    AfterAll {
        Remove-Item $script:temporaryRoot -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'detects connector pane input/output changes and terminal differences' {
        $connectorChanges = $comparisonReport.differences.connector_pane_changes
        $connectorChanges.Count | Should -BeGreaterThan 0
        ($connectorChanges | Where-Object { $_.type -eq 'input_count_changed' }).Count | Should -Be 1
        ($connectorChanges | Where-Object { $_.type -eq 'terminal_added' -and $_.terminal -eq 'ControlB' }).Count | Should -Be 1
        ($connectorChanges | Where-Object { $_.type -eq 'terminal_removed' -and $_.terminal -eq 'Telemetry' }).Count | Should -Be 1
    }

    It 'records dependency additions, removals, and version updates' {
        $deps = $comparisonReport.differences.dependency_changes
        ($deps | Where-Object { $_.type -eq 'dependency_added' -and $_.vi -eq 'NewDep.vi' }).Count | Should -Be 1
        ($deps | Where-Object { $_.type -eq 'dependency_removed' -and $_.vi -eq 'RemovedDep.vi' }).Count | Should -Be 1
        ($deps | Where-Object { $_.type -eq 'dependency_version_changed' -and $_.vi -eq 'BaseDep.vi' -and $_.from -eq '1.0.0' -and $_.to -eq '1.1.0' }).Count | Should -Be 1
    }

    It 'flags introduced deprecated APIs and surfaces breaking context' {
        $deprecated = $comparisonReport.differences.deprecated_api_changes
        ($deprecated | Where-Object { $_.type -eq 'deprecated_api_introduced' -and $_.api -eq 'DeprecatedFn.vi' }).Count | Should -Be 1
        ($comparisonReport.breaking_changes | Where-Object { $_.type -eq 'connector_pane_modified' }).Count | Should -BeGreaterThan 0
        $comparisonReport.recommendation | Should -Match 'Breaking changes detected'
    }

    It 'emits LV2025.3 diff payload required by the VI Comparison report' {
        $payload = $comparisonReport.lv2025_payload
        $payload.format.version | Should -Be '25.3'
        $payload.header.base_vi.name | Should -Be 'BaseExample.vi'
        $payload.summary.counts.connector_changes | Should -BeGreaterThan 0
        $payload.diff.connector_pane.added.Count | Should -Be 1
        $payload.diff.dependencies.updated.Count | Should -Be 1
        $payload.diff.deprecated_apis.introduced.Count | Should -Be 1
    }

    It 'renders an LV2025.3-compatible HTML report' {
        Test-Path $reportHtmlPath | Should -BeTrue
        $html = Get-Content -Path $reportHtmlPath -Raw
        $html | Should -Match 'vi-comparison-data'
        $html | Should -Match 'VI Comparison Report'
        $html | Should -Match 'meta name=\"lv-version\" content=\"25.3\"'
        $html | Should -Match 'BaseExample.vi'
        $html | Should -Match 'CompareExample.vi'
    }
}
