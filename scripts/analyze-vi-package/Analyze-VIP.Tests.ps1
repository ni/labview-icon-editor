# Analyze-VIP.Tests.ps1
# Pester tests that assert policy requirements against a VI Package (.vip) by reading it directly.

[CmdletBinding()]
param(
[string]$VipPath,
[string]$MinLVVersion
)

# Tests run in a dedicated scope; relax strict mode locally to avoid expansion of placeholder tokens like <application>.
Set-StrictMode -Off

$vipReaderPath = Join-Path $PSScriptRoot 'VIPReader.psm1'
$pendingSkipReason = $null

function Resolve-VipPath {
    param([string]$ExplicitPath)

    $vipPath = if ($ExplicitPath) { $ExplicitPath } else { $env:VIP_PATH }
    if ($vipPath -and (Test-Path -LiteralPath $vipPath -PathType Leaf)) {
        return $vipPath
    }

    $repoRoot = $null
    try { $repoRoot = (git -C $PSScriptRoot rev-parse --show-toplevel 2>$null) } catch {}
    if (-not $repoRoot) {
        $probe = $PSScriptRoot
        for ($i = 0; $i -lt 5 -and $probe; $i++) {
            if (Test-Path (Join-Path $probe '.git')) { $repoRoot = $probe; break }
            $probe = Split-Path -Parent $probe
        }
    }

    if (-not $repoRoot) { return $null }

    $vipDir = Join-Path $repoRoot 'builds\vip-stash'
    $tagVersion = '0.1.0'
    try {
        $tag = git -C $repoRoot describe --tags --abbrev=0 2>$null
        if ($tag -and ($tag -match 'v?(\d+)\.(\d+)\.(\d+)')) {
            $tagVersion = "{0}.{1}.{2}" -f $Matches[1], $Matches[2], $Matches[3]
        }
    } catch {}
    $commitCount = $null
    try { $commitCount = git -C $repoRoot rev-list --count HEAD 2>$null } catch {}
    if ($commitCount) {
        $deterministicName = "ni_icon_editor-{0}.{1}.vip" -f $tagVersion, $commitCount
        $candidate = Join-Path $vipDir $deterministicName
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            Write-Information ("VIP_PATH not set; using deterministic VIP {0}" -f $candidate) -InformationAction Continue
            return $candidate
        }
    }

    $fallback = Get-ChildItem -Path $vipDir -Filter *.vip -File -Recurse -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($fallback) {
        $resolved = $fallback.FullName
        Write-Information ("VIP_PATH not set; using latest VIP under {0}: {1}" -f $vipDir, $resolved) -InformationAction Continue
        return $resolved
    }

    return $null
}

if (-not (Test-Path -LiteralPath $vipReaderPath)) {
    $pendingSkipReason = "VIPReader module not found at $vipReaderPath; skipping Analyze-VIP."
}

$script:ResolvedVipPath = Resolve-VipPath -ExplicitPath $VipPath
if (-not $script:ResolvedVipPath -or -not (Test-Path -LiteralPath $script:ResolvedVipPath -PathType Leaf)) {
    Write-Warning "VIP_PATH not set and no .vip under builds\vip-stash. Set VIP_PATH or run via run-local.ps1. Skipping Analyze-VIP tests."
    Describe "Analyze VIP" -Skip:$true { It "skipped" { } }
    return
}

# Skip if we intentionally emitted a placeholder VIP to represent a skipped vipm build.
if ($script:ResolvedVipPath -like '*vipm-skipped-placeholder.vip') {
    $pendingSkipReason = "Placeholder VIP detected (vipm build skipped); skipping Analyze-VIP."
}

if ($pendingSkipReason) {
    Write-Warning $pendingSkipReason
    Describe "Analyze VIP" -Skip:$true { It "skipped" { } }
    return
}

Import-Module -Name $vipReaderPath -Force

# Ensure a minimum LabVIEW version is present for comparison logic.
if (-not $env:MIN_LV_VERSION -and $MinLVVersion) {
    $env:MIN_LV_VERSION = $MinLVVersion
}
elseif (-not $env:MIN_LV_VERSION) {
    $env:MIN_LV_VERSION = '23.0'
}

