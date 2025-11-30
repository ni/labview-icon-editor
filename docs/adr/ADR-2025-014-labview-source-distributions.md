---
status: Proposed
title: Automate LabVIEW Source Distribution Builds via CLI
date: 2025-11-29
authors: NI\dev
---

## Context

We already build and archive LabVIEW artifacts such as `.vip` packages via the DevMode toolchain and IntegrationEngineCli processes. LabVIEW 2021 adds a **Source Distribution** build specification (in this case the “Editor Packed Library” build spec referenced by `seed.vipb`) that produces a curated set of VI sources (VIs, dependencies, pre/post build VIs) suitable for redistribution, auditing, or downstream packaging. Building the source distribution requires LabVIEW 2020 or newer, since the CLI and Application Builder API used here ship with 2020+.

- configuring a LabVIEW project build spec with explicit source files, destination folder, and optional pre/post build VIs.
- enabling VI Server for LabVIEWCLI so headless automation can connect over TCP/IP.
- invoking `LabVIEWCLI -OperationName ExecuteBuildSpec` with `-ProjectPath`, `-TargetName` (e.g., "My Computer"), and the build spec name.
- optionally directing CLI log output via `-LogFilePath` and setting verbosity (Detailed/Diagnostic).
- handling generated files (usually a folder of VIs plus support files) via a post-build VI or CI script actions such as copying, zipping, or artifact upload.

The CLI returns the generated file list and non-zero exit codes on failure, which integrates well with CI runners. Compared to instrumenting the Application Builder API VIs directly (e.g., via `RunVI`), the CLI approach is simpler for single-spec automation and already exposes the necessary metadata to script post-build artifact handling.

## Decision (minimum LabVIEW 2020+)

We will adopt LabVIEWCLI’s `ExecuteBuildSpec` operation to automate Source Distribution builds in CI/DevMode tasks when an additional artifact beyond `.vip` is required. The steps are:

1. Configure a Source Distribution build spec in the project with the necessary `Always Included` VIs, enable VI Server, and add any pre/post build VIs that perform stamping or artifact staging.
2. Invoke LabVIEWCLI from our automation runner (DevMode agent, CI job, or scripts) with `-ProjectPath`, `-TargetName` (typically `My Computer`), and `-BuildSpecName`.
3. Capture command output or the log file (`-LogFilePath`) to detect generated file paths and diagnose failures; treat any non-zero exit as a build failure.
4. After the CLI run completes, copy/zip the reported files using either the post-build VI (preferred for tight versioning) or the CI script (preferred for repository-level artifact storage). The CI script path should parse CLI output or rely on deterministic destinations.
5. Keep the `.vip` artifact generation unchanged; this ADR only introduces source distribution builds as an additional artifact when needed for compliance, reviewer access, or downstream packaging.

### Tasking, manifest, and artifacts

- Add a **VS Code task** (`20 Build: Source Distribution`) and IntegrationEngine step (`scripts/ie.ps1 build-source-distribution`, also invoked inside managed/worktree builds) that run `scripts/build-source-distribution/Build_Source_Distribution.ps1 -RepositoryPath .` alongside the lvlibp + VI Package flow. Both paths log artifacts for CI/local parity.
- Emit **manifest JSON + CSV** alongside the Source Distribution output. Each file entry must include: relative path as emitted in the build output, `last_commit`, `commit_author`, `commit_date`, `commit_source` (file vs. llb_container), and `size_bytes`. Top-level metadata should capture project path, target, build spec name, LabVIEW version, and timestamp. This manifest must be updated any time the Source Distribution is rebuilt.
- Publish the **Source Distribution folder + manifest** as a zipped artifact for CI/DevMode runs (`builds/artifacts/source-distribution.zip`) so requirements evidence can reference a stable bundle. Artifact upload/log-stash hooks must be wired into the new task and CI job.

## Consequences

- **Automated source artifact**: We can now produce source-level deliverables via CLI with minimal custom LabVIEW scripting while retaining audit trails via CLI exit/log & the build spec’s output list. This flow assumes LabVIEW 2020+ is available on the build agents so the CLI and Application Builder capabilities are present.
- **CI integration**: The CLI's structured output and exit codes collaborate with existing CI scripts (PowerShell/ps1 wrappers) for logging, artifact archives, and failure notifications.
- **Dual artifact maintenance**: Teams must now care for both `.vip` and source distribution specs (pre/post build VIs, packaging logic), which increases configuration overhead but improves traceability/security for source consumers.
- **Future work**: If additional control is required (e.g., dynamic spec updates or multi-step build logic), the Application Builder API remains available. For most cases the CLI path will suffice, but we can revisit the more complex scripting approach if we need to modify specs at runtime.
