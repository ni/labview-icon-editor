function Format-CommandValue {
    param([string]$Value)
    if ($null -eq $Value) { return "''" }
    if ($Value -match '^[A-Za-z0-9_./:\\-]+$') {
        return $Value
    }
    $escaped = $Value -replace "'", "''"
    return "'$escaped'"
}

function New-InvokeRepoCliCommandString {
    param(
        [Parameter(Mandatory = $true)][string]$CliName,
        [Parameter(Mandatory = $true)][string]$RepoRoot,
        [string[]]$CliArguments = @()
    )

    $parts = @(
        'pwsh',
        '-NoProfile',
        '-File',
        'scripts/common/invoke-repo-cli.ps1',
        '-CliName',
        (Format-CommandValue $CliName),
        '-RepoRoot',
        (Format-CommandValue $RepoRoot)
    )

    if ($CliArguments -and $CliArguments.Count -gt 0) {
        $json = ($CliArguments | ConvertTo-Json -Compress)
        $parts += '-CliArgsJson'
        $parts += (Format-CommandValue $json)
    }

    return [string]::Join(' ', $parts)
}
