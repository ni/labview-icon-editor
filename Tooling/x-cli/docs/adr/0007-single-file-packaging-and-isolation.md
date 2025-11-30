# ADR 0007: Single-File Packaging and Isolation

- Status: Accepted
- Date: 2025-09-02
- Deciders: x-cli maintainers
- Tags: distribution, security

## Context
XCli distributes a cross-platform CLI. To run without a preinstalled .NET runtime and avoid additional downloads, the project uses .NET 8 self-contained single-file publishing. To maintain a secure sandbox, runtime code must avoid network assemblies and launching external processes.

## Decision
- XCli targets .NET 8 and publishes as a self-contained single-file executable using `PublishSingleFile` and `SelfContained` project settings.
- An `IsolationGuard` scans referenced assemblies and IL instructions:
  - References to `System.Net*` assemblies trigger an error.
  - Any call to `System.Diagnostics.Process.Start` causes execution to fail.

## Consequences
- Cross-platform distribution is simplified; users receive one executable per OS without requiring a shared runtime or network libraries.
- Runtime execution is sandboxed: no dynamic `Process.Start` is permitted and network dependencies are disallowed.
