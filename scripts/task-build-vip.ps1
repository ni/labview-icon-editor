[CmdletBinding()]
param(
    [string]$RepositoryPath = ".",
    [ValidateSet("32","64","both")]
    [string]$Bitness = "64",
    [switch]$SkipCIGate
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repo = (Resolve-Path -LiteralPath $RepositoryPath -ErrorAction Stop).ProviderPath
$getVer = Join-Path $repo 'scripts/get-package-lv-version.ps1'
$ciGate = Join-Path $repo 'scripts/check-ci-gate.ps1'
$build  = Join-Path $repo 'scripts/run-build-or-package.ps1'
$analyze = Join-Path $repo '.github/actions/analyze-vi-package/run-local.ps1'
$vipDir = Join-Path $repo 'builds/VI Package'

if (-not (Test-Path -LiteralPath $getVer))  { throw "Missing get-package-lv-version.ps1 at $getVer" }
if (-not (Test-Path -LiteralPath $build))   { throw "Missing run-build-or-package.ps1 at $build" }
if (-not (Test-Path -LiteralPath $analyze)) { throw "Missing analyze runner at $analyze" }

$minLv = & $getVer -RepositoryPath $repo
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($minLv)) {
    throw "Failed to derive LabVIEW version from VIPB under $repo."
}

if (-not $SkipCIGate) {
    if (-not (Test-Path -LiteralPath $ciGate)) {
        throw "Missing check-ci-gate.ps1 at $ciGate"
    }
    & $ciGate -WorkflowFile '.github/workflows/ci.yml' -RepositoryPath $repo
    if ($LASTEXITCODE -ne 0) {
        Write-Host 'CI gate failed. Ensure gh is installed/authenticated and a successful .github/workflows/ci.yml run exists for this commit. Set GH_TOKEN/GITHUB_TOKEN if needed.'
        exit $LASTEXITCODE
    }
}

& $build -BuildMode 'vip+lvlibp' -WorkspacePath $repo -LabVIEWMinorRevision 3 -LvlibpBitness $Bitness
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

& $analyze -VipArtifactPath $vipDir -MinLabVIEW $minLv
exit $LASTEXITCODE
