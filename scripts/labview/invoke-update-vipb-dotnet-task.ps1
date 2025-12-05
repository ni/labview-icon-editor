[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$RepositoryPath,
    [string]$TargetBranch,
    [string]$BaseBranch = 'develop',
    [string]$WorkingBranch,
    [Parameter(Mandatory=$true)][ValidateRange(2020,2035)][int]$LabVIEWVersion,
    [Parameter(Mandatory=$true)][ValidateSet('0','3')][string]$LabVIEWMinor,
    [Parameter(Mandatory=$true)][ValidateSet('32','64')][string]$Bitness,
    [string]$VipbPath = 'Tooling/deployment/seed.vipb',
    [string]$CommitMessage,
    [switch]$SkipCommit,
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptPath = Join-Path $PSScriptRoot 'update-vipb-version-dotnet.ps1'
if (-not (Test-Path -LiteralPath $scriptPath -PathType Leaf)) {
    throw "Unable to locate update script at $scriptPath"
}

$repo = (Resolve-Path -LiteralPath $RepositoryPath -ErrorAction Stop).ProviderPath

function Invoke-Git {
    param([string[]]$Arguments)
    $result = & git -C $repo @Arguments
    if ($LASTEXITCODE -ne 0) {
        $joined = $Arguments -join ' '
        throw "git $joined failed with exit code $LASTEXITCODE"
    }
    return $result
}

if ([string]::IsNullOrWhiteSpace($TargetBranch)) {
    $TargetBranch = $BaseBranch
}

$effectiveBranch = $TargetBranch
if (-not [string]::IsNullOrWhiteSpace($WorkingBranch)) {
    Write-Host "Creating or updating working branch '$WorkingBranch' from '$BaseBranch'..."
    Invoke-Git -Arguments @('fetch','origin',$BaseBranch) | Out-Null
    $baseRef = "origin/$BaseBranch"
    try {
        Invoke-Git -Arguments @('rev-parse',$baseRef) | Out-Null
    } catch {
        $baseRef = $BaseBranch
    }
    Invoke-Git -Arguments @('checkout','-B',$WorkingBranch,$baseRef) | Out-Null
    $effectiveBranch = $WorkingBranch
}

$params = @{
    RepositoryPath = $repo
    TargetBranch   = $effectiveBranch
    LabVIEWVersion = $LabVIEWVersion
    LabVIEWMinor   = $LabVIEWMinor
    Bitness        = $Bitness
    VipbPath       = $VipbPath
}
if ($SkipCommit) { $params.SkipCommit = $true }
if ($DryRun) { $params.DryRun = $true }
if ([string]::IsNullOrWhiteSpace($CommitMessage) -and -not [string]::IsNullOrWhiteSpace($env:VIPB_COMMIT_MESSAGE)) {
    $CommitMessage = $env:VIPB_COMMIT_MESSAGE
}

if (-not [string]::IsNullOrWhiteSpace($CommitMessage)) {
    $params.CommitMessage = $CommitMessage
}

& $scriptPath @params
exit $LASTEXITCODE
