#Requires -Version 7.0
<#
.SYNOPSIS
Runs a deterministic local Linux container preflight using .lvcontainer.

.DESCRIPTION
Resolves the Linux container contract from .lvcontainer, verifies or pulls
the target image, runs runner-cli parity context/run in linux-container mode,
and optionally runs the Linux VI Analyzer worker in Docker.

The script writes:
- Parity context JSON (path configurable)
- Summary JSON with deterministic keys (path configurable)

.PARAMETER RepoRoot
Repository root path. Defaults to current directory.

.PARAMETER ContextOutputPath
Path to write parity context JSON. Relative paths are rooted at RepoRoot.
Default: builds/status/local-preflight-parity-context-<sha>.json

.PARAMETER SummaryOutputPath
Path to write summary JSON. Relative paths are rooted at RepoRoot.
Default: builds/status/local-linux-preflight-summary-<sha>.json

.PARAMETER SkipViAnalyzer
Skip Linux VI Analyzer worker execution.

.PARAMETER DryRun
Print the command plan without running external commands.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$RepoRoot = '.',

    [Parameter(Mandatory = $false)]
    [AllowNull()]
    [AllowEmptyString()]
    [string]$ContextOutputPath = '',

    [Parameter(Mandatory = $false)]
    [AllowNull()]
    [AllowEmptyString()]
    [string]$SummaryOutputPath = '',

    [Parameter(Mandatory = $false)]
    [switch]$SkipViAnalyzer,

    [Parameter(Mandatory = $false)]
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

function Resolve-RepoRootPath {
    param([Parameter(Mandatory = $true)][string]$PathInput)

    return (Resolve-Path -Path $PathInput -ErrorAction Stop).Path
}

function Resolve-AbsolutePathFromRoot {
    param(
        [Parameter(Mandatory = $true)][string]$RepoRootPath,
        [Parameter(Mandatory = $true)][string]$PathInput
    )

    if ([System.IO.Path]::IsPathRooted($PathInput)) {
        return [System.IO.Path]::GetFullPath($PathInput)
    }

    return [System.IO.Path]::GetFullPath((Join-Path -Path $RepoRootPath -ChildPath $PathInput))
}

function Initialize-ParentDirectory {
    param([Parameter(Mandatory = $true)][string]$FilePath)

    $parent = Split-Path -Path $FilePath -Parent
    if (-not [string]::IsNullOrWhiteSpace($parent) -and -not (Test-Path -Path $parent -PathType Container)) {
        New-Item -Path $parent -ItemType Directory -Force | Out-Null
    }
}

function Get-GitSha {
    param([Parameter(Mandatory = $true)][string]$RepoRootPath)

    $sha = git -C $RepoRootPath rev-parse HEAD 2>$null
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($sha)) {
        throw "Unable to resolve git SHA from repository root: $RepoRootPath"
    }

    return $sha.Trim()
}

function Format-CommandForDisplay {
    param(
        [Parameter(Mandatory = $true)][string]$FilePath,
        [Parameter(Mandatory = $false)][string[]]$ArgumentList
    )

    $parts = @($FilePath)
    foreach ($arg in @($ArgumentList)) {
        if ($null -eq $arg) {
            continue
        }

        $value = [string]$arg
        if ($value -match '\s') {
            $parts += '"' + $value.Replace('"', '\"') + '"'
        } else {
            $parts += $value
        }
    }

    return ($parts -join ' ')
}

function Invoke-ExternalCommand {
    param(
        [Parameter(Mandatory = $true)][string]$Label,
        [Parameter(Mandatory = $true)][string]$FilePath,
        [Parameter(Mandatory = $false)][string[]]$ArgumentList,
        [Parameter(Mandatory = $false)][switch]$AllowFailure
    )

    $display = Format-CommandForDisplay -FilePath $FilePath -ArgumentList $ArgumentList
    Write-Host ("[{0}] {1}" -f $Label, $display)

    if ($DryRun) {
        return 0
    }

    & $FilePath @ArgumentList | Out-Host
    $exitCode = if ($null -eq $LASTEXITCODE) { 0 } else { [int]$LASTEXITCODE }

    if (-not $AllowFailure -and $exitCode -ne 0) {
        throw ("{0} failed with exit code {1}." -f $Label, $exitCode)
    }

    return $exitCode
}

$resolvedRepoRoot = Resolve-RepoRootPath -PathInput $RepoRoot
$sha = Get-GitSha -RepoRootPath $resolvedRepoRoot
$shortSha = if ($sha.Length -ge 7) { $sha.Substring(0, 7) } else { $sha }

if ([string]::IsNullOrWhiteSpace($ContextOutputPath)) {
    $ContextOutputPath = "builds/status/local-preflight-parity-context-$shortSha.json"
}
if ([string]::IsNullOrWhiteSpace($SummaryOutputPath)) {
    $SummaryOutputPath = "builds/status/local-linux-preflight-summary-$shortSha.json"
}

$resolvedContextOutputPath = Resolve-AbsolutePathFromRoot -RepoRootPath $resolvedRepoRoot -PathInput $ContextOutputPath
$resolvedSummaryOutputPath = Resolve-AbsolutePathFromRoot -RepoRootPath $resolvedRepoRoot -PathInput $SummaryOutputPath

Initialize-ParentDirectory -FilePath $resolvedContextOutputPath
Initialize-ParentDirectory -FilePath $resolvedSummaryOutputPath

