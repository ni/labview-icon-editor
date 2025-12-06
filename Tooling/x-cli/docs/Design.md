# X-CLI — Design Specification
**Status:** Approved
**Owner:** `@maintainer`
**Last Updated:** 2025‑08‑23

## 0. Executive Summary
`x-cli` is a lightweight, side‑effect‑free command‑line utility ...ilure policy, and emits structured logs for pipeline assertions.

### Host behaviour

### Log replay and diff
- `log-replay` reads JSONL records and reproduces historic g-cli logs with original syntax and timing, printing only what was captured.
- `log-diff` compares baseline and candidate JSONL runs, reporting per-test (or aggregate) timing deltas in text or JSON formats.
- JSONL schema: each line contains `t` (delay ms), `s` (`stdout`/`stderr`), `m` (message). Optional fields such as `test` and `meta` feed the diff analyser without affecting replay.

- x-cli always reports its own diagnostics with the `x-cli` tag and emits `VersionInfo.Version` for `--version`.
- There is no injected/alias mode or environment override; external wrappers are out of scope.

**Design goals**
- Deterministic simulation of common G‑CLI subcommands used in CI (e.g., build/package/test/apply VIPC).
- No network or external process launches; minimal and explicit filesystem writes (optional log file).
- Cross‑platform, fast startup, self‑contained binary packaging.
- A clear, testable contract: CLI usage, exit codes, stderr JSON logging.

**Non‑goals**
- Executing LabVIEW operations.
- Bi‑directional IPC with LabVIEW.
- Long‑running orchestration or remote calls.

---

## 1. Context & Constraints
- **Consumers:** CI runners (GitHub Actions, Azure Pipelines), local developer terminals.
- **Constraints:** Must avoid network access and `Process.Start`. Must complete typical invocations in < 2s (excludi
...
- Design must be simple enough to be implemented and reviewed within two sprints.

---

## 2. External Interfaces
- **CLI:** `x-cli <subcommand> [args] [--] [payload]`
  - `--help` / `--version`
  - `--delay <ms>` — optional artificial delay
  - ...
- **Config file (optional):** JSON; merged with environment and defaults.
- **Environment:** `XCLI_*` variables; `XCLI_FAIL_ON` controls failure policy.
- **Logging:** one JSON line per invocation to stderr; optional file output (`--log-file`).

---

## 3. Configuration Model
- **Precedence:** defaults < config file < environment < CLI flags
- **Failure policy:** combines `mode` (always/never/match), `match` (string/regex), `exitCode`.
- **Simulation plan:** consolidated view of inputs that drive behavior.
- **Validation:** on startup; invalid config yields non‑zero exit and error log.

---

## 4. Architecture

> **Architecture Packet (ISO/IEC/IEEE 42010) — Navigation**
> - Stakeholders & Concerns → `docs/architecture/Stakeholders-Concerns.md`
> - Viewpoints → `docs/architecture/Viewpoints.md`
> - Views:
>   - Context → `docs/architecture/Context.md`
>   - Container → `docs/architecture/Container.md`
>   - Component → `docs/architecture/Component.md` (see also legacy `docs/Component.md`)
>   - Deployment → `docs/architecture/Deployment.md`
> - Correspondences → `docs/architecture/Correspondences.md`
> - ADR Index → `docs/adr/README.md`
> - 42010 Trace → `docs/compliance/Architecture-42010-Trace.md`

### 4.1 Context
- `x-cli` sits in CI pipelines and on dev machines.
- External actors: developer, CI runner, filesystem.
- No outbound network or process spawning is permitted.

### 4.2 Containers
- Single executable (self‑contained); configuration and logs are filesystem‑bound.
- Commands (echo/reverse/upper) share a common parsing and routing layer.

### 4.3 Key components & responsibilities
- **Cli / ArgParser** — tokenize args, detect `--help|--version`, split at `--`.
- **CommandRouter** — records `<subcommand>` and args; no execution of external tools.
- **ConfigProviders** — merge JSON file, `XCLI_FAIL_ON`, `XCLI_*`, then defaults (in that precedence).
- **FailurePolicy** — determines success/failure and exit code by `mode` and `match`.
- **ExecutionEngine** — applies optional delay; no I/O except logging.
- **Logger (JsonLineLogger)** — emits single‑line JSON to stderr and optional log file (append, safe sharing).
- **IsolationGuard** — unit‑tested assertions to prevent networking/process launches; used as a guard rail.
- **Utilities** — version banner, OS/platform detection, time source.

### 4.4 Deployment
- Distributed as a single self‑contained file per OS/arch.
- No external service dependencies.

---

## 5. Detailed Behaviors
- **Echo:** writes payload unchanged; returns success unless failure policy triggers.
- **Reverse:** writes reversed payload; returns success unless failure policy triggers.
- **Upper:** writes uppercase payload; returns success unless failure policy triggers.
- **Delay:** optional wait time; bounded; does not block cancellation.
- **Errors:** always logged with a machine‑readable `reason`.

---

## 6. Extensibility
- Command routing table enables adding new subcommands with minimal changes.
- Logging schema versioned; adding fields is backward‑compatible.

---

## 7. Testing Strategy (Design linkage)
- Unit tests for parsing, logging, simulation plan merge, guard checks.
- Integration tests exercise typical invocations on CI runners.
- Coverage thresholds enforced in CI; reports uploaded as artifacts.

---

## 8. Traceability Hooks
- Each requirement (SRS) has an ID; referenced in code comments and tests.
- Commits include a `codex: <change_type> | SRS: <IDs>` trailer.
- Automation keeps `docs/VCRM.csv` in sync.

---

## 9. Risks & Mitigations
- **Risk:** Accidental introduction of side‑effects.  
  **Mitigation:** IsolationGuard + CI checks.
- **Risk:** Broken JSON schema in logs.  
  **Mitigation:** schema test + golden sample comparison.
- **Risk:** CI‑host variance in perf.  
  **Mitigation:** wide margins; make perf test informational.

---

## 10. Approval
- **Design Review:** (see `/docs/Review/Design-Review-Checklist.md`)
- **Sign‑off Record:** `/docs/Review/Design-Signoff.md` (kept alongside this doc)
