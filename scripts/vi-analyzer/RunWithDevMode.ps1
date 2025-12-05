[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$RequestPath,
    [string]$RepositoryPath = "."
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

Write-Warning "Deprecated: prefer 'pwsh scripts/common/invoke-repo-cli.ps1 -Cli OrchestrationCli -- vi-analyzer --repo <path> --bitness <64|32|both> --request <json>'; this script remains as a delegate."
Write-Information "[legacy-ps] vi-analyzer delegate invoked" -InformationAction Continue

function Read-JsonFile {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw ("Request file not found: {0}" -f $Path)
    }
    try {
        return Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        throw ("Failed to parse JSON at {0}: {1}" -f $Path, $_.Exception.Message)
    }
}

$repoRoot = (Resolve-Path -LiteralPath $RepositoryPath -ErrorAction Stop).ProviderPath
$requestFull = if ([System.IO.Path]::IsPathRooted($RequestPath)) { $RequestPath } else { Join-Path $repoRoot $RequestPath }
$request = Read-JsonFile -Path $requestFull

$bitness = if ($request.bitness) { [string]$request.bitness } else { '64' }
$bitnessList = @()
switch -Regex ($bitness) {
    '^both$' { $bitnessList = @('32','64') }
    '^32$'   { $bitnessList = @('32') }
    default  { $bitnessList = @('64') }
}

$bindScript = Join-Path $repoRoot 'scripts/bind-development-mode/BindDevelopmentMode.ps1'
if (-not (Test-Path -LiteralPath $bindScript)) {
    throw "BindDevelopmentMode.ps1 not found at $bindScript"
}

$env:XCLI_ALLOW_PROCESS_START = '1'
$collectedCliLog = $null
$requestToUse = $requestFull

function Write-Stage {
    param([string]$Label)
    $line = "=" * 78
    Write-Host $line
    Write-Host ("[STAGE] {0}" -f $Label)
    Write-Host $line
}

