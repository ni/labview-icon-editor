#Requires -Version 7.0
<#
.SYNOPSIS
    Helper functions for DevMode no-LabVIEW smoke coverage.
#>

function Get-DevModeNoLabVIEWSmokeSuite {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [ValidateSet('minimal', 'balanced', 'full')]
        [string]$Depth = 'balanced'
    )

    $tests = @(
        [pscustomobject]@{
            Path = 'Test/Pester/DevMode.NoLabVIEW.Tests.ps1'
            Kind = 'unit'
        }
    )

    switch ($Depth) {
        'balanced' {
            $tests += [pscustomobject]@{
                Path = 'Test/Pester/MissingInProject.DevMode.NoLabVIEW.Integration.Tests.ps1'
                Kind = 'integration'
            }
            $tests += [pscustomobject]@{
                Path = 'Test/Pester/LUnit.DevMode.NoLabVIEW.Integration.Tests.ps1'
                Kind = 'integration'
            }
            break
        }
        'full' {
            $tests += [pscustomobject]@{
                Path = 'Test/Pester/MissingInProject.DevMode.NoLabVIEW.Integration.Tests.ps1'
                Kind = 'integration'
            }
            $tests += [pscustomobject]@{
                Path = 'Test/Pester/LUnit.DevMode.NoLabVIEW.Integration.Tests.ps1'
                Kind = 'integration'
            }
            $tests += [pscustomobject]@{
                Path = 'Test/Pester/VerifyIEPaths.DevMode.Integration.Tests.ps1'
                Kind = 'integration'
            }
            $tests += [pscustomobject]@{
                Path = 'Test/Pester/BuildLvlibp.DevMode.NoLabVIEW.Integration.Tests.ps1'
                Kind = 'integration'
            }
            break
        }
        default {
            break
        }
    }

    return [pscustomobject]@{
        Depth = $Depth
        Tests = @($tests)
    }
}

function Resolve-BoolFromEnvValue {
    [CmdletBinding()]
    param(
        [string]$Name,
        [bool]$Default = $false
    )

    if (-not (Test-Path "Env:$Name")) {
        return $Default
    }

    $raw = (Get-Item "Env:$Name").Value
    if ([string]::IsNullOrWhiteSpace($raw)) {
        return $Default
    }

    $normalized = $raw.Trim().ToLowerInvariant()
    return ($normalized -notin @('0', 'false', 'no', 'off'))
}

function Get-LabVIEWInstallRootForSmoke {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Version,

        [Parameter(Mandatory = $true)]
        [ValidateSet('32', '64')]
        [string]$Bitness
    )

    $candidates = @()
    $regPaths = @()
    if ($Bitness -eq '32') {
        $candidates += "C:\Program Files (x86)\National Instruments\LabVIEW $Version"
        $regPaths += "HKLM:\SOFTWARE\WOW6432Node\National Instruments\LabVIEW $Version"
    } else {
        $candidates += "C:\Program Files\National Instruments\LabVIEW $Version"
        $regPaths += "HKLM:\SOFTWARE\National Instruments\LabVIEW $Version"
    }

    foreach ($candidate in $candidates) {
        if (Test-Path -Path $candidate) {
            return $candidate
        }
    }

    foreach ($regPath in $regPaths) {
        try {
            $props = Get-ItemProperty -Path $regPath -ErrorAction Stop
            foreach ($name in @('Path', 'InstallDir', 'InstallPath')) {
                $value = $props.$name
                if (-not [string]::IsNullOrWhiteSpace($value) -and (Test-Path -Path $value)) {
                    return $value
                }
            }
        } catch {
            continue
        }
    }

    return $null
}

function Test-SmokeDirectoryWriteAccess {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (-not (Test-Path -Path $Path -PathType Container)) {
        return $false
    }

    $probe = Join-Path $Path ("lvie-smoke-write-probe-{0}.tmp" -f ([guid]::NewGuid().ToString('N')))
    try {
        New-Item -Path $probe -ItemType File -Force | Out-Null
        Remove-Item -Path $probe -Force -ErrorAction SilentlyContinue
        return $true
    } catch {
        return $false
    }
}

