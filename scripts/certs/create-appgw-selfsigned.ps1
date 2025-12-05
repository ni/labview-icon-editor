[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$DnsName,

    [Parameter(Mandatory = $true)]
    [string]$OutputDir,

    [string]$CertName = "appgw-backend-selfsigned",
    [int]$ValidDays = 365,
    [securestring]$PfxPassword
)

<# 
.SYNOPSIS
Creates a self-signed TLS certificate (PFX + CER) for Azure Application Gateway backends and prints usage instructions.

.DESCRIPTION
- Generates a self-signed cert with the provided DNS name in CN/SAN.
- Exports a PFX (for backend binding) and a CER/public cert (for App Gateway trusted root).
- Emits next steps for binding on the backend and configuring the App Gateway HTTP setting.

.NOTES
Run in an elevated PowerShell session. The cert is created in LocalMachine\My.
#>

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

if (-not $PfxPassword) {
    $PfxPassword = Read-Host -AsSecureString -Prompt "Enter a password to protect the PFX"
}

$outDir = Resolve-Path -LiteralPath $OutputDir

$cert = New-SelfSignedCertificate `
    -DnsName $DnsName `
    -CertStoreLocation "Cert:\LocalMachine\My" `
    -FriendlyName $CertName `
    -NotAfter (Get-Date).AddDays($ValidDays)

$pfxPath = Join-Path $outDir "$CertName.pfx"
$cerPath = Join-Path $outDir "$CertName.cer"

Export-PfxCertificate -Cert $cert -FilePath $pfxPath -Password $PfxPassword | Out-Null
Export-Certificate -Cert $cert -FilePath $cerPath | Out-Null

Write-Host "Created self-signed cert:" $cert.Thumbprint
Write-Host "DNS: $DnsName"
Write-Host "PFX: $pfxPath"
Write-Host "CER: $cerPath"
Write-Host ""
Write-Host "Next steps:"
Write-Host "1) Backend: install/bind the PFX to your site on $DnsName (IIS/NGINX/etc.)."
Write-Host "2) App Gateway: upload the CER as the trusted root in the HTTP setting that targets this backend; set host override to $DnsName."
Write-Host "3) Verify AppGW health probes succeed and end-to-end HTTPS works."
