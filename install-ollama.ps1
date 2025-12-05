# Installing Ollama CLI via PowerShell on Windows
# This script will download the installer and start it.
$installerUrl = "https://ollama.com/download/OllamaSetup.exe"
$installerPath = Join-Path $env:TEMP "OllamaSetup.exe"
Write-Host "Downloading Ollama installer..." -ForegroundColor Cyan
Invoke-WebRequest -Uri $installerUrl -OutFile $installerPath
Write-Host "Launching installer..." -ForegroundColor Cyan
Start-Process -FilePath $installerPath -Wait
Write-Host "Done. If prompted, reboot or restart shell to pick up PATH changes." -ForegroundColor Green