function Resolve-DevModeNoLabVIEWSmokeSuiteForBitness {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('minimal', 'balanced', 'full')]
        [string]$Depth,

        [Parameter(Mandatory = $true)]
        [string]$LabVIEWVersion,

        [Parameter(Mandatory = $true)]
        [ValidateSet('32', '64')]
        [string]$Bitness
    )

    $requestedSuite = Get-DevModeNoLabVIEWSmokeSuite -Depth $Depth
    $allowAclDowngrade = Resolve-BoolFromEnvValue -Name 'LVIE_DEVMODE_SMOKE_ALLOW_ACL_DOWNGRADE' -Default (Resolve-BoolFromEnvValue -Name 'LVIE_RUNNER_ACL_WARN_ONLY' -Default $false)

    $installRoot = Get-LabVIEWInstallRootForSmoke -Version $LabVIEWVersion -Bitness $Bitness
    $iconApiDir = $null
    $canWriteIconApi = $true
    if (-not [string]::IsNullOrWhiteSpace($installRoot)) {
        $iconApiDir = Join-Path $installRoot 'vi.lib\LabVIEW Icon API'
        if (Test-Path -Path $iconApiDir -PathType Container) {
            $canWriteIconApi = Test-SmokeDirectoryWriteAccess -Path $iconApiDir
        }
    }

    if ($Depth -eq 'minimal' -or $canWriteIconApi) {
        return [pscustomobject]@{
            RequestedDepth = $Depth
            EffectiveDepth = $requestedSuite.Depth
            Suite          = $requestedSuite
            AccessPath     = $iconApiDir
            AccessWritable = $canWriteIconApi
            AccessReason   = $null
            Downgraded     = $false
        }
    }

    $message = if ($iconApiDir) {
        "No write access to '$iconApiDir'."
    } else {
        "LabVIEW $LabVIEWVersion ($Bitness-bit) install root not found."
    }

    if (-not $allowAclDowngrade) {
        throw ("DevMode.NoLabVIEW smoke cannot run at depth '{0}' for {1}-bit. {2} Set LVIE_DEVMODE_SMOKE_ALLOW_ACL_DOWNGRADE=1 to allow minimal-depth fallback." -f $Depth, $Bitness, $message)
    }

    $minimalSuite = Get-DevModeNoLabVIEWSmokeSuite -Depth 'minimal'
    return [pscustomobject]@{
        RequestedDepth = $Depth
        EffectiveDepth = $minimalSuite.Depth
        Suite          = $minimalSuite
        AccessPath     = $iconApiDir
        AccessWritable = $canWriteIconApi
        AccessReason   = $message
        Downgraded     = $true
    }
}

