#Requires -Version 7.0
[CmdletBinding()]
param(
    [string]$ArtifactsRoot = 'tests/results/_agent/icon-editor',
    [string]$GhTokenPath,
    [string]$ReleaseTag,
    [string]$ReleaseName,
    [switch]$SkipUpload
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$message = @'
[icon-editor] Publish-LocalArtifacts.ps1 has been retired.

Use the staged publish pipeline instead:
  1. tools/Stage-XCliArtifact.ps1
  2. tools/Test-XCliReleaseAsset.ps1
  3. tools/Promote-XCliArtifact.ps1
  4. tools/Upload-XCliArtifact.ps1

These steps are already wired into the VS Code tasks (Stage/Test/Promote/Upload)
and Invoke-XCliTestPlanScenario.ps1. Re-run your one-shot build, then call those
helpers to package and upload VIP/PPL artifacts.
'@

throw $message