function Normalize-LabVIEWVersion {
    param([string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value)) {
        throw "LabVIEW version input is empty."
    }

    $pattern = '(?<maj>\d{2,4})(?:\.(?<min>\d{1,2}))?'
    $match = [regex]::Match($Value, $pattern)
    if (-not $match.Success) {
        throw "Unable to parse LabVIEW version from '$Value'."
    }

    $maj = [int]$match.Groups['maj'].Value
    if ($maj -lt 100) { $maj += 2000 }
    $minor = 0
    if ($match.Groups['min'].Success) {
        $minor = [int]$match.Groups['min'].Value
    }
    if ($minor -eq 0) {
        $spMatch = [regex]::Match($Value, '(?i)SP\s*(?<sp>\d+)')
        if ($spMatch.Success) {
            $minor = [int]$spMatch.Groups['sp'].Value
        }
    }

    return [pscustomobject]@{
        Major    = $maj
        Minor    = $minor
        AsString = ('{0}.{1}' -f $maj, $minor)
    }
}

BeforeAll {
    function Resolve-VipPath {
        param([string]$ExplicitPath)

        $vipPath = if ($ExplicitPath) { $ExplicitPath } else { $env:VIP_PATH }
        if ($vipPath -and (Test-Path -LiteralPath $vipPath -PathType Leaf)) {
            return $vipPath
        }

        $repoRoot = $null
        try { $repoRoot = (git -C $PSScriptRoot rev-parse --show-toplevel 2>$null) } catch {}
        if (-not $repoRoot) {
            $probe = $PSScriptRoot
            for ($i = 0; $i -lt 5 -and $probe; $i++) {
                if (Test-Path (Join-Path $probe '.git')) { $repoRoot = $probe; break }
                $probe = Split-Path -Parent $probe
            }
        }

        if (-not $repoRoot) { return $null }

        $vipDir = Join-Path $repoRoot 'builds\vip-stash'
        $tagVersion = '0.1.0'
        try {
            $tag = git -C $repoRoot describe --tags --abbrev=0 2>$null
            if ($tag -and ($tag -match 'v?(\d+)\.(\d+)\.(\d+)')) {
                $tagVersion = "{0}.{1}.{2}" -f $Matches[1], $Matches[2], $Matches[3]
            }
        } catch {}
        $commitCount = $null
        try { $commitCount = git -C $repoRoot rev-list --count HEAD 2>$null } catch {}
        if ($commitCount) {
            $deterministicName = "ni_icon_editor-{0}.{1}.vip" -f $tagVersion, $commitCount
            $candidate = Join-Path $vipDir $deterministicName
            if (Test-Path -LiteralPath $candidate -PathType Leaf) {
                Write-Information ("VIP_PATH not set; using deterministic VIP {0}" -f $candidate) -InformationAction Continue
                return $candidate
            }
        }

        $fallback = Get-ChildItem -Path $vipDir -Filter *.vip -File -Recurse -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if ($fallback) {
            $resolved = $fallback.FullName
            Write-Information ("VIP_PATH not set; using latest VIP under {0}: {1}" -f $vipDir, $resolved) -InformationAction Continue
            return $resolved
        }

        return $null
    }

    $vipReaderPath = Join-Path $PSScriptRoot 'VIPReader.psm1'
    if (-not (Test-Path -LiteralPath $vipReaderPath)) {
        throw "VIPReader module not found at $vipReaderPath; unable to analyze VIP."
    }
    Import-Module -Name $vipReaderPath -Force

    if (-not $env:MIN_LV_VERSION) {
        if ($MinLVVersion) { $env:MIN_LV_VERSION = $MinLVVersion }
        else { $env:MIN_LV_VERSION = '23.0' }
    }

    $localVip = (Get-Variable -Scope Script -Name ResolvedVipPath -ErrorAction SilentlyContinue).Value
    if (-not $localVip -or -not (Test-Path -LiteralPath $localVip -PathType Leaf)) {
        $localVip = Resolve-VipPath -ExplicitPath $VipPath
    }
    if (-not $localVip -or -not (Test-Path -LiteralPath $localVip -PathType Leaf)) {
        $localVip = if ($VipPath) { $VipPath } else { $env:VIP_PATH }
        if (-not $localVip -or -not (Test-Path -LiteralPath $localVip -PathType Leaf)) {
            $repoRoot = $null
            try { $repoRoot = (git -C $PSScriptRoot rev-parse --show-toplevel 2>$null) } catch {}
            if (-not $repoRoot) {
                $probe = $PSScriptRoot
                for ($i = 0; $i -lt 5 -and $probe; $i++) {
                    if (Test-Path (Join-Path $probe '.git')) { $repoRoot = $probe; break }
                    $probe = Split-Path -Parent $probe
                }
            }
            if ($repoRoot) {
        $vipDir = Join-Path $repoRoot 'builds\vip-stash'
                $tagVersion = '0.1.0'
                try {
                    $tag = git -C $repoRoot describe --tags --abbrev=0 2>$null
                    if ($tag -and ($tag -match 'v?(\d+)\.(\d+)\.(\d+)')) {
                        $tagVersion = "{0}.{1}.{2}" -f $Matches[1], $Matches[2], $Matches[3]
                    }
                } catch {}
                $commitCount = $null
                try { $commitCount = git -C $repoRoot rev-list --count HEAD 2>$null } catch {}
                if ($commitCount) {
                    $deterministicName = "ni_icon_editor-{0}.{1}.vip" -f $tagVersion, $commitCount
                    $candidate = Join-Path $vipDir $deterministicName
                    if (Test-Path -LiteralPath $candidate -PathType Leaf) {
                        Write-Information ("VIP_PATH not set; using deterministic VIP {0}" -f $candidate) -InformationAction Continue
                        $localVip = $candidate
                    }
                }
                if (-not $localVip) {
                    $fallback = Get-ChildItem -Path $vipDir -Filter *.vip -File -Recurse -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
                    if ($fallback) {
                        $localVip = $fallback.FullName
                        Write-Information ("VIP_PATH not set; using latest VIP under {0}: {1}" -f $vipDir, $localVip) -InformationAction Continue
                    }
                }
            }
        }
    }
    if (-not $localVip -or -not (Test-Path -LiteralPath $localVip -PathType Leaf)) {
        throw "Unable to resolve VIP for analysis. Set VIP_PATH or ensure builds\\vip-stash contains a .vip."
    }
    $script:ResolvedVipPath = $localVip
    $script:vip = Read-VipSpec -Path $script:ResolvedVipPath
    $script:S = $vip.Sections
    $script:entries = $vip.ZipEntries
    $script:entryNames = $entries | ForEach-Object { [System.IO.Path]::GetFileName($_) }
    function global:Get-VersionPart([string]$ver) {
        if (-not $ver) { return @() }
        return ($ver -split '\.').ForEach({ $_ -as [int] })
    }
    function global:Set-NormalizedFileName([string]$name) {
        if (-not $name) { return '' }
        $base = [System.IO.Path]::GetFileName($name)
        return ([regex]::Replace($base, '[^a-zA-Z0-9]', '')).ToLowerInvariant()
    }
    function global:Set-NormalizedScriptToken([string]$name) {
        if (-not $name) { return '' }
        $base = [System.IO.Path]::GetFileNameWithoutExtension($name).ToLowerInvariant()
        $base = $base -replace '^vip', ''
        $base = $base -replace 'customaction', ''
        $base = $base -replace '[^a-z0-9]', ''
        return $base
    }
    $script:normalizedEntries = $entryNames | ForEach-Object { Set-NormalizedFileName $_ }
    $script:normalizedScriptEntries = $entryNames | ForEach-Object { Set-NormalizedScriptToken $_ }
}

