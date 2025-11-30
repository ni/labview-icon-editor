param(
    # Path to the built artifact (directory containing .vip, or a .zip of the artifact). Mirrors CI artifact path.
    [string]$VipArtifactPath = "builds/vip-stash",
    # Minimum LabVIEW version (major.minor)
    [string]$MinLabVIEW = "21.0"
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Off

$script:tempDir = $null
function Resolve-Vip {
    param([string]$PathSpec)

    if (Test-Path -LiteralPath $PathSpec -PathType Leaf -ErrorAction SilentlyContinue) {
        if ([IO.Path]::GetExtension($PathSpec) -ieq '.zip') {
            $script:tempDir = Join-Path -Path ([IO.Path]::GetTempPath()) -ChildPath ([IO.Path]::GetRandomFileName())
            New-Item -ItemType Directory -Path $script:tempDir -Force | Out-Null
            Expand-Archive -LiteralPath $PathSpec -DestinationPath $script:tempDir -Force
            $PathSpec = $script:tempDir
        } else {
            return (Resolve-Path -LiteralPath $PathSpec).Path
        }
    }

    if (Test-Path -LiteralPath $PathSpec -PathType Container -ErrorAction SilentlyContinue) {
        $vip = Get-ChildItem -Path $PathSpec -Filter *.vip -File -Recurse |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 1
        if (-not $vip) { throw "No .vip file found under '$PathSpec'." }
        return $vip.FullName
    }

    # Wildcard or pattern path
    $candidate = Get-ChildItem -Path $PathSpec -File -Recurse -ErrorAction SilentlyContinue |
        Where-Object { $_.Extension -ieq '.vip' } |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1
    if (-not $candidate) { throw "No .vip file matched '$PathSpec'." }
    return $candidate.FullName
}

try {
    $resolvedVip = Resolve-Vip -PathSpec $VipArtifactPath

    # Ensure Pester 5.7.1 (align with CI and run-local)
    $desiredVersion = [version]'5.7.1'
    Remove-Module Pester -ErrorAction SilentlyContinue
    $mod = Get-Module -ListAvailable -Name Pester | Where-Object { $_.Version -eq $desiredVersion } | Select-Object -First 1
    if (-not $mod) {
        Install-Module Pester -RequiredVersion $desiredVersion -Scope CurrentUser -Force -SkipPublisherCheck
        $mod = Get-Module -ListAvailable -Name Pester | Where-Object { $_.Version -eq $desiredVersion } | Select-Object -First 1
    }
    if (-not $mod) { throw "Pester $desiredVersion not available even after install." }
    Import-Module $mod.Path -Force

    $work = $PSScriptRoot
    Set-Location $work
    $tests = Join-Path $work "Analyze-VIP.Tests.ps1"
    $results = Join-Path $work "pester-results.xml"

    Write-Information "Analyzing VIP: $resolvedVip" -InformationAction Continue
    $env:VIP_PATH = $resolvedVip
    $env:MIN_LV_VERSION = $MinLabVIEW
    $config = [PesterConfiguration]::Default
    $config.Run.Path = @($tests)
    $config.Run.PassThru = $true
    $config.Output.Verbosity = 'Detailed'
    $config.TestResult.Enabled = $true
    $config.TestResult.OutputPath = $results
    Invoke-Pester -Configuration $config | Out-Host

    Write-Information "JUnit report: $results" -InformationAction Continue
} finally {
    if ($script:tempDir -and (Test-Path $script:tempDir)) {
        Remove-Item -LiteralPath $script:tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}
