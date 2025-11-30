[CmdletBinding()]
param(
    [string[]]$CliNames = @('IntegrationEngineCli', 'OrchestrationCli', 'DevModeAgentCli', 'XCli')
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Assert-That {
    param(
        [object]$Condition,
        [string]$Message
    )
    if (-not [bool]$Condition) { throw $Message }
}

$helper = Join-Path $PSScriptRoot '..\common\resolve-repo-cli.ps1'
if (-not (Test-Path -LiteralPath $helper -PathType Leaf)) {
    throw "Helper not found at $helper"
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("probe-helper-" + [guid]::NewGuid())
$provenanceOutput = $null
$rid = [System.Runtime.InteropServices.RuntimeInformation]::RuntimeIdentifier
$createdCachePaths = New-Object System.Collections.Generic.List[string]

# Ensure no leftover CLI processes hold locks
foreach ($name in @('IntegrationEngineCli','OrchestrationCli','DevModeAgentCli','XCli')) {
    try { Stop-Process -Name $name -Force -ErrorAction SilentlyContinue } catch { }
}

function Invoke-With {
    param([string[]]$Cmd)
    & $Cmd[0] @($Cmd[1..($Cmd.Count-1)])
}

New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null

function Get-CachePath {
    param([string]$Cli, [string]$Ver, [string]$Rid)
    if ($IsWindows -and $env:LOCALAPPDATA) {
        return Join-Path $env:LOCALAPPDATA "labview-icon-editor\tooling-cache\$Cli\$Ver\$Rid\publish"
    }
    if ($env:HOME) {
        return Join-Path $env:HOME ".cache/labview-icon-editor/tooling-cache/$Cli/$Ver/$Rid/publish"
    }
    throw "Cannot determine cache root (LOCALAPPDATA or HOME required)."
}

try {
    foreach ($cli in $CliNames) {
        Write-Host ("=== CLI: {0} ===" -f $cli) -ForegroundColor Cyan
        $exeName = if ($IsWindows) { "$cli.exe" } else { $cli }
        $sourceRepoRoot = Join-Path $tempRoot $cli
        if (-not (Test-Path -LiteralPath $sourceRepoRoot)) { New-Item -ItemType Directory -Path $sourceRepoRoot | Out-Null }

        Write-Host "Scenario 1: worktree probe" -ForegroundColor Cyan
        $worktree = & $helper -CliName $cli -RepoPath $repoRoot -SourceRepoPath $repoRoot -PrintProvenance:$false
        Assert-That ($worktree.Tier -eq 'worktree') "Expected worktree tier, got $($worktree.Tier)"
        Assert-That (-not [string]::IsNullOrWhiteSpace($worktree.ProjectPath)) "Expected ProjectPath for worktree tier"

        Write-Host "Scenario 2: source repo fallback" -ForegroundColor Cyan
        $source = & $helper -CliName $cli -RepoPath $sourceRepoRoot -SourceRepoPath $repoRoot -PrintProvenance:$false
        Write-Host ("Source tier={0} project={1}" -f $source.Tier, $source.ProjectPath) -ForegroundColor DarkGray
        Assert-That ($source.Tier -eq 'source') "Expected source tier, got $($source.Tier)"
        Assert-That ($source.ProjectPath -match 'Tooling[\\/]+') "Expected ProjectPath for source tier"

        Write-Host "Scenario 3: cache hit" -ForegroundColor Cyan
        $cacheVersion = "test-$cli-" + ([guid]::NewGuid().ToString('N'))
        $cachePath = Get-CachePath -Cli $cli -Ver $cacheVersion -Rid $rid
        New-Item -ItemType Directory -Path $cachePath -Force | Out-Null
        $createdCachePaths.Add($cachePath)
        $dummyExe = Join-Path $cachePath $exeName
        if (-not (Test-Path -LiteralPath $dummyExe)) {
            Set-Content -LiteralPath $dummyExe -Value 'placeholder' -NoNewline -Encoding ASCII
        }
        $cache = & $helper -CliName $cli -RepoPath $sourceRepoRoot -SourceRepoPath $sourceRepoRoot -VersionOverride $cacheVersion -Rid $rid -PrintProvenance:$false
        Assert-That ($cache.Tier -eq 'cache') "Expected cache tier, got $($cache.Tier)"
        Assert-That (-not [string]::IsNullOrWhiteSpace($cache.BinaryPath) -and ($cache.BinaryPath -match [regex]::Escape($exeName))) "Expected BinaryPath to point at cache exe"

        Write-Host "Scenario 4: publish on miss" -ForegroundColor Cyan
        $publishVersion = "publish-$cli-" + ([guid]::NewGuid().ToString('N'))
        $publishCachePath = Get-CachePath -Cli $cli -Ver $publishVersion -Rid $rid
        if (Test-Path -LiteralPath $publishCachePath) {
            Remove-Item -LiteralPath $publishCachePath -Recurse -Force -ErrorAction SilentlyContinue
        }
        $createdCachePaths.Add($publishCachePath)
        $publish = & $helper -CliName $cli -RepoPath $sourceRepoRoot -SourceRepoPath $repoRoot -VersionOverride $publishVersion -Rid $rid -ForcePublish -PrintProvenance:$false
        Assert-That ($publish.Tier -eq 'publish') "Expected publish tier, got $($publish.Tier)"
        Assert-That (Test-Path -LiteralPath $publishCachePath -PathType Container) "Expected publish cache directory at $publishCachePath"
        $publishedExe = Join-Path $publishCachePath $exeName
        Assert-That (Test-Path -LiteralPath $publishedExe -PathType Leaf) "Expected published exe at $publishedExe"

        Write-Host "Scenario 5: clear-tooling-cache deletes entry" -ForegroundColor Cyan
        $clearVersion = "clear-$cli-" + ([guid]::NewGuid().ToString('N'))
        $clearCachePath = Get-CachePath -Cli $cli -Ver $clearVersion -Rid $rid
        if (Test-Path -LiteralPath $clearCachePath) {
            Remove-Item -LiteralPath $clearCachePath -Recurse -Force -ErrorAction SilentlyContinue
        }
        $createdCachePaths.Add($clearCachePath)
        & $helper -CliName $cli -RepoPath $sourceRepoRoot -SourceRepoPath $repoRoot -VersionOverride $clearVersion -Rid $rid -ForcePublish -PrintProvenance:$false | Out-Null
        Assert-That (Test-Path -LiteralPath $clearCachePath -PathType Container) "Expected seeded cache at $clearCachePath"

        $clearScript = Join-Path $PSScriptRoot '..\clear-tooling-cache.ps1'
        Assert-That (Test-Path -LiteralPath $clearScript -PathType Leaf) "clear-tooling-cache script missing at $clearScript"
        & $clearScript -CliName $cli -Version $clearVersion -Rid $rid | Out-Null
        Assert-That (-not (Test-Path -LiteralPath $clearCachePath)) "Cache path should be removed after clear-tooling-cache"

        Write-Host "Scenario 6: republish after clear" -ForegroundColor Cyan
        $repub = & $helper -CliName $cli -RepoPath $sourceRepoRoot -SourceRepoPath $repoRoot -VersionOverride $clearVersion -Rid $rid -ForcePublish -PrintProvenance:$false
        Assert-That ($repub.Tier -eq 'publish') "Expected publish tier after clear, got $($repub.Tier)"
        Assert-That (Test-Path -LiteralPath $clearCachePath -PathType Container) "Expected cache path recreated after clear"

        Write-Host "Scenario 7: cache key mismatch detection" -ForegroundColor Cyan
        $mismatchVersion = "mismatch-$cli-" + ([guid]::NewGuid().ToString('N'))
        $mismatchCachePath = Get-CachePath -Cli $cli -Ver $mismatchVersion -Rid $rid
        if (Test-Path -LiteralPath $mismatchCachePath) {
            Remove-Item -LiteralPath $mismatchCachePath -Recurse -Force -ErrorAction SilentlyContinue
        }
        $createdCachePaths.Add($mismatchCachePath)
        New-Item -ItemType Directory -Path $mismatchCachePath -Force | Out-Null
        $mismatchExe = Join-Path $mismatchCachePath $exeName
        Set-Content -LiteralPath $mismatchExe -Value 'placeholder' -NoNewline -Encoding ASCII
        $expectedKey = "$cli/expected-bogus/$rid"
        $mismatchThrown = $false
        try {
            & $helper -CliName $cli -RepoPath $sourceRepoRoot -SourceRepoPath $sourceRepoRoot -VersionOverride $mismatchVersion -Rid $rid -ExpectedCacheKey $expectedKey -PrintProvenance:$false | Out-Null
        }
        catch {
            $mismatchThrown = $true
        }
        Assert-That $mismatchThrown "Expected resolver to throw on cache key mismatch"

        Write-Host "Scenario 8: CLI --print-provenance reports tier/cacheKey/rid" -ForegroundColor Cyan
        $worktreeProv = & $helper -CliName $cli -RepoPath $repoRoot -SourceRepoPath $repoRoot -PrintProvenance:$false
        Assert-That ($worktreeProv.Command.Count -ge 1) "Expected command to invoke CLI"
        $cmd = $worktreeProv.Command + @('--print-provenance')
        $provenanceOutput = Invoke-With -Cmd $cmd
        $provText = ($provenanceOutput -join "`n")
        Assert-That ($provText -match 'tier=') "Provenance output should include tier"
        Assert-That ($provText -match 'cacheKey=') "Provenance output should include cacheKey"
        Assert-That ($provText -match "rid=$rid") "Provenance output should include rid"

        Write-Host "Scenario 9: provenance mismatch fails fast" -ForegroundColor Cyan
        $badExpectedKey = "$cli/bogus/$rid"
        $mismatchThrown2 = $false
        try {
            & $helper -CliName $cli -RepoPath $sourceRepoRoot -SourceRepoPath $sourceRepoRoot -VersionOverride $cacheVersion -Rid $rid -ExpectedCacheKey $badExpectedKey -PrintProvenance:$false | Out-Null
        }
        catch {
            $mismatchThrown2 = $true
        }
        Assert-That $mismatchThrown2 "Expected resolver to throw when expected cache key does not match resolved key"
    }

    Write-Host "All probe-helper smoke checks passed." -ForegroundColor Green
}
finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
    foreach ($p in $createdCachePaths) {
        if ($p -and (Test-Path -LiteralPath $p)) {
            Remove-Item -LiteralPath $p -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}