# Utility for version parsing (x.y or x.y.z.w)
Describe "Package metadata" {
    It "VIP-PKG-001: Package.Name SHALL be non-empty and use lowercase letters, digits, or underscores only" {
        $name = Get-VipField -Sections $S -Section 'Package' -Key 'Name'
        $name | Should -Not -BeNullOrEmpty
        $name | Should -Match '^[a-z0-9_]+$'
    }

    It "VIP-PKG-002: Package.Version SHALL be a four-integer dotted version (major.minor.patch.build)" {
        $ver = Get-VipField -Sections $S -Section 'Package' -Key 'Version'
        $ver | Should -Match '^\d+\.\d+\.\d+\.\d+$'
    }

    It "VIP-PKG-003: Package.ID SHALL be a 32-hexadecimal identifier" {
        $id = Get-VipField -Sections $S -Section 'Package' -Key 'ID'
        $id | Should -Match '^[0-9a-fA-F]{32}$'
    }

    It "VIP-PKG-004: Package.File Format SHALL equal 'vip'" {
        (Get-VipField -Sections $S -Section 'Package' -Key 'File Format') | Should -BeExactly 'vip'
    }

    It "VIP-PKG-005: Package.Format Version SHALL be numeric and not earlier than 2017" {
        $fv = Get-VipField -Sections $S -Section 'Package' -Key 'Format Version'
        $fv | Should -Match '^\d{4}$'
        [int]$fv | Should -BeGreaterOrEqual 2017
    }

    It "VIP-PKG-006: Package.Display Name SHALL be non-empty" {
        (Get-VipField -Sections $S -Section 'Package' -Key 'Display Name') | Should -Not -BeNullOrEmpty
    }
}

