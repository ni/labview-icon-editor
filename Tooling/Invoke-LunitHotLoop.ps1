#Requires -Version 7.0

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$RepoRoot = '.',

    [Parameter(Mandatory = $false)]
    [ValidateSet('32', '64')]
    [string]$Bitness = '64',

    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 100)]
    [int]$MaxAttempts = 3,

    [Parameter(Mandatory = $false)]
    [ValidateRange(0, 600)]
    [int]$WaitSeconds = 5,

    [Parameter(Mandatory = $false)]
    [ValidateRange(10, 1800)]
    [int]$CloseTimeoutSeconds = 120,

    [Parameter(Mandatory = $false)]
    [string]$LabVIEWVersionOverride,

    [Parameter(Mandatory = $false)]
    [ValidateRange(2000, 2999)]
    [int]$LabVIEWYearOverride,

    [Parameter(Mandatory = $false)]
    [bool]$SkipValidateOnGcliFail = $true,

    [Parameter(Mandatory = $false)]
    [bool]$SkipValidate = $true,

    [Parameter(Mandatory = $false)]
    [string]$ProjectPathOverride
)

$ErrorActionPreference = 'Stop'

function Get-LabVIEWYearFromNumericVersion {
    param(
        [Parameter(Mandatory = $true)]
        [string]$NumericVersion
    )

    $majorToken = ($NumericVersion.Trim() -split '\.')[0]
    $major = 0
    if (-not [int]::TryParse($majorToken, [ref]$major)) {
        throw ("Unable to parse LabVIEW major version from '{0}'." -f $NumericVersion)
    }

    if ($major -ge 1000) {
        return $major
    }

    return (2000 + $major)
}

function Save-RecentLabVIEWTempLog {
    param(
        [Parameter(Mandatory = $true)]
        [datetime]$SinceUtc,

        [Parameter(Mandatory = $true)]
        [string]$DestinationDir
    )

    $tempRoot = [System.IO.Path]::GetTempPath()
    if ([string]::IsNullOrWhiteSpace($tempRoot) -or -not (Test-Path -Path $tempRoot -PathType Container)) {
        return @()
    }

    $candidates = @(Get-ChildItem -Path $tempRoot -Filter 'lvtemporary_*.log' -File -ErrorAction SilentlyContinue |
        Where-Object { $_.LastWriteTimeUtc -ge $SinceUtc.AddMinutes(-1) } |
        Sort-Object LastWriteTimeUtc -Descending |
        Select-Object -First 20)

    if ($candidates.Count -eq 0) {
        return @()
    }

    New-Item -Path $DestinationDir -ItemType Directory -Force | Out-Null
    $saved = New-Object System.Collections.Generic.List[string]
    $index = 0
    foreach ($candidate in $candidates) {
        $destinationPath = Join-Path $DestinationDir ("{0:D2}-{1}" -f $index, $candidate.Name)
        Copy-Item -Path $candidate.FullName -Destination $destinationPath -Force
        $saved.Add($destinationPath) | Out-Null
        $index++
    }

    return $saved.ToArray()
}

function Stop-ResidualLabVIEWProcess {
    param(
        [Parameter(Mandatory = $true)]
        [string]$LogPath
    )

    $running = @(Get-Process -Name 'LabVIEW' -ErrorAction SilentlyContinue)
    if ($running.Count -eq 0) {
        "[post-close-residual] none-running" | Tee-Object -FilePath $LogPath -Append | Out-Host
        return
    }

    foreach ($proc in $running) {
        $path = $null
        try { $path = $proc.Path } catch { $path = '<path-unavailable>' }
        ("[post-close-residual] stopping pid={0} path={1}" -f $proc.Id, $path) | Tee-Object -FilePath $LogPath -Append | Out-Host
        try {
            Stop-Process -Id $proc.Id -Force -ErrorAction Stop
        } catch {
            ("[post-close-residual] stop-failed pid={0} error={1}" -f $proc.Id, $_.Exception.Message) | Tee-Object -FilePath $LogPath -Append | Out-Host
        }
    }
}

