# Architecture Decision Records — Index

This index lists all ADRs in this repository.

| # | Title | Date | Status | Purpose |
|---:|---|:---:|:---:|---|
| 0001 | [Harden AGENTS.md Contract Enforcement](./0001-agents-contract-hardening.md) | 2025-08-28 | Accepted | `AGENTS.md` defines the normative contract for autonomo...ow drift between intent and practice. Key pain points include: |
| 0002 | [Codex Verified Human Mirror](../archive/adr/0002-codex-verified-human-mirror.md) | 2025-08-29 | Archived | Archived with pipeline simplification; depends on removed workflows. |
| 0003 | [AGENTS Hierarchy](./0003-agents-hierarchy.md) | 2025-09-01 | Accepted | `AGENTS.md` at the repository root defines the canonica...ctories sometimes need additional guidance or exceptions. Withou |
| 0004 | [CI Environment Expectations (Updated)](./0004-codex-environment-expectations.md) |  |  | The x-cli project runs inside a curated CI environment. Drift between assumptions and runner state causes friction; this ADR sets expectations. |
| 0005 | [Metadata Hydration](./0005-metadata-hydration.md) | 2025-09-01 | Accepted | The repository requires structured commit and PR metada...maries, change types, and SRS IDs from GitHub issues is error‑pr |
| 0006 | [Requirements Traceability](./0006-requirements-traceability.md) | 2025-09-01 | Accepted | Maintaining a reliable link between Software Requiremen...and code changes is essential for auditability. Without a struct |
| 0007 | [Single-File Packaging and Isolation](./0007-single-file-packaging-and-isolation.md) | 2025-09-02 | Accepted | XCli distributes a cross-platform CLI. To run without a...tional downloads, the project uses .NET 8 self-contained single- |
| 0008 | [Environment and Config Precedence for Simulation](./0008-env-config-simulation.md) | 2025-09-03 | Accepted | SimulationPlan loads failure behavior from `XCLI_*` env...ile. Clear precedence and failure handling are required so CI sc |
| 0009 | [JSON Logging and Retry Strategy](./0009-json-logging.md) | 2025-09-02 | Accepted | XCli logs every command invocation as a single-line JSO...and may also append to a file when `XCLI_LOG_PATH` is set. Concu |
| 0010 | [Environment Helper Caching and Process Name](./0010-env-helper-process-name.md) | 2025-09-04 | Accepted | The `Env` helper centralizes access to environment vari...tive snapshot of process variables to avoid repeated lookups and |
| 0011 | [SRS Registry Loading](./0011-srs-registry.md) | 2025-09-05 | Accepted | The project relies on a centralized registry so that re...s map to actual SRS documents. Without a strict loader, malforme |
| 0012 | [Traceability Matrix](./0012-traceability-matrix.md) | 2025-09-06 | Accepted | The project needs a single, machine-readable source tha...ests, and commit history. Without a maintained map, requirements |
| 0013 | [Module-SRS Mapping](./0013-module-srs-mapping.md) | 2025-09-06 | Accepted | Source files must reference the requirements they satis... is error-prone. Without a central map, modules may add files th |
| 0014 | [Traceability Telemetry](./0014-traceability-telemetry.md) | 2025-09-02 | Accepted | Requirements in `docs/srs` map the specification ...hat audits and automation can reason about coverage over time. |
| 00xx | [Add <Runtime/Tool> to Base Image](./00xx-template-add-runtime.md) |  |  |  |