Describe "Descriptive metadata" {
    It "VIP-DESC-001: Description.License SHALL be one of the approved identifiers (MIT, BSD-3, Apache-2.0, GPL-3.0-only, Proprietary)" {
        $allowed = @('MIT','BSD-3','Apache-2.0','GPL-3.0-only','Proprietary')
        $lic = Get-VipField -Sections $S -Section 'Description' -Key 'License'
        $allowed | Should -Contain $lic
    }

    It "VIP-DESC-002: Description.Copyright SHALL be present" {
        (Get-VipField -Sections $S -Section 'Description' -Key 'Copyright') | Should -Not -BeNullOrEmpty
    }

    It "VIP-DESC-003: Description.Vendor SHALL be present" {
        (Get-VipField -Sections $S -Section 'Description' -Key 'Vendor') | Should -Not -BeNullOrEmpty
    }

    It "VIP-DESC-004: Description.Packager SHALL be present" {
        (Get-VipField -Sections $S -Section 'Description' -Key 'Packager') | Should -Not -BeNullOrEmpty
    }

    It "VIP-DESC-005: Description.URL, if present, SHALL be a valid HTTP(S) URL" {
        $url = Get-VipField -Sections $S -Section 'Description' -Key 'URL'
        if ($null -ne $url -and $url -ne '') {
            $url | Should -Match '^https?://'
        } else {
            $true | Should -BeTrue # pass when empty
        }
    }
}

Describe "LabVIEW installation behavior" {
    It "VIP-LV-001: LabVIEW.Close before install SHALL be TRUE" {
        (Get-VipField -Sections $S -Section 'LabVIEW' -Key 'close labview before install') | Should -BeExactly 'TRUE'
    }
    It "VIP-LV-002: LabVIEW.Restart after install SHALL be TRUE" {
        (Get-VipField -Sections $S -Section 'LabVIEW' -Key 'restart labview after install') | Should -BeExactly 'TRUE'
    }
    It "VIP-LV-003: LabVIEW.Skip mass compile after install SHALL be TRUE" {
        (Get-VipField -Sections $S -Section 'LabVIEW' -Key 'skip mass compile after install') | Should -BeExactly 'TRUE'
    }
    It "VIP-LV-004: LabVIEW.Install into global environment SHALL be FALSE" {
        (Get-VipField -Sections $S -Section 'LabVIEW' -Key 'install into global environment') | Should -BeExactly 'FALSE'
    }
}

