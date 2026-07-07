#Requires -Version 7.0
#Requires -Modules Pester

<#
.SYNOPSIS
    Pester tests for runner contract parsing, validation, and label normalization.

.DESCRIPTION
    Covers:
      - RunnerContract.ps1 helper functions (load, save, path resolution)
      - Validate-RunnerContract.ps1 contract validation
      - Label set normalization (Initialize-Runner.ps1 logic)
      - Path normalization
#>

BeforeAll {
    $Script:ToolingRoot   = Split-Path -Parent $PSScriptRoot
    $Script:ContractHelper = Join-Path $Script:ToolingRoot 'support' 'RunnerContract.ps1'
    $Script:TemplatePath   = Join-Path $Script:ToolingRoot 'runner-contract.template.json'

    # Dot-source the contract helper so its functions are available
    . $Script:ContractHelper
}

# ---------------------------------------------------------------------------
# 1. Contract Template
# ---------------------------------------------------------------------------
Describe 'Contract Template' {

    It 'template file exists' {
        $Script:TemplatePath | Should -Exist
    }

    It 'template is valid JSON with required fields' {
        $json = Get-Content -Raw -Path $Script:TemplatePath | ConvertFrom-Json
        $json.version              | Should -BeOfType [long]
        $json.runner_root          | Should -Not -BeNullOrEmpty
        $json.work_root            | Should -Not -BeNullOrEmpty
        $json.worktree_root        | Should -Not -BeNullOrEmpty
        $json.artifact_root        | Should -Not -BeNullOrEmpty
        $json.lock_root            | Should -Not -BeNullOrEmpty
        $json.log_root             | Should -Not -BeNullOrEmpty
        $json.runner_label         | Should -Not -BeNullOrEmpty
        $json.runner_labels        | Should -Not -BeNullOrEmpty
        $json.canonical_runner_label | Should -Not -BeNullOrEmpty
        $json.updated_at_utc       | Should -Not -BeNullOrEmpty
        $json.created_at_utc       | Should -Not -BeNullOrEmpty
    }

    It 'runner_labels is an array with string elements' {
        $json = Get-Content -Raw -Path $Script:TemplatePath | ConvertFrom-Json
        $json.runner_labels.Count | Should -BeGreaterOrEqual 1
        $json.runner_labels | Should -BeOfType [string]
    }

    It 'version is 1' {
        $json = Get-Content -Raw -Path $Script:TemplatePath | ConvertFrom-Json
        $json.version | Should -Be 1
    }
}

