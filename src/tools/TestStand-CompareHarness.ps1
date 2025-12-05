#requires -Version 7.0
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Baseline,
    [Parameter(Mandatory)][string]$Candidate,
    [Parameter(Mandatory)][string]$OutputDirectory,
    [string]$NoiseProfile = 'full',
    [switch]$IgnoreAttributes,
    [switch]$IgnoreFrontPanel,
    [switch]$IgnoreFrontPanelPosition,
    [switch]$IgnoreBlockDiagram,
    [switch]$IgnoreBlockDiagramCosmetics
)

# Harness that invokes LVCompare when available; falls back to a captured stub otherwise.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $OutputDirectory -PathType Container)) {
    New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null
}

function Resolve-LVComparePath {
    $candidates = New-Object System.Collections.Generic.List[string]
    if ($env:LABVIEW_EXE_PATH) {
        $candidates.Add((Join-Path (Split-Path -Parent $env:LABVIEW_EXE_PATH) 'LVCompare.exe'))
    }
    $candidates.Add('C:\Program Files\National Instruments\LabVIEW 2025\LVCompare.exe')
    $candidates.Add('C:\Program Files\National Instruments\LabVIEW 2023\LVCompare.exe')
    $candidates.Add('C:\Program Files\National Instruments\LabVIEW 2021\LVCompare.exe')
    $candidates.Add('C:\Program Files (x86)\National Instruments\LabVIEW 2025\LVCompare.exe')
    $cmd = Get-Command -Name 'LVCompare.exe' -ErrorAction SilentlyContinue
    if (-not $cmd) { $cmd = Get-Command -Name 'LVCompare' -ErrorAction SilentlyContinue }
    if ($cmd) { $candidates.Add($cmd.Source) }

    foreach ($path in ($candidates | Where-Object { $_ })) {
        if (Test-Path -LiteralPath $path -PathType Leaf) { return (Resolve-Path -LiteralPath $path).Path }
    }

    $probeRoot = 'C:\Program Files\National Instruments'
    if (Test-Path -LiteralPath $probeRoot -PathType Container) {
        $found = Get-ChildItem -Path $probeRoot -Filter 'LVCompare.exe' -Recurse -ErrorAction SilentlyContinue -Force | Select-Object -First 1
        if ($found) { return $found.FullName }
    }
    return $null
}

function Write-Report {
    param([string]$Path, [string]$Title, [string]$Body)
    $encoded = [System.Net.WebUtility]::HtmlEncode($Body)
    $html = @"
<!DOCTYPE html>
<html><head><meta charset='utf-8'><title>$Title</title></head>
<body><pre>$encoded</pre></body></html>
"@
    $html | Set-Content -LiteralPath $Path -Encoding UTF8
}

function Write-Capture {
    param([string]$Dir, [string]$Status, [string]$Reason, [int]$ExitCode, [string]$StdOut, [string]$StdErr, [string]$LvComparePath)
    $capture = [ordered]@{
        schema   = 'labview-cli-capture@v1'
        status   = $Status
        reason   = $Reason
        exitCode = $ExitCode
        at       = (Get-Date).ToString('o')
        lvcompare = $LvComparePath
        stdout  = $StdOut
        stderr  = $StdErr
    }
    $capture | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $Dir 'lvcompare-capture.json') -Encoding UTF8
}

if (-not (Test-Path -LiteralPath $Baseline -PathType Leaf) -or -not (Test-Path -LiteralPath $Candidate -PathType Leaf)) {
    $msg = "Baseline or candidate missing. Baseline=$Baseline Candidate=$Candidate"
    Write-Warning "[harness] $msg"
    Write-Capture -Dir $OutputDirectory -Status 'fail' -Reason $msg -ExitCode 1 -StdOut '' -StdErr '' -LvComparePath $null
    Write-Report -Path (Join-Path $OutputDirectory 'compare-report.html') -Title 'VI Compare (missing input)' -Body $msg
    return
}

$lvCompareExe = Resolve-LVComparePath
$stdout = ''
$stderr = ''
$exitCode = 0
$status = 'success'
$reason = 'LVCompare executed.'

if (-not $lvCompareExe) {
    $status = 'dry-run'
    $reason = 'LVCompare.exe not found; stub capture only.'
    Write-Warning "[harness] $reason"
} else {
    $args = @($Baseline, $Candidate, '-nobdcosm', '-nofppos', '-nobdcolor', '-nofpcolor')
    try {
        $proc = Start-Process -FilePath $lvCompareExe -ArgumentList $args -NoNewWindow -PassThru -Wait -RedirectStandardOutput (Join-Path $OutputDirectory 'lvcompare.stdout.txt') -RedirectStandardError (Join-Path $OutputDirectory 'lvcompare.stderr.txt')
        $exitCode = $proc.ExitCode
        if (Test-Path -LiteralPath (Join-Path $OutputDirectory 'lvcompare.stdout.txt')) {
            $stdout = Get-Content -LiteralPath (Join-Path $OutputDirectory 'lvcompare.stdout.txt') -Raw -ErrorAction SilentlyContinue
        }
        if (Test-Path -LiteralPath (Join-Path $OutputDirectory 'lvcompare.stderr.txt')) {
            $stderr = Get-Content -LiteralPath (Join-Path $OutputDirectory 'lvcompare.stderr.txt') -Raw -ErrorAction SilentlyContinue
        }
        if ($exitCode -ne 0) {
            $status = 'fail'
            $reason = "LVCompare exited with $exitCode."
        }
    } catch {
        $status = 'fail'
        $reason = "LVCompare invocation failed: $($_.Exception.Message)"
        $stderr = $_.ToString()
        $exitCode = 1
    }
}

Write-Capture -Dir $OutputDirectory -Status $status -Reason $reason -ExitCode $exitCode -StdOut $stdout -StdErr $stderr -LvComparePath $lvCompareExe

$summary = [ordered]@{
    schema     = 'teststand-compare-harness@v1'
    baseline   = $Baseline
    candidate  = $Candidate
    noiseProfile = $NoiseProfile
    ignoreAttributes = [bool]$IgnoreAttributes
    ignoreFrontPanel = [bool]$IgnoreFrontPanel
    ignoreFrontPanelPosition = [bool]$IgnoreFrontPanelPosition
    ignoreBlockDiagram = [bool]$IgnoreBlockDiagram
    ignoreBlockDiagramCosmetics = [bool]$IgnoreBlockDiagramCosmetics
    compared   = ($status -eq 'success' -and $exitCode -eq 0)
    message    = $reason
    exitCode   = $exitCode
    lvcompare  = $lvCompareExe
    generatedAt = (Get-Date).ToString('o')
}

$summaryPath = Join-Path $OutputDirectory 'harness-summary.json'
$summary | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $summaryPath -Encoding UTF8

$reportBody = if ($status -eq 'success') { 'LVCompare completed successfully.' } else { $reason }
Write-Report -Path (Join-Path $OutputDirectory 'compare-report.html') -Title 'VI Compare' -Body $reportBody

Write-Host ("[harness] Summary written to {0} (status={1}, exit={2})" -f $summaryPath, $status, $exitCode)
