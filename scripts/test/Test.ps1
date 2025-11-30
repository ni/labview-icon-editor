# Runs missing-in-project and unit tests without building artifacts.
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$RepositoryPath,

    [ValidateSet('both','64','32')]
    [string]$SupportedBitness = 'both',

    [switch]$ViAnalyzerOnly,
    [string]$ViAnalyzerRequestPath = 'configs/vi-analyzer-request.sample.json',

    [switch]$ForcePlainOutput
)

$ErrorActionPreference = 'Stop'
$isCi = ($env:GITHUB_ACTIONS -eq 'true' -or $env:CI -eq 'true')
$isVsTask = ($env:VSCODE_PID -or $env:TERM_PROGRAM -eq 'vscode')
$forcePlain = $ForcePlainOutput -and -not $isVsTask
$isPlain = $isCi -or $forcePlain
if ($isPlain) {
    try { $PSStyle.OutputRendering = 'PlainText' } catch { }
    $ProgressPreference = 'SilentlyContinue'
    $env:NO_COLOR = '1'
    $env:CLICOLOR = '0'
}
$hasStyle = (-not $isPlain) -and ($PSStyle -ne $null)

function Test-PathExistence {
    param([string]$Path,[string]$Description)
    if (-not (Test-Path -LiteralPath $Path)) {
        throw ("{0} not found: {1}" -f $Description, $Path)
    }
}

function Invoke-ScriptSafe {
    param(
        [Parameter(Mandatory)][string]$ScriptPath,
        [hashtable]$ArgumentMap
    )

    $render = if ($ArgumentMap) {
        ($ArgumentMap.GetEnumerator() | ForEach-Object { "-$($_.Key) $($_.Value)" }) -join ' '
    } else { '' }
    Write-Host ("[cmd] {0} {1}" -f $ScriptPath, $render)
    try {
        & $ScriptPath @ArgumentMap
    }
    catch {
        $code = if ($LASTEXITCODE -ne $null -and $LASTEXITCODE -ne 0) { $LASTEXITCODE } else { 1 }
        $global:LASTEXITCODE = $code
        throw ("Error occurred while executing ""{0}"": {1}" -f $ScriptPath, $_.Exception.Message)
    }
    if ($LASTEXITCODE -ne 0) {
        throw ("{0} exited with code {1}" -f $ScriptPath, $LASTEXITCODE)
    }
}

$script:BuildStart = Get-Date
$transcriptStarted = $false
$logFile = $null
$results = @()
$overallStatus = 'success'
$currentArch = $null
$commitKey = $null
$script:lvVersion = $null
function Resolve-CommitKey {
    param([string]$RepoPath)
    $key = 'manual'
    try {
        Push-Location -LiteralPath $RepoPath
        $key = (git rev-parse --short HEAD 2>$null).Trim()
    }
    catch {
        $global:LASTEXITCODE = 0
    }
    finally {
        Pop-Location -ErrorAction SilentlyContinue
    }
    if ([string]::IsNullOrWhiteSpace($key)) { $key = 'manual' }
    return $key
}

function Write-Step {
    param(
        [string]$Step,
        [string]$Message,
        [string]$Color,
        [string]$Arch,
        [string]$LabVIEWVersion
    )
    $archPretty = $null
    if ($Arch) {
        switch -Regex ($Arch) {
            '^x?64$' { $archPretty = '64-bit'; break }
            '^x?32$' { $archPretty = '32-bit'; break }
            default  { $archPretty = $Arch }
        }
    }

    $lvPretty = if ($LabVIEWVersion) { $LabVIEWVersion } elseif ($script:lvVersion) { $script:lvVersion } else { $null }

    $parts = @("STEP $Step")
    if (-not [string]::IsNullOrWhiteSpace($Message)) { $parts += $Message }
    if ($archPretty) { $parts += $archPretty }
    if ($lvPretty) { $parts += ("LabVIEW {0}" -f $lvPretty) }
    $text = $parts -join " | "
    if ($hasStyle -and $Color) {
        Write-Host $text -ForegroundColor $Color
    }
    else {
        Write-Host $text
    }
}

function Write-Stage {
    param([string]$Label)
    $line = "=" * 78
    $now = Get-Date
    $elapsed = if ($script:BuildStart) { ($now - $script:BuildStart).TotalSeconds } else { 0 }
    if ($hasStyle) {
        Write-Host $line -ForegroundColor Yellow
        Write-Host ("[STAGE] {0} (t +{1:n1}s)" -f $Label, $elapsed) -ForegroundColor Yellow
        Write-Host $line -ForegroundColor Yellow
    }
    else {
        Write-Host $line
        Write-Host ("[STAGE] {0} (t +{1:n1}s)" -f $Label, $elapsed)
        Write-Host $line
    }
}

