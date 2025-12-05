[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Write-Host "=== Ollama Executor Quickstart ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "1) Expand a task alias to get the full prompt:" -ForegroundColor Yellow
Write-Host "   pwsh -NoProfile -File scripts/ollama-executor/AgentPromptAliases.ps1 <keyword>" -ForegroundColor Gray
Write-Host "   Known keywords (common): seed2021, seed2024q3, seedlatest, vipbparse" -ForegroundColor Gray
Write-Host ""
Write-Host "2) Confirm repo state:" -ForegroundColor Yellow
Write-Host "   git status && git branch --show-current" -ForegroundColor Gray
Write-Host ""
Write-Host "3) Ensure the Seed image exists (vendored default):" -ForegroundColor Yellow
Write-Host "   docker build -f Tooling/seed/Dockerfile -t seed:latest ." -ForegroundColor Gray
Write-Host "   (Override via SEED_IMAGE if needed)" -ForegroundColor Gray
Write-Host ""
Write-Host "4) Run the generated instructions (e.g., create-seeded-branch.ps1) then push/report." -ForegroundColor Yellow
Write-Host ""
Write-Host "Tip: rerun this script anytime for a minimal refresher." -ForegroundColor Green

