[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$CliName,

    [Parameter(Mandatory)]
    [string]$RepoPath,

    [string]$SourceRepoPath,

    [string]$VersionOverride,

    [string]$Rid = 'win-x64',

    [switch]$PrintProvenance,

    # Internal: test hook to force the publish tier (used only by probe-helper-smoke)
    [switch]$ForcePublish,

    # Optional: assert the resolved cache key matches this value; throws if different.
    [string]$ExpectedCacheKey
)

<#
.SYNOPSIS
    Resolve a repo CLI path with probe/build/cache as per ADR-2025-013.

.DESCRIPTION
    Probes in order: worktree project -> source repo project -> cached publish -> publish and cache.
    Returns a PSCustomObject with Command (array), Path, Tier, CacheKey and other provenance fields.
    If -PrintProvenance is set, prints the provenance to the console.
#>

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Get-CacheRoot {
    param([string]$Cli, [string]$Ver, [string]$Runtime)
    if ($IsWindows -and $env:LOCALAPPDATA) {
        return Join-Path $env:LOCALAPPDATA "labview-icon-editor\tooling-cache\$Cli\$Ver\$Runtime\publish"
    }
    if ($env:HOME) {
        return Join-Path $env:HOME ".cache/labview-icon-editor/tooling-cache/$Cli/$Ver/$Runtime/publish"
    }
    throw "Unable to resolve cache root: set LOCALAPPDATA (Windows) or HOME (POSIX)."
}

function Get-CliExeName {
    param([string]$Cli)
    if ($IsWindows) { return "$Cli.exe" }
    return $Cli
}

function Get-CliProjectPath {
    param([string]$Root, [string]$Name)
    $map = @{
        'DevModeAgentCli'   = 'Tooling/dotnet/DevModeAgentCli/DevModeAgentCli.csproj'
        'OrchestrationCli'  = 'Tooling/dotnet/OrchestrationCli/OrchestrationCli.csproj'
        'OrchestrationCompatCli' = 'Tooling/dotnet/OrchestrationCompatCli/OrchestrationCompatCli.csproj'
        'IntegrationEngineCli' = 'Tooling/dotnet/IntegrationEngineCli/IntegrationEngineCli.csproj'
        'OllamaSmokeCli'    = 'Tooling/dotnet/OllamaSmokeCli/OllamaSmokeCli.csproj'
        'XCli'              = 'Tooling/x-cli/src/XCli/XCli.csproj'
        'RequirementsSummarizer' = 'Tooling/dotnet/RequirementsSummarizer/RequirementsSummarizer.csproj'
        'VipbJsonTool'      = 'Tooling/dotnet/VipbJsonTool/VipbJsonTool.csproj'
    }
    if (-not $map.ContainsKey($Name)) { return $null }
    $candidate = Join-Path (Resolve-Path -LiteralPath $Root).Path $map[$Name]
    if (Test-Path -LiteralPath $candidate -PathType Leaf) { return $candidate }
    return $null
}

function Get-GitSha {
    param([string]$Path)
    try {
        $sha = (git -C $Path rev-parse HEAD 2>$null).Trim()
        if ($sha) { return $sha }
    } catch { }
    return "unknown"
}

$repoFull = (Resolve-Path -LiteralPath $RepoPath).Path
$sourceFull = if ($SourceRepoPath) { (Resolve-Path -LiteralPath $SourceRepoPath).Path } else { $repoFull }
$version = if ($VersionOverride) { $VersionOverride } else { Get-GitSha -Path $repoFull }
$cacheRoot = Get-CacheRoot -Cli $CliName -Ver $version -Runtime $Rid
$exeName = Get-CliExeName -Cli $CliName

$tier = $null
$exePath = $null
$command = $null
$usedProject = $null
$log = @()
$runFailures = @()

function Invoke-Publish {
    param([string]$ProjectPath)
    if (-not $ProjectPath -or -not (Test-Path -LiteralPath $ProjectPath -PathType Leaf)) {
        throw "Cannot publish: project path not found ($ProjectPath)."
    }
    if (-not (Test-Path -LiteralPath $cacheRoot)) {
        New-Item -ItemType Directory -Path $cacheRoot -Force | Out-Null
    }
    $publishArgs = @(
        'publish', $ProjectPath,
        '-c', 'Release',
        '-r', $Rid,
        '-o', $cacheRoot,
        '--self-contained', 'false'
    )
    & dotnet @publishArgs | Out-Null
    $exeCandidate = Join-Path $cacheRoot $exeName
    if (-not (Test-Path -LiteralPath $exeCandidate -PathType Leaf)) {
        throw "Publish completed but $exeCandidate not found."
    }
    $script:exePath = (Resolve-Path -LiteralPath $exeCandidate).Path
    $script:command = @($exePath)
    $script:tier = 'publish'
    $script:usedProject = $ProjectPath
}

