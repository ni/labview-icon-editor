[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$RepositoryPath,

    [ValidateSet('bind','unbind','status')]
    [string]$Mode = 'bind',

    [ValidateSet('both','32','64')]
    [string]$Bitness = 'both',

    [switch]$Force,
    [switch]$DryRun,
    [string]$JsonOutputPath
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Normalize-PathLower {
    param([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path)) { return '' }
    return ([System.IO.Path]::GetFullPath($Path)).TrimEnd('\\','/').ToLowerInvariant()
}

function Get-ExpectedTokenPath {
    param([string]$Repo)
    $project = Get-ChildItem -Path $Repo -Filter *.lvproj -File -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($project) {
        return Split-Path -Parent $project.FullName
    }
    return $Repo
}

function Get-LibraryPathState {
    param(
        [string]$LvVersion,
        [string]$Arch
    )

    $result = [ordered]@{
        IniPath = $null
        Paths   = @()
    }

    $iniPath = Resolve-LVIniPath -LvVersion $LvVersion -Arch $Arch
    $result.IniPath = $iniPath

    $lines = Get-Content -LiteralPath $iniPath -ErrorAction Stop
    if ($lines -isnot [System.Array]) { $lines = @($lines) }

    $pattern = 'LocalHost\.LibraryPaths\d*\s*=\s*(?<val>.*)'
    foreach ($line in $lines) {
        $m = [regex]::Match($line, $pattern, 'IgnoreCase')
        if (-not $m.Success) { continue }
        $val = $m.Groups['val'].Value.Trim()
        if (-not [string]::IsNullOrWhiteSpace($val)) {
            $full = ([System.IO.Path]::GetFullPath($val))
            $result.Paths += $full
        }
    }

    return $result
}

$RepositoryPath = (Resolve-Path -LiteralPath $RepositoryPath).Path
$expectedToken = Get-ExpectedTokenPath -Repo $RepositoryPath
$expectedNorm = Normalize-PathLower $expectedToken

$actionRoot = Split-Path -Parent $PSScriptRoot
$setDevScript    = Join-Path -Path $actionRoot -ChildPath 'set-development-mode/Set_Development_Mode.ps1'
$revertDevScript = Join-Path -Path $actionRoot -ChildPath 'revert-development-mode/RevertDevelopmentMode.ps1'
$helperScript    = Join-Path -Path $actionRoot -ChildPath 'add-token-to-labview/LocalhostLibraryPaths.ps1'

if (-not (Test-Path -LiteralPath $helperScript)) {
    throw "Missing helper script: $helperScript"
}
. $helperScript

$versionScriptCandidates = @(
    (Join-Path $RepositoryPath 'scripts/get-package-lv-version.ps1'),
    (Join-Path $RepositoryPath '.github/scripts/get-package-lv-version.ps1'),
    (Join-Path $actionRoot '..' 'scripts/get-package-lv-version.ps1')
) | Where-Object { Test-Path $_ }

if (-not $versionScriptCandidates) {
    throw "Unable to locate get-package-lv-version.ps1"
}
$versionScript = $versionScriptCandidates | Select-Object -First 1

$precheckError = $null
try {
    if (-not (Test-Path -LiteralPath $RepositoryPath)) {
        throw "RepositoryPath does not exist: $RepositoryPath"
    }

    $iniTokenVi = Join-Path -Path $RepositoryPath -ChildPath 'Tooling/deployment/Create_LV_INI_Token.vi'
    if (($Mode -ne 'status') -and -not (Test-Path -LiteralPath $iniTokenVi)) {
        throw "Missing Create_LV_INI_Token.vi at $iniTokenVi"
    }

    foreach ($path in @($setDevScript, $revertDevScript)) {
        if (($Mode -ne 'status') -and -not (Test-Path -LiteralPath $path)) {
            throw "Missing required script: $path"
        }
    }

    if ($Mode -ne 'status') {
        $gcli = Get-Command g-cli -ErrorAction SilentlyContinue
        if (-not $gcli) {
            throw "g-cli is not available on PATH; install g-cli before running bind/unbind."
        }
    }
}
catch {
    $precheckError = $_
}

$lvVersion = $null
try {
    $lvVersion = pwsh -NoProfile -File $versionScript -RepositoryPath $RepositoryPath
}
catch {
    if (-not $precheckError) { $precheckError = $_ }
}

$bitnessList = if ($Bitness -eq 'both') { @('32','64') } else { @($Bitness) }
$results = New-Object System.Collections.Generic.List[object]
$hadFailure = $false

function New-ResultObject {
    param(
        [string]$Arch
    )
    $obj = [ordered]@{
        bitness        = $Arch
        available      = $true
        expected_path  = $expectedToken
        current_path   = ''
        post_path      = ''
        action         = 'status'
        status         = 'skip'
        message        = ''
    }
    return New-Object psobject -Property $obj
}

if ($precheckError) {
    foreach ($arch in $bitnessList) {
        $res = New-ResultObject -Arch $arch
        $res.status = 'fail'
        $res.action = $Mode
        $res.message = $precheckError.Exception.Message
        $res.available = $false
        $res.post_path = ''
        $results.Add($res)
    }
}
else {
    foreach ($arch in $bitnessList) {
        $res = New-ResultObject -Arch $arch
        try {
            $state = Get-LibraryPathState -LvVersion $lvVersion -Arch $arch
            $res.current_path = if ($state.Paths) { $state.Paths[0] } else { '' }
        }
        catch {
            $res.available = $false
            $res.status = 'skip'
            $res.action = 'skip'
            $res.message = "LabVIEW.ini not found for $arch-bit or cannot be read: $($_.Exception.Message)"
            Write-Warning $res.message
            $results.Add($res)
            continue
        }

        $res.action = $Mode

        $currentNorm = Normalize-PathLower $res.current_path
        $expectedMatch = ($state.Paths | ForEach-Object { Normalize-PathLower $_ }) -contains $expectedNorm
        $hasAnyPath = $state.Paths.Count -gt 0

        if ($Mode -eq 'status') {
            $res.status = 'success'
            $res.post_path = $res.current_path
            $res.message = 'Status only'
            $results.Add($res)
            continue
        }

        $conflictsOtherRepo = (-not [string]::IsNullOrWhiteSpace($currentNorm)) -and ($currentNorm -ne $expectedNorm) -and -not $Force
        if ($conflictsOtherRepo) {
            $res.status = 'fail'
            $res.message = "LocalHost.LibraryPaths points to another path ($($res.current_path)); use -Force to overwrite."
            $res.post_path = $res.current_path
            $results.Add($res)
            $hadFailure = $true
            continue
        }

        if ($Mode -eq 'bind') {
            if ($expectedMatch) {
                $res.status = 'success'
                $res.message = 'Already bound'
                $res.post_path = $res.current_path
                $results.Add($res)
                continue
            }

            if ($DryRun) {
                $res.status = 'dry-run'
                $res.message = 'Dry run: would bind development mode'
                $res.post_path = $res.current_path
                $results.Add($res)
                continue
            }

            $bindAttempted = $false
            try {
                $bindAttempted = $true
                & $setDevScript -RepositoryPath $RepositoryPath -SupportedBitness $arch | Out-Null
            }
            catch {
                $res.status = 'fail'
                $res.message = "Bind failed: $($_.Exception.Message)"
                if ($bindAttempted) {
                    try {
                        & $revertDevScript -RepositoryPath $RepositoryPath -SupportedBitness $arch | Out-Null
                        $res.message += '; attempted revert after failure'
                    }
                    catch {
                        $res.message += "; revert failed: $($_.Exception.Message)"
                    }
                }
                $hadFailure = $true
                try {
                    $statePost = Get-LibraryPathState -LvVersion $lvVersion -Arch $arch
                    $res.post_path = if ($statePost.Paths) { $statePost.Paths[0] } else { '' }
                }
                catch {}
                $results.Add($res)
                continue
            }

            $statePost = Get-LibraryPathState -LvVersion $lvVersion -Arch $arch
            $res.post_path = if ($statePost.Paths) { $statePost.Paths[0] } else { '' }
            $postMatch = ($statePost.Paths | ForEach-Object { Normalize-PathLower $_ }) -contains $expectedNorm
            if ($postMatch) {
                $res.status = 'success'
                $res.message = 'Bound development mode'
            }
            else {
                $res.status = 'fail'
                $res.message = 'Bind completed but expected token not found after verification.'
                $hadFailure = $true
            }
            $results.Add($res)
            continue
        }

        if ($Mode -eq 'unbind') {
            if (-not $hasAnyPath -and -not $Force) {
                $res.status = 'success'
                $res.message = 'No dev-mode token present; nothing to unbind.'
                $res.post_path = $res.current_path
                $results.Add($res)
                continue
            }

            if (-not $expectedMatch -and $hasAnyPath -and -not $Force) {
                $res.status = 'fail'
                $res.message = 'No matching dev-mode token to remove; use -Force to clear mismatched entry if desired.'
                $res.post_path = $res.current_path
                $results.Add($res)
                $hadFailure = $true
                continue
            }

            if ($DryRun) {
                $res.status = 'dry-run'
                $res.message = 'Dry run: would unbind development mode'
                $res.post_path = $res.current_path
                $results.Add($res)
                continue
            }

            try {
                & $revertDevScript -RepositoryPath $RepositoryPath -SupportedBitness $arch | Out-Null
            }
            catch {
                $res.status = 'fail'
                $res.message = "Unbind failed: $($_.Exception.Message)"
                $hadFailure = $true
                try {
                    $statePost = Get-LibraryPathState -LvVersion $lvVersion -Arch $arch
                    $res.post_path = if ($statePost.Paths) { $statePost.Paths[0] } else { '' }
                }
                catch {}
                $results.Add($res)
                continue
            }

            $statePost = Get-LibraryPathState -LvVersion $lvVersion -Arch $arch
            $res.post_path = if ($statePost.Paths) { $statePost.Paths[0] } else { '' }
            $postMatch = ($statePost.Paths | ForEach-Object { Normalize-PathLower $_ }) -contains $expectedNorm
            if (-not $postMatch) {
                $res.status = 'success'
                $res.message = 'Unbound development mode'
            }
            else {
                $res.status = 'fail'
                $res.message = 'Expected dev-mode token still present after unbind.'
                $hadFailure = $true
            }
            $results.Add($res)
            continue
        }
    }
}

if (-not $JsonOutputPath) {
    $JsonOutputPath = Join-Path -Path $RepositoryPath -ChildPath 'reports/dev-mode-bind.json'
}

$JsonOutputPath = [System.IO.Path]::GetFullPath($JsonOutputPath)
$parent = Split-Path -Parent $JsonOutputPath
if (-not (Test-Path -LiteralPath $parent)) {
    New-Item -ItemType Directory -Path $parent -Force | Out-Null
}

$results | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $JsonOutputPath -Encoding utf8

Write-Host "Development mode bind/unbind summary (mode=$Mode, repo=$RepositoryPath)"
foreach ($r in $results) {
    $msg = "bitness=$($r.bitness); action=$($r.action); status=$($r.status); current=$($r.current_path); post=$($r.post_path); msg=$($r.message)"
    Write-Host $msg
}
Write-Host "JSON summary: $JsonOutputPath"

$exitFail = $results | Where-Object { $_.status -in @('fail','blocked') }
if ($exitFail.Count -gt 0) {
    exit 1
}

exit 0
