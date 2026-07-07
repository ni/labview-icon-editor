$ErrorActionPreference = 'Stop'

Describe 'G-CLI runner helper' {
    BeforeAll {
        $script:repoRoot = Resolve-Path -Path (Join-Path $PSScriptRoot '..\..')
        $script:helperPath = Join-Path $script:repoRoot 'Tooling\support\GcliRunner.ps1'
        if (-not (Test-Path -Path $script:helperPath)) {
            throw "g-cli helper not found at $script:helperPath"
        }
        . $script:helperPath

        $script:pwshPath = (Get-Command pwsh -ErrorAction Stop).Source
    }

    It 'captures stdout and stderr separately' {
        $scriptArgs = @(
            '-NoProfile',
            '-Command',
            "[Console]::Out.WriteLine('stdout line'); [Console]::Error.WriteLine('stderr line'); exit 7"
        )

        $result = Invoke-GCliCommand -ExecutablePath $script:pwshPath -Arguments $scriptArgs

        $result.OutputLines | Should -Contain 'stdout line'
        $result.ErrorLines | Should -Contain 'stderr line'
        $result.ExitCode | Should -Be 7
        $result.TimedOut | Should -BeFalse
    }

    It 'marks the process as timed out when it exceeds the timeout' {
        $scriptArgs = @(
            '-NoProfile',
            '-Command',
            'Start-Sleep -Seconds 5'
        )

        $result = Invoke-GCliCommand -ExecutablePath $script:pwshPath -Arguments $scriptArgs -TimeoutMs 200

        $result.TimedOut | Should -BeTrue
    }
}