# Tier 1: active repo/worktree
$proj = Get-CliProjectPath -Root $repoFull -Name $CliName
if ($ForcePublish -and $proj) {
    Invoke-Publish -ProjectPath $proj
}
elseif ($proj) {
    try {
        $tier = 'worktree'
        $usedProject = $proj
        $command = @('dotnet', 'run', '--project', $proj, '--')
        $exePath = $proj
        # Lightweight build probe instead of full CLI run
        $buildProbe = Start-Process -FilePath 'dotnet' -ArgumentList @('build', $proj, '--nologo', '--clp:ErrorsOnly') -WorkingDirectory $repoFull -NoNewWindow -PassThru -Wait
        if ($buildProbe.ExitCode -ne 0) {
            $runFailures += "Worktree build failed (exit $($buildProbe.ExitCode)) for $proj"
            $tier = $null; $command = $null; $exePath = $null; $usedProject = $null
        }
    }
    catch {
        $runFailures += "Worktree probe threw: $($_.Exception.Message)"
        $tier = $null; $command = $null; $exePath = $null; $usedProject = $null
    }
}

# Tier 2: source repo
if (-not $command) {
    $proj = Get-CliProjectPath -Root $sourceFull -Name $CliName
    if ($ForcePublish -and $proj) {
        Invoke-Publish -ProjectPath $proj
    }
    elseif ($proj) {
        try {
            $tier = 'source'
            $usedProject = $proj
            $command = @('dotnet', 'run', '--project', $proj, '--')
            $exePath = $proj
            $buildProbe = Start-Process -FilePath 'dotnet' -ArgumentList @('build', $proj, '--nologo', '--clp:ErrorsOnly') -WorkingDirectory $sourceFull -NoNewWindow -PassThru -Wait
            if ($buildProbe.ExitCode -ne 0) {
                $runFailures += "Source build failed (exit $($buildProbe.ExitCode)) for $proj"
                $tier = $null; $command = $null; $exePath = $null; $usedProject = $null
            }
        }
        catch {
            $runFailures += "Source probe threw: $($_.Exception.Message)"
            $tier = $null; $command = $null; $exePath = $null; $usedProject = $null
        }
    }
}

# Tier 3: cached publish
if (-not $command) {
    $exeCandidate = Join-Path $cacheRoot $exeName
    if (Test-Path -LiteralPath $exeCandidate -PathType Leaf) {
        $tier = 'cache'
        $exePath = (Resolve-Path -LiteralPath $exeCandidate).Path
        $command = @($exePath)
    }
}

# Tier 4: publish and cache
if (-not $command) {
    $proj = Get-CliProjectPath -Root $sourceFull -Name $CliName
    if (-not $proj) {
        throw "Cannot locate $CliName in worktree or source repo; cache empty and no project to publish."
    }
    Invoke-Publish -ProjectPath $proj
}

if ($command -and -not $exePath -and $command.Count -gt 0) {
    $first = $command[0]
    if ($first -notlike 'dotnet') { $exePath = $first }
}

$provenance = [pscustomobject]@{
    CliName     = $CliName
    Version     = $version
    Rid         = $Rid
    Tier        = $tier
    CacheKey    = "$CliName/$version/$Rid"
    CachePath   = $cacheRoot
    ProjectPath = $usedProject
    BinaryPath  = $exePath
    Command     = $command
}

if ($ExpectedCacheKey) {
    if (-not ($provenance.CacheKey -eq $ExpectedCacheKey)) {
        throw ("Resolved cache key '{0}' does not match expected '{1}'." -f $provenance.CacheKey, $ExpectedCacheKey)
    }
}

function Write-ProvenanceLog {
    param([psobject]$Prov)
    $line = @(
        "cli=$($Prov.CliName)"
        "tier=$($Prov.Tier)"
        "cacheKey=$($Prov.CacheKey)"
        "cachePath=$($Prov.CachePath)"
        "binaryPath=$($Prov.BinaryPath)"
        "projectPath=$($Prov.ProjectPath)"
        "rid=$($Prov.Rid)"
    ) -join ' '
    Write-Host $line
}

Write-ProvenanceLog -Prov $provenance
if ($runFailures.Count -gt 0) {
    foreach ($f in $runFailures) {
        Write-Warning $f
    }
}

if ($PrintProvenance) {
    $provenance | Format-List
    Write-ProvenanceLog -Prov $provenance
}

return $provenance
