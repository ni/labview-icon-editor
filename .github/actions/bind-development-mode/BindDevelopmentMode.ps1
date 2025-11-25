[CmdletBinding()]
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [object[]]$Args
)

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..\..')
$scriptPath = Join-Path $repoRoot 'scripts/bind-development-mode/BindDevelopmentMode.ps1'

if (-not (Test-Path -LiteralPath $scriptPath)) {
    throw "Missing bind script: $scriptPath"
}

& $scriptPath @Args
