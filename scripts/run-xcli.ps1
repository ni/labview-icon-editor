[CmdletBinding()]
param(
    [string]$Runner = "gcli",
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$XcliArgs
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

if (-not $XcliArgs -or $XcliArgs.Count -eq 0) {
    throw "Expected x-cli command (e.g., source-dist-build)."
}

$command = $XcliArgs[0]
$rest = if ($XcliArgs.Count -gt 1) { $XcliArgs[1..($XcliArgs.Count-1)] } else { @() }

function Parse-Args {
    param([string[]]$Args)

    $parsed = [ordered]@{
        repo         = $null
        commitIndex  = $null
        verboseGit   = $false
        allowDirty   = $false
        perfCpu      = $false
    }

    for ($i = 0; $i -lt $Args.Count; $i++) {
        switch ($Args[$i]) {
            '--repo' {
                if ($i + 1 -ge $Args.Count) { throw "--repo expects a value" }
                $parsed.repo = $Args[++$i]
            }
            '--commit-index' {
                if ($i + 1 -ge $Args.Count) { throw "--commit-index expects a value" }
                $parsed.commitIndex = $Args[++$i]
            }
            '--verbose-git' { $parsed.verboseGit = $true }
            '--allow-dirty' { $parsed.allowDirty = $true }
            '--perf-cpu'    { $parsed.perfCpu = $true }
            default { }
        }
    }

    return $parsed
}

switch ($command) {
    'source-dist-build' {
        $parsed = Parse-Args -Args $rest
        $repoRoot = if ($parsed.repo) { $parsed.repo } else { '.' }
        $buildScript = Join-Path $PSScriptRoot 'build-source-distribution/Build_Source_Distribution.ps1'
        if (-not (Test-Path -LiteralPath $buildScript)) {
            throw "Missing Build_Source_Distribution.ps1 at $buildScript"
        }

        $invoke = @{ RepositoryPath = $repoRoot }
        if ($parsed.commitIndex) { $invoke.CommitIndexPath = $parsed.commitIndex }
        if ($parsed.verboseGit) { $invoke.VerboseGit = $true }

        if ($Runner.ToLower() -ne 'gcli') {
            throw "Unsupported runner '$Runner'; only gcli is implemented in run-xcli shim."
        }

        Write-Host "[run-xcli] Dispatching to Build_Source_Distribution.ps1 (gcli)"
        & $buildScript @invoke
    }
    default {
        throw "Unsupported x-cli command '$command'"
    }
}

exit $LASTEXITCODE
