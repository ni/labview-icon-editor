# Analyze-VIP.Tests.ps1
# Pester tests that assert policy requirements against a VI Package (.vip) by reading it directly.

param()

# Tests run in a dedicated scope; relax strict mode locally to avoid expansion of placeholder tokens like <application>.
Set-StrictMode -Off

Import-Module "$PSScriptRoot/VIPReader.psm1" -Force

BeforeAll {
$script:vip = Read-VipSpec -Path $env:VIP_PATH
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
        $m = [regex]::Match($val, 'LabVIEW>=(\d+\.\d+)')
        $m.Success | Should -BeTrue
        $specified = $m.Groups[1].Value
        # Compare major.minor numerically
        $minParts = (Get-VersionPart $env:MIN_LV_VERSION)
        $specParts = (Get-VersionPart $specified)
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
}
