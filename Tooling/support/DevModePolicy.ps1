#Requires -Version 7.0

function Get-DevModePolicyBlockedInvocationList {
    return @(
        '.github/actions/set-development-mode/Set_Development_Mode.ps1',
        '.github/actions/revert-development-mode/RevertDevelopmentMode.ps1',
        'Tooling/Toggle-DevMode.ps1',
        'Tooling/Set-DevelopmentMode-NoLabVIEW.ps1',
        'Tooling/Revert-DevelopmentMode-NoLabVIEW.ps1',
        'Tooling/Invoke-DevModeNoLabVIEWSmoke.ps1'
    )
}

function Get-DevModePolicyMessage {
    param(
        [AllowNull()]
        [AllowEmptyString()]
        [string]$EntryPoint,

        [AllowNull()]
        [AllowEmptyCollection()]
        [string[]]$BlockedOptions
    )

    $entryPointName = if ([string]::IsNullOrWhiteSpace($EntryPoint)) {
        '<unknown>'
    } else {
        [System.IO.Path]::GetFileName($EntryPoint)
    }

    $blockedPaths = (Get-DevModePolicyBlockedInvocationList) -join ', '
    $message = "Dev mode invocation is disabled by repository policy. No automation flow may toggle dev mode via LabVIEW or filesystem/INI edits. Blocked invocation paths: $blockedPaths. Entry point: $entryPointName."

    if ($BlockedOptions -and $BlockedOptions.Count -gt 0) {
        $message += " Blocked options in this invocation: $($BlockedOptions -join ', ')."
    }

    return $message
}

function Assert-DevModeInvocationBlocked {
    param(
        [AllowNull()]
        [AllowEmptyString()]
        [string]$EntryPoint
    )

    throw (Get-DevModePolicyMessage -EntryPoint $EntryPoint)
}

function Assert-DevModePolicyParameterNotBound {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$BoundParameters,

        [Parameter(Mandatory = $true)]
        [string[]]$BlockedParameters,

        [AllowNull()]
        [AllowEmptyString()]
        [string]$EntryPoint
    )

    $blockedOptions = @(
        $BlockedParameters |
            Where-Object { $BoundParameters.ContainsKey($_) } |
            ForEach-Object { "-$_" }
    )

    if ($blockedOptions.Count -gt 0) {
        throw (Get-DevModePolicyMessage -EntryPoint $EntryPoint -BlockedOptions $blockedOptions)
    }
}