Describe "Platform constraints" {
    It "VIP-PLAT-001: Platform.Exclusive_LabVIEW_Version SHALL specify a minimal version using 'LabVIEW>='" {
        $val = Get-VipField -Sections $S -Section 'Platform' -Key 'Exclusive_LabVIEW_Version'
        $val | Should -Match '^LabVIEW>='
        $specNorm = Normalize-LabVIEWVersion $val
        $minNorm = Normalize-LabVIEWVersion $env:MIN_LV_VERSION
        $specParts = @($specNorm.Major, $specNorm.Minor)
        $minParts = @($minNorm.Major, $minNorm.Minor)
        # Pad to equal length for comparison
        while ($minParts.Count -lt 2) { $minParts += 0 }
        while ($specParts.Count -lt 2) { $specParts += 0 }
        # assert spec >= min
        $specOk = ($specParts[0] -gt $minParts[0]) -or (($specParts[0] -eq $minParts[0]) -and ($specParts[1] -ge $minParts[1]))
        $specOk | Should -BeTrue
    }

    It "VIP-PLAT-002: Platform.Exclusive_LabVIEW_System SHALL be 'ALL' unless a narrower system is justified" {
        (Get-VipField -Sections $S -Section 'Platform' -Key 'Exclusive_LabVIEW_System') | Should -BeExactly 'ALL'
    }

    It "VIP-PLAT-003: Platform.Exclusive_OS SHALL be 'Windows NT' (package is Windows-only)" {
        (Get-VipField -Sections $S -Section 'Platform' -Key 'Exclusive_OS') | Should -BeExactly 'Windows NT'
    }
}

Describe "Scripted actions" {
    It "VIP-SCRIPT-001: Script VIs.PreInstall, if specified, SHALL point to a file included in the VIP" {
        $val = Get-VipField -Sections $S -Section 'Script VIs' -Key 'PreInstall'
        if ($val -and $val -ne '') {
            $normalizedScriptEntries | Should -Contain 'preinstall'
        } else { $true | Should -BeTrue }
    }
    It "VIP-SCRIPT-002: Script VIs.PostInstall, if specified, SHALL point to a file included in the VIP" {
        $val = Get-VipField -Sections $S -Section 'Script VIs' -Key 'PostInstall'
        if ($val -and $val -ne '') {
            $normalizedScriptEntries | Should -Contain 'postinstall'
        } else { $true | Should -BeTrue }
    }
    It "VIP-SCRIPT-003: Script VIs.PreUninstall, if specified, SHALL point to a file included in the VIP" {
        $val = Get-VipField -Sections $S -Section 'Script VIs' -Key 'PreUninstall'
        if ($val -and $val -ne '') {
            $normalizedScriptEntries | Should -Contain 'preuninstall'
        } else { $true | Should -BeTrue }
    }
    It "VIP-SCRIPT-004: Script VIs.PostUninstall, if specified, SHALL point to a file included in the VIP" {
        $val = Get-VipField -Sections $S -Section 'Script VIs' -Key 'PostUninstall'
        if ($val -and $val -ne '') {
            $normalizedScriptEntries | Should -Contain 'postuninstall'
        } else { $true | Should -BeTrue }
    }
}

Describe "Dependencies and activation" {
    It "VIP-DEPS-001: Dependencies.AutoReqProv SHALL be FALSE (explicit dependency declaration only)" {
        (Get-VipField -Sections $S -Section 'Dependencies' -Key 'AutoReqProv') | Should -BeExactly 'FALSE'
    }
    It "VIP-DEPS-002: Dependencies.Requires SHALL pin the package's system sub-package to the same version as the parent" {
        $requires = Get-VipField -Sections $S -Section 'Dependencies' -Key 'Requires'
        $name = Get-VipField -Sections $S -Section 'Package' -Key 'Name'
        $ver  = Get-VipField -Sections $S -Section 'Package' -Key 'Version'
        $expected = ($name + '_system=' + $ver)
        $requires.Replace(' ', '').ToLower() | Should -Match ([regex]::Escape($expected.ToLower()))
    }
    It "VIP-DEPS-003: Activation.License File SHALL be empty (no activation file) for open-source packages" {
        ((Get-VipField -Sections $S -Section 'Activation' -Key 'License File') ?? '') | Should -BeExactly ''
    }
    It "VIP-DEPS-004: Activation.Licensed Library SHALL be empty for open-source packages" {
        ((Get-VipField -Sections $S -Section 'Activation' -Key 'Licensed Library') ?? '') | Should -BeExactly ''
    }
}