function Write-Summary {
    param(
        [Parameter(Mandatory)][array]$Results
    )
    if (-not $Results -or $Results.Count -eq 0) { return }
    Write-Host ""
    Write-Stage "Summary"
    foreach ($r in $Results) {
        $label = if ($r.arch -eq '64') { 'x64' } elseif ($r.arch -eq '32') { 'x86' } else { $r.arch }
        $msg = if ($r.message) { $r.message } else { '' }
        $status = $r.status
        $color = switch ($status.ToLower()) {
            'success' { 'Green' }
            'failed'  { 'Red' }
            default   { $null }
        }
        $line = ("[{0}] {1}" -f $label, $status)
        if ($msg) { $line = $line + (" - {0}" -f $msg) }
        if ($hasStyle -and $color) {
            Write-Host $line -ForegroundColor $color
        }
        else {
            Write-Host $line
        }
    }
}

function New-VIAnalyzerRequestWithVersion {
    param(
        [Parameter(Mandatory)][string]$RequestPath,
        [Parameter(Mandatory)][string]$RepoRoot,
        [Parameter(Mandatory)][string]$LabVIEWVersion
    )

    $fullPath = if ([System.IO.Path]::IsPathRooted($RequestPath)) { $RequestPath } else { Join-Path $RepoRoot $RequestPath }
    if (-not (Test-Path -LiteralPath $fullPath -PathType Leaf)) {
        throw "VI Analyzer request not found: $fullPath"
    }

    try {
        $requestObj = Get-Content -LiteralPath $fullPath -Raw | ConvertFrom-Json -ErrorAction Stop
        if (-not $requestObj) { return $fullPath }

        $requestObj.labVIEWVersion = [int]$LabVIEWVersion

        # Drop an embedded CLI path if it targets a different LabVIEW version; let RunWithDevMode add a fresh hint.
        try {
            if ($requestObj.PSObject.Properties['labVIEWCLIPath']) {
                $cliPath = [string]$requestObj.labVIEWCLIPath
                if ($cliPath -match 'LabVIEW\s*(?<ver>\d{4})' -and $Matches['ver'] -ne [string]$LabVIEWVersion) {
                    $requestObj.PSObject.Properties.Remove('labVIEWCLIPath') | Out-Null
                }
            }
        }
        catch { }

        $tempPath = Join-Path ([System.IO.Path]::GetTempPath()) ("vi-analyzer-request-{0}.json" -f ([System.Guid]::NewGuid().ToString('N')))
        $requestObj | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $tempPath -Encoding utf8
        return $tempPath
    }
    catch {
        Write-Warning ("Failed to patch VI Analyzer request {0}: {1}. Using original." -f $fullPath, $_.Exception.Message)
        return $fullPath
    }
}

function Test-LabVIEWInstalled {
    param([string]$Version,[string]$Bitness)
    $root = if ($Bitness -eq '32') { Join-Path $env:ProgramFilesX86 "National Instruments" } else { Join-Path $env:ProgramFiles "National Instruments" }
    $exe = Join-Path $root ("LabVIEW {0}\\LabVIEW.exe" -f $Version)
    return [IO.File]::Exists($exe)
}

function Ensure-LabVIEWClosed {
    param(
        [string]$Version,
        [string[]]$BitnessList,
        [string]$CloseScript
    )
    foreach ($arch in $BitnessList) {
        try {
            & $CloseScript -Package_LabVIEW_Version $Version -SupportedBitness $arch -KillLabVIEW -KillTimeoutSeconds 5 -TimeoutSeconds 30 | Out-Null
        }
        catch {
            Write-Warning ("Force-closing LabVIEW {0} ({1}-bit) failed: {2}" -f $Version, $arch, $_.Exception.Message)
            try {
                Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -like 'LabVIEW*' -and $_.Path -like "*LabVIEW $Version*" } |
                    Stop-Process -Force -ErrorAction SilentlyContinue
            }
            catch { }
        }
    }
}

