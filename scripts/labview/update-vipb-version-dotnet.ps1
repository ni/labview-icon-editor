[CmdletBinding(SupportsShouldProcess=$true)]
param(
    [Parameter(Mandatory=$true)][string]$RepositoryPath,
    [Parameter(Mandatory=$true)][string]$TargetBranch,
    [Parameter(Mandatory=$true)][ValidateRange(2020,2035)][int]$LabVIEWVersion,
    [ValidateSet('0','3')][string]$LabVIEWMinor='3',
    [ValidateSet('32','64')][string]$Bitness='64',
    [string]$VipbPath='Tooling/deployment/seed.vipb',
    [string]$CommitMessage,
    [switch]$SkipCommit,
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repo = (Resolve-Path -LiteralPath $RepositoryPath -ErrorAction Stop).ProviderPath
$vipbProject = Join-Path $repo 'Tooling/dotnet/VipbJsonTool/VipbJsonTool.csproj'
if (-not (Test-Path -LiteralPath $vipbProject -PathType Leaf)) {
    throw "VipbJsonTool project not found at $vipbProject"
}
$vipbPublishDir = Join-Path $repo 'builds/tooling-cache/vipbjson-win-x64'
$vipbExe = Join-Path $vipbPublishDir 'VipbJsonTool.exe'

function Invoke-Git {
    param([string[]]$Arguments)
    $result = & git -C $repo @Arguments
    if ($LASTEXITCODE -ne 0) {
        $joined = $Arguments -join ' '
        throw "git $joined failed with exit code $LASTEXITCODE"
    }
    return $result
}

$quarter = if ($LabVIEWMinor -eq '3') { 'Q3' } else { 'Q1' }
$majorToken = if ($LabVIEWVersion -ge 2000) { $LabVIEWVersion - 2000 } else { $LabVIEWVersion }
$versionString = '{0}.{1} ({2}-bit)' -f $majorToken, $LabVIEWMinor, $Bitness
$libraryVersion = '{0}.{1}.0.1' -f $majorToken, $LabVIEWMinor

if ($DryRun) {
    Write-Host '[DRY RUN] Validating inputs...'
    Invoke-Git -Arguments @('rev-parse','--verify',$TargetBranch) | Out-Null
    return [pscustomobject]@{
        Repository = $repo
        Branch = $TargetBranch
        LabVIEWVersion = $LabVIEWVersion
        LabVIEWMinor = $LabVIEWMinor
        Bitness = $Bitness
        VersionString = $versionString
        LibraryVersion = $libraryVersion
    }
}

Write-Host "Checking out branch '$TargetBranch'..."
try {
    Invoke-Git -Arguments @('fetch','origin',$TargetBranch) | Out-Null
} catch {
    Write-Warning "Unable to fetch origin/$TargetBranch (branch may be local only). Proceeding with local branch."
}
Invoke-Git -Arguments @('checkout',$TargetBranch) | Out-Null

$vipbFull = (Resolve-Path -LiteralPath (Join-Path $repo $VipbPath) -ErrorAction Stop).ProviderPath
$vipbRel = [System.IO.Path]::GetRelativePath($repo, $vipbFull)
$stashDir = Join-Path $repo 'builds/vipb-stash'
New-Item -ItemType Directory -Force -Path $stashDir | Out-Null
$sanitizedBranch = $TargetBranch -replace '[^A-Za-z0-9_-]','-'
$vipbJson = Join-Path $stashDir ("seed.vipb.{0}.{1}{2}.json" -f $sanitizedBranch, $LabVIEWVersion, $LabVIEWMinor)

function Ensure-VipbJsonTool {
    if (Test-Path -LiteralPath $vipbExe -PathType Leaf) {
        return
    }
    Write-Host 'Publishing VipbJsonTool (win-x64, framework-dependent)...'
    New-Item -ItemType Directory -Force -Path $vipbPublishDir | Out-Null
    $publishArgs = @(
        'publish', $vipbProject,
        '-c', 'Release',
        '-r', 'win-x64',
        '--self-contained', 'false',
        '-p:PublishSingleFile=false',
        '-o', $vipbPublishDir
    )
    & dotnet @publishArgs
    if ($LASTEXITCODE -ne 0) {
        throw "dotnet publish for VipbJsonTool failed with exit code $LASTEXITCODE"
    }
    if (-not (Test-Path -LiteralPath $vipbExe -PathType Leaf)) {
        throw "VipbJsonTool executable not found at $vipbExe after publish"
    }
}

function Invoke-VipbJsonTool {
    param([string[]]$CliArgs)
    Ensure-VipbJsonTool
    & $vipbExe @CliArgs
    if ($LASTEXITCODE -ne 0) {
        $joined = $CliArgs -join ' '
        throw "VipbJsonTool invocation '$joined' failed with exit code $LASTEXITCODE"
    }
}

Write-Host 'Decoding VIPB via VipbJsonTool...'
Invoke-VipbJsonTool -CliArgs @('vipb2json', $vipbFull, $vipbJson)

if (-not (Test-Path -LiteralPath $vipbJson -PathType Leaf)) {
    throw "VipbJsonTool did not produce JSON at $vipbJson"
}

$json = Get-Content -LiteralPath $vipbJson -Raw | ConvertFrom-Json
$generalSettings = $null
if ($json.PSObject.Properties['VI_Package_Builder_Settings']) {
    $generalSettings = $json.VI_Package_Builder_Settings.Library_General_Settings
} elseif ($json.PSObject.Properties['Package']) {
    $generalSettings = $json.Package.Library_General_Settings
} elseif ($json.PSObject.Properties['Library_General_Settings']) {
    $generalSettings = $json.Library_General_Settings
}
if (-not $generalSettings) {
    $props = $json.PSObject.Properties.Name -join ', '
    throw "Unable to locate Library_General_Settings in VIPB JSON. Known properties: $props"
}
$generalSettings.Package_LabVIEW_Version = $versionString
if ($generalSettings.PSObject.Properties['Library_Version']) {
    $generalSettings.Library_Version = $libraryVersion
}
$json | ConvertTo-Json -Depth 50 | Set-Content -LiteralPath $vipbJson -Encoding UTF8

Write-Host 'Encoding VIPB via VipbJsonTool...'
Invoke-VipbJsonTool -CliArgs @('json2vipb', $vipbJson, $vipbFull)
Remove-Item -LiteralPath $vipbJson -Force -ErrorAction SilentlyContinue

Write-Host 'Staging updated VIPB...'
Invoke-Git -Arguments @('add', $vipbRel) | Out-Null

if ($SkipCommit) {
    Write-Host 'SkipCommit set. Leaving changes staged.'
    return
}

if ([string]::IsNullOrWhiteSpace($CommitMessage)) {
    $CommitMessage = "Seed VIPB: LabVIEW $LabVIEWVersion $quarter ${Bitness}-bit ($versionString)"
}

Write-Host 'Committing changes...'
Invoke-Git -Arguments @('commit','-m',$CommitMessage) | Out-Null

Write-Host ''
Write-Host '=== VIPB Update Complete ===' -ForegroundColor Green
Write-Host "Branch: $TargetBranch"
Write-Host "Version String: $versionString"
Write-Host "Commit Message: $CommitMessage"

return [pscustomobject]@{
    Branch = $TargetBranch
    VipbPath = $vipbRel
    VersionString = $versionString
    CommitMessage = $CommitMessage
}
