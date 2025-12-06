param(
    [Parameter(Mandatory)][string]$Repo,
    [Parameter(Mandatory)][string]$Token
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Invoke-GH {
    param([string]$GhArgs)
    $p = Start-Process -FilePath gh -ArgumentList $GhArgs -NoNewWindow -PassThru -Wait -RedirectStandardOutput stdout.tmp -RedirectStandardError stderr.tmp
    $out = Get-Content stdout.tmp -Raw -ErrorAction SilentlyContinue
    $err = Get-Content stderr.tmp -Raw -ErrorAction SilentlyContinue
    Remove-Item stdout.tmp, stderr.tmp -ErrorAction SilentlyContinue
    if ($p.ExitCode -ne 0) {
        throw "gh exit $($p.ExitCode): $err"
    }
    return $out
}

if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    throw "GitHub CLI (gh) not found in PATH."
}

$env:GH_TOKEN = $Token
$env:GH_REPO  = $Repo

# Fetch collaborators with their permissions
$json = Invoke-GH "api repos/$Repo/collaborators --paginate"
$data = $json | ConvertFrom-Json

$result = @()
foreach ($c in $data) {
    $name = if ($c.PSObject.Properties.Name -contains 'name' -and $c.name) { $c.name } else { '' }
    $perm = 'unknown'
    if ($c.PSObject.Properties.Name -contains 'permissions' -and $c.permissions) {
        $perm = ($c.permissions.PSObject.Properties | Where-Object { $_.Value }) | Select-Object -ExpandProperty Name -First 1
        if (-not $perm) { $perm = 'unknown' }
    }
    $result += [pscustomobject]@{
        login       = $c.login
        name        = $name
        permission  = $perm
        two_factor  = if ($c.PSObject.Properties.Name -contains 'two_factor_authentication') { $c.two_factor_authentication } else { $null }
        site_admin  = if ($c.PSObject.Properties.Name -contains 'site_admin') { $c.site_admin } else { $null }
    }
}

$result | ConvertTo-Json -Depth 4 | Out-File -FilePath "collaborators.json" -Encoding utf8
Write-Host "Collaborators report written to collaborators.json"