function Resolve-RunnerCliInvocation {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepoRoot,

        [Parameter(Mandatory = $true)]
        [string]$RunnerCliProjectPath
    )

    $dllPath = Join-Path $RepoRoot 'Tooling/runner-cli/RunnerCli/bin/Release/net8.0/win-x64/runner-cli.dll'
    if (Test-Path -Path $dllPath -PathType Leaf) {
        return [pscustomobject]@{
            FilePath = 'dotnet'
            PrefixArgs = @($dllPath)
            Mode = 'prebuilt-dll'
        }
    }

    $exePath = Join-Path $RepoRoot 'Tooling/runner-cli/RunnerCli/bin/Release/net8.0/win-x64/runner-cli.exe'
    if (Test-Path -Path $exePath -PathType Leaf) {
        return [pscustomobject]@{
            FilePath = $exePath
            PrefixArgs = @()
            Mode = 'prebuilt-exe'
        }
    }

    return [pscustomobject]@{
        FilePath = 'dotnet'
        PrefixArgs = @('run', '--project', $RunnerCliProjectPath, '-c', 'Release', '--')
        Mode = 'dotnet-run-fallback'
    }
}

$repoPath = (Resolve-Path -Path $RepoRoot).Path
$lvversionPath = Join-Path $repoPath '.lvversion'
if (-not (Test-Path -Path $lvversionPath -PathType Leaf)) {
    throw ".lvversion not found at $lvversionPath"
}

$lvVersionFromFile = (Get-Content -Path $lvversionPath -Raw).Trim()
$lvVersionRaw = if ([string]::IsNullOrWhiteSpace($LabVIEWVersionOverride)) { $lvVersionFromFile } else { $LabVIEWVersionOverride.Trim() }
$labviewYear = if ($PSBoundParameters.ContainsKey('LabVIEWYearOverride')) { $LabVIEWYearOverride } else { Get-LabVIEWYearFromNumericVersion -NumericVersion $lvVersionRaw }
$closeViaScriptAllowed = [string]::Equals($lvVersionRaw, $lvVersionFromFile, [System.StringComparison]::OrdinalIgnoreCase)

$projectPath = if ([string]::IsNullOrWhiteSpace($ProjectPathOverride)) {
    Join-Path $repoPath 'lv_icon_editor.lvproj'
} elseif ([System.IO.Path]::IsPathRooted($ProjectPathOverride)) {
    $ProjectPathOverride
} else {
    Join-Path $repoPath $ProjectPathOverride
}
if (-not (Test-Path -Path $projectPath)) {
    throw "Project path not found at $projectPath"
}

$reportPath = Join-Path $repoPath (".github/actions/run-unit-tests/UnitTestReport-Windows-{0}.xml" -f $Bitness)
$legacyReportPath = Join-Path $repoPath '.github/actions/run-unit-tests/UnitTestReport.xml'
$closeScriptPath = Join-Path $repoPath '.github/actions/close-labview/Close_LabVIEW.ps1'
$runnerCliProject = Join-Path $repoPath 'Tooling/runner-cli/RunnerCli/RunnerCli.csproj'
$runnerCliInvocation = Resolve-RunnerCliInvocation -RepoRoot $repoPath -RunnerCliProjectPath $runnerCliProject
$logRoot = Join-Path $repoPath 'TestResults/agent-logs/lunit-hotloop'
New-Item -Path $logRoot -ItemType Directory -Force | Out-Null

# Keep local parse-mode validation deterministic when running from a non-worktree repo path.
if ([string]::IsNullOrWhiteSpace($env:LVIE_WORKTREE_ROOT)) {
    $env:LVIE_WORKTREE_ROOT = $repoPath
    Write-Host ("LVIE_WORKTREE_ROOT not set; using repo root for local hot loop: {0}" -f $env:LVIE_WORKTREE_ROOT)
}

$env:LVIE_LUNIT_VERBOSE_GCLI = '1'

