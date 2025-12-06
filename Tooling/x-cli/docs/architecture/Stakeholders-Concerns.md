# Stakeholders & Concerns

| Stakeholder | Primary Concerns | Measurable Fit Criteria |
|---|---|---|
| CI Maintainer | Fast, deterministic runs; easy integration; failure surfaces visible in logs | Typical invocation completes ≤2s (excl. optional delay); single-file distribution; stderr JSON log per invocation; zero network/process launches enforced |
| Developer | Local parity with CI; discoverability; simple debugging | Same flags/behavior locally as in CI; `--help` covers all commands/flags; local run produces identical logs given same inputs |
| QA | Verifiability and coverage; traceability to requirements | ≥75% line coverage overall (critical modules ≥80%); RTM row exists for each critical requirement; reproducible tests with fixed seeds where applicable |
| Security | No network access; no external process execution; supply-chain hygiene | Static guard prevents references to `System.Net*` and `Process.Start`; SBOM present; dependencies pinned |
| Release/CM | Versioning, packaging, and integrity of artifacts | SemVer tags create release baselines; self-contained single-file artifact uploaded to Releases; checksum recorded |
| Product/Owner | Feature clarity; correctness of CLI behaviors | Each capability specified with acceptance criteria; backward compatibility documented per release |

## Quality Scenarios (NFR)
- **Performance:** End-to-end CLI run (typical subcommand) finishes in ≤2s on CI runners; optional `--delay` accurately adds delay ±50ms.
- **Portability:** Binaries run on Windows/Linux/macOS without additional runtimes; single-file packaging verified in CI.
- **Determinism:** Given identical inputs/env, outputs (exit code, stderr JSON) are identical across runs/platforms.
- **Isolation:** No network calls; no external process launches; writes only to explicit output paths/log file.
- **Observability:** Every invocation emits one structured JSON log line to stderr; optional file log append-only; error conditions include trace IDs.