function Test-DevModeNoLabVIEWSmokeCoverage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [AllowNull()]
        [object]$PesterResult,

        [Parameter(Mandatory = $true)]
        [AllowNull()]
        [object]$Suite
    )

    $repoRoot = (Resolve-Path -Path (Join-Path $PSScriptRoot '..\..')).Path

    $suiteTests = @()
    if ($Suite -and $Suite.PSObject.Properties.Name -contains 'Tests') {
        $suiteTests = @($Suite.Tests)
    } elseif ($Suite -is [System.Collections.IEnumerable]) {
        $suiteTests = @($Suite)
    }

    $integrationTests = @(
        $suiteTests |
            Where-Object {
                $_ -and
                $_.PSObject.Properties.Name -contains 'Kind' -and
                $_.Kind -eq 'integration'
            }
    )

    $pesterTests = @()
    if ($PesterResult -and $PesterResult.PSObject.Properties.Name -contains 'Tests') {
        $pesterTests = @($PesterResult.Tests)
    }

    $messages = New-Object System.Collections.Generic.List[string]
    $details = @()
    $passed = $true

    foreach ($integration in $integrationTests) {
        $expectedPath = [System.IO.Path]::GetFullPath((Join-Path -Path $repoRoot -ChildPath $integration.Path))
        $matchingTests = @(
            $pesterTests |
                Where-Object {
                    $filePath = $null
                    if ($_.PSObject.Properties.Name -contains 'ScriptBlock' -and $_.ScriptBlock) {
                        if ($_.ScriptBlock.PSObject.Properties.Name -contains 'File') {
                            $filePath = $_.ScriptBlock.File
                        }
                    }

                    if ([string]::IsNullOrWhiteSpace($filePath)) {
                        return $false
                    }

                    try {
                        $candidatePath = [System.IO.Path]::GetFullPath($filePath)
                        return $candidatePath.Equals($expectedPath, [System.StringComparison]::OrdinalIgnoreCase)
                    } catch {
                        return $false
                    }
                }
        )

        $executedTests = @(
            $matchingTests |
                Where-Object {
                    $resultName = if ($_.PSObject.Properties.Name -contains 'Result') { [string]$_.Result } else { '' }
                    -not [string]::IsNullOrWhiteSpace($resultName) -and $resultName -notin @('Skipped', 'NotRun', 'Inconclusive')
                }
        )

        $detail = [pscustomobject]@{
            Path          = $integration.Path
            TotalTests    = $matchingTests.Count
            ExecutedTests = $executedTests.Count
        }
        $details += $detail

        if ($matchingTests.Count -eq 0) {
            $passed = $false
            $messages.Add(("Integration smoke produced no test results: {0}" -f $integration.Path))
            continue
        }

        if ($executedTests.Count -eq 0) {
            $passed = $false
            $messages.Add(("Integration smoke was fully skipped: {0}" -f $integration.Path))
        }
    }

    return [pscustomobject]@{
        Passed   = $passed
        Messages = @($messages)
        Details  = @($details)
    }
}

function Get-GitStatusLinesForPath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepoRoot,

        [Parameter(Mandatory = $true)]
        [string]$ProjectRelativePath
    )

    $git = Get-Command git -ErrorAction SilentlyContinue
    if (-not $git) {
        throw "git is required to validate '$ProjectRelativePath' clean state."
    }

    $rawOutput = & $git.Source -C $RepoRoot status --porcelain -- $ProjectRelativePath 2>&1
    if ($LASTEXITCODE -ne 0) {
        $message = ($rawOutput | ForEach-Object { [string]$_ }) -join ' '
        throw ("Unable to check git status for '{0}': {1}" -f $ProjectRelativePath, $message.Trim())
    }

    $lines = @(
        $rawOutput |
            ForEach-Object { [string]$_ } |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    )
    return $lines
}

function Test-ProjectFileCleanFromStatus {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [string[]]$StatusLines
    )

    if (-not $StatusLines -or $StatusLines.Count -eq 0) {
        return $true
    }

    foreach ($line in $StatusLines) {
        if (-not [string]::IsNullOrWhiteSpace([string]$line)) {
            return $false
        }
    }

    return $true
}

function Assert-DevModeNoLabVIEWProjectFileClean {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepoRoot,

        [Parameter(Mandatory = $false)]
        [string]$ProjectRelativePath = 'lv_icon_editor.lvproj',

        [AllowNull()]
        [string[]]$StatusLines
    )

    $lines = if ($PSBoundParameters.ContainsKey('StatusLines')) {
        @($StatusLines)
    } else {
        Get-GitStatusLinesForPath -RepoRoot $RepoRoot -ProjectRelativePath $ProjectRelativePath
    }

    if (-not (Test-ProjectFileCleanFromStatus -StatusLines $lines)) {
        throw "'$ProjectRelativePath' must be clean before smoke/parity. Clear it, then rerun."
    }
}
