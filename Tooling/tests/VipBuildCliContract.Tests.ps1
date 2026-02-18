#Requires -Version 7.0
#Requires -Modules Pester

$ErrorActionPreference = 'Stop'

Describe 'VIP build CLI contract' {
    BeforeAll {
        $script:repoRoot = Resolve-Path -Path (Join-Path $PSScriptRoot '..\..')
        $script:buildVipScript = Join-Path $script:repoRoot '.github\actions\build-vip\build_vip.ps1'
        $script:buildVipAction = Join-Path $script:repoRoot '.github\actions\build-vip\action.yml'
        $script:invokeVipBuildScript = Join-Path $script:repoRoot 'Tooling\Invoke-VipBuild.ps1'
        $script:runnerCliProgram = Join-Path $script:repoRoot 'Tooling\runner-cli\RunnerCli\Program.cs'
        $script:ciWorkflowPath = Join-Path $script:repoRoot '.github\workflows\ci.yml'
    }

    It 'build_vip.ps1 invokes VIPM CLI build and does not call g-cli directly' {
        (Test-Path -LiteralPath $script:buildVipScript -PathType Leaf) | Should -BeTrue
        $content = Get-Content -Path $script:buildVipScript -Raw

        $content | Should -Match 'Get-Command vipm'
        $content | Should -Match "'build'"
        $content | Should -Match 'vipm-build\.log'
        $content | Should -Not -Match '&\s*g-cli'
    }

    It 'build_vip.ps1 synchronizes VIPM target port and timeout to LabVIEW contract before build' {
        (Test-Path -LiteralPath $script:buildVipScript -PathType Leaf) | Should -BeTrue
        $content = Get-Content -Path $script:buildVipScript -Raw

        $content | Should -Match 'function Set-VipmTargetSettingsFromContract'
        $content | Should -Match 'Resolve-LabVIEWCliPortFromContract'
        $content | Should -Match 'Connection Timeout'
        $content | Should -Match 'Set-VipmTargetSettingsFromContract\s*`?\s*-RepoRoot'
    }

    It 'build-vip action preflight validates VIPM CLI and publishes VIPM logs artifact' {
        (Test-Path -LiteralPath $script:buildVipAction -PathType Leaf) | Should -BeTrue
        $content = Get-Content -Path $script:buildVipAction -Raw

        $content | Should -Match 'Pre-flight VIPM CLI availability check'
        $content | Should -Match 'Get-Command vipm'
        $content | Should -Match 'vipm-preflight\.log'
        $content | Should -Match 'name:\s*vipm-logs'
        $content | Should -Not -Match 'Pre-flight g-cli'
    }

    It 'Invoke-VipBuild enforces single attempt and rejects deprecated retry env settings' {
        (Test-Path -LiteralPath $script:invokeVipBuildScript -PathType Leaf) | Should -BeTrue
        $content = Get-Content -Path $script:invokeVipBuildScript -Raw

        $content | Should -Match 'Assert-DeprecatedVipmRetrySettingsUnset'
        $content | Should -Match 'VIP build attempt 1 of 1'
        $content | Should -Not -Match 'Retrying after'
        $content | Should -Not -Match 'MaxAttempts'
        $content | Should -Not -Match 'RetryDelaySeconds'
    }

    It 'runner-cli vip build no longer exposes retry flags' {
        (Test-Path -LiteralPath $script:runnerCliProgram -PathType Leaf) | Should -BeTrue
        $content = Get-Content -Path $script:runnerCliProgram -Raw

        $content | Should -Not -Match '--max-attempts'
        $content | Should -Not -Match '--retry-delay-seconds'
    }

    It 'CI build-vip job does not define deprecated VIPM retry env knobs' {
        (Test-Path -LiteralPath $script:ciWorkflowPath -PathType Leaf) | Should -BeTrue
        $content = Get-Content -Path $script:ciWorkflowPath -Raw

        $content | Should -Not -Match 'LVIE_VIPM_MAX_ATTEMPTS'
        $content | Should -Not -Match 'LVIE_VIPM_RETRY_DELAY_SECONDS'
    }

    It 'CI build-vip job derives LabVIEW version inputs from .lvversion via version-gate outputs' {
        (Test-Path -LiteralPath $script:ciWorkflowPath -PathType Leaf) | Should -BeTrue
        $content = Get-Content -Path $script:ciWorkflowPath -Raw
        $buildVipMatch = [regex]::Match(
            $content,
            '(?ms)^  build-vip:\r?\n(?<body>.*?)(?=^  [a-zA-Z0-9_-]+:\r?\n|\z)'
        )
        $buildVipMatch.Success | Should -BeTrue
        $buildVipSection = $buildVipMatch.Groups['body'].Value

        $buildVipSection | Should -Match 'LVIE_REQUIRED_LABVIEW_VERSION:\s*\$\{\{\s*needs\.version-gate\.outputs\.raw\s*\}\}'
        $buildVipSection | Should -Match 'LVIE_REQUIRED_LABVIEW_VERSION_YEAR:\s*\$\{\{\s*needs\.version-gate\.outputs\.year\s*\}\}'
        $buildVipSection | Should -Match 'LVIE_REQUIRED_LABVIEW_MINOR_REVISION:\s*\$\{\{\s*needs\.version-gate\.outputs\.minor\s*\}\}'
        $buildVipSection | Should -Match 'Assert VI Package LabVIEW version contract'
        $buildVipSection | Should -Match 'LabVIEW version drift detected'
        $buildVipSection | Should -Match 'LabVIEW minor revision drift detected'
        $buildVipSection | Should -Match '-LabVIEWVersion \$env:LVIE_REQUIRED_LABVIEW_VERSION'
        $buildVipSection | Should -Match '-LabVIEWMinorRevision \$env:LVIE_REQUIRED_LABVIEW_MINOR_REVISION'
        $buildVipSection | Should -Match '''--labview-version'',\s*\$env:LVIE_REQUIRED_LABVIEW_VERSION'
        $buildVipSection | Should -Match '''--labview-minor-revision'',\s*\$env:LVIE_REQUIRED_LABVIEW_MINOR_REVISION'
        $buildVipSection | Should -Not -Match '''--labview-version'',\s*\$env:LABVIEW_VERSION_RAW'
    }
}
