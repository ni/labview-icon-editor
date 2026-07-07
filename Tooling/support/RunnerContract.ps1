#Requires -Version 7.0

function Resolve-RunnerWorkRoot {
    param(
        [string]$RunnerRoot,
        [string]$WorkRoot
    )

    if (-not [string]::IsNullOrWhiteSpace($WorkRoot)) {
        return $WorkRoot
    }

    if (-not [string]::IsNullOrWhiteSpace($env:RUNNER_WORKSPACE)) {
        return $env:RUNNER_WORKSPACE
    }

    if (-not [string]::IsNullOrWhiteSpace($env:GITHUB_WORKSPACE)) {
        $root = Split-Path -Parent (Split-Path -Parent $env:GITHUB_WORKSPACE)
        if (-not [string]::IsNullOrWhiteSpace($root)) {
            return $root
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($RunnerRoot)) {
        if ((Split-Path -Leaf $RunnerRoot) -ieq '_work') {
            return $RunnerRoot
        }
        return (Join-Path $RunnerRoot '_work')
    }

    return $null
}

function Resolve-RunnerContractPath {
    param(
        [string]$ContractPath,
        [string]$RunnerRoot,
        [string]$WorkRoot
    )

    if (-not [string]::IsNullOrWhiteSpace($ContractPath)) {
        return $ContractPath
    }

    if (-not [string]::IsNullOrWhiteSpace($env:LVIE_RUNNER_CONTRACT_PATH)) {
        return $env:LVIE_RUNNER_CONTRACT_PATH
    }

    $workRoot = Resolve-RunnerWorkRoot -RunnerRoot $RunnerRoot -WorkRoot $WorkRoot
    if ([string]::IsNullOrWhiteSpace($workRoot)) {
        return $null
    }

    return (Join-Path $workRoot 'lvie\runner-contract.json')
}

function Get-RunnerContract {
    param(
        [string]$ContractPath,
        [string]$RunnerRoot,
        [string]$WorkRoot
    )

    $path = Resolve-RunnerContractPath -ContractPath $ContractPath -RunnerRoot $RunnerRoot -WorkRoot $WorkRoot
    if ([string]::IsNullOrWhiteSpace($path)) {
        return $null
    }
    if (-not (Test-Path -Path $path)) {
        return $null
    }

    try {
        return (Get-Content -Raw -Path $path | ConvertFrom-Json)
    } catch {
        Write-Warning ("Failed to read runner contract at {0}: {1}" -f $path, $_.Exception.Message)
        return $null
    }
}

function Set-RunnerContract {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ContractPath,
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Contract
    )

    $dir = Split-Path -Parent $ContractPath
    if (-not (Test-Path -Path $dir)) {
        New-Item -Path $dir -ItemType Directory -Force | Out-Null
    }

    $Contract | ConvertTo-Json -Depth 6 | Set-Content -Path $ContractPath -Encoding ascii
}

function Set-RunnerContractEnvironment {
    param(
        [pscustomobject]$Contract,
        [string]$ContractPath
    )

    if (-not $Contract) {
        return
    }

    if (-not [string]::IsNullOrWhiteSpace($Contract.runner_root) -and [string]::IsNullOrWhiteSpace($env:LVIE_RUNNER_ROOT)) {
        $env:LVIE_RUNNER_ROOT = $Contract.runner_root
    }
    if (-not [string]::IsNullOrWhiteSpace($Contract.work_root) -and [string]::IsNullOrWhiteSpace($env:LVIE_RUNNER_WORK_ROOT)) {
        $env:LVIE_RUNNER_WORK_ROOT = $Contract.work_root
    }
    if (-not [string]::IsNullOrWhiteSpace($Contract.worktree_root) -and [string]::IsNullOrWhiteSpace($env:LVIE_WORKTREE_ROOT)) {
        $env:LVIE_WORKTREE_ROOT = $Contract.worktree_root
    }
    if (-not [string]::IsNullOrWhiteSpace($Contract.artifact_root) -and [string]::IsNullOrWhiteSpace($env:LVIE_ARTIFACT_ROOT)) {
        $env:LVIE_ARTIFACT_ROOT = $Contract.artifact_root
    }
    if (-not [string]::IsNullOrWhiteSpace($Contract.lock_root) -and [string]::IsNullOrWhiteSpace($env:LVIE_LOCK_ROOT)) {
        $env:LVIE_LOCK_ROOT = $Contract.lock_root
    }
    if (-not [string]::IsNullOrWhiteSpace($Contract.log_root) -and [string]::IsNullOrWhiteSpace($env:LVIE_LOG_ROOT)) {
        $env:LVIE_LOG_ROOT = $Contract.log_root
    }
    if (-not [string]::IsNullOrWhiteSpace($Contract.runner_label) -and [string]::IsNullOrWhiteSpace($env:LVIE_RUNNER_LABEL)) {
        $env:LVIE_RUNNER_LABEL = $Contract.runner_label
    }
    if ($Contract.runner_labels -and [string]::IsNullOrWhiteSpace($env:LVIE_RUNNER_LABELS)) {
        $env:LVIE_RUNNER_LABELS = ($Contract.runner_labels -join ',')
    }
    if (-not [string]::IsNullOrWhiteSpace($Contract.canonical_runner_label) -and [string]::IsNullOrWhiteSpace($env:LVIE_CANONICAL_RUNNER_LABEL)) {
        $env:LVIE_CANONICAL_RUNNER_LABEL = $Contract.canonical_runner_label
    }
    if (-not [string]::IsNullOrWhiteSpace($ContractPath) -and [string]::IsNullOrWhiteSpace($env:LVIE_RUNNER_CONTRACT_PATH)) {
        $env:LVIE_RUNNER_CONTRACT_PATH = $ContractPath
    }
}