# ---------------------------------------------------------------------------
# 2. Set-RunnerContract / Get-RunnerContract  (round-trip)
# ---------------------------------------------------------------------------
Describe 'Set-RunnerContract and Get-RunnerContract' {

    BeforeEach {
        $Script:TempDir = Join-Path ([System.IO.Path]::GetTempPath()) "lvie-test-$([guid]::NewGuid().ToString('N'))"
        New-Item -Path $Script:TempDir -ItemType Directory -Force | Out-Null
        $Script:ContractFile = Join-Path $Script:TempDir 'runner-contract.json'
    }

    AfterEach {
        if (Test-Path $Script:TempDir) {
            Remove-Item -Path $Script:TempDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'writes and reads back a contract with all fields intact' {
        $contract = [pscustomobject]@{
            version               = 1
            runner_root           = $Script:TempDir
            work_root             = $Script:TempDir
            worktree_root         = (Join-Path $Script:TempDir 'w')
            artifact_root         = (Join-Path $Script:TempDir 'artifacts')
            lock_root             = (Join-Path $Script:TempDir 'locks')
            log_root              = (Join-Path $Script:TempDir 'logs')
            runner_label          = 'test-label'
            runner_labels         = @('test-label', 'extra')
            canonical_runner_label = 'test-label'
            updated_at_utc        = '2025-01-01T00:00:00Z'
            created_at_utc        = '2025-01-01T00:00:00Z'
        }

        Set-RunnerContract -ContractPath $Script:ContractFile -Contract $contract
        $Script:ContractFile | Should -Exist

        $loaded = Get-RunnerContract -ContractPath $Script:ContractFile
        $loaded.version        | Should -Be 1
        $loaded.runner_root    | Should -Be $Script:TempDir
        $loaded.runner_label   | Should -Be 'test-label'
        $loaded.runner_labels  | Should -Contain 'test-label'
        $loaded.runner_labels  | Should -Contain 'extra'
        $loaded.canonical_runner_label | Should -Be 'test-label'
    }

    It 'creates parent directory when it does not exist' {
        $nested = Join-Path $Script:TempDir 'sub' 'dir' 'runner-contract.json'
        $contract = [pscustomobject]@{
            version    = 1
            runner_root = $Script:TempDir
        }

        Set-RunnerContract -ContractPath $nested -Contract $contract
        $nested | Should -Exist
    }

    It 'Get-RunnerContract returns null for non-existent path' {
        $result = Get-RunnerContract -ContractPath (Join-Path $Script:TempDir 'nope.json')
        $result | Should -BeNullOrEmpty
    }

    It 'Get-RunnerContract returns null for invalid JSON' {
        $badFile = Join-Path $Script:TempDir 'bad.json'
        'not json at all' | Set-Content -Path $badFile
        $result = Get-RunnerContract -ContractPath $badFile
        $result | Should -BeNullOrEmpty
    }
}

# ---------------------------------------------------------------------------
# 3. Resolve-RunnerWorkRoot
# ---------------------------------------------------------------------------
Describe 'Resolve-RunnerWorkRoot' {

    BeforeEach {
        # Save and clear env vars that the function reads
        $Script:SavedRunnerWorkspace  = $env:RUNNER_WORKSPACE
        $Script:SavedGitHubWorkspace  = $env:GITHUB_WORKSPACE
        $env:RUNNER_WORKSPACE = $null
        $env:GITHUB_WORKSPACE = $null
    }

    AfterEach {
        $env:RUNNER_WORKSPACE = $Script:SavedRunnerWorkspace
        $env:GITHUB_WORKSPACE = $Script:SavedGitHubWorkspace
    }

    It 'prefers explicit WorkRoot parameter' {
        $result = Resolve-RunnerWorkRoot -WorkRoot '/my/work' -RunnerRoot '/runner'
        $result | Should -Be '/my/work'
    }

    It 'falls back to RUNNER_WORKSPACE env var' {
        $env:RUNNER_WORKSPACE = '/env/workspace'
        $result = Resolve-RunnerWorkRoot -WorkRoot '' -RunnerRoot ''
        $result | Should -Be '/env/workspace'
    }

    It 'derives from GITHUB_WORKSPACE (grandparent)' {
        $env:GITHUB_WORKSPACE = '/actions-runner/_work/repo/repo'
        $result = Resolve-RunnerWorkRoot -WorkRoot '' -RunnerRoot ''
        $result | Should -Be '/actions-runner/_work'
    }

    It 'appends _work to RunnerRoot when leaf is not _work' {
        $result = Resolve-RunnerWorkRoot -WorkRoot '' -RunnerRoot '/runner'
        $result | Should -Be '/runner/_work'
    }

    It 'returns RunnerRoot as-is when leaf is _work' {
        $result = Resolve-RunnerWorkRoot -WorkRoot '' -RunnerRoot '/runner/_work'
        $result | Should -Be '/runner/_work'
    }

    It 'returns null when nothing is available' {
        $result = Resolve-RunnerWorkRoot -WorkRoot '' -RunnerRoot ''
        $result | Should -BeNullOrEmpty
    }
}

# ---------------------------------------------------------------------------
# 4. Resolve-RunnerContractPath
# ---------------------------------------------------------------------------
Describe 'Resolve-RunnerContractPath' {

    BeforeEach {
        $Script:SavedContractEnv = $env:LVIE_RUNNER_CONTRACT_PATH
        $Script:SavedRunnerWorkspace = $env:RUNNER_WORKSPACE
        $Script:SavedGitHubWorkspace = $env:GITHUB_WORKSPACE
        $env:LVIE_RUNNER_CONTRACT_PATH = $null
        $env:RUNNER_WORKSPACE = $null
        $env:GITHUB_WORKSPACE = $null
    }

    AfterEach {
        $env:LVIE_RUNNER_CONTRACT_PATH = $Script:SavedContractEnv
        $env:RUNNER_WORKSPACE = $Script:SavedRunnerWorkspace
        $env:GITHUB_WORKSPACE = $Script:SavedGitHubWorkspace
    }

    It 'prefers explicit ContractPath parameter' {
        $result = Resolve-RunnerContractPath -ContractPath '/my/contract.json'
        $result | Should -Be '/my/contract.json'
    }

    It 'falls back to LVIE_RUNNER_CONTRACT_PATH env var' {
        $env:LVIE_RUNNER_CONTRACT_PATH = '/env/contract.json'
        $result = Resolve-RunnerContractPath
        $result | Should -Be '/env/contract.json'
    }

    It 'derives from WorkRoot' {
        $result = Resolve-RunnerContractPath -WorkRoot '/actions-runner/_work'
        # On Linux the path separator is /
        $expected = Join-Path '/actions-runner/_work' 'lvie' 'runner-contract.json'
        $result | Should -Be $expected
    }

    It 'returns null when nothing is available' {
        $result = Resolve-RunnerContractPath
        $result | Should -BeNullOrEmpty
    }
}

# ---------------------------------------------------------------------------
# 5. Validate-RunnerContract.ps1  (script-level validation)
# ---------------------------------------------------------------------------
Describe 'Validate-RunnerContract.ps1' {

    BeforeAll {
        $Script:ValidateScript = Join-Path $Script:ToolingRoot 'Validate-RunnerContract.ps1'
    }

    BeforeEach {
        $Script:TempDir = Join-Path ([System.IO.Path]::GetTempPath()) "lvie-val-$([guid]::NewGuid().ToString('N'))"
        New-Item -Path $Script:TempDir -ItemType Directory -Force | Out-Null

        # Create required subdirectories
        $Script:Dirs = @{
            runner_root   = (Join-Path $Script:TempDir 'runner')
            work_root     = (Join-Path $Script:TempDir 'work')
            worktree_root = (Join-Path $Script:TempDir 'worktree')
            artifact_root = (Join-Path $Script:TempDir 'artifacts')
            lock_root     = (Join-Path $Script:TempDir 'locks')
            log_root      = (Join-Path $Script:TempDir 'logs')
        }
        $Script:Dirs.Values | ForEach-Object { New-Item -Path $_ -ItemType Directory -Force | Out-Null }

        $Script:ContractFile = Join-Path $Script:TempDir 'contract.json'
    }

    AfterEach {
        if (Test-Path $Script:TempDir) {
            Remove-Item -Path $Script:TempDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'throws when contract path is not provided and env var is unset' {
        $saved = $env:LVIE_RUNNER_CONTRACT_PATH
        $env:LVIE_RUNNER_CONTRACT_PATH = $null
        try {
            { & $Script:ValidateScript -ContractPath '' } | Should -Throw '*not provided*'
        } finally {
            $env:LVIE_RUNNER_CONTRACT_PATH = $saved
        }
    }

    It 'throws when contract file does not exist' {
        { & $Script:ValidateScript -ContractPath (Join-Path $Script:TempDir 'missing.json') } | Should -Throw '*not found*'
    }

    It 'throws when a required directory is missing' {
        $contract = @{
            version       = 1
            runner_root   = $Script:Dirs.runner_root
            work_root     = $Script:Dirs.work_root
            worktree_root = (Join-Path $Script:TempDir 'does-not-exist')
            artifact_root = $Script:Dirs.artifact_root
            lock_root     = $Script:Dirs.lock_root
            log_root      = $Script:Dirs.log_root
        }
        $contract | ConvertTo-Json | Set-Content -Path $Script:ContractFile

        { & $Script:ValidateScript -ContractPath $Script:ContractFile } | Should -Throw '*not found*worktree_root*'
    }

    It 'throws when a required field is empty' {
        $contract = @{
            version       = 1
            runner_root   = ''
            work_root     = $Script:Dirs.work_root
            worktree_root = $Script:Dirs.worktree_root
            artifact_root = $Script:Dirs.artifact_root
            lock_root     = $Script:Dirs.lock_root
            log_root      = $Script:Dirs.log_root
        }
        $contract | ConvertTo-Json | Set-Content -Path $Script:ContractFile

        { & $Script:ValidateScript -ContractPath $Script:ContractFile } | Should -Throw '*missing*runner_root*'
    }

    It 'succeeds when all directories exist (safe.directory warning only)' {
        $contract = @{
            version       = 1
            runner_root   = $Script:Dirs.runner_root
            work_root     = $Script:Dirs.work_root
            worktree_root = $Script:Dirs.worktree_root
            artifact_root = $Script:Dirs.artifact_root
            lock_root     = $Script:Dirs.lock_root
            log_root      = $Script:Dirs.log_root
        }
        $contract | ConvertTo-Json | Set-Content -Path $Script:ContractFile

        { & $Script:ValidateScript -ContractPath $Script:ContractFile -FailOnMissingSafeDirectory:$false } | Should -Not -Throw
    }
}

# ---------------------------------------------------------------------------
# 6. Label set normalization
# ---------------------------------------------------------------------------
Describe 'Label set normalization' {

    It 'deduplicates and trims labels' {
        $raw = @('  label-a ', 'label-b', 'label-a', '', '  ', 'label-c')
        $normalized = $raw | ForEach-Object { $_.Trim() } | Where-Object { $_ } | Select-Object -Unique
        $normalized | Should -HaveCount 3
        $normalized | Should -Contain 'label-a'
        $normalized | Should -Contain 'label-b'
        $normalized | Should -Contain 'label-c'
    }

    It 'parses comma-separated label string' {
        $value = 'label-a, label-b , label-c'
        $parsed = $value -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ }
        $parsed | Should -HaveCount 3
        $parsed[0] | Should -Be 'label-a'
        $parsed[1] | Should -Be 'label-b'
        $parsed[2] | Should -Be 'label-c'
    }

    It 'returns empty array from empty or whitespace string' {
        $value = '   '
        $parsed = $value -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ }
        $parsed | Should -HaveCount 0
    }

    It 'case-insensitive label matching works' {
        $expected = @('Self-Hosted-Windows-LV')
        $actual   = @('self-hosted-windows-lv')
        $expectedNorm = $expected | ForEach-Object { $_.Trim().ToLowerInvariant() }
        $actualNorm   = $actual   | ForEach-Object { $_.Trim().ToLowerInvariant() }
        $missing = $expectedNorm | Where-Object { $actualNorm -notcontains $_ }
        $missing | Should -HaveCount 0
    }
}

# ---------------------------------------------------------------------------
# 7. Path normalization (mirrors Initialize-Runner.ps1 logic)
# ---------------------------------------------------------------------------
Describe 'Path normalization' {

    BeforeAll {
        function Resolve-NormalizedPath {
            param([string]$Path)
            if ([string]::IsNullOrWhiteSpace($Path)) { return $Path }
            $full = [System.IO.Path]::GetFullPath($Path)
            if ($full.Length -gt 3 -and $full.EndsWith([System.IO.Path]::DirectorySeparatorChar)) {
                $full = $full.TrimEnd([System.IO.Path]::DirectorySeparatorChar)
            }
            return $full
        }
    }

    It 'removes trailing separator from long paths' {
        $result = Resolve-NormalizedPath -Path '/tmp/some/path/'
        $result | Should -Not -Match '/$'
    }

    It 'preserves root paths' {
        $result = Resolve-NormalizedPath -Path '/'
        $result | Should -Be '/'
    }

    It 'returns input for null or whitespace' {
        $result = Resolve-NormalizedPath -Path ''
        $result | Should -BeNullOrEmpty
        # Whitespace-only strings pass the IsNullOrWhiteSpace check and are returned as-is
        $result2 = Resolve-NormalizedPath -Path '   '
        $result2 | Should -Be '   '
    }

    It 'resolves relative paths to absolute' {
        $result = Resolve-NormalizedPath -Path 'relative/path'
        [System.IO.Path]::IsPathRooted($result) | Should -BeTrue
    }
}

# ---------------------------------------------------------------------------
# 8. Set-RunnerContractEnvironment
# ---------------------------------------------------------------------------
Describe 'Set-RunnerContractEnvironment' {

    BeforeEach {
        # Save current env vars
        $Script:SavedEnvVars = @{
            LVIE_RUNNER_ROOT          = $env:LVIE_RUNNER_ROOT
            LVIE_RUNNER_WORK_ROOT     = $env:LVIE_RUNNER_WORK_ROOT
            LVIE_WORKTREE_ROOT        = $env:LVIE_WORKTREE_ROOT
            LVIE_ARTIFACT_ROOT        = $env:LVIE_ARTIFACT_ROOT
            LVIE_LOCK_ROOT            = $env:LVIE_LOCK_ROOT
            LVIE_LOG_ROOT             = $env:LVIE_LOG_ROOT
            LVIE_RUNNER_LABEL         = $env:LVIE_RUNNER_LABEL
            LVIE_RUNNER_LABELS        = $env:LVIE_RUNNER_LABELS
            LVIE_CANONICAL_RUNNER_LABEL = $env:LVIE_CANONICAL_RUNNER_LABEL
            LVIE_RUNNER_CONTRACT_PATH = $env:LVIE_RUNNER_CONTRACT_PATH
        }
        # Clear them
        $Script:SavedEnvVars.Keys | ForEach-Object { Remove-Item "env:$_" -ErrorAction SilentlyContinue }
    }

    AfterEach {
        $Script:SavedEnvVars.GetEnumerator() | ForEach-Object {
            Set-Item "env:$($_.Key)" $_.Value
        }
    }

    It 'sets environment variables from contract when they are empty' {
        $contract = [pscustomobject]@{
            runner_root           = '/runner'
            work_root             = '/work'
            worktree_root         = '/worktree'
            artifact_root         = '/artifacts'
            lock_root             = '/locks'
            log_root              = '/logs'
            runner_label          = 'my-label'
            runner_labels         = @('my-label', 'extra')
            canonical_runner_label = 'my-label'
        }

        Set-RunnerContractEnvironment -Contract $contract -ContractPath '/contract.json'

        $env:LVIE_RUNNER_ROOT          | Should -Be '/runner'
        $env:LVIE_RUNNER_WORK_ROOT     | Should -Be '/work'
        $env:LVIE_WORKTREE_ROOT        | Should -Be '/worktree'
        $env:LVIE_ARTIFACT_ROOT        | Should -Be '/artifacts'
        $env:LVIE_LOCK_ROOT            | Should -Be '/locks'
        $env:LVIE_LOG_ROOT             | Should -Be '/logs'
        $env:LVIE_RUNNER_LABEL         | Should -Be 'my-label'
        $env:LVIE_RUNNER_LABELS        | Should -Be 'my-label,extra'
        $env:LVIE_CANONICAL_RUNNER_LABEL | Should -Be 'my-label'
        $env:LVIE_RUNNER_CONTRACT_PATH | Should -Be '/contract.json'
    }

    It 'does not overwrite existing environment variables' {
        $env:LVIE_RUNNER_ROOT = '/existing'
        $contract = [pscustomobject]@{
            runner_root = '/new'
        }

        Set-RunnerContractEnvironment -Contract $contract
        $env:LVIE_RUNNER_ROOT | Should -Be '/existing'
    }

    It 'handles null contract gracefully' {
        { Set-RunnerContractEnvironment -Contract $null } | Should -Not -Throw
    }
}
