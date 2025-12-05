<#
.SYNOPSIS
    Generate a LabVIEW 2025.3-compatible VI Comparison report from comparison data.
#>
param(
    [Parameter(Mandatory = $true)]
    [string]$ComparisonDataPath,

    [Parameter(Mandatory = $true)]
    [string]$OutputPath,

    [ValidateSet('lv2025', 'custom')]
    [string]$TemplateFormat = 'lv2025'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $ComparisonDataPath)) {
    throw "Comparison data not found at $ComparisonDataPath"
}

$templatePath = Join-Path $PSScriptRoot 'templates/lv2025-report.template.html'
if (-not (Test-Path -LiteralPath $templatePath)) {
    throw "Report template missing at $templatePath"
}

function ConvertTo-EncodedJson {
    param($Object)
    $json = $Object | ConvertTo-Json -Depth 20
    return $json -replace '</script', '<\/script'
}

function Build-FallbackPayload {
    param($Data)

    $differences = $Data.differences
    $breaking = if ($Data.breaking_changes) { $Data.breaking_changes } else { @() }
    $impact = if ($Data.compatibility_impact) { $Data.compatibility_impact } else { @{} }

    $connectorChanges = @($differences.connector_pane_changes)
    $dependencyChanges = @($differences.dependency_changes)
    $deprecatedChanges = @($differences.deprecated_api_changes)

    $connectorAdded = $connectorChanges | Where-Object { $_.type -eq "terminal_added" }
    $connectorRemoved = $connectorChanges | Where-Object { $_.type -eq "terminal_removed" }

    $dependencyAdded = $dependencyChanges | Where-Object { $_.type -eq "dependency_added" }
    $dependencyRemoved = $dependencyChanges | Where-Object { $_.type -eq "dependency_removed" }
    $dependencyUpdated = $dependencyChanges | Where-Object { $_.type -eq "dependency_version_changed" }

    $deprecatedIntroduced = $deprecatedChanges | Where-Object { $_.type -eq "deprecated_api_introduced" }
    $deprecatedRemoved = $deprecatedChanges | Where-Object { $_.type -eq "deprecated_api_removed" }

    $inputDelta = ($Data.compare.connector_pane.input_count -as [int]) - ($Data.base.connector_pane.input_count -as [int])
    $outputDelta = ($Data.compare.connector_pane.output_count -as [int]) - ($Data.base.connector_pane.output_count -as [int])

    return @{
        format = @{
            version     = "25.3"
            report_type = "vi-comparison"
            schema      = "vi-history-suite/1.0"
        }
        header = @{
            base_vi    = @{
                name    = $Data.base.vi_name
                path    = $Data.base.vi_path
                version = $Data.base.lv_version
            }
            compare_vi = @{
                name    = $Data.compare.vi_name
                path    = $Data.compare.vi_path
                version = $Data.compare.lv_version
            }
            generated_at   = $Data.generated_at
            recommendation = $Data.recommendation
        }
        summary = @{
            version_change = $differences.version_change
            counts         = @{
                connector_changes   = $connectorChanges.Count
                dependency_changes  = $dependencyChanges.Count
                deprecated_api_hits = $deprecatedChanges.Count
                breaking_changes    = $breaking.Count
            }
            severity      = @{
                high   = ($breaking | Where-Object { $_.severity -eq "high" }).Count
                medium = ($breaking | Where-Object { $_.severity -eq "medium" }).Count
                low    = ($breaking | Where-Object { $_.severity -eq "low" }).Count
            }
            compatibility = $impact
        }
        diff = @{
            version = $differences.version_change
            connector_pane = @{
                input_delta = $inputDelta
                output_delta = $outputDelta
                added   = $connectorAdded
                removed = $connectorRemoved
                changes = $connectorChanges
            }
            dependencies = @{
                added   = $dependencyAdded
                removed = $dependencyRemoved
                updated = $dependencyUpdated
                changes = $dependencyChanges
            }
            deprecated_apis = @{
                introduced = $deprecatedIntroduced
                removed    = $deprecatedRemoved
                changes    = $deprecatedChanges
            }
            breaking_changes = $breaking
        }
    }
}

