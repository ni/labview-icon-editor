<#
.SYNOPSIS
    Compare two VI versions and identify differences that drive the LV 2025.3 VI Comparison report.

.DESCRIPTION
    Compares two VI files and generates a structured diff payload, breaking-change summary,
    and LV 2025.3-compatible metadata that can be rendered by Generate-VIHistoryReport.ps1.

.PARAMETER BaseVI
    Path to the baseline VI file.

.PARAMETER CompareVI
    Path to the comparison VI file.

.PARAMETER OutputFormat
    Output format: json, html, lv2025. Default: lv2025.

.PARAMETER OutputPath
    Path to save the comparison report. If not specified, outputs to console for JSON/LV payloads
    or writes an HTML report next to the comparison VI.

.EXAMPLE
    pwsh -NoProfile -File Compare-VIHistory.ps1 -BaseVI "v1/MyVI.vi" -CompareVI "v2/MyVI.vi"

.EXAMPLE
    pwsh -NoProfile -File Compare-VIHistory.ps1 -BaseVI "v1/MyVI.vi" -CompareVI "v2/MyVI.vi" -OutputFormat html -OutputPath "report.html"
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$BaseVI,

    [Parameter(Mandatory = $true)]
    [string]$CompareVI,

    [Parameter(Mandatory = $false)]
    [ValidateSet("json", "html", "lv2025")]
    [string]$OutputFormat = "lv2025",

    [Parameter(Mandatory = $false)]
    [string]$OutputPath = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$metadataScript = Join-Path $scriptDir "SimulateVIMetadata.ps1"
$reportGenerator = Join-Path $scriptDir "Generate-VIHistoryReport.ps1"
$deprecationCatalogPath = Join-Path $scriptDir "api-deprecations.json"

function Get-DeprecationCatalog {
    if (-not (Test-Path -LiteralPath $deprecationCatalogPath)) {
        return @{}
    }

    try {
        $catalog = Get-Content -LiteralPath $deprecationCatalogPath -Raw | ConvertFrom-Json
        $index = @{}
        foreach ($entry in $catalog.deprecations) {
            $index[$entry.api] = $entry
        }
        return $index
    }
    catch {
        Write-Warning ("Could not parse API deprecations catalog: {0}" -f $_.Exception.Message)
        return @{}
    }
}

function Get-VIMetadataWrapper {
    param([string]$VIPath)

    $output = & $metadataScript -VIPath $VIPath -OutputFormat json 2>&1 | Where-Object { $_ -match '^\s*{' } | Out-String
    return $output | ConvertFrom-Json
}

function Compare-VIVersions {
    param($Base, $Compare)

    $versionChange = $null
    if ($Base.lv_version -ne $Compare.lv_version) {
        $versionChange = @{
            from            = $Base.lv_version
            to              = $Compare.lv_version
            from_normalized = $Base.lv_version_normalized
            to_normalized   = $Compare.lv_version_normalized
        }
    }

    return $versionChange
}

