# Example Usage:
# .\Applyvipc.ps1 -MinimumSupportedLVVersion "2021" -SupportedBitness "64" -RelativePath "C:\labview-icon-editor" -VIPCPath "Tooling\deployment\Dependencies.vipc" -VIP_LVVersion "2021"

param (
    [string]$MinimumSupportedLVVersion,
    [string]$VIP_LVVersion,
    [string]$SupportedBitness,
    [string]$RelativePath,
    [string]$VIPCPath
)

if ($VIP_LVVersion -eq "2021" -and $SupportedBitness -eq "64") {
    $VIP_LVVersion_A = "21.0 (64-bit)"
} elseif ($VIP_LVVersion -eq "2021" -and $SupportedBitness -eq "32") {
    $VIP_LVVersion_A = "21.0"
} elseif ($VIP_LVVersion -eq "2022" -and $SupportedBitness -eq "64") {
    $VIP_LVVersion_A = "22.3 (64-bit)"
} elseif ($VIP_LVVersion -eq "2022" -and $SupportedBitness -eq "32") {
    $VIP_LVVersion_A = "22.3"
} elseif ($VIP_LVVersion -eq "2023" -and $SupportedBitness -eq "64") {
    $VIP_LVVersion_A = "23.3 (64-bit)"
} elseif ($VIP_LVVersion -eq "2023" -and $SupportedBitness -eq "32") {
    $VIP_LVVersion_A = "23.3"
} elseif ($VIP_LVVersion -eq "2024" -and $SupportedBitness -eq "64") {
    $VIP_LVVersion_A = "24.3 (64-bit)"
} elseif ($VIP_LVVersion -eq "2024" -and $SupportedBitness -eq "32") {
    $VIP_LVVersion_A = "24.3"
} else {
    Write-Output "Unsupported VIP_LVVersion or SupportedBitness"
    exit 1
}

if ($MinimumSupportedLVVersion -eq "2021" -and $SupportedBitness -eq "64") {
    $VIP_LVVersion_B = "21.0 (64-bit)"
} elseif ($MinimumSupportedLVVersion -eq "2021" -and $SupportedBitness -eq "32") {
    $VIP_LVVersion_B = "21.0"
} elseif ($MinimumSupportedLVVersion -eq "2022" -and $SupportedBitness -eq "64") {
    $VIP_LVVersion_B = "22.3 (64-bit)"
} elseif ($MinimumSupportedLVVersion -eq "2022" -and $SupportedBitness -eq "32") {
    $VIP_LVVersion_B = "22.3"
} elseif ($MinimumSupportedLVVersion -eq "2023" -and $SupportedBitness -eq "64") {
    $VIP_LVVersion_B = "23.3 (64-bit)"
} elseif ($MinimumSupportedLVVersion -eq "2023" -and $SupportedBitness -eq "32") {
    $VIP_LVVersion_B = "23.3"
} elseif ($MinimumSupportedLVVersion -eq "2024" -and $SupportedBitness -eq "64") {
    $VIP_LVVersion_B = "24.3 (64-bit)"
} elseif ($MinimumSupportedLVVersion -eq "2024" -and $SupportedBitness -eq "32") {
    $VIP_LVVersion_B = "24.3"
} else {
    Write-Output "Unsupported MinimumSupportedLVVersion or SupportedBitness"
    exit 1
}

function Execute-GCLICommand {
    param (
        [string]$Command
    )

    Write-Output "Executing: $Command"
    Invoke-Expression $Command

    if ($LASTEXITCODE -ne 0) {
        Write-Error "Command failed: $Command"
        exit $LASTEXITCODE
    }
}

Write-Output "Applying dependencies for $VIP_LVVersion_B"

$command1 = "g-cli --lv-ver $MinimumSupportedLVVersion --arch $SupportedBitness -v `"$RelativePath\Tooling\Deployment\Applyvipc.vi`" -- `"$RelativePath\$VIPCPath`" `"$VIP_LVVersion_B`""
Execute-GCLICommand -Command $command1

if ($VIP_LVVersion -ne $MinimumSupportedLVVersion) {
    Write-Output "Switching versions to apply dependencies for $VIP_LVVersion_A"

    $command2 = "g-cli --lv-ver $MinimumSupportedLVVersion --arch $SupportedBitness -v QuitLabVIEW"
    Execute-GCLICommand -Command $command2

    $command3 = "g-cli --lv-ver $VIP_LVVersion --arch $SupportedBitness -v `"$RelativePath\Tooling\Deployment\Applyvipc.vi`" -- `"$RelativePath\$VIPCPath`" `"$VIP_LVVersion_A`""
    Execute-GCLICommand -Command $command3
}

$command4 = "g-cli --lv-ver $VIP_LVVersion --arch $SupportedBitness -v QuitLabVIEW"
Execute-GCLICommand -Command $command4

Write-Host "Apply dependencies to LabVIEW $MinimumSupportedLVVersion ($SupportedBitness-bit)"
