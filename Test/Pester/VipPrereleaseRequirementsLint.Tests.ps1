$ErrorActionPreference = 'Stop'

Describe 'VIP prerelease requirements v1 lint' {
    BeforeAll {
        $script:repoRoot = (Resolve-Path -Path (Join-Path $PSScriptRoot '..\..')).Path
        $script:lintScript = Join-Path $script:repoRoot 'Tooling\Test-VipPrereleaseRequirementsV1.ps1'
        if (-not (Test-Path -Path $script:lintScript)) {
            throw "Lint script not found at $script:lintScript"
        }

        $script:sourceRequirements = Join-Path $script:repoRoot 'docs\vip-prerelease-requirements.md'
        $script:sourceAcceptance = Join-Path $script:repoRoot 'docs\vip-prerelease-requirements-v1-acceptance.md'
        $script:sourceTrace = Join-Path $script:repoRoot 'docs\vip-prerelease-requirements-v0-to-v1-trace.md'
        $script:sourceWorkflow = Join-Path $script:repoRoot '.github\workflows\ci-composite.yml'
        $script:sourceComputeAction = Join-Path $script:repoRoot '.github\actions\compute-version\action.yml'
    }

    function script:New-VipRequirementsFixtureRepo {
        $root = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        New-Item -Path (Join-Path $root 'docs') -ItemType Directory -Force | Out-Null
        New-Item -Path (Join-Path $root '.github\workflows') -ItemType Directory -Force | Out-Null
        New-Item -Path (Join-Path $root '.github\actions\compute-version') -ItemType Directory -Force | Out-Null
        New-Item -Path (Join-Path $root 'builds\status') -ItemType Directory -Force | Out-Null

        Copy-Item -Path $script:sourceRequirements -Destination (Join-Path $root 'docs\vip-prerelease-requirements.md') -Force
        Copy-Item -Path $script:sourceAcceptance -Destination (Join-Path $root 'docs\vip-prerelease-requirements-v1-acceptance.md') -Force
        Copy-Item -Path $script:sourceTrace -Destination (Join-Path $root 'docs\vip-prerelease-requirements-v0-to-v1-trace.md') -Force
        Copy-Item -Path $script:sourceWorkflow -Destination (Join-Path $root '.github\workflows\ci-composite.yml') -Force
        Copy-Item -Path $script:sourceComputeAction -Destination (Join-Path $root '.github\actions\compute-version\action.yml') -Force

        return $root
    }

    function script:Invoke-LintExpectFail {
        param(
            [Parameter(Mandatory = $true)]
            [string]$RepoRoot
        )

        $statusPath = Join-Path $RepoRoot 'builds\status\vip-prerelease-requirements-lint.json'
        $threw = $false
        try {
            & $script:lintScript -RepoRoot $RepoRoot -StatusOutputPath $statusPath
        } catch {
            $threw = $true
        }

        $threw | Should -BeTrue
        (Test-Path -Path $statusPath) | Should -BeTrue
        $status = Get-Content -Raw -Path $statusPath | ConvertFrom-Json
        $status.status | Should -Be 'fail'
        return $status
    }

    It 'passes on current repository docs and interface contracts' {
        $statusPath = Join-Path $TestDrive 'vip-prerelease-lint-pass.json'
        { & $script:lintScript -RepoRoot $script:repoRoot -StatusOutputPath $statusPath } | Should -Not -Throw
        (Test-Path -Path $statusPath) | Should -BeTrue
        $status = Get-Content -Raw -Path $statusPath | ConvertFrom-Json
        $status.status | Should -Be 'pass'
    }

    It 'fails when duplicate VR IDs are introduced' {
        $fixtureRoot = New-VipRequirementsFixtureRepo
        $requirementsPath = Join-Path $fixtureRoot 'docs\vip-prerelease-requirements.md'
        $duplicateLine = Get-Content -Path $requirementsPath | Where-Object { $_ -match '^VR-SCOPE-001:' } | Select-Object -First 1
        Add-Content -Path $requirementsPath -Value $duplicateLine

        $status = Invoke-LintExpectFail -RepoRoot $fixtureRoot
        ($status.findings | Where-Object { $_.message -match 'Duplicate requirement ID detected' }).Count | Should -BeGreaterThan 0
    }

    It 'fails when requirement numbering is non-monotonic within a family' {
        $fixtureRoot = New-VipRequirementsFixtureRepo
        $requirementsPath = Join-Path $fixtureRoot 'docs\vip-prerelease-requirements.md'
        $content = Get-Content -Raw -Path $requirementsPath
        $content = $content -replace 'VR-PUR-006:', 'VR-PUR-000:'
        Set-Content -Path $requirementsPath -Value $content -Encoding ascii

        $status = Invoke-LintExpectFail -RepoRoot $fixtureRoot
        ($status.findings | Where-Object { $_.message -match 'Non-monotonic requirement ordering' }).Count | Should -BeGreaterThan 0
    }

    It 'fails when acceptance and trace mappings are missing for a requirement ID' {
        $fixtureRoot = New-VipRequirementsFixtureRepo
        $acceptancePath = Join-Path $fixtureRoot 'docs\vip-prerelease-requirements-v1-acceptance.md'
        $tracePath = Join-Path $fixtureRoot 'docs\vip-prerelease-requirements-v0-to-v1-trace.md'

        $acceptanceContent = Get-Content -Raw -Path $acceptancePath
        $acceptanceContent = $acceptanceContent -replace 'VR-SEC-001, VR-SEC-002, VR-SEC-003', 'VR-SEC-001, VR-SEC-002'
        Set-Content -Path $acceptancePath -Value $acceptanceContent -Encoding ascii

        $traceContent = Get-Content -Raw -Path $tracePath
        $traceContent = $traceContent -replace 'VR-SEC-001, VR-SEC-002, VR-SEC-003, ', 'VR-SEC-001, VR-SEC-002, '
        Set-Content -Path $tracePath -Value $traceContent -Encoding ascii

        $status = Invoke-LintExpectFail -RepoRoot $fixtureRoot
        ($status.findings | Where-Object { $_.message -match 'Requirement ID missing from acceptance matrix: VR-SEC-003' }).Count | Should -BeGreaterThan 0
        ($status.findings | Where-Object { $_.message -match 'Requirement ID missing from trace matrix: VR-SEC-003' }).Count | Should -BeGreaterThan 0
    }
}
