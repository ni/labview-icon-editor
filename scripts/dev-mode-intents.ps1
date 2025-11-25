[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function ConvertTo-DevModeIntent {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Phrase
    )

    $prefix = [regex]::Match($Phrase, '^(?is)\s*(/devmode|agent:)\s+(?<rest>.+)$')
    if (-not $prefix.Success) { return @() }

    $rest = $prefix.Groups['rest'].Value
    $forceRequested = ($rest -match '(?i)\b(force|overwrite)\b')

    $segments = [regex]::Split($rest, '(?i)\band\b|,') | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    $intents = New-Object System.Collections.Generic.List[object]
    foreach ($segment in $segments) {
        $match = [regex]::Match($segment, '(?i)\b(?<mode>bind|unbind)\s+(?<year>20\d{2})\s+(?<bitness>32|64|both)[- ]?bit\b')
        if ($match.Success) {
            $intents.Add([pscustomobject]@{
                Mode           = $match.Groups['mode'].Value.ToLowerInvariant()
                Year           = $match.Groups['year'].Value
                Bitness        = $match.Groups['bitness'].Value.ToLowerInvariant()
                ForceRequested = $forceRequested
            })
        }
        if ($intents.Count -ge 3) { break }
    }

    return @($intents.ToArray())
}

function Get-DevModeIntentPlan {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][array]$Intents,
        [Parameter(Mandatory)][string]$RepositoryPath,
        [string]$SummaryPath
    )

    $repoPath = (Resolve-Path -LiteralPath $RepositoryPath).Path
    if (-not $SummaryPath) {
        $SummaryPath = Join-Path $repoPath 'reports/dev-mode-bind.json'
    }

    $summary = @()
    if (Test-Path -LiteralPath $SummaryPath) {
        try {
            $summary = @(Get-Content -LiteralPath $SummaryPath -Raw | ConvertFrom-Json)
        }
        catch {
            Write-Verbose ("Unable to parse summary at {0}: {1}" -f $SummaryPath, $_.Exception.Message)
            $summary = @()
        }
    }

    $plans = New-Object System.Collections.Generic.List[object]

    foreach ($intent in $Intents) {
        $bitTargets = if ($intent.Bitness -eq 'both') { @('32', '64') } else { @($intent.Bitness) }
        $bitTargets = @($bitTargets)
        $blocked = $false
        $skipCount = 0
        $reasons = New-Object System.Collections.Generic.List[string]

        foreach ($bit in $bitTargets) {
            $entry = $summary | Where-Object { "$($_.bitness)" -eq $bit } | Select-Object -First 1
            $current = if ($entry) { $entry.current_path } else { $null }
            $expected = if ($entry) { $entry.expected_path } else { $null }
            $status = if ($entry -and ($entry.PSObject.Properties.Name -contains 'status')) { $entry.status } else { $null }
            $message = if ($entry -and ($entry.PSObject.Properties.Name -contains 'message')) { $entry.message } else { $null }

            $expectedMismatch = (-not [string]::IsNullOrWhiteSpace($expected)) -and ($expected -ine $repoPath)
            $currentMatchesRepo = (-not [string]::IsNullOrWhiteSpace($current)) -and ($current -ieq $repoPath)
            $currentPointsElsewhere = (-not [string]::IsNullOrWhiteSpace($current)) -and ($current -ine $repoPath)
            $iniMissing = $status -eq 'skip' -and ($message -match '(?i)not found')

            if ($expectedMismatch) {
                $blocked = $true
                $reasons.Add("bitness $bit expected_path $expected does not match repo $repoPath")
                continue
            }
            if ($iniMissing) {
                $blocked = $true
                $reasons.Add("bitness $bit missing LabVIEW.ini entry; cannot proceed")
                continue
            }

            if ($intent.Mode -eq 'bind') {
                if ($currentMatchesRepo) {
                    $skipCount++
                    $reasons.Add("bitness $bit already bound")
                }
                elseif ($currentPointsElsewhere -and -not $intent.ForceRequested) {
                    $blocked = $true
                    $reasons.Add("bitness $bit points to $current; requires Force")
                }
            }
            else {
                if ($currentPointsElsewhere -and -not $intent.ForceRequested) {
                    $blocked = $true
                    $reasons.Add("bitness $bit points to $current; requires Force")
                }
                elseif ([string]::IsNullOrWhiteSpace($current)) {
                    $skipCount++
                    $reasons.Add("bitness $bit already unbound or missing")
                }
            }
        }

        $action = 'pending'
        if ($blocked) {
            $action = 'blocked'
        }
        elseif ($skipCount -eq $bitTargets.Count) {
            $action = 'skip'
        }

        $plans.Add([pscustomobject]@{
            Mode           = $intent.Mode
            Year           = $intent.Year
            Bitness        = $intent.Bitness
            BitnessTargets = $bitTargets
            ForceRequested = [bool]$intent.ForceRequested
            ForceApplied   = [bool]$intent.ForceRequested
            Action         = $action
            Reason         = ($reasons -join '; ')
            SummaryPath    = $SummaryPath
            RepositoryPath = $repoPath
        })
    }

    return @($plans.ToArray())
}

function Invoke-BindScript {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$BindScriptPath,
        [Parameter(Mandatory)][string]$RepositoryPath,
        [Parameter(Mandatory)]$Plan
    )

    $argsList = @(
        '-RepositoryPath', $RepositoryPath,
        '-Mode', $Plan.Mode,
        '-Bitness', $Plan.Bitness
    )
    if ($Plan.ForceApplied) { $argsList += '-Force' }

    & $BindScriptPath @argsList
}

function Invoke-DevModeIntents {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory)][string]$Phrase,
        [string]$RepositoryPath = (Get-Location).Path,
        [string]$SummaryPath,
        [string]$BindScriptPath = (Join-Path $PSScriptRoot 'bind-development-mode/BindDevelopmentMode.ps1')
    )

    $RepositoryPath = (Resolve-Path -LiteralPath $RepositoryPath).Path
    if (-not $SummaryPath) {
        $SummaryPath = Join-Path $RepositoryPath 'reports/dev-mode-bind.json'
    }

    $intents = ConvertTo-DevModeIntent -Phrase $Phrase
    if (-not $intents -or $intents.Count -eq 0) {
        throw "No dev-mode intents were parsed. Ensure the phrase starts with /devmode or agent: and contains bind|unbind YEAR BITNESS-bit."
    }

    $plans = Get-DevModeIntentPlan -Intents $intents -RepositoryPath $RepositoryPath -SummaryPath $SummaryPath
    $blocked = $plans | Where-Object { $_.Action -eq 'blocked' }
    if ($blocked) {
        $reason = ($blocked | ForEach-Object { $_.Reason } | Where-Object { $_ } | Select-Object -First 1)
        throw ("Blocked: {0}" -f $reason)
    }

    foreach ($plan in ($plans | Where-Object { $_.Action -eq 'pending' })) {
        $target = "{0} {1}-bit (year {2})" -f $plan.Mode, $plan.Bitness, $plan.Year
        $what = if ($plan.ForceApplied) { "run with Force using $BindScriptPath" } else { "run using $BindScriptPath" }
        if ($PSCmdlet.ShouldProcess($target, $what)) {
            Invoke-BindScript -BindScriptPath $BindScriptPath -RepositoryPath $RepositoryPath -Plan $plan
        }
    }

    return $plans
}
