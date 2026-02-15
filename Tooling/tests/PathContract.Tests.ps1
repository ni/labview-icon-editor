#Requires -Version 7.0
#Requires -Modules Pester

BeforeAll {
    $Script:ToolingRoot = Split-Path -Parent $PSScriptRoot
    $Script:PathContractScript = Join-Path $Script:ToolingRoot 'support\PathContract.ps1'
    $Script:PathContractGuardScript = Join-Path $Script:ToolingRoot 'Test-PathContract.ps1'
    . $Script:PathContractScript
}

Describe 'PathContract shell compatibility' {
    It 'does not declare file-scope #Requires -Version' {
        $content = Get-Content -LiteralPath $Script:PathContractScript -Raw
        $content | Should -Not -Match '^\s*#\s*requires\s+-version\b'
    }

    It 'can be dot-sourced in Windows PowerShell 5.1 when powershell.exe is available' -Skip:(-not (Get-Command powershell.exe -ErrorAction SilentlyContinue)) {
        $ps51Path = (Get-Command powershell.exe -ErrorAction Stop).Source
        $escapedPath = $Script:PathContractScript -replace "'", "''"
        $probeCommand = "& { . '$escapedPath'; 'PATH_CONTRACT_IMPORT_OK' }"
        $output = & $ps51Path -NoProfile -ExecutionPolicy Bypass -Command $probeCommand 2>&1

        $LASTEXITCODE | Should -Be 0
        (($output | ForEach-Object { $_.ToString() }) -join [Environment]::NewLine) | Should -Match 'PATH_CONTRACT_IMPORT_OK'
    }

    It 'fails the guard when PathContract contains #Requires -Version (synthetic regression)' {
        $tempRepo = Join-Path $TestDrive 'repo'
        $tempPathContractDir = Join-Path $tempRepo 'Tooling\support'
        New-Item -Path $tempPathContractDir -ItemType Directory -Force | Out-Null

        @(
            '#Requires -Version 7.0'
            '$ErrorActionPreference = ''Stop'''
            'function ConvertTo-LvieFullPath { param([string]$Path) return $Path }'
        ) | Set-Content -Path (Join-Path $tempPathContractDir 'PathContract.ps1') -Encoding utf8

        { & $Script:PathContractGuardScript -RepoRoot $tempRepo } | Should -Throw '*ScriptRequiresUnmatchedPSVersion*'
    }
}

Describe 'Resolve-LvieRepoRoot' {
    It 'prefers LVIE_REPO_ROOT over workspace and repo aliases' {
        $result = Resolve-LvieRepoRoot `
            -LvieRepoRoot 'C:\canonical\repo' `
            -WorkspaceRoot 'C:\workspace\alias' `
            -RepoRoot 'C:\repo\alias' `
            -DefaultRepoRoot 'C:\default\repo'

        $result.Path | Should -Be ([System.IO.Path]::GetFullPath('C:\canonical\repo'))
        $result.Source | Should -Be '$env:LVIE_REPO_ROOT'
    }

    It 'falls back to WORKSPACE_ROOT when canonical root is missing' {
        $result = Resolve-LvieRepoRoot `
            -LvieRepoRoot '' `
            -WorkspaceRoot 'C:\workspace\alias' `
            -RepoRoot 'C:\repo\alias' `
            -DefaultRepoRoot 'C:\default\repo'

        $result.Path | Should -Be ([System.IO.Path]::GetFullPath('C:\workspace\alias'))
        $result.Source | Should -Be '$env:WORKSPACE_ROOT or parameter:WorkspaceRoot'
    }
}

Describe 'Resolve-LvieProjectPath' {
    It 'prefers LVIE_PROJECT_PATH when provided' {
        $result = Resolve-LvieProjectPath `
            -LvieProjectPath 'C:\canonical\repo\custom.lvproj' `
            -ProjectPath 'C:\legacy\repo\legacy.lvproj' `
            -RepoRoot 'C:\canonical\repo' `
            -ProjectRelativePath 'lv_icon_editor.lvproj'

        $result.Path | Should -Be ([System.IO.Path]::GetFullPath('C:\canonical\repo\custom.lvproj'))
        $result.Source | Should -Be '$env:LVIE_PROJECT_PATH'
    }

    It 'derives project path from repo root and relative path when explicit project paths are missing' {
        $result = Resolve-LvieProjectPath `
            -LvieProjectPath '' `
            -ProjectPath '' `
            -RepoRoot 'C:\canonical\repo' `
            -ProjectRelativePath 'relative\project.lvproj'

        $result.Path | Should -Be ([System.IO.Path]::GetFullPath('C:\canonical\repo\relative\project.lvproj'))
        $result.RelativePath | Should -Be 'relative\project.lvproj'
        $result.Source | Should -Be '$env:LVIE_PROJECT_RELATIVE_PATH or default'
    }
}

Describe 'Join-LvieRepoPath' {
    It 'joins a relative path with repo root' {
        $result = Join-LvieRepoPath -RepoRoot 'C:\canonical\repo' -RelativePath 'Test\Templates'
        $result | Should -Be ([System.IO.Path]::GetFullPath('C:\canonical\repo\Test\Templates'))
    }

    It 'returns absolute path input unchanged' {
        $result = Join-LvieRepoPath -RepoRoot 'C:\canonical\repo' -RelativePath 'C:\absolute\path.txt'
        $result | Should -Be ([System.IO.Path]::GetFullPath('C:\absolute\path.txt'))
    }
}