function New-SummaryCard {
    param(
        [string]$Label,
        [string]$Value,
        [string]$Accent = "neutral",
        [string]$Subtext = ""
    )

    return "<div class='summary-card $Accent'><div class='label'>$Label</div><div class='value'>$Value</div><div class='subtext'>$Subtext</div></div>"
}

function New-CompatibilityTable {
    param($Impact)

    $rows = @()
    $entries = @()
    if ($Impact -is [System.Collections.IDictionary]) {
        $entries = $Impact.GetEnumerator()
    }
    else {
        $entries = $Impact.PSObject.Properties | ForEach-Object { @{ Name = $_.Name; Value = $_.Value } }
    }

    foreach ($kvp in ($entries | Sort-Object Name)) {
        $state = $kvp.Value
        $class = switch ($state) {
            "compatible" { "compatible" }
            "compatible_with_warnings" { "warnings" }
            "incompatible" { "incompatible" }
            default { "warnings" }
        }
        $rows += "<tr><td>$($kvp.Name)</td><td class='$class'>$state</td></tr>"
    }
    return "<table class='compatibility'><thead><tr><th>Version/Platform</th><th>Status</th></tr></thead><tbody>$($rows -join '')</tbody></table>"
}

function New-List {
    param([string[]]$Items)
    return "<ul>" + ($Items -join "") + "</ul>"
}

function New-DetailSection {
    param(
        [string]$Title,
        [string[]]$Items
    )

    if (-not $Items -or $Items.Count -eq 0) {
        return ""
    }
    return "<section class='detail'><h3>$Title</h3>" + (New-List -Items $Items) + "</section>"
}

function Get-PropValue {
    param(
        $Object,
        [string]$Name
    )

    if ($null -eq $Object) { return $null }
    if (-not $Object.PSObject) { return $null }
    $prop = $Object.PSObject.Properties[$Name]
    if ($null -ne $prop) { return $prop.Value }
    return $null
}

$data = Get-Content -LiteralPath $ComparisonDataPath -Raw | ConvertFrom-Json
$payload = if ($data.lv2025_payload) { $data.lv2025_payload } else { Build-FallbackPayload -Data $data }

$summaryCards = @()
$breakingAccent = if ($payload.summary.counts.breaking_changes -gt 0) { "alert" } else { "ok" }
$summaryCards += New-SummaryCard -Label "Breaking changes" -Value $payload.summary.counts.breaking_changes -Accent $breakingAccent -Subtext "Severity: H$($payload.summary.severity.high)/M$($payload.summary.severity.medium)/L$($payload.summary.severity.low)"
$summaryCards += New-SummaryCard -Label "Connector pane" -Value $payload.summary.counts.connector_changes -Subtext "inputs delta $($payload.diff.connector_pane.input_delta), outputs delta $($payload.diff.connector_pane.output_delta)"
$depAddedCount = (@($payload.diff.dependencies.added) | Measure-Object).Count
$depRemovedCount = (@($payload.diff.dependencies.removed) | Measure-Object).Count
$deprecatedAddedCount = (@($payload.diff.deprecated_apis.introduced) | Measure-Object).Count
$summaryCards += New-SummaryCard -Label "Dependencies" -Value $payload.summary.counts.dependency_changes -Subtext "$depAddedCount added | $depRemovedCount removed"
$summaryCards += New-SummaryCard -Label "Deprecated APIs" -Value $payload.summary.counts.deprecated_api_hits -Subtext "$deprecatedAddedCount introduced"