try {
    $repoRoot = (Resolve-Path -LiteralPath $RepositoryPath -ErrorAction Stop).ProviderPath
    $actionsRoot = Split-Path -Parent $PSScriptRoot
    $versionScript = Join-Path $repoRoot 'scripts/get-package-lv-version.ps1'
    $lvVersion = '2021'
    $script:lvVersion = $lvVersion
    if (Test-Path -LiteralPath $versionScript) {
        try {
            $lvVersion = & $versionScript -RepositoryPath $repoRoot
            if (-not [string]::IsNullOrWhiteSpace($lvVersion)) {
                $script:lvVersion = $lvVersion
            }
        }
        catch {
            Write-Warning ("Failed to resolve LabVIEW version from VIPB; using default {0}. {1}" -f $lvVersion, $_.Exception.Message)
        }
    }
    if ([string]::IsNullOrWhiteSpace($lvVersion)) {
        $lvVersion = $script:lvVersion
    }
    $missingScript = Join-Path $repoRoot 'scripts/missing-in-project/RunMissingCheckWithGCLI.ps1'
    $unitTestsScript = Join-Path $actionsRoot 'run-unit-tests/RunUnitTests.ps1'
    if ($ViAnalyzerOnly) {
        $viWrapper = Join-Path $repoRoot 'scripts/vi-analyzer/RunWithDevMode.ps1'
        if (-not (Test-Path -LiteralPath $viWrapper)) {
            throw "VI Analyzer wrapper not found at $viWrapper"
        }
        $reqPath = New-VIAnalyzerRequestWithVersion -RequestPath $ViAnalyzerRequestPath -RepoRoot $repoRoot -LabVIEWVersion $lvVersion
        Write-Host "[test] Running VI Analyzer only..."
        & $viWrapper -RequestPath $reqPath -RepositoryPath $repoRoot
        exit $LASTEXITCODE
    }
    $closeLvScript = Join-Path $repoRoot 'scripts/close-labview/Close_LabVIEW.ps1'
    $bindDevModeScript = Join-Path $repoRoot 'scripts/bind-development-mode/BindDevelopmentMode.ps1'
    $setDevModeScript = Join-Path $repoRoot 'scripts/set-development-mode/Set_Development_Mode.ps1'
    $revertDevModeScript = Join-Path $repoRoot 'scripts/revert-development-mode/RevertDevelopmentMode.ps1'
    $readPathsScript = Join-Path $repoRoot 'scripts/read-library-paths.ps1'
    $lvprojPath = Join-Path $repoRoot 'lv_icon_editor.lvproj'
    $commitKey = Resolve-CommitKey -RepoPath $repoRoot

    Test-PathExistence -Path $missingScript -Description "missing-in-project script"
    Test-PathExistence -Path $unitTestsScript -Description "RunUnitTests script"
    Test-PathExistence -Path $closeLvScript -Description "Close_LabVIEW script"
    Test-PathExistence -Path $lvprojPath -Description "LabVIEW project"

    function Ensure-DevModeReady {
        param(
            [Parameter(Mandatory)][ValidateSet('32','64')][string]$Arch
        )

        if (-not (Test-Path -LiteralPath $readPathsScript)) {
            Write-Host "[devmode] read-library-paths.ps1 not found; skipping dev mode preflight."
            return
        }

        $checkPaths = {
            try {
                & $readPathsScript -RepositoryPath $repoRoot -SupportedBitness $Arch -FailOnMissing
                return $LASTEXITCODE -eq 0
            }
            catch {
                $global:LASTEXITCODE = 0
                return $false
            }
        }

        if (& $checkPaths) { return }

        Write-Host ("[devmode] Rebinding development mode to this repo for {0}-bit (clearing old tokens)..." -f $Arch)
        if (Test-Path -LiteralPath $bindDevModeScript) {
            & $bindDevModeScript -RepositoryPath $repoRoot -Mode unbind -Bitness $Arch -Force
            & $bindDevModeScript -RepositoryPath $repoRoot -Mode bind -Bitness $Arch -Force
        }
        elseif (Test-Path -LiteralPath $setDevModeScript) {
            if (Test-Path -LiteralPath $revertDevModeScript) {
                & $revertDevModeScript -RepositoryPath $repoRoot -SupportedBitness $Arch
            }
            & $setDevModeScript -RepositoryPath $repoRoot -SupportedBitness $Arch
        }
        else {
            throw "No dev-mode binder found (expected at $bindDevModeScript); cannot remediate LocalHost.LibraryPaths."
        }

        if (-not (& $checkPaths)) {
            throw ("LocalHost.LibraryPaths still not aligned to this repo after dev-mode remediation for {0}-bit." -f $Arch)
        }
    }

    $requestedArches = if ($SupportedBitness -eq 'both') { @('32','64') } else { @($SupportedBitness) }
    $arches = @()
    foreach ($a in $requestedArches) {
        if (Test-LabVIEWInstalled -Version $lvVersion -Bitness $a) {
            $arches += $a
        }
        else {
            Write-Warning ("LabVIEW {0} ({1}-bit) not installed; skipping this bitness." -f $lvVersion, $a)
        }
    }
    if (-not $arches) {
        throw "No installed LabVIEW bitness found for $lvVersion (requested: $SupportedBitness)."
    }
    Write-Host ("Repository   : {0}" -f $repoRoot)
    Write-Host ("Commit       : {0}" -f $commitKey)
    Write-Host ("LV version   : {0}" -f $lvVersion)
    Write-Host ("Bitness list : {0}" -f ($arches -join ', '))

    # Begin transcript for traceability
    $logDir = Join-Path $repoRoot 'builds\logs'
    if (-not (Test-Path -LiteralPath $logDir)) {
        New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    }
    $logFile = Join-Path $logDir ("test-{0:yyyyMMdd-HHmmss}.log" -f $script:BuildStart)
    try {
        Start-Transcript -Path $logFile -Append -ErrorAction Stop | Out-Null
        $transcriptStarted = $true
        Write-Information ("Transcript logging enabled at {0}" -f $logFile) -InformationAction Continue
    }
    catch {
        Write-Warning ("Failed to start transcript logging: {0}" -f $_.Exception.Message)
        $logFile = $null
    }

    # Run VI Analyzer first (uses LabVIEWCLI; avoid g-cli conflicts)
    $viWrapper = Join-Path $repoRoot 'scripts/vi-analyzer/RunWithDevMode.ps1'
    $viReqPath = $null
    try {
        $viReqPath = New-VIAnalyzerRequestWithVersion -RequestPath $ViAnalyzerRequestPath -RepoRoot $repoRoot -LabVIEWVersion $lvVersion
    }
    catch {
        Write-Warning ("Failed to prepare VI Analyzer request at {0}: {1}" -f $ViAnalyzerRequestPath, $_.Exception.Message)
    }
    if (-not (Test-Path -LiteralPath $viWrapper)) {
        Write-Warning ("VI Analyzer wrapper not found at {0}; skipping analyzer stage." -f $viWrapper)
    }
    elseif (-not $viReqPath) {
        Write-Warning ("VI Analyzer request could not be prepared from {0}; skipping analyzer stage." -f $ViAnalyzerRequestPath)
    }
    elseif (-not (Test-Path -LiteralPath $viReqPath -PathType Leaf)) {
        Write-Warning ("VI Analyzer request not found at {0}; skipping analyzer stage." -f $viReqPath)
    }
    else {
        Write-Stage "VI Analyzer (preflight + run)"
        & $viWrapper -RequestPath $viReqPath -RepositoryPath $repoRoot
        if ($LASTEXITCODE -ne 0) {
            Write-Warning ("VI Analyzer stage failed (exit $LASTEXITCODE); continuing with remaining tests.")
            $results += [pscustomobject]@{
                arch    = 'pre'
                status  = 'failed'
                message = "VI Analyzer failed (exit $LASTEXITCODE)"
            }
        }
    }

    $results = @()
    $overallStatus = 'success'

    foreach ($arch in $arches) {
        $currentArch = $arch
        Write-Stage ("{0}-bit test phase" -f $arch)

        Write-Step -Step "1.0" -Message "Dev mode set" -Color "Cyan" -Arch $arch -LabVIEWVersion $lvVersion
        Ensure-DevModeReady -Arch $arch

        Write-Step -Step "2.0" -Message "Detect missing items on LabVIEW project (start)" -Color "Cyan" -Arch $arch -LabVIEWVersion $lvVersion
        Invoke-ScriptSafe -ScriptPath $missingScript -ArgumentMap @{
            LVVersion   = $lvVersion
            Arch        = $arch
            ProjectFile = $lvprojPath
        }
        Write-Step -Step "2.1" -Message "Detect missing items on LabVIEW project completed" -Color "Green" -Arch $arch -LabVIEWVersion $lvVersion

        Write-Step -Step "3.0" -Message "Unit tests" -Color "Green" -Arch $arch -LabVIEWVersion $lvVersion
        Invoke-ScriptSafe -ScriptPath $unitTestsScript -ArgumentMap @{
            Package_LabVIEW_Version = $lvVersion
            SupportedBitness        = $arch
            AbsoluteProjectPath     = $lvprojPath
        }

        Write-Step -Step "4.0" -Message "Close LabVIEW" -Color "Magenta" -Arch $arch -LabVIEWVersion $lvVersion
        try {
            & $closeLvScript -Package_LabVIEW_Version $lvVersion -SupportedBitness $arch | Out-Null
        }
        catch {
            Write-Warning ("Failed to close LabVIEW {0}-bit: {1}" -f $arch, $_.Exception.Message)
        }

        $results += [pscustomobject]@{
            arch     = $arch
            status   = 'success'
            message  = ''
        }
    }

    # Final safety: ensure no LabVIEW remains running for the arches we touched.
    Write-Step -Step "5.0" -Message "Final LabVIEW cleanup" -LabVIEWVersion $lvVersion
    Ensure-LabVIEWClosed -Version $lvVersion -BitnessList $arches -CloseScript $closeLvScript

    Write-Host "Tests completed."
}
catch {
    $overallStatus = 'failed'
    $failedArch = if ($currentArch) { $currentArch } else { $SupportedBitness }
    $results += [pscustomobject]@{
        arch    = $failedArch
        status  = 'failed'
        message = $_.Exception.Message
    }
    Write-Error $_.Exception.Message
}
finally {
    if ($transcriptStarted) {
        try { Stop-Transcript | Out-Null } catch { Write-Warning ("Failed to stop transcript: {0}" -f $_.Exception.Message) }
    }

    try {
        $commitKey = Resolve-CommitKey -RepoPath $repoRoot
        $stashRoot = Join-Path $repoRoot 'builds\test-stash'
        $stashDir  = Join-Path $stashRoot $commitKey
        if (-not (Test-Path -LiteralPath $stashDir)) {
            New-Item -ItemType Directory -Path $stashDir -Force | Out-Null
        }
        $manifest = [pscustomobject]@{
            type          = 'test'
            commit        = $commitKey
            labviewVersion= $lvVersion
            bitness       = $arches
            status        = $overallStatus
            results       = $results
            timestampUtc  = (Get-Date).ToUniversalTime().ToString("o")
            logPath       = if ($logFile) { [System.IO.Path]::GetRelativePath($repoRoot, $logFile) } else { $null }
        }
        $manifestPath = Join-Path $stashDir 'manifest.json'
        $manifest | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $manifestPath -Encoding utf8
        Write-Information ("[artifact][test-stash] Manifest: {0}" -f $manifestPath) -InformationAction Continue
        if ($logFile -and (Test-Path -LiteralPath $logFile)) {
            Write-Information ("[artifact][test-log] {0}" -f $logFile) -InformationAction Continue
        }

        $logStashScript = Join-Path $repoRoot 'scripts/log-stash/Write-LogStashEntry.ps1'
        if (Test-Path -LiteralPath $logStashScript) {
            try {
                $logs = @()
                if ($logFile -and (Test-Path -LiteralPath $logFile)) { $logs += $logFile }
                $attachments = @()
                if (Test-Path -LiteralPath $manifestPath) { $attachments += $manifestPath }

                $label = if ($env:GITHUB_JOB) { $env:GITHUB_JOB } elseif ($isCi) { 'ci-test' } else { 'local-test' }
                $durationMs = [int][Math]::Round(((Get-Date) - $script:BuildStart).TotalMilliseconds,0)
                & $logStashScript `
                    -RepositoryPath $repoRoot `
                    -Category 'test' `
                    -Label $label `
                    -LogPaths $logs `
                    -AttachmentPaths $attachments `
                    -Status $overallStatus `
                    -LabVIEWVersion $lvVersion `
                    -Bitness $arches `
                    -ProducerScript $PSCommandPath `
                    -ProducerTask 'Test.ps1' `
                    -ProducerArgs @{ SupportedBitness = $SupportedBitness; ForcePlainOutput = $ForcePlainOutput.IsPresent } `
                    -StartedAtUtc $script:BuildStart.ToUniversalTime() `
                    -DurationMs $durationMs
            }
            catch {
                Write-Warning ("Failed to write log-stash bundle: {0}" -f $_.Exception.Message)
            }
        }
    }
    catch {
        Write-Warning ("Failed to write test manifest: {0}" -f $_.Exception.Message)
    }

    try {
        Write-Summary -Results $results
        if ($logFile) {
            Write-Host ("Log file: {0}" -f $logFile)
        }
        Write-Host ("Manifest: builds\test-stash\{0}\manifest.json" -f ($commitKey ?? 'manual'))
    }
    catch {
        Write-Warning ("Failed to emit summary: {0}" -f $_.Exception.Message)
    }

    if ($overallStatus -eq 'failed') {
        exit 1
    }
}
