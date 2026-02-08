#Requires -Version 7.0
<#
.SYNOPSIS
    Verifies that VIPC package versions are installed for a LabVIEW bitness.

.DESCRIPTION
    Extracts package expectations from a .vipc file and compares them against
    installed package files recorded in the VIPM database for the target
    LabVIEW version/bitness.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$RepoRoot,

    [Parameter(Mandatory = $true)]
    [string]$VIPCPath,

    [Parameter(Mandatory = $true)]
    [ValidateSet('32', '64')]
    [string]$SupportedBitness,

    [Parameter(Mandatory = $false)]
    [AllowNull()]
    [AllowEmptyString()]
    [string]$LabVIEWVersion = '',

    [Parameter(Mandatory = $true)]
    [string]$OutputPath,

    [Parameter(Mandatory = $false)]
    [bool]$FailOnMismatch = $true
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-PackageEntry {
    param(
        [Parameter(Mandatory = $true)]
        [string]$PackageName
    )

    $match = [regex]::Match($PackageName, '^(?<root>.+)-(?<version>\d.+)$')
    if (-not $match.Success) {
        return [pscustomobject]@{
            root        = $PackageName
            version     = $null
            package_name = $PackageName
            parse_error = $true
        }
    }

    return [pscustomobject]@{
        root         = $match.Groups['root'].Value
        version      = $match.Groups['version'].Value
        package_name = $PackageName
        parse_error  = $false
    }
}

function Get-InstalledPackageBasename {
    param(
        [Parameter(Mandatory = $true)]
        [string]$PackageDirectory
    )

    if (-not (Test-Path -Path $PackageDirectory -PathType Container)) {
        return @()
    }

    $extensions = @('.vip', '.ogp', '.ogpa')
    return @(
        Get-ChildItem -Path $PackageDirectory -File -ErrorAction SilentlyContinue |
            Where-Object { $extensions -contains $_.Extension.ToLowerInvariant() } |
            ForEach-Object { $_.BaseName } |
            Sort-Object -Unique
    )
}

