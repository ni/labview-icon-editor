[CmdletBinding()]
param(
    [ValidateSet('gcli','labviewcli')]
    [string]$Runner = 'gcli',
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$XcliArgs
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$root = Split-Path -Parent $PSScriptRoot
$tempHelper = Join-Path $PSScriptRoot 'common/Ensure-StandardTempPath.ps1'
if (-not (Test-Path -LiteralPath $tempHelper)) {
    throw "Temp helper not found: $tempHelper"
}
. $tempHelper
Ensure-StandardTempPath -Label 'labview-icon-editor' | Out-Null

if ($Runner -eq 'gcli') {
    $stale = Get-Process -Name XCli -ErrorAction SilentlyContinue
    if ($stale) {
        Write-Host ("[x-cli-wrapper] Stopping lingering XCli processes: {0}" -f (($stale | Select-Object -ExpandProperty Id) -join ',')) 
        $stale | Stop-Process -Force -ErrorAction SilentlyContinue
    }

    $dotnetArgs = @(
        'run',
        '--project', (Join-Path $root 'Tooling/x-cli/src/XCli/XCli.csproj'),
        '--'
    ) + $XcliArgs

    Write-Host ("[x-cli-wrapper] runner=gcli dotnet {0}" -f ($dotnetArgs -join ' '))
    & dotnet @dotnetArgs
    exit $LASTEXITCODE
}

# LabVIEWCLI mode
$repoRoot = $null
for ($i=0; $i -lt $XcliArgs.Length; $i++) {
    if ($XcliArgs[$i] -eq '--repo' -and ($i + 1) -lt $XcliArgs.Length) {
        $repoRoot = $XcliArgs[$i+1]
        break
    }
}
if (-not $repoRoot) {
    $repoRoot = (Get-Location).Path
}
$repoRoot = (Resolve-Path -LiteralPath $repoRoot).Path
$projectPath = Join-Path $repoRoot 'lv_icon_editor.lvproj'
$logPath = Join-Path $repoRoot 'reports/logs/lvsd-build.log'
$lvsdScript = Join-Path $root 'scripts/labview/build-source-distribution.ps1'
$argsList = @(
    '-RepositoryPath', $repoRoot,
    '-ProjectPath', $projectPath,
    '-VipbPath', 'Tooling/deployment/seed.vipb',
    '-BuildSpecName', 'Source Distribution',
    '-TargetName', 'My Computer',
    '-LogFilePath', $logPath,
    '-AllowLabVIEWFallback'
)
Write-Host ("[x-cli-wrapper] runner=labviewcli pwsh -File {0} {1}" -f $lvsdScript, ($argsList -join ' '))
& pwsh -NoProfile -File $lvsdScript @argsList
exit $LASTEXITCODE