function Compare-ConnectorPanes {
    param($Base, $Compare)

    $changes = @()
    $basePane = $Base.connector_pane
    $comparePane = $Compare.connector_pane
    if (-not $basePane) {
        $basePane = [pscustomobject]@{ input_count = 0; output_count = 0; terminals = @(); has_error_terminals = $false }
    }
    if (-not $comparePane) {
        $comparePane = [pscustomobject]@{ input_count = 0; output_count = 0; terminals = @(); has_error_terminals = $false }
    }

    $baseInputs = $basePane.input_count
    $compareInputs = $comparePane.input_count
    if ($baseInputs -ne $compareInputs) {
        $changes += @{
            type     = "input_count_changed"
            from     = $baseInputs
            to       = $compareInputs
            severity = "high"
        }
    }

    $baseOutputs = $basePane.output_count
    $compareOutputs = $comparePane.output_count
    if ($baseOutputs -ne $compareOutputs) {
        $changes += @{
            type     = "output_count_changed"
            from     = $baseOutputs
            to       = $compareOutputs
            severity = "high"
        }
    }

    if ($basePane.has_error_terminals -ne $comparePane.has_error_terminals) {
        $changes += @{
            type     = "error_terminal_configuration_changed"
            from     = $basePane.has_error_terminals
            to       = $comparePane.has_error_terminals
            severity = "high"
        }
    }

    $baseTerminals = @($basePane.terminals)
    $compareTerminals = @($comparePane.terminals)
    $baseKeys = @{}
    $compareKeys = @{}

    foreach ($term in $baseTerminals) {
        $key = "{0}:{1}" -f $term.direction, $term.name
        $baseKeys[$key] = $term
    }
    foreach ($term in $compareTerminals) {
        $key = "{0}:{1}" -f $term.direction, $term.name
        $compareKeys[$key] = $term
    }

    foreach ($key in $compareKeys.Keys) {
        if (-not $baseKeys.ContainsKey($key)) {
            $parts = $key.Split(':')
            $changes += @{
                type      = "terminal_added"
                direction = $parts[0]
                terminal  = $parts[1]
                severity  = "high"
            }
        }
    }

    foreach ($key in $baseKeys.Keys) {
        if (-not $compareKeys.ContainsKey($key)) {
            $parts = $key.Split(':')
            $changes += @{
                type      = "terminal_removed"
                direction = $parts[0]
                terminal  = $parts[1]
                severity  = "high"
            }
        }
    }

    return $changes
}

function Compare-Dependencies {
    param($Base, $Compare)

    $changes = @()
    $baseDeps = @{ }
    $compareDeps = @{ }

    foreach ($dep in @($Base.dependencies)) {
        if ($dep.vi) { $baseDeps[$dep.vi] = $dep }
    }
    foreach ($dep in @($Compare.dependencies)) {
        if ($dep.vi) { $compareDeps[$dep.vi] = $dep }
    }

    foreach ($vi in $baseDeps.Keys) {
        if (-not $compareDeps.ContainsKey($vi)) {
            $changes += @{
                type     = "dependency_removed"
                vi       = $vi
                version  = $baseDeps[$vi].version
                severity = "high"
            }
        }
    }

    foreach ($vi in $compareDeps.Keys) {
        if (-not $baseDeps.ContainsKey($vi)) {
            $changes += @{
                type     = "dependency_added"
                vi       = $vi
                version  = $compareDeps[$vi].version
                severity = "low"
            }
            continue
        }

        $baseVersion = $baseDeps[$vi].version
        $compareVersion = $compareDeps[$vi].version
        if ($baseVersion -and $compareVersion -and $baseVersion -ne $compareVersion) {
            $changes += @{
                type     = "dependency_version_changed"
                vi       = $vi
                from     = $baseVersion
                to       = $compareVersion
                severity = "medium"
            }
        }
    }

    return $changes
}

function Compare-DeprecatedApis {
    param($Base, $Compare, $Catalog)

    $changes = @()
    $baseSet = @($Base.deprecated_apis)
    $compareSet = @($Compare.deprecated_apis)

    foreach ($api in $compareSet) {
        if (-not ($baseSet -contains $api)) {
            $severity = if ($Catalog.ContainsKey($api)) { $Catalog[$api].severity } else { "medium" }
            $replacement = if ($Catalog.ContainsKey($api)) { $Catalog[$api].replacement } else { $null }
            $changes += @{
                type         = "deprecated_api_introduced"
                api          = $api
                replacement  = $replacement
                severity     = $severity
                deprecated_in = if ($Catalog.ContainsKey($api)) { $Catalog[$api].deprecated_in } else { $null }
            }
        }
    }

    foreach ($api in $baseSet) {
        if (-not ($compareSet -contains $api)) {
            $changes += @{
                type         = "deprecated_api_removed"
                api          = $api
                severity     = "low"
                deprecated_in = if ($Catalog.ContainsKey($api)) { $Catalog[$api].deprecated_in } else { $null }
            }
        }
    }

    return $changes
}

