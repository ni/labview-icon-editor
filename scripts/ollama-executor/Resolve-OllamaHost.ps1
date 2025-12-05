[CmdletBinding()]
param()

function Test-OllamaEndpoint {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Endpoint,
        [int]$TimeoutSec = 5
    )

    $uri = "$($Endpoint.TrimEnd('/'))/api/tags"
    try {
        $response = Invoke-RestMethod -Uri $uri -Method Get -TimeoutSec $TimeoutSec
    }
    catch {
        return $false
    }

    if ($response -and $response.models) {
        return $true
    }

    return $false
}

function Resolve-OllamaHost {
    [CmdletBinding()]
    param(
        [string]$RequestedHost,
        [string[]]$FallbackHosts = @("http://localhost:11436", "http://host.docker.internal:11435", "http://localhost:11435")
    )

    $candidates = @()
    if (-not [string]::IsNullOrWhiteSpace($RequestedHost)) {
        $candidates += $RequestedHost
    }

    foreach ($fallbackHost in $FallbackHosts) {
        if ([string]::IsNullOrWhiteSpace($fallbackHost)) { continue }
        if ($candidates -contains $fallbackHost) { continue }
        $candidates += $fallbackHost
    }

    foreach ($candidate in $candidates) {
        Write-Verbose "[ollama-resolver] Probing $candidate"
        if (Test-OllamaEndpoint -Endpoint $candidate) {
            return $candidate
        }
    }

    $list = if ($candidates.Count -gt 0) { $candidates -join ', ' } else { '<none>' }
    throw "Unable to reach any Ollama host. Tried: $list"
}