$summary = [ordered]@{
    sha                 = $sha
    lvcontainer_raw     = ''
    release_tag         = ''
    linux_image         = ''
    parity_context_path = $resolvedContextOutputPath
    parity_run_exit_code = $null
    vi_analyzer_exit_code = $null
    status              = 'fail'
    timestamp_utc       = (Get-Date).ToUniversalTime().ToString('o')
}

$exitCode = 1
try {
    $containerHelperPath = Join-Path $resolvedRepoRoot 'Tooling\support\LabVIEWContainerRelease.ps1'
    if (-not (Test-Path -Path $containerHelperPath -PathType Leaf)) {
        throw "Container release helper was not found: $containerHelperPath"
    }

    . $containerHelperPath
    $containerInfo = Get-LabVIEWContainerReleaseInfo -RepoRoot $resolvedRepoRoot

    $summary.lvcontainer_raw = [string]$containerInfo.Raw
    $summary.release_tag = [string]$containerInfo.ReleaseTag
    $summary.linux_image = [string]$containerInfo.LinuxImage

    if (-not [string]::Equals([string]$containerInfo.Os, 'linux', [System.StringComparison]::OrdinalIgnoreCase)) {
        throw ("Resolved .lvcontainer tag '{0}' is not linux (os={1})." -f [string]$containerInfo.Tag, [string]$containerInfo.Os)
    }
    if ([string]::IsNullOrWhiteSpace($summary.release_tag)) {
        throw "Resolved ReleaseTag is empty for .lvcontainer value '$($summary.lvcontainer_raw)'."
    }
    if ([string]::IsNullOrWhiteSpace($summary.linux_image)) {
        throw "Resolved LinuxImage is empty for .lvcontainer value '$($summary.lvcontainer_raw)'."
    }

    $runnerCliProject = Join-Path $resolvedRepoRoot 'Tooling\runner-cli\RunnerCli\RunnerCli.csproj'
    if (-not (Test-Path -Path $runnerCliProject -PathType Leaf)) {
        throw "runner-cli project not found at $runnerCliProject"
    }

    $inspectExit = Invoke-ExternalCommand `
        -Label 'docker-image-inspect' `
        -FilePath 'docker' `
        -ArgumentList @('image', 'inspect', $summary.linux_image) `
        -AllowFailure
    if ($inspectExit -ne 0) {
        Invoke-ExternalCommand `
            -Label 'docker-pull' `
            -FilePath 'docker' `
            -ArgumentList @('pull', $summary.linux_image) | Out-Null
    }

    $contextArgs = @(
        'run',
        '--project', $runnerCliProject,
        '--configuration', 'Release',
        '--',
        'parity', 'context',
        '--mode', 'linux-container',
        '--repo-root', $resolvedRepoRoot,
        '--lv-release', $summary.release_tag,
        '--output', $resolvedContextOutputPath
    )
    Invoke-ExternalCommand -Label 'parity-context' -FilePath 'dotnet' -ArgumentList $contextArgs | Out-Null

    $parityRunArgs = @(
        'run',
        '--project', $runnerCliProject,
        '--configuration', 'Release',
        '--',
        'parity', 'run',
        '--mode', 'linux-container',
        '--context', $resolvedContextOutputPath,
        '--build-spec', 'true'
    )
    $parityRunExitCode = Invoke-ExternalCommand -Label 'parity-run' -FilePath 'dotnet' -ArgumentList $parityRunArgs
    $summary.parity_run_exit_code = $parityRunExitCode

    if (-not $SkipViAnalyzer) {
        $viAnalyzerScriptInContainer = '/workspace/Tooling/container-parity/run-vi-analyzer-linux.sh'
        $tasksPathInContainer = '/workspace/Tooling/vi-analyzer/tasks.linux.json'
        $dockerCommand = "chmod +x $viAnalyzerScriptInContainer && $viAnalyzerScriptInContainer"

        $viAnalyzerArgs = @(
            'run',
            '--rm',
            '-v', ("{0}:/workspace" -f $resolvedRepoRoot),
            '-e', 'LVIE_REPO_ROOT=/workspace',
            '-e', 'WORKSPACE_ROOT=/workspace',
            '-e', 'REPO_ROOT=/workspace',
            '-e', "LVIE_VI_ANALYZER_TASKS_PATH=$tasksPathInContainer",
            '-e', "LVIE_VI_ANALYZER_LABVIEW_YEAR=$([string]$containerInfo.Year)",
            $summary.linux_image,
            'bash', '-lc', $dockerCommand
        )

        $viAnalyzerExitCode = Invoke-ExternalCommand -Label 'vi-analyzer-linux' -FilePath 'docker' -ArgumentList $viAnalyzerArgs
        $summary.vi_analyzer_exit_code = $viAnalyzerExitCode
    }

    $summary.status = if ($DryRun) { 'dry-run' } else { 'pass' }
    $exitCode = 0
} catch {
    Write-Error $_
    $summary.status = 'fail'
    $exitCode = 1
} finally {
    $summary.timestamp_utc = (Get-Date).ToUniversalTime().ToString('o')
    $summary | ConvertTo-Json -Depth 6 | Out-File -FilePath $resolvedSummaryOutputPath -Encoding utf8
    Write-Host ("Summary written: {0}" -f $resolvedSummaryOutputPath)
}

exit $exitCode