$comparisonBullets = @()
if ($payload.diff.version) {
    $comparisonBullets += "<li>Version change: $($payload.diff.version.from) -> $($payload.diff.version.to)</li>"
}
foreach ($change in $payload.diff.connector_pane.changes) {
    $terminalLabel = Get-PropValue -Object $change -Name 'terminal'
    $terminalSuffix = if ($terminalLabel) { " ($terminalLabel)" } else { "" }
    $comparisonBullets += "<li>Connector change: $($change.type)$terminalSuffix</li>"
}
foreach ($change in $payload.diff.dependencies.changes) {
    $comparisonBullets += "<li>Dependency: $($change.vi) ($($change.type))</li>"
}
foreach ($change in $payload.diff.deprecated_apis.changes) {
    $comparisonBullets += "<li>Deprecated API: $($change.api) ($($change.type))</li>"
}
$comparisonList = New-List -Items $comparisonBullets

$compatibilityTable = New-CompatibilityTable -Impact $payload.summary.compatibility

$detailSections = @()
$detailSections += New-DetailSection -Title "Connector Pane" -Items (@($payload.diff.connector_pane.changes) | ForEach-Object {
    $changeType = Get-PropValue -Object $_ -Name 'type'
    if (-not $changeType) { return }
    $term = Get-PropValue -Object $_ -Name 'terminal'
    "<li>$changeType $term</li>"
} | Where-Object { $_ })
$detailSections += New-DetailSection -Title "Dependencies" -Items (@($payload.diff.dependencies.changes) | ForEach-Object {
    $changeType = Get-PropValue -Object $_ -Name 'type'
    if (-not $changeType) { return }
    $fromVal = Get-PropValue -Object $_ -Name 'from'
    $toVal = Get-PropValue -Object $_ -Name 'to'
    "<li>$($_.vi): $changeType $fromVal -> $toVal</li>"
} | Where-Object { $_ })
$detailSections += New-DetailSection -Title "Deprecated APIs" -Items (@($payload.diff.deprecated_apis.changes) | ForEach-Object {
    $changeType = Get-PropValue -Object $_ -Name 'type'
    if (-not $changeType) { return }
    "<li>$($_.api) ($changeType)</li>"
} | Where-Object { $_ })
$detailSections = $detailSections -join ""

$breakingCallouts = @()
foreach ($change in $payload.diff.breaking_changes) {
    $breakingCallouts += "<div class='callout severity-$($change.severity)'><strong>$($change.type)</strong><div>$($change.description)</div></div>"
}
$breakingHtml = if ($breakingCallouts.Count -gt 0) { ($breakingCallouts -join "") } else { "<div class='callout severity-ok'>No breaking changes detected</div>" }

$template = Get-Content -LiteralPath $templatePath -Raw
$filled = $template
$filled = $filled.Replace('{{REPORT_TITLE}}', 'VI Comparison Report')
$filled = $filled.Replace('{{BASE_NAME}}', [System.Net.WebUtility]::HtmlEncode($payload.header.base_vi.name))
$filled = $filled.Replace('{{COMPARE_NAME}}', [System.Net.WebUtility]::HtmlEncode($payload.header.compare_vi.name))
$filled = $filled.Replace('{{SUMMARY_CARDS}}', $summaryCards -join "")
$filled = $filled.Replace('{{COMPARISON}}', $comparisonList)
$filled = $filled.Replace('{{COMPATIBILITY}}', $compatibilityTable)
$filled = $filled.Replace('{{DETAILS}}', $detailSections)
$filled = $filled.Replace('{{BREAKING}}', $breakingHtml)
$filled = $filled.Replace('{{RECOMMENDATION}}', [System.Net.WebUtility]::HtmlEncode($payload.header.recommendation))
$filled = $filled.Replace('{{PAYLOAD_JSON}}', (ConvertTo-EncodedJson -Object $payload))

$dir = Split-Path -Parent $OutputPath
if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
Set-Content -LiteralPath $OutputPath -Value $filled -Encoding utf8

Write-Host "VI Comparison report written to $OutputPath" -ForegroundColor Green