function Detect-BreakingChanges {
    param($Differences, $Impact)

    $breakingChanges = @()

    if ($Differences.version_change -and
        $Differences.version_change.to_normalized -lt $Differences.version_change.from_normalized) {
        $breakingChanges += @{
            type        = "version_downgrade"
            severity    = "high"
            description = "VI version downgraded from $($Differences.version_change.from) to $($Differences.version_change.to)"
        }
    }

    foreach ($change in $Differences.connector_pane_changes) {
        if ($change.severity -eq "high") {
            $breakingChanges += @{
                type        = "connector_pane_modified"
                severity    = "high"
                description = "Connector pane $($change.type)"
            }
        }
    }

    foreach ($change in $Differences.dependency_changes) {
        if ($change.severity -in @("high", "medium")) {
            $breakingChanges += @{
                type        = "dependency_issue"
                severity    = $change.severity
                description = "Dependency $($change.vi) change: $($change.type)"
            }
        }
    }

    foreach ($change in $Differences.deprecated_api_changes) {
        if ($change.severity -ne "low") {
            $breakingChanges += @{
                type        = "deprecated_api_usage"
                severity    = $change.severity
                description = "Deprecated API detected: $($change.api)"
            }
        }
    }

    $incompatibles = $Impact.GetEnumerator() | Where-Object { $_.Value -eq "incompatible" }
    foreach ($entry in $incompatibles) {
        $breakingChanges += @{
            type        = "compatibility_regression"
            severity    = "medium"
            description = "Compatibility lost for $($entry.Name)"
        }
    }

    return $breakingChanges
}

function Get-CompatibilityImpact {
    param($Base, $Compare)

    $impact = @{}

    $versions = @("lv2021", "lv2023", "lv2024", "lv2025")
    foreach ($version in $versions) {
        $baseCompat = $Base.compatibility.$version
        $compareCompat = $Compare.compatibility.$version

        if ($baseCompat -and -not $compareCompat) {
            $impact.$version = "incompatible"
        }
        elseif ($compareCompat -and -not $baseCompat) {
            $impact.$version = "compatible_with_warnings"
        }
        elseif ($compareCompat) {
            $impact.$version = "compatible"
        }
        else {
            $impact.$version = "incompatible"
        }
    }

    return $impact
}

function Get-Recommendation {
    param($BreakingChanges, $Impact)

    if ($BreakingChanges.Count -gt 0) {
        return "Breaking changes detected ($($BreakingChanges.Count)) - Review required before upgrade"
    }

    $incompatibleCount = ($Impact.GetEnumerator() | Where-Object { $_.Value -eq "incompatible" }).Count
    if ($incompatibleCount -gt 0) {
        return "Compatibility warnings - $incompatibleCount version(s) incompatible"
    }

    return "No breaking changes detected - Upgrade recommended"
}