Describe "File layout" {
    It "VIP-FILE-001: Files.Num File Groups SHALL be 1" {
        (Get-VipField -Sections $S -Section 'Files' -Key 'Num File Groups') | Should -BeExactly '1'
    }
    It "VIP-FILE-002: Files.Sub-Packages SHALL include a system package with the same version" {
        $sub = (Get-VipField -Sections $S -Section 'Files' -Key 'Sub-Packages')
        $name = Get-VipField -Sections $S -Section 'Package' -Key 'Name'
        $ver  = Get-VipField -Sections $S -Section 'Package' -Key 'Version'
        $expected = ($name + '_system-' + $ver)
        $sub.Replace(' ', '').ToLower() | Should -Match ([regex]::Escape($expected.ToLower()))
    }
    It "VIP-FILE-003: File Group 0.Target Dir SHALL be <application>" {
        Set-StrictMode -Off
        $target = Get-VipField -Sections $S -Section 'File Group 0' -Key 'Target Dir'
        $targetString = ($target -as [string]) -replace '[<>]', ''
        if ($targetString.ToLowerInvariant() -ne 'application') {
            throw "Expected Target Dir '<application>' but found '$targetString'."
        }
    }
    It "VIP-FILE-004: File Group 0.Replace Mode SHALL be Always" {
        (Get-VipField -Sections $S -Section 'File Group 0' -Key 'Replace Mode') | Should -BeExactly 'Always'
    }
}

Describe "LabVIEW version normalization helper" {
    $matrix = @(
        @{ Label = 'YYYY'; Raw = '2023'; ExpectedMajor = 2023; ExpectedMinor = 0 },
        @{ Label = 'YY.decimal'; Raw = '23.0'; ExpectedMajor = 2023; ExpectedMinor = 0 },
        @{ Label = 'LabVIEW>=major.minor'; Raw = 'LabVIEW>=23.5 (64-bit)'; ExpectedMajor = 2023; ExpectedMinor = 5 },
        @{ Label = 'Year with SP annotation'; Raw = '2025 SP1 64-bit'; ExpectedMajor = 2025; ExpectedMinor = 1 }
    )

    foreach ($entry in $matrix) {
        It ("normalizes {0}" -f $entry.Label) {
            $normalized = Normalize-LabVIEWVersion $entry.Raw
            $normalized.Major | Should -Be $entry.ExpectedMajor
            $normalized.Minor | Should -Be $entry.ExpectedMinor
        }
    }
}

# Optional smoke tests for presence of known entries (icon & scripts)
Describe "Presence of core files in the VIP" {
    It "VIP-CONTENT-001: icon.bmp SHALL be included" {
        $entries | Should -Contain 'icon.bmp'
    }
    It "VIP-CONTENT-002: Script VIs (*.vi) referenced SHALL be included" {
        foreach ($token in @('preinstall','postinstall','preuninstall','postuninstall')) {
            $normalizedScriptEntries | Should -Contain $token -Because ("Expected script token {0} in package entries." -f $token)
        }
    }
    It "VIP-CONTENT-003: System sub-package SHALL be included" {
        $systemPackage = $entryNames | Where-Object { $_ -match '_system-\d+\.\d+\.\d+\.\d+\.vip$' } | Select-Object -First 1
        $systemPackage | Should -Not -BeNullOrEmpty -Because "Expected system sub-package (*.vip) to be present."
    }
    It "VIP-CONTENT-004: Neutral lvlibp SHALL be included under resource/plugins" {
        $entries | ForEach-Object { $_.ToLowerInvariant() } | Should -Contain 'resource/plugins/lv_icon.lvlibp' -Because "Expected neutral lv_icon.lvlibp inside the package."
    }
    It "VIP-CONTENT-005: Windows x64 lvlibp SHALL be included under resource/plugins" {
        $entries | ForEach-Object { $_.ToLowerInvariant() } | Should -Contain 'resource/plugins/lv_icon.lvlibp.windows_x64' -Because "Expected x64 lv_icon.lvlibp.windows_x64 inside the package."
    }
    It "VIP-CONTENT-006: Windows x86 lvlibp SHALL be included under resource/plugins" {
        $entries | ForEach-Object { $_.ToLowerInvariant() } | Should -Contain 'resource/plugins/lv_icon.lvlibp.windows_x86' -Because "Expected x86 lv_icon.lvlibp.windows_x86 inside the package."
    }
}
