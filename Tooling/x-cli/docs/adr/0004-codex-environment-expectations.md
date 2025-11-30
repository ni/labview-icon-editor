# ADR 0004: CI Environment Expectations (Updated)

- Status: Accepted
- Date: 2025-09-01
- Deciders: x-cli maintainers
- Tags: environment, process
- Scope: This ADR applies to the `x-cli` project (container expectations for agents and maintainers).

## Context

The x-cli project runs inside a curated CI environment. Drift between assumptions and the actual runner/container has caused onboarding friction (e.g., invoking `pwsh` when PowerShell is not present). We need a clear contract for: (1) tools provided out of the box, (2) what contributors must provision at setup time, (3) supported environment variables, and (4) how ephemeral state and caches are handled.

## Decision

### Preinstalled packages (base image)
The base container ships with the following runtimes today:

- **Python 3.12**, **Node.js 20**, **Ruby 3.4.4**, **Rust 1.89.0**, **Go 1.24.3**, **Bun 1.2.14**, **PHP 8.4**, **Java 21**, **Swift 6.1**.

Python **3.12** is the required baseline for CI workflows and helper scripts.

The **authoritative list** of preinstalled tools and versions is maintained in `docs/preinstalled-tools.md`. Setup scripts **must consult** this manifest and **skip reinstalling** tools already present.

> Rationale: Avoid redundant installs, version conflicts, and slow cold starts.

### PowerShell requirement for `x-cli`
PowerShell **may not** be included in all runner images. For `x-cli`, certain CI tasks and validations require PowerShell. Therefore:

- `x-cli` **requires** **PowerShell 7.4.11** at runtime.
- Agents must install PowerShell **during setup** (pinned to `7.4.11`) plus the modules:
  - **Pester** (for PowerShell tests)
  - **PSReadLine** (for shell ergonomics; harmless in CI)
- Installation must be **idempotent** and **non-interactive**. Prefer installing from a pinned `.deb` artifact; fall back to the Microsoft package feed if needed. Verify version post‑install.

### Environment variables
Setup **must** configure:

- `DOTNET_ROOT` → the .NET SDK install path when user‑scoped install is used (e.g., `$HOME/.dotnet`).
- `PATH` → prepend `$DOTNET_ROOT:$DOTNET_ROOT/tools` so `dotnet` and tools are available.
- `DOTNET_CLI_TELEMETRY_OPTOUT=1` to disable telemetry in CI.

> Policy: Any **new** global environment variables must be introduced via a follow‑up ADR (no ad‑hoc additions).

### Secrets
The container has **no built‑in secrets**. Credentials needed for builds/tests must be **supplied at invocation time** (e.g., environment variables in CI) and **must not be persisted to disk**.

### Ephemeral container & caches
Containers are **ephemeral** across runs. Agents **must not** depend on cross‑run state. Within a single run, setup **shall** warm caches where useful (e.g., `dotnet restore` on `*.sln`/`*.csproj`; `npm ci`; `pip install -r ...`) to reduce latency.

### Process to propose new base runtimes (maintainers)
Adding a runtime/tool to the **base image** (e.g., Zig, Deno) requires:

1. **Use case**: which agents require it and why a setup‑time install is insufficient.
2. **Impact**: size/perf implications, maintenance ownership, security review.
3. **Alternatives considered**: setup‑time install, conditional install, separate utility image.
4. **Rollout plan**: version pinning, upgrade cadence, deprecation policy.
5. **ADR**: a short ADR documenting the above, to be reviewed/approved by maintainers.

### Responsibilities

**Contributors (for `x-cli`):**
- Read `docs/preinstalled-tools.md` and **skip** preinstalled tools.
- Install PowerShell 7.4.11 (+ Pester, PSReadLine) where required and configure .NET env consistently across platforms.
- Warm language caches for the current run; assume **no** cross‑run persistence.

**Maintainers:**
- Keep `docs/preinstalled-tools.md` accurate.
- Review proposals for new base runtimes via ADR.
- Coordinate base image updates and publish deprecation/upgrade guidance.

## Consequences

- A single source of truth reduces onboarding friction and surprises.
- PowerShell expectations are explicit for `x-cli`, avoiding “command not found” failures.
- Setup remains fast by reusing preinstalled tools and warming caches per run.
- Base image growth is controlled via ADRs with clear justification and ownership.