function Build-DiffSummary {
    param($Base, $Compare, $Differences)

    $connectorAdded = $Differences.connector_pane_changes | Where-Object { $_.type -eq "terminal_added" }
    $connectorRemoved = $Differences.connector_pane_changes | Where-Object { $_.type -eq "terminal_removed" }
    $connectorCounts = @{
        input_delta  = ($Compare.connector_pane.input_count -as [int]) - ($Base.connector_pane.input_count -as [int])
        output_delta = ($Compare.connector_pane.output_count -as [int]) - ($Base.connector_pane.output_count -as [int])
    }

    $dependencyAdded = $Differences.dependency_changes | Where-Object { $_.type -eq "dependency_added" }
    $dependencyRemoved = $Differences.dependency_changes | Where-Object { $_.type -eq "dependency_removed" }
    $dependencyUpdated = $Differences.dependency_changes | Where-Object { $_.type -eq "dependency_version_changed" }

    $deprecatedIntroduced = $Differences.deprecated_api_changes | Where-Object { $_.type -eq "deprecated_api_introduced" }
    $deprecatedRemoved = $Differences.deprecated_api_changes | Where-Object { $_.type -eq "deprecated_api_removed" }

    return @{
        connector_pane = @{
            added           = $connectorAdded
            removed         = $connectorRemoved
            changes         = $Differences.connector_pane_changes
            input_delta     = $connectorCounts.input_delta
            output_delta    = $connectorCounts.output_delta
            error_terminals = @{
                from = $Base.connector_pane.has_error_terminals
                to   = $Compare.connector_pane.has_error_terminals
            }
        }
        dependencies   = @{
            added   = $dependencyAdded
            removed = $dependencyRemoved
            updated = $dependencyUpdated
            changes = $Differences.dependency_changes
        }
        deprecated_apis = @{
            introduced = $deprecatedIntroduced
            removed    = $deprecatedRemoved
            changes    = $Differences.deprecated_api_changes
        }
    }
}

function Build-Lv2025Payload {
    param($BaseMeta, $CompareMeta, $Differences, $Impact, $Breaking, $Recommendation, $GeneratedAt, $DiffSummary)

    $breakingList = if ($null -ne $Breaking) { @($Breaking) } else { @() }
    $connectorChanges = if ($Differences.connector_pane_changes) { @($Differences.connector_pane_changes) } else { @() }
    $dependencyChanges = if ($Differences.dependency_changes) { @($Differences.dependency_changes) } else { @() }
    $deprecatedChanges = if ($Differences.deprecated_api_changes) { @($Differences.deprecated_api_changes) } else { @() }

    if ($env:VI_HISTORY_DEBUG -eq "1") {
        Write-Host ("[DEBUG] breakingList type: {0}, length: {1}" -f ($breakingList.GetType().FullName), ($breakingList.Length)) -ForegroundColor DarkYellow
        if ($breakingList.Length -gt 0) {
            Write-Host ("[DEBUG] first breaking item type: {0}" -f ($breakingList[0].GetType().FullName)) -ForegroundColor DarkYellow
        }
    }

    $severityCounts = @{
        high   = ($breakingList | Where-Object { $_.severity -eq "high" } | Measure-Object).Count
        medium = ($breakingList | Where-Object { $_.severity -eq "medium" } | Measure-Object).Count
        low    = ($breakingList | Where-Object { $_.severity -eq "low" } | Measure-Object).Count
    }

    return @{
        format = @{
            version     = "25.3"
            report_type = "vi-comparison"
            schema      = "vi-history-suite/1.0"
        }
        header = @{
            base_vi    = @{
                name    = $BaseMeta.vi_name
                path    = $BaseMeta.vi_path
                version = $BaseMeta.lv_version
            }
            compare_vi = @{
                name    = $CompareMeta.vi_name
                path    = $CompareMeta.vi_path
                version = $CompareMeta.lv_version
            }
            generated_at   = $GeneratedAt
            recommendation = $Recommendation
        }
        summary = @{
            version_change = $Differences.version_change
            counts         = @{
                connector_changes   = ($connectorChanges | Measure-Object).Count
                dependency_changes  = ($dependencyChanges | Measure-Object).Count
                deprecated_api_hits = ($deprecatedChanges | Measure-Object).Count
                breaking_changes    = ($breakingList | Measure-Object).Count
            }
            severity       = $severityCounts
            compatibility  = $Impact
        }
        diff = @{
            version         = $Differences.version_change
            connector_pane  = @{
                added           = if ($DiffSummary.connector_pane.added) { @($DiffSummary.connector_pane.added) } else { @() }
                removed         = if ($DiffSummary.connector_pane.removed) { @($DiffSummary.connector_pane.removed) } else { @() }
                changes         = if ($DiffSummary.connector_pane.changes) { @($DiffSummary.connector_pane.changes) } else { @() }
                input_delta     = $DiffSummary.connector_pane.input_delta
                output_delta    = $DiffSummary.connector_pane.output_delta
                error_terminals = $DiffSummary.connector_pane.error_terminals
            }
            dependencies    = @{
                added   = if ($DiffSummary.dependencies.added) { @($DiffSummary.dependencies.added) } else { @() }
                removed = if ($DiffSummary.dependencies.removed) { @($DiffSummary.dependencies.removed) } else { @() }
                updated = if ($DiffSummary.dependencies.updated) { @($DiffSummary.dependencies.updated) } else { @() }
                changes = if ($DiffSummary.dependencies.changes) { @($DiffSummary.dependencies.changes) } else { @() }
            }
            deprecated_apis = @{
                introduced = if ($DiffSummary.deprecated_apis.introduced) { @($DiffSummary.deprecated_apis.introduced) } else { @() }
                removed    = if ($DiffSummary.deprecated_apis.removed) { @($DiffSummary.deprecated_apis.removed) } else { @() }
                changes    = if ($DiffSummary.deprecated_apis.changes) { @($DiffSummary.deprecated_apis.changes) } else { @() }
            }
            breaking_changes = $breakingList
        }
    }
}

