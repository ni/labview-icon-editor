# .NET SDK Requirements for Self-Hosted Runners

We are unifying on .NET tooling for build/publish tasks. The Windows self-hosted runner must satisfy these requirements before running CI:

- Install .NET SDK `8.0.x` (match upstream build; ensure `dotnet --list-sdks` reports an 8.0 line).
- Ensure `dotnet` is on `PATH` for the runner user (non-elevated runs must still resolve the SDK).
- Keep 8.0 patched (apply monthly SDK updates). Side-by-side installs of other SDKs are fine; do not remove 8.0.x.
- Verify readiness with `scripts/setup-runner/Verify-RunnerPrereqs.ps1`, which fails if the 8.0 SDK is missing.
- If a `global.json` is added later, the runner must satisfy that pinned SDK; otherwise continue with 8.0.x.
