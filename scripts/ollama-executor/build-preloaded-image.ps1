[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$BaseImage,

    [Parameter(Mandatory = $true)]
    [string]$PreloadedTag,

    [Parameter(Mandatory = $true)]
    [string]$ModelBundlePath,

    [string]$ImportTag = "llama3-8b-local",
    [string]$TargetTag = "llama3-8b-local",
    [string[]]$ExtraTags,
    [switch]$Push,
    [switch]$Force,
    [string]$BundleSha256,
    [switch]$SkipPullBase,
    [string]$CaCertPath,
    [string]$Memory,
    [string]$Cpus
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

. "$PSScriptRoot/ollama-common.ps1"
Assert-DockerReady -Purpose "build preloaded Ollama image"

if (-not (Test-Path -LiteralPath $ModelBundlePath)) {
    throw "Model bundle not found at '$ModelBundlePath'"
}
$ModelBundlePath = (Resolve-Path -LiteralPath $ModelBundlePath).Path

if ($BundleSha256) {
    $actualHash = (Get-FileHash -LiteralPath $ModelBundlePath -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actualHash -ne $BundleSha256.ToLowerInvariant()) {
        throw "Bundle hash mismatch. Expected $BundleSha256 but got $actualHash for $ModelBundlePath"
    }
}

$existingImg = docker images --format "{{.Repository}}:{{.Tag}}" | Where-Object { $_ -eq $PreloadedTag }
if ($existingImg -and -not $Force) {
    throw "PreloadedTag '$PreloadedTag' already exists locally. Re-run with -Force to overwrite."
}

if (-not $SkipPullBase) {
    Write-Host "Pulling base image $BaseImage"
    docker pull $BaseImage | Out-Null
}

$containerName = "ollama-preload"
docker rm -f $containerName 2>$null | Out-Null

Write-Host "Starting preload container from $BaseImage"
$runArgs = @("run", "-d", "--name", $containerName)
if ($Cpus) { $runArgs += @("--cpus", $Cpus) }
if ($Memory) { $runArgs += @("--memory", $Memory) }
if ($CaCertPath) {
    if (-not (Test-Path -LiteralPath $CaCertPath)) { throw "CA cert not found at '$CaCertPath'" }
    $runArgs += @("--volume", "$(Resolve-Path -LiteralPath $CaCertPath):/usr/local/share/ca-certificates/custom-ca.crt:ro")
}
$runArgs += @($BaseImage, "serve")
docker @runArgs | Out-Null

if ($CaCertPath) {
    Write-Host "Updating CA certificates inside container"
    docker exec $containerName update-ca-certificates | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "update-ca-certificates failed in container" }
}

try {
    $bundleName = Split-Path -Leaf $ModelBundlePath
    $containerBundle = "/tmp/$bundleName"
    Write-Host "Copying bundle into container: $bundleName"
    docker cp $ModelBundlePath "$containerName:$containerBundle" | Out-Null

    Write-Host "Importing bundle as $ImportTag"
    docker exec $containerName ollama import $containerBundle | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "ollama import failed (exit $LASTEXITCODE)"
    }
    if ($ImportTag -ne $TargetTag) {
        Write-Host "Retagging $ImportTag -> $TargetTag"
        docker exec $containerName ollama cp $ImportTag $TargetTag | Out-Null
        if ($LASTEXITCODE -ne 0) {
            throw "ollama cp failed while retagging $ImportTag -> $TargetTag (exit $LASTEXITCODE)"
        }
    }

    $list = docker exec $containerName ollama list 2>$null
    Write-Host "Models after import:" $list
    if (-not ($list -match [regex]::Escape($TargetTag))) {
        throw "Expected model tag '$TargetTag' not found after import."
    }

    Write-Host "Stopping preload container"
    docker stop $containerName | Out-Null

    Write-Host "Committing preloaded image to $PreloadedTag"
    docker commit $containerName $PreloadedTag | Out-Null
    foreach ($tag in ($ExtraTags | Where-Object { $_ })) {
        Write-Host "Tagging $PreloadedTag as $tag"
        docker tag $PreloadedTag $tag | Out-Null
    }

    # Verify in a fresh container to ensure the committed image has the tag
    Write-Host "Verifying committed image has model $TargetTag"
    $verifyOut = docker run --rm $PreloadedTag ollama list 2>$null
    if (-not ($verifyOut -match [regex]::Escape($TargetTag))) {
        throw "Verification failed: model '$TargetTag' not present in committed image."
    }

    if ($Push) {
        Write-Host "Pushing $PreloadedTag"
        docker push $PreloadedTag | Out-Null
        foreach ($tag in ($ExtraTags | Where-Object { $_ })) {
            Write-Host "Pushing $tag"
            docker push $tag | Out-Null
        }
    }
}
finally {
    docker rm -f $containerName 2>$null | Out-Null
}

Write-Host "Preloaded image ready: $PreloadedTag"