$tempExtractRoot = $null
try {
    $resolvedRepoRoot = (Resolve-Path -Path $RepoRoot).Path
    $resolvedVipcPath = Join-Path -Path $resolvedRepoRoot -ChildPath $VIPCPath
    if (-not (Test-Path -Path $resolvedVipcPath -PathType Leaf)) {
        throw "VIPC file not found at '$resolvedVipcPath'."
    }

    $versionHelper = Join-Path -Path $resolvedRepoRoot -ChildPath 'Tooling\support\LabVIEWVersion.ps1'
    if (-not (Test-Path -Path $versionHelper -PathType Leaf)) {
        throw "LabVIEW version helper not found at '$versionHelper'."
    }

    . $versionHelper
    $lvInfo = Get-LabVIEWVersionInfo -VersionInput $LabVIEWVersion -RepoRoot $resolvedRepoRoot

    $vipmDbRoot = Join-Path -Path $env:ProgramData -ChildPath 'JKI\VIPM\databases'
    $dbFolderName = if ($SupportedBitness -eq '64') {
        "LV $($lvInfo.NumericVersion) (64-bit)"
    } else {
        "LV $($lvInfo.NumericVersion)"
    }
    $vipmDbPath = Join-Path -Path $vipmDbRoot -ChildPath $dbFolderName

    if (-not (Test-Path -Path $vipmDbPath -PathType Container)) {
        throw "VIPM database path not found for LabVIEW $($lvInfo.NumericVersion) ($SupportedBitness-bit): '$vipmDbPath'."
    }

    $tempExtractRoot = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath ("vipc-audit-{0}" -f [guid]::NewGuid().ToString())
    New-Item -Path $tempExtractRoot -ItemType Directory -Force | Out-Null
    Expand-Archive -Path $resolvedVipcPath -DestinationPath $tempExtractRoot -Force

    $expectedPackages = @(
        Get-ChildItem -Path $tempExtractRoot -File -Filter '*.spec' -ErrorAction SilentlyContinue |
            ForEach-Object { $_.BaseName } |
            Sort-Object -Unique
    )

    if ($expectedPackages.Count -eq 0) {
        $configPath = Join-Path -Path $tempExtractRoot -ChildPath 'config.xml'
        if (Test-Path -Path $configPath -PathType Leaf) {
            [xml]$configXml = Get-Content -Path $configPath
            $expectedPackages = @(
                $configXml.VI_Package_Configuration.Target.Package |
                    ForEach-Object { [string]$_.Name } |
                    Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
                    Sort-Object -Unique
            )
        }
    }

    if ($expectedPackages.Count -eq 0) {
        throw "No expected package entries were discovered in '$resolvedVipcPath'."
    }

    $expectedEntries = @($expectedPackages | ForEach-Object { Get-PackageEntry -PackageName $_ })

    $expectedByRoot = @{}
    foreach ($entry in $expectedEntries) {
        if (-not $expectedByRoot.ContainsKey($entry.root)) {
            $expectedByRoot[$entry.root] = New-Object System.Collections.Generic.List[string]
        }
        $expectedByRoot[$entry.root].Add($entry.package_name)
    }

    $rootAudit = New-Object System.Collections.Generic.List[object]
    foreach ($root in ($expectedByRoot.Keys | Sort-Object)) {
        $expectedForRoot = @($expectedByRoot[$root] | Sort-Object -Unique)
        $packageDirectory = Join-Path -Path $vipmDbPath -ChildPath $root
        $installedForRoot = @(Get-InstalledPackageBasename -PackageDirectory $packageDirectory)

        $missingExpected = @($expectedForRoot | Where-Object { $installedForRoot -notcontains $_ })
        $unexpectedInstalled = @($installedForRoot | Where-Object { $expectedForRoot -notcontains $_ })

        $rootAudit.Add([pscustomobject]@{
            root                 = $root
            package_dir          = $packageDirectory
            package_dir_exists   = (Test-Path -Path $packageDirectory -PathType Container)
            expected             = $expectedForRoot
            installed            = $installedForRoot
            missing_expected     = $missingExpected
            unexpected_installed = $unexpectedInstalled
            matched              = ($missingExpected.Count -eq 0 -and $unexpectedInstalled.Count -eq 0)
        })
    }

    $mismatchRoots = @($rootAudit | Where-Object { -not $_.matched })
    $missingExpectedPackages = @($rootAudit | ForEach-Object { @($_.missing_expected) })
    $unexpectedInstalledPackages = @($rootAudit | ForEach-Object { @($_.unexpected_installed) })

    $summary = [ordered]@{
        roots_checked                = $rootAudit.Count
        mismatched_roots             = $mismatchRoots.Count
        missing_expected_count       = $missingExpectedPackages.Count
        unexpected_installed_count   = $unexpectedInstalledPackages.Count
        status                       = if ($mismatchRoots.Count -eq 0) { 'pass' } else { 'fail' }
    }

    $report = [ordered]@{
        generated_utc       = (Get-Date).ToUniversalTime().ToString('o')
        repo_root           = $resolvedRepoRoot
        vipc_path           = $resolvedVipcPath
        vipc_sha256         = (Get-FileHash -Path $resolvedVipcPath -Algorithm SHA256).Hash
        labview_version_raw = $lvInfo.Raw
        labview_year        = $lvInfo.Year
        labview_numeric     = $lvInfo.NumericVersion
        supported_bitness   = $SupportedBitness
        vipm_database_path  = $vipmDbPath
        expected_package_count = $expectedPackages.Count
        expected_packages   = $expectedPackages
        parse_errors        = @($expectedEntries | Where-Object { $_.parse_error } | ForEach-Object { $_.package_name })
        root_audit          = $rootAudit
        summary             = $summary
    }

    $outputDirectory = Split-Path -Parent $OutputPath
    if (-not [string]::IsNullOrWhiteSpace($outputDirectory) -and -not (Test-Path -Path $outputDirectory)) {
        New-Item -Path $outputDirectory -ItemType Directory -Force | Out-Null
    }

    $report | ConvertTo-Json -Depth 12 | Set-Content -Path $OutputPath -Encoding utf8

    Write-Host ("VIPC audit complete for LabVIEW {0} ({1}-bit)." -f $lvInfo.NumericVersion, $SupportedBitness)
    Write-Host ("Expected packages: {0}" -f $expectedPackages.Count)
    Write-Host ("Mismatched roots: {0}" -f $mismatchRoots.Count)
    Write-Host ("Report: {0}" -f (Resolve-Path -Path $OutputPath).Path)

    if ($mismatchRoots.Count -gt 0) {
        Write-Warning "VIPC audit detected mismatches:"
        foreach ($rootResult in $mismatchRoots) {
            Write-Warning ("  Root: {0}" -f $rootResult.root)
            if ($rootResult.missing_expected.Count -gt 0) {
                Write-Warning ("    Missing expected: {0}" -f ($rootResult.missing_expected -join ', '))
            }
            if ($rootResult.unexpected_installed.Count -gt 0) {
                Write-Warning ("    Unexpected installed: {0}" -f ($rootResult.unexpected_installed -join ', '))
            }
        }

        if ($FailOnMismatch) {
            throw "VIPC audit failed: installed package state does not match expected VIPC contents."
        }
    }

    $global:LASTEXITCODE = 0
}
catch {
    Write-Error $_.Exception.Message
    exit 1
}
finally {
    if (-not [string]::IsNullOrWhiteSpace($tempExtractRoot) -and (Test-Path -Path $tempExtractRoot)) {
        Remove-Item -Path $tempExtractRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}
