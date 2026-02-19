#Requires -Version 7.0
#Requires -Modules Pester

$Script:CanRunWorktreeTests = $IsWindows -and $null -ne (Get-Command git -ErrorAction SilentlyContinue)

BeforeAll {
    $Script:ToolingRoot = Split-Path -Parent $PSScriptRoot
    $Script:ScriptPath = Join-Path $Script:ToolingRoot 'New-CIWorktreeForJob.ps1'
    $Script:RepoRoot = (Resolve-Path -Path (Join-Path $Script:ToolingRoot '..')).Path

    function Invoke-NewCiWorktreeForJob {
        param(
            [Parameter(Mandatory = $true)]
            [string]$Bitness,
            [Parameter(Mandatory = $true)]
            [string]$WorktreeRoot,
            [Parameter(Mandatory = $true)]
            [string]$RepoRoot,
            [string]$JobName,
            [string]$WorkflowIdentity,
            [string]$RunId,
            [string]$RunAttempt,
            [string]$Variant
        )

        $invokeArgs = @{
            Bitness = $Bitness
            WorktreeRoot = $WorktreeRoot
            RepoRoot = $RepoRoot
        }

        if (-not [string]::IsNullOrWhiteSpace($JobName)) {
            $invokeArgs.JobName = $JobName
        }
        if (-not [string]::IsNullOrWhiteSpace($WorkflowIdentity)) {
            $invokeArgs.WorkflowIdentity = $WorkflowIdentity
        }
        if (-not [string]::IsNullOrWhiteSpace($RunId)) {
            $invokeArgs.RunId = $RunId
        }
        if (-not [string]::IsNullOrWhiteSpace($RunAttempt)) {
            $invokeArgs.RunAttempt = $RunAttempt
        }
        if (-not [string]::IsNullOrWhiteSpace($Variant)) {
            $invokeArgs.Variant = $Variant
        }

        $output = & $Script:ScriptPath @invokeArgs
        $worktreePath = $output | Select-Object -Last 1
        if ([string]::IsNullOrWhiteSpace($worktreePath)) {
            throw "New-CIWorktreeForJob.ps1 did not return a worktree path."
        }

        return ([System.IO.Path]::GetFullPath([string]$worktreePath)).TrimEnd('\')
    }

    function Remove-WorktreeSafe {
        param(
            [string]$RepoRoot,
            [string]$WorktreePath
        )

        if ([string]::IsNullOrWhiteSpace($WorktreePath)) {
            return
        }

        & git -C $RepoRoot worktree remove --force $WorktreePath 2>$null | Out-Null
        & git -C $RepoRoot worktree prune 2>$null | Out-Null
        if (Test-Path -Path $WorktreePath) {
            Remove-Item -Path $WorktreePath -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

Describe 'New-CIWorktreeForJob.ps1' {
    It 'uses workflow identity in deterministic naming to avoid cross-workflow collisions' -Skip:(-not $Script:CanRunWorktreeTests) {
        $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("lvie-worktree-name-{0}" -f [guid]::NewGuid().ToString('N'))
        New-Item -Path $tempRoot -ItemType Directory -Force | Out-Null

        $pathA = $null
        $pathB = $null
        try {
            $common = @{
                Bitness = '64'
                WorktreeRoot = $tempRoot
                RepoRoot = $Script:RepoRoot
                JobName = 'collision-test-job'
                RunId = 'worktree-name-run'
                RunAttempt = '1'
            }
            $pathA = Invoke-NewCiWorktreeForJob @common -WorkflowIdentity 'workflow-a'
            $pathB = Invoke-NewCiWorktreeForJob @common -WorkflowIdentity 'workflow-b'

            $pathA | Should -Not -Be $pathB
            Test-Path -Path $pathA | Should -BeTrue
            Test-Path -Path $pathB | Should -BeTrue
        }
        finally {
            Remove-WorktreeSafe -RepoRoot $Script:RepoRoot -WorktreePath $pathA
            Remove-WorktreeSafe -RepoRoot $Script:RepoRoot -WorktreePath $pathB
            if (Test-Path -Path $tempRoot) {
                Remove-Item -Path $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }

    It 'recovers when target worktree is missing but still registered' -Skip:(-not $Script:CanRunWorktreeTests) {
        $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("lvie-worktree-stale-{0}" -f [guid]::NewGuid().ToString('N'))
        New-Item -Path $tempRoot -ItemType Directory -Force | Out-Null

        $worktreePath = $null
        try {
            $worktreeArgs = @{
                Bitness = '64'
                WorktreeRoot = $tempRoot
                RepoRoot = $Script:RepoRoot
                JobName = 'stale-registration-job'
                WorkflowIdentity = 'workflow-stale'
                RunId = 'stale-run'
                RunAttempt = '1'
            }

            $worktreePath = Invoke-NewCiWorktreeForJob @worktreeArgs
            Test-Path -Path $worktreePath | Should -BeTrue

            Remove-Item -Path $worktreePath -Recurse -Force -ErrorAction Stop
            Test-Path -Path $worktreePath | Should -BeFalse

            $worktreeListBefore = (& git -C $Script:RepoRoot worktree list --porcelain 2>$null) -join [Environment]::NewLine
            $expectedPathInGitOutput = $worktreePath -replace '\\', '/'
            $worktreeListBefore | Should -Match ([regex]::Escape($expectedPathInGitOutput))

            $worktreePath = Invoke-NewCiWorktreeForJob @worktreeArgs
            Test-Path -Path $worktreePath | Should -BeTrue
        }
        finally {
            Remove-WorktreeSafe -RepoRoot $Script:RepoRoot -WorktreePath $worktreePath
            if (Test-Path -Path $tempRoot) {
                Remove-Item -Path $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }

    It 'falls back to local workflow/run tokens when GitHub env vars are absent' -Skip:(-not $Script:CanRunWorktreeTests) {
        $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("lvie-worktree-local-{0}" -f [guid]::NewGuid().ToString('N'))
        New-Item -Path $tempRoot -ItemType Directory -Force | Out-Null

        $saved = @{
            GITHUB_WORKFLOW_REF = $env:GITHUB_WORKFLOW_REF
            GITHUB_WORKFLOW = $env:GITHUB_WORKFLOW
            GITHUB_RUN_ID = $env:GITHUB_RUN_ID
            GITHUB_RUN_ATTEMPT = $env:GITHUB_RUN_ATTEMPT
        }

        $worktreePath = $null
        try {
            $env:GITHUB_WORKFLOW_REF = $null
            $env:GITHUB_WORKFLOW = $null
            $env:GITHUB_RUN_ID = $null
            $env:GITHUB_RUN_ATTEMPT = $null

            $worktreePath = Invoke-NewCiWorktreeForJob `
                -Bitness '64' `
                -WorktreeRoot $tempRoot `
                -RepoRoot $Script:RepoRoot `
                -JobName 'fallback-local-job'

            $leaf = Split-Path -Path $worktreePath -Leaf
            $leaf | Should -Match '^ci-[0-9A-F]{8}-[0-9A-F]{8}-64-local-1$'
        }
        finally {
            $env:GITHUB_WORKFLOW_REF = $saved.GITHUB_WORKFLOW_REF
            $env:GITHUB_WORKFLOW = $saved.GITHUB_WORKFLOW
            $env:GITHUB_RUN_ID = $saved.GITHUB_RUN_ID
            $env:GITHUB_RUN_ATTEMPT = $saved.GITHUB_RUN_ATTEMPT
            Remove-WorktreeSafe -RepoRoot $Script:RepoRoot -WorktreePath $worktreePath
            if (Test-Path -Path $tempRoot) {
                Remove-Item -Path $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }
}