$success = $false
$lastExit = 1
for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $attemptTag = ('attempt-{0:D2}-{1}' -f $attempt, $stamp)
    $logPath = Join-Path $logRoot ("{0}.log" -f $attemptTag)

    Write-Host ("=== HOT LOOP {0} (LV {1} => {2}, {3}-bit) ===" -f $attemptTag, $lvVersionRaw, $labviewYear, $Bitness)
    ("[runner-cli-mode] {0}" -f $runnerCliInvocation.Mode) | Tee-Object -FilePath $logPath -Append | Out-Host
    ("[runner-cli-path] {0}" -f $runnerCliInvocation.FilePath) | Tee-Object -FilePath $logPath -Append | Out-Host

    if (Test-Path -Path $reportPath) {
        Remove-Item -Path $reportPath -Force -ErrorAction SilentlyContinue
    }
    if (Test-Path -Path $legacyReportPath) {
        Remove-Item -Path $legacyReportPath -Force -ErrorAction SilentlyContinue
    }

    $runStartUtc = (Get-Date).ToUniversalTime()
    $runnerCliArgs = @()
    $runnerCliArgs += $runnerCliInvocation.PrefixArgs
    $runnerCliArgs += @(
        'lunit', 'run',
        '--repo-root', $repoPath,
        '--year', $labviewYear,
        '--labview-version', $lvVersionRaw,
        '--bitness', $Bitness,
        '--project-path', $projectPath,
        '--report-path', $reportPath,
        '--verbose-gcli'
    )
    if ($SkipValidateOnGcliFail) {
        $runnerCliArgs += '--skip-validate-on-gcli-fail'
    }
    if ($SkipValidate) {
        $runnerCliArgs += '--skip-validate'
    }
    $runOutput = & $runnerCliInvocation.FilePath @runnerCliArgs 2>&1

    $runExit = if ($null -eq $LASTEXITCODE) { 0 } else { [int]$LASTEXITCODE }
    $lastExit = $runExit
    "[runner-cli-exit] $runExit" | Tee-Object -FilePath $logPath -Append | Out-Host
    $runOutput | ForEach-Object { $_.ToString() } | Tee-Object -FilePath $logPath -Append | Out-Host

    $reportUsed = $null
    if (Test-Path -Path $reportPath -PathType Leaf) {
        $reportUsed = $reportPath
    } elseif (Test-Path -Path $legacyReportPath -PathType Leaf) {
        $reportUsed = $legacyReportPath
    }

    $testcaseCount = 0
    if ($reportUsed) {
        try {
            [xml]$xmlDoc = Get-Content -Path $reportUsed -Raw -ErrorAction Stop
            $nodes = $xmlDoc.SelectNodes('//testcase')
            if ($nodes) {
                $testcaseCount = $nodes.Count
            }
        } catch {
            ("[report-parse-error] {0}" -f $_.Exception.Message) | Tee-Object -FilePath $logPath -Append | Out-Host
        }
    }

    "[report-used] $reportUsed" | Tee-Object -FilePath $logPath -Append | Out-Host
    "[testcase-count] $testcaseCount" | Tee-Object -FilePath $logPath -Append | Out-Host

    $attemptTempLogDir = Join-Path $logRoot ("{0}-labview-temp-logs" -f $attemptTag)
    if ($runExit -ne 0 -or $testcaseCount -le 0) {
        $tempLogs = Save-RecentLabVIEWTempLog -SinceUtc $runStartUtc -DestinationDir $attemptTempLogDir
        if ($tempLogs.Count -gt 0) {
            ("[temp-logs] saved={0} dir={1}" -f $tempLogs.Count, $attemptTempLogDir) | Tee-Object -FilePath $logPath -Append | Out-Host
            foreach ($tempLog in $tempLogs) {
                ("[temp-log] {0}" -f $tempLog) | Tee-Object -FilePath $logPath -Append | Out-Host
            }
        } else {
            "[temp-logs] none-found" | Tee-Object -FilePath $logPath -Append | Out-Host
        }
    }

    if (-not $closeViaScriptAllowed) {
        "[post-close-exit] skipped-contract-mismatch" | Tee-Object -FilePath $logPath -Append | Out-Host
        ("[post-close-note] skipped Close_LabVIEW.ps1 because override version '{0}' differs from .lvversion '{1}'." -f $lvVersionRaw, $lvVersionFromFile) | Tee-Object -FilePath $logPath -Append | Out-Host
    } elseif (Test-Path -Path $closeScriptPath -PathType Leaf) {
        $closeOutput = & pwsh -NoProfile -File $closeScriptPath -LabVIEWVersion $labviewYear -SupportedBitness $Bitness -TimeoutSeconds $CloseTimeoutSeconds 2>&1
        $closeExit = if ($null -eq $LASTEXITCODE) { 0 } else { [int]$LASTEXITCODE }
        "[post-close-exit] $closeExit" | Tee-Object -FilePath $logPath -Append | Out-Host
        $closeOutput | ForEach-Object { $_.ToString() } | Tee-Object -FilePath $logPath -Append | Out-Host
    } else {
        "[post-close-exit] script-missing" | Tee-Object -FilePath $logPath -Append | Out-Host
    }
    Stop-ResidualLabVIEWProcess -LogPath $logPath

    if ($runExit -eq 0 -and $testcaseCount -gt 0) {
        Write-Host ("HOT LOOP SUCCESS on attempt {0}" -f $attempt)
        $success = $true
        break
    }

    if ($attempt -lt $MaxAttempts -and $WaitSeconds -gt 0) {
        Start-Sleep -Seconds $WaitSeconds
    }
}

Write-Host ("LOG_ROOT={0}" -f $logRoot)
if (-not $success) {
    Write-Warning ("HOT LOOP completed without success after {0} attempt(s)." -f $MaxAttempts)
}

exit $lastExit