function Write-ReportOutput {
    param(
        $Report,
        [string]$Format,
        [string]$Path
    )

    if ($Format -in @("json", "lv2025")) {
        $json = $Report | ConvertTo-Json -Depth 15
        if ($Path) {
            $targetDir = Split-Path -Parent $Path
            if ($targetDir -and -not (Test-Path -LiteralPath $targetDir)) {
                New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
            }
            $json | Set-Content -Path $Path -Encoding utf8
            Write-Host "✓ Report saved to: $Path" -ForegroundColor Green
        }
        else {
            Write-Output $json
        }
        return
    }

    if ($Format -eq "html") {
        $defaultHtmlPath = if ($Path) { $Path } else { Join-Path (Get-Location).Path "vi-comparison-report.html" }
        $targetDir = Split-Path -Parent $defaultHtmlPath
        if ($targetDir -and -not (Test-Path -LiteralPath $targetDir)) {
            New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
        }
        $intermediateJson = [System.IO.Path]::ChangeExtension($defaultHtmlPath, ".json")
        $Report | ConvertTo-Json -Depth 15 | Set-Content -Path $intermediateJson -Encoding utf8

        Write-Host "Rendering LV 2025.3 comparison report..." -ForegroundColor Yellow
        & $reportGenerator -ComparisonDataPath $intermediateJson -OutputPath $defaultHtmlPath | Out-Null
        Write-Host "✓ Report saved to: $defaultHtmlPath" -ForegroundColor Green
        return
    }
}

