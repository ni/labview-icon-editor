[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Assert-DockerReady {
    param(
        [string]$Purpose = "Docker operation"
    )

    if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
        throw "Docker CLI not found on PATH. Install/start Docker Desktop and retry the $Purpose."
    }

    if ($IsLinux) {
        $sock = "/var/run/docker.sock"
        if (-not (Test-Path -LiteralPath $sock)) {
            throw "Docker socket '$sock' is missing. In the devcontainer, mount the host socket (-v /var/run/docker.sock:/var/run/docker.sock) and ensure Docker Desktop is running."
        }
    }

    $null = docker info --format '{{.ServerVersion}}' 2>$null
    if ($LASTEXITCODE -ne 0) {
        throw "Docker daemon is unreachable. Start Docker Desktop and confirm the socket/pipe is accessible before retrying the $Purpose."
    }
}