try {
    Write-Stage "VI Analyzer toolkit check"
    try {
        Import-Module (Join-Path $repoRoot 'src/tools/VendorTools.psm1') -Force
        Import-Module (Join-Path $repoRoot 'src/tools/icon-editor/MipScenarioHelpers.psm1') -Force
        $version = if ($request.labVIEWVersion) { [int]$request.labVIEWVersion } else { 2021 }
        $bitnessInt = if ($bitnessList -contains '64') { 64 } else { 32 }
        $toolkitInfo = Test-VIAnalyzerToolkit -Version $version -Bitness $bitnessInt
        if (-not $toolkitInfo.exists) {
            Write-Host ("[analyzer] VI Analyzer toolkit not found for {0} ({1}-bit): {2}. Skipping analyzer run." -f $version, $bitnessInt, $toolkitInfo.reason) -ForegroundColor Yellow
            return
        }
        Write-Host ("[analyzer] VI Analyzer toolkit detected at {0}" -f $toolkitInfo.toolkitPath) -ForegroundColor DarkGray

        # Derive LabVIEW CLI inputs (path/port) for potential use
        $lvExe = $null
        $portNumber = $null
        try {
            $lvExe = Resolve-LabVIEWExePath -Version $version -Bitness $bitnessInt
            if ($lvExe) {
                $iniPath = Get-LabVIEWIniPath -LabVIEWExePath $lvExe
                $portValue = Get-LabVIEWIniValue -LabVIEWExePath $lvExe -LabVIEWIniPath $iniPath -Key 'server.tcp.port'
                if (-not [string]::IsNullOrWhiteSpace($portValue)) {
                    $portNumber = $portValue.Trim()
                }
            }
        } catch {
            Write-Warning ("[analyzer] Failed to resolve LabVIEW exe/port: {0}" -f $_.Exception.Message)
        }

        if ($portNumber) {
            Write-Host ("[analyzer] Detected VI Server port {0} in LabVIEW.ini" -f $portNumber) -ForegroundColor DarkGray
        } else {
            Write-Warning ("[analyzer] VI Server port not found in LabVIEW.ini for LabVIEW {0} ({1}-bit). Ensure VI Server is enabled (server.tcp.port)." -f $version, $bitnessInt)
        }

        # Patch the request with any discovered hints (port, CLI path) without mutating the original file
        $effectiveRequest = $request
        $patched = $false
        try {
            $effectiveRequest = $request | ConvertTo-Json -Depth 8 | ConvertFrom-Json -Depth 8
        } catch {
            Write-Warning ("[analyzer] Failed to clone request for hint injection: {0}" -f $_.Exception.Message)
        }

        $extraArgs = @()
        if ($effectiveRequest.PSObject.Properties['additionalArguments'] -and $effectiveRequest.additionalArguments) {
            $extraArgs = @($effectiveRequest.additionalArguments)
        }
        if ($portNumber -and -not ($extraArgs | Where-Object { $_ -eq '-PortNumber' })) {
            $extraArgs += '-PortNumber'
            $extraArgs += [string]$portNumber
            $patched = $true
        }
        if ($extraArgs) {
            $effectiveRequest.additionalArguments = $extraArgs
        } elseif (-not $effectiveRequest.PSObject.Properties['additionalArguments']) {
            $effectiveRequest | Add-Member -NotePropertyName 'additionalArguments' -NotePropertyValue @()
        } elseif (-not $effectiveRequest.additionalArguments) {
            $effectiveRequest.additionalArguments = @()
        }

        if ($lvExe -and -not ($effectiveRequest.additionalArguments | Where-Object { $_ -eq '-LabVIEWPath' })) {
            $effectiveRequest.additionalArguments += '-LabVIEWPath'
            $effectiveRequest.additionalArguments += $lvExe
            $patched = $true
        }

        if (-not $effectiveRequest.labVIEWCLIPath) {
            try {
                $cliHint = Resolve-LabVIEWCliPath
                if ($cliHint) {
                    $effectiveRequest.labVIEWCLIPath = $cliHint
                    $patched = $true
                }
            } catch {
                Write-Warning ("[analyzer] Failed to resolve LabVIEWCLI path hint: {0}" -f $_.Exception.Message)
            }
        }

        if ($patched) {
            $tempRequest = Join-Path ([System.IO.Path]::GetTempPath()) ("vi-analyzer-request-{0}.json" -f ([System.Guid]::NewGuid().ToString('N')))
            $effectiveRequest | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $tempRequest -Encoding utf8
            $requestToUse = $tempRequest
            Write-Host ("[analyzer] Using request with port/path hints: {0}" -f $requestToUse) -ForegroundColor DarkGray
        }
    }
    catch {
        Write-Warning ("[analyzer] Toolkit check failed: {0}. Proceeding to bind/run anyway." -f $_.Exception.Message)
    }

    Write-Stage ("Dev mode bind ({0})" -f ($bitnessList -join "/"))
    foreach ($b in $bitnessList) {
        Write-Host ("[devmode] Binding {0}-bit to this repo..." -f $b)
        & $bindScript -RepositoryPath $repoRoot -Mode bind -Bitness $b -Force
    }

    Write-Stage "VI Analyzer"
    Write-Host "[analyzer] Running vi-analyzer-run via x-cli..."
$resolver = Join-Path $repoRoot 'scripts/common/resolve-repo-cli.ps1'
if (-not (Test-Path -LiteralPath $resolver -PathType Leaf)) {
    throw "CLI resolver not found at $resolver"
}
$prov = & $resolver -CliName 'XCli' -RepoPath $repoRoot -SourceRepoPath $repoRoot -PrintProvenance:$false
Write-Host ("[analyzer] x-cli tier={0} cacheKey={1}" -f $prov.Tier, $prov.CacheKey) -ForegroundColor DarkGray
$cmd = $prov.Command + @('vi-analyzer-run', '--request', $requestToUse)
$analyzerOutput = & $cmd[0] @($cmd[1..($cmd.Count-1)]) 2>&1
    $collectedCliLog = ($analyzerOutput | Select-String -Pattern 'LabVIEWCLI started logging in file:\s*(.+)' | Select-Object -Last 1 | ForEach-Object { $_.Matches[0].Groups[1].Value.Trim() }) -as [string]
    $analyzerOutput | ForEach-Object { Write-Host $_ }
}
finally {
    Write-Stage ("Dev mode unbind ({0})" -f ($bitnessList -join "/"))
    foreach ($b in $bitnessList) {
        try {
            Write-Host ("[devmode] Unbinding {0}-bit from this repo..." -f $b)
            & $bindScript -RepositoryPath $repoRoot -Mode unbind -Bitness $b -Force
        }
        catch {
            Write-Warning ("[devmode] Unbind failed for {0}-bit: {1}" -f $b, $_.Exception.Message)
        }
    }
    if ($collectedCliLog -and (Test-Path -LiteralPath $collectedCliLog)) {
        try {
            $stashRoot = Join-Path $repoRoot 'builds\log-stash'
            if (Test-Path -LiteralPath $stashRoot) {
                $latestManifest = Get-ChildItem -LiteralPath $stashRoot -Recurse -Filter manifest.json | Sort-Object LastWriteTime -Descending | Select-Object -First 1
                if ($latestManifest) {
                    $bundleDir = Split-Path -Parent $latestManifest.FullName
                    $logsDir = Join-Path $bundleDir 'logs'
                    if (-not (Test-Path -LiteralPath $logsDir)) { New-Item -ItemType Directory -Path $logsDir -Force | Out-Null }
                    $dest = Join-Path $logsDir (Split-Path -Leaf $collectedCliLog)
                    Copy-Item -LiteralPath $collectedCliLog -Destination $dest -Force
                    Write-Host ("[analyzer] Copied LabVIEWCLI log into bundle: {0}" -f $dest)
                }
            }
        }
        catch {
            Write-Warning ("[analyzer] Failed to copy LabVIEWCLI log from {0}: {1}" -f $collectedCliLog, $_.Exception.Message)
        }
    }
}