function Main {
    Write-Host "=== VI Comparison Engine ===" -ForegroundColor Cyan
    Write-Host "Base VI:    $BaseVI"
    Write-Host "Compare VI: $CompareVI"
    Write-Host "Format:     $OutputFormat"
    Write-Host ""

    try {
        $generatedAt = (Get-Date).ToString("o")
        $deprecationCatalog = Get-DeprecationCatalog

        Write-Host "Extracting metadata from base VI..." -ForegroundColor Yellow
        $baseMeta = Get-VIMetadataWrapper -VIPath $BaseVI

        Write-Host "Extracting metadata from compare VI..." -ForegroundColor Yellow
        $compareMeta = Get-VIMetadataWrapper -VIPath $CompareVI

        Write-Host "Comparing VIs..." -ForegroundColor Yellow
        $versionChange = Compare-VIVersions -Base $baseMeta -Compare $compareMeta
        $connectorChanges = Compare-ConnectorPanes -Base $baseMeta -Compare $compareMeta
        $dependencyChanges = Compare-Dependencies -Base $baseMeta -Compare $compareMeta
        $deprecatedChanges = Compare-DeprecatedApis -Base $baseMeta -Compare $compareMeta -Catalog $deprecationCatalog
        if (-not $connectorChanges) { $connectorChanges = @() }
        if (-not $dependencyChanges) { $dependencyChanges = @() }
        if (-not $deprecatedChanges) { $deprecatedChanges = @() }

        $differences = @{
            version_change          = $versionChange
            connector_pane_changes  = $connectorChanges
            dependency_changes      = $dependencyChanges
            deprecated_api_changes  = $deprecatedChanges
        }

        $compatImpact = Get-CompatibilityImpact -Base $baseMeta -Compare $compareMeta
        $breakingChanges = Detect-BreakingChanges -Differences $differences -Impact $compatImpact
        $recommendation = Get-Recommendation -BreakingChanges $breakingChanges -Impact $compatImpact
        $diffSummary = Build-DiffSummary -Base $baseMeta -Compare $compareMeta -Differences $differences
        if ($env:VI_HISTORY_DEBUG -eq "1") {
            Write-Host ("[DEBUG] connector change count: {0}" -f (($connectorChanges | Measure-Object).Count)) -ForegroundColor DarkYellow
            Write-Host ("[DEBUG] dependency change count: {0}" -f (($dependencyChanges | Measure-Object).Count)) -ForegroundColor DarkYellow
            Write-Host ("[DEBUG] deprecated change count: {0}" -f (($deprecatedChanges | Measure-Object).Count)) -ForegroundColor DarkYellow
            Write-Host ("[DEBUG] diffSummary.connector_pane.added is null: {0}" -f ($null -eq $diffSummary.connector_pane.added)) -ForegroundColor DarkYellow
        }

        $lv2025Payload = Build-Lv2025Payload -BaseMeta $baseMeta -CompareMeta $compareMeta -Differences $differences -Impact $compatImpact -Breaking $breakingChanges -Recommendation $recommendation -GeneratedAt $generatedAt -DiffSummary $diffSummary

        if ($env:VI_HISTORY_DEBUG -eq "1") {
            $connPayload = $lv2025Payload.diff.connector_pane
            Write-Host ("[DEBUG] lv2025 connector changes count: {0}" -f (($connPayload.changes | Measure-Object).Count)) -ForegroundColor DarkYellow
            Write-Host ("[DEBUG] lv2025 connector added null: {0}" -f ($null -eq $connPayload.added)) -ForegroundColor DarkYellow
            Write-Host ("[DEBUG] lv2025 connector added count: {0}" -f ((@($connPayload.added) | Measure-Object).Count)) -ForegroundColor DarkYellow
        }

        $report = @{
            report_kind          = "vi-comparison"
            base                 = $baseMeta
            compare              = $compareMeta
            differences          = $differences
            breaking_changes     = $breakingChanges
            compatibility_impact = $compatImpact
            recommendation       = $recommendation
            generated_at         = $generatedAt
            tool_version         = "1.0"
            lv2025_payload       = $lv2025Payload
        }

        Write-ReportOutput -Report $report -Format $OutputFormat -Path $OutputPath

        Write-Host ""
        Write-Host "✓ Comparison completed successfully" -ForegroundColor Green
        Write-Host "Breaking changes: $($breakingChanges.Count)" -ForegroundColor $(if ($breakingChanges.Count -eq 0) { "Green" } else { "Red" })
        Write-Host "Recommendation: $recommendation" -ForegroundColor Cyan

        exit 0
    }
    catch {
        Write-Host "✗ Error: $_" -ForegroundColor Red
        if ($_.ScriptStackTrace) {
            Write-Host "Stack: $($_.ScriptStackTrace)" -ForegroundColor DarkYellow
        }
        exit 1
    }
}

Main
