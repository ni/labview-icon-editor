# ADR: Ollama locked executor for scripted builds

- **ID**: ADR-2025-017  
- **Status**: Accepted  
- **Date**: 2025-02-16

## Context
We need a safe way to let a local LLM drive scripted build flows (package-build, source-distribution, local-sd-ppl) without granting arbitrary shell access or requiring external services. The workflows shall run offline, keep repo data local, and bound execution time to avoid hung LabVIEW builds or unattended prompts. VS Code tasks already exist to invoke these flows; the decision is how to expose LLM help while keeping the surface area controlled.

## Options
- **A** — Local Ollama with a locked executor (allowlisted commands, two-turn loop, bounded timeout); pros: offline, data stays local, minimal attack surface; cons: requires local model install/download, CPU/RAM load, still needs guardrails tuning.
- **B** — Remote cloud LLM executor (OpenAI or Azure endpoints) with similar wrapper; pros: no local model setup, higher-quality models; cons: data egress/cost, network dependency, harder to enforce allowlists and latency/timeout guarantees.
- **C** — No LLM-driven execution; rely on manual script invocation; pros: simplest, no new dependencies or attack surface; cons: slower developer feedback, less automation, more context switching.

## Decision
Choose Option A: use a local Ollama-based locked executor for build flows. The executor (`scripts/ollama-executor/Drive-Ollama-Executor.ps1`) enforces an exact allowlist, two-turn interactions, and a hard `CommandTimeoutSec` per run. Task wrappers (e.g., `Run-Locked-SourceDistribution.ps1`) keep scope to a single permitted command and are surfaced via VS Code tasks (labels 30–32) with user-configurable timeouts.

## Consequences
- **+** Offline/local-only execution, no data egress; consistent guardrails via allowlists, stop-after-first-command, and timeouts.
- **+** Fits existing VS Code task UX; minimal change to build scripts and repo structure.
- **–** Requires local Ollama installation and model download; CPU/GPU load may slow builds.
- **–** Guardrails shall be maintained as scripts evolve; lock-step command changes require task and allowlist updates.

## Follow-ups
- [ ] Document Ollama install/model prerequisites and expected resource usage in `docs/vscode-tasks.md`.
- [ ] Add a lightweight health check task for Ollama availability and model presence before running locked tasks.

> Traceability: VS Code tasks 30–32 in `.vscode/tasks.json`; executor scripts under `scripts/ollama-executor/`.
