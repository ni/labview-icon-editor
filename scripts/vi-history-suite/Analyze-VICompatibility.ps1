<#
.SYNOPSIS
    Analyze VI compatibility across LabVIEW versions and platforms.

.DESCRIPTION
    Analyzes one or more VI files for compatibility across different LabVIEW
    versions (2021-2025) and platforms (32-bit/64-bit).

.PARAMETER VIPath
    Path to VI file or directory containing VI files.

.PARAMETER TargetVersions
    Array of LabVIEW versions to check. Default: all supported versions.

.PARAMETER TargetPlatforms
    Array of platforms to check. Default: both 32-bit and 64-bit.

.PARAMETER OutputFormat
    Output format: json, html, matrix. Default: json.

.EXAMPLE
    pwsh -NoProfile -File Analyze-VICompatibility.ps1 -VIPath "MyVI.vi"

.EXAMPLE
    pwsh -NoProfile -File Analyze-VICompatibility.ps1 -VIPath "src/" -TargetVersions @("2024", "2025")
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$VIPath,
    
    [Parameter(Mandatory=$false)]
    [string[]]$TargetVersions = @("2021", "2023", "2024", "2025"),
    
    [Parameter(Mandatory=$false)]
    [string[]]$TargetPlatforms = @("32-bit", "64-bit"),
    
    [Parameter(Mandatory=$false)]
    [ValidateSet("json", "html", "matrix")]
    [string]$OutputFormat = "json"
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$metadataScript = Join-Path $scriptDir "SimulateVIMetadata.ps1"
$compatMatrixPath = Join-Path $scriptDir "vi-compatibility-matrix.json"

function Get-CompatibilityMatrix {
    param($Metadata, $TargetVersions, $TargetPlatforms)
    
    $compatData = Get-Content $compatMatrixPath | ConvertFrom-Json
    $matrix = @{}
    
    foreach ($version in $TargetVersions) {
        foreach ($platform in $TargetPlatforms) {
            $key = "lv${version}_$(if ($platform -eq '32-bit') { '32bit' } else { '64bit' })"
            
            $compatible = $true
            $reason = ""
            $warnings = @()
            
            # Check version compatibility
            $versionNum = [int]$version
            if ($Metadata.lv_version_normalized -gt $versionNum) {
                $compatible = $false
                $reason = "VI saved in LabVIEW $($Metadata.lv_version), incompatible with $version"
            }
            
            # Check platform-specific features
            if ($platform -eq "32-bit" -and $Metadata.platform_features -contains "64-bit specific") {
                $compatible = $false
                $reason = "Uses 64-bit only features"
            }
            
            # Check for deprecated APIs
            if ($Metadata.deprecated_apis.Count -gt 0) {
                $warnings += "Uses $($Metadata.deprecated_apis.Count) deprecated API(s)"
            }
            
            $matrix.$key = @{
                compatible = $compatible
                reason = $reason
                warnings = $warnings
            }
        }
    }
    
    return $matrix
}

function Get-RecommendedMinimum {
    param($Matrix)
    
    # Find minimum compatible version
    $versions = @("2021", "2023", "2024", "2025")
    $platforms = @("32bit", "64bit")
    
    foreach ($version in $versions) {
        foreach ($platform in $platforms) {
            $key = "lv${version}_$platform"
            if ($Matrix.$key.compatible) {
                $platformName = if ($platform -eq "32bit") { "32-bit" } else { "64-bit" }
                return "LabVIEW $version $platformName"
            }
        }
    }
    
    return "No compatible version found"
}

function Get-UpgradePath {
    param($Matrix, $Metadata)
    
    $steps = @()
    
    # Check for deprecated APIs
    if ($Metadata.deprecated_apis.Count -gt 0) {
        $steps += "Step 1: Replace deprecated APIs"
    }
    
    # Check for platform restrictions
    if ($Metadata.platform_features -contains "64-bit specific") {
        $steps += "Step 2: Add 32-bit compatibility or document 64-bit requirement"
    }
    
    if ($steps.Count -eq 0) {
        $steps += "No upgrade steps required"
    }
    
    return $steps
}

function Main {
    Write-Host "=== VI Compatibility Analyzer ===" -ForegroundColor Cyan
    Write-Host "VI Path: $VIPath"
    Write-Host "Target Versions: $($TargetVersions -join ', ')"
    Write-Host "Target Platforms: $($TargetPlatforms -join ', ')"
    Write-Host ""
    
    try {
        # Get VI metadata
        Write-Host "Analyzing VI compatibility..." -ForegroundColor Yellow
        $output = & $metadataScript -VIPath $VIPath -OutputFormat json 2>&1 | Where-Object { $_ -match '^\s*{' } | Out-String
        $metadata = $output | ConvertFrom-Json
        
        # Generate compatibility matrix
        $matrix = Get-CompatibilityMatrix -Metadata $metadata -TargetVersions $TargetVersions -TargetPlatforms $TargetPlatforms
        $recommendedMin = Get-RecommendedMinimum -Matrix $matrix
        $upgradePath = Get-UpgradePath -Matrix $matrix -Metadata $metadata
        
        # Build analysis report
        $report = @{
            vi_name = $metadata.vi_name
            vi_path = $VIPath
            compatibility_matrix = $matrix
            recommended_minimum = $recommendedMin
            upgrade_path = $upgradePath
            analyzed_at = (Get-Date).ToString("o")
        }
        
        # Output report
        if ($OutputFormat -eq "json") {
            $json = $report | ConvertTo-Json -Depth 10
            Write-Output $json
        }
        elseif ($OutputFormat -eq "matrix") {
            Write-Host ""
            Write-Host "Compatibility Matrix:" -ForegroundColor Cyan
            foreach ($key in $matrix.Keys | Sort-Object) {
                $status = if ($matrix.$key.compatible) { "✓" } else { "✗" }
                $color = if ($matrix.$key.compatible) { "Green" } else { "Red" }
                Write-Host "$status $key" -ForegroundColor $color
                if ($matrix.$key.reason) {
                    Write-Host "  Reason: $($matrix.$key.reason)" -ForegroundColor Yellow
                }
            }
        }
        
        Write-Host ""
        Write-Host "✓ Analysis completed successfully" -ForegroundColor Green
        Write-Host "Recommended minimum: $recommendedMin" -ForegroundColor Cyan
        
        exit 0
    }
    catch {
        Write-Host "✗ Error: $_" -ForegroundColor Red
        exit 1
    }
}

Main
