# Copilot instructions

- **Purpose & platform**: Orchestrates the LabVIEW Icon Editor builds (LabVIEW 2021 SP1 32/64) with Windows-first PowerShell + .NET CLIs; devcontainer/Codespaces are only for Ollama/executor simulation (no LabVIEW builds inside containers).
- **Layout (ADR-2025-011)**: Keep orchestration/tooling at repo root (`scripts/`, `Tooling/`, `configs/`, `docs/`); shared modules live in `src/tools/` with thin loaders in `tools/`. Tasks/CI resolve from the repo root—do not relocate scripts into `src/`.
- **Big picture**: IntegrationEngine/OrchestrationCli drive builds; DevModeAgentCli manages LocalHost.LibraryPaths; XCli powers VI Analyzer/History helpers. Hand-offs and hashes are captured in `artifacts/labview-icon-api-handshake.json` when SD→PPL flows run.

## Core workflows (VS Code tasks mirror)
- **Apply dependencies** before any build: task `01 Verify / Apply dependencies` → OrchestrationCli `apply-deps` (needs VIPM CLI on PATH).
- **Build package**: task `02 Build LVAddon (VI Package)` → `package-build` (defaults LV 2021, `SupportedBitness=64`, `LvlibpBitness=both`, version `0.1.0+1`). If VIPM missing, a `vipm-skipped-placeholder.vip` is written—install VIPM, delete placeholder, rerun.
- **Source Distribution**: task `20 Build: Source Distribution` via `scripts/run-xcli.ps1` → OrchestrationCli `source-dist-build` (runner `gcli` default); verify with task `21 Verify: Source Distribution` (`source-dist-verify` strict manifest/hash).
- **PPL from SD**: task `22 Build PPL from Source Distribution` extracts the SD, binds dev-mode to the extracted tree, and builds lvlibp; task `23 Orchestration: SD->PPL (LabVIEWCLI)` runs the serialized lock/bind/build/unbind flow using LabVIEWCLI for both phases.
- **Isolated worktree builds/tests**: task `17 Build (isolated worktree)` and task `12 Tests: run (isolated worktree)` keep the main tree untouched; unbind the main repo first if LocalHost tokens might clash.
- **Dev mode tokens**: tasks `06/06b/06c` bind/unbind/clear LocalHost.LibraryPaths using DevModeAgentCli with VIPB-derived year/bitness; use `-Force` only when intentionally overwriting other-repo tokens.

## Ollama executor & simulation
- Locked tasks `30/31/32/32b` call `scripts/ollama-executor/Run-*.ps1`; traffic stays on `OLLAMA_HOST` (devcontainer default `http://host.docker.internal:11435`; host default `http://localhost:11435`). Provide `OLLAMA_MODEL_TAG` or import a `.ollama` bundle via task 29.
- **Simulation mode knobs** (set `OLLAMA_EXECUTOR_MODE=sim`): `OLLAMA_SIM_CREATE_ARTIFACTS=true` to emit stub zips/ppls + handshake, `OLLAMA_REQUIREMENTS_APPLIED=<csv>` to force requirements flag, `OLLAMA_SIM_FAIL=true` or `OLLAMA_SIM_EXIT=<code>` to force failure/exit code, `OLLAMA_SIM_DELAY_MS=<ms>` to add latency, `OLLAMA_SIM_PLATFORMS=2021-32,2021-64,2025-64` to constrain reported LabVIEW platforms. Use to validate flows without LabVIEW/VIPM.
- **Stub artifacts & handshake**: sim runs drop stub SD/PPL under `artifacts/` plus `builds-isolated/<runKey>/`; `artifacts/labview-icon-api-handshake.json` records `zipSha256`/`pplSha256`, `mode=sim`, `prereqBypassed=true`, `requirements` (from `OLLAMA_REQUIREMENTS_APPLIED`), and the run key/paths—use it to prove parity or feed consumer steps. Summary log: `reports/logs/ollama-host-<runKey>.summary.json`.
- **Handshake shape (example)**:
```json
{
	"runKey": "local-linux-sim",
	"lockPath": ".locks/orchestration.lock",
	"lockTtlSec": 1800,
	"forceLock": false,
	"zipRelPath": "artifacts/labview-icon-api.zip",
	"zipSha256": "<sha256>",
	"pplRelPath": "artifacts/labview-icon-api.ppl",
	"pplSha256": "<sha256>",
	"timestampUtc": "2025-12-06T00:00:00.000Z",
	"mode": "sim",
	"requirements": ["OEX-PARITY-001", "OEX-PARITY-002"],
	"prereqBypassed": true
}
```
- **Consumer validation**: `scripts/orchestration/ConsumeSdInContainer.ps1` (and docker harness profiles) read the handshake, recompute SHA256 inside the container, and fail if hashes mismatch; container logs include consumed paths + hashes and lock/runKey outcomes.
- **Consumer command** (inside docker harness):
	`pwsh -NoProfile -File scripts/orchestration/ConsumeSdInContainer.ps1 -Repo /workspace -HandshakePath /workspace/artifacts/labview-icon-api-handshake.json -RunKey docker-harness-A`
- **Log snippet**:
	`[consume-sd][zip] /workspace/artifacts/labview-icon-api.zip sha256=abc…123 computed=abc…123`
	`[consume-sd][lock] path=.locks/orchestration.lock runKey=docker-harness-A keepLock=False`
- Quick mock without a model: `pwsh -NoProfile -File scripts/ollama-executor/Run-MockScenario.ps1 -Task source-distribution` (or `package-build` / `local-sd-ppl`).

## CLI & env patterns
- Prefer `scripts/common/invoke-repo-cli.ps1 -Cli <OrchestrationCli|IntegrationEngineCli|DevModeAgentCli|XCli> -- <args>`; VS Code tasks are thin wrappers.
- XCli requires `XCLI_ALLOW_PROCESS_START=1` and `XCLI_REPO_ROOT` (set by tasks); sample requests live under `configs/`.
- Tooling cache lives at `%LOCALAPPDATA%/labview-icon-editor/tooling-cache`; clear specific entries with `scripts/clear-tooling-cache.ps1`. Task 19 (probe helper smoke) exercises cache tiers.

## Conventions & guardrails
- Follow `AGENT.md`: least privilege, whitelisted commands, avoid secret/log exfiltration, cap auto-applied changes. Log run keys, lock TTLs, and SHA256s for SD→PPL flows; keep handshake JSON in `artifacts/`.
- Requirements source of truth: `docs/requirements/requirements_rewritten_29148_flags.csv`; regenerate summaries via `scripts/run-requirements-summary-task.ps1` and keep `reports/requirements-summary*.md/html` in sync.
- Keep repo structure per ADR-2025-011; tasks/CI assume root-relative paths.

## Pointers
- Overview: `README.md`; task details: `docs/vscode-tasks.md`; layout rationale: `docs/adr/ADR-2025-011-repo-structure.md`; Ollama parity/sim: `docs/ollama-parity-quickstart.md`; automation contract: `AGENT.md`.