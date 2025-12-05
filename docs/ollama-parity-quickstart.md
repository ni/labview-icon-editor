# Ollama Executor Parity Quickstart (Sim Mode)

This quickstart shows how to run the locked Ollama executor flow in simulation mode on Linux/WSL and Windows, without LabVIEW/VIPM. Simulation mode exercises the full path, emits stub artifacts, and writes a handshake JSON with hashes to prove parity.

## Flags
- `OLLAMA_EXECUTOR_MODE=sim` — enables simulation/bypass of Windows-only prereqs.
- `OLLAMA_REQUIREMENTS_APPLIED` — optional comma list of requirement IDs to log (default: OEX-PARITY-001..004).
- `OLLAMA_SIM_CREATE_ARTIFACTS=true` — create stub artifacts in sim runs.

## Linux/WSL
```bash
export OLLAMA_EXECUTOR_MODE=sim
export OLLAMA_REQUIREMENTS_APPLIED=OEX-PARITY-001,OEX-PARITY-002,OEX-PARITY-003,OEX-PARITY-004
pwsh -NoProfile -File scripts/orchestration/Run-Ollama-Host.ps1 \
  -Repo . \
  -RunKey local-linux-sim \
  -PwshTimeoutSec 900 \
  -OllamaPrompt "local-sd/local-sd-ppl"
```
Expected outputs:
- Stub artifacts under `artifacts/` (zip/ppl) and `builds-isolated/local-linux-sim/`.
- `artifacts/labview-icon-api-handshake.json` with `zipSha256`, `pplSha256`, `requirements`, `mode=sim`, and `prereqBypassed=true`.
- Logs: `reports/logs/ollama-host-local-linux-sim.log` and `.summary.json`.

## Windows (sim mode)
```powershell
$env:OLLAMA_EXECUTOR_MODE = "sim"
$env:OLLAMA_REQUIREMENTS_APPLIED = "OEX-PARITY-001,OEX-PARITY-002,OEX-PARITY-003,OEX-PARITY-004"
pwsh -NoProfile -File scripts/orchestration/Run-Ollama-Host.ps1 `
  -Repo . `
  -RunKey local-windows-sim `
  -PwshTimeoutSec 900 `
  -OllamaPrompt "local-sd/local-sd-ppl"
```
Expected outputs mirror Linux: stub artifacts, handshake JSON with hashes/requirements, logs under `reports/logs/`.

## Notes
- Real (non-sim) runs still enforce Windows prerequisites (LabVIEW/VIPM).
- CI has parity lanes (`ollama-sim-linux`, `ollama-sim-windows`) that run these steps and validate the handshake JSON.
