# Maintaining x-cli (upstream in this repo)

## Build & test

- Build: `dotnet build Tooling/x-cli/XCli.sln -c Release`
- Test: `dotnet test Tooling/x-cli/XCli.sln -c Release`
- Quick help smoke: `dotnet run --project Tooling/x-cli/src/XCli/XCli.csproj -- --help`

## Packaging

- Normalize distro artifacts: `pwsh Tooling/x-cli/scripts/build.ps1` → `dist/x-cli-win-x64`, `dist/x-cli-linux-x64`
- Pack NuGet-style package: `pwsh Tooling/x-cli/scripts/pack-cli.ps1` → `package/`
- Versioning: prefer tag-based SemVer; pass version via pack script params if needed

## Telemetry

- Schemas (authoritative): `docs/schemas/x-cli/telemetry.events.v2.schema.json`, `docs/schemas/x-cli/telemetry.summary.v1.schema.json`
- Validate after runs: `dotnet run --project Tooling/x-cli/src/XCli/XCli.csproj -- telemetry validate --events artifacts/qa-telemetry.jsonl --schema docs/schemas/x-cli/telemetry.events.v2.schema.json`
- Summarize: `... telemetry summarize --in artifacts/qa-telemetry.jsonl --out telemetry/summary.json`
- Gate: `... telemetry check --summary telemetry/summary.json --max-failures 0`

## Release (outline)

- Build/test Release
- Run scripts/build.ps1 to produce dist binaries; run pack to produce package
- Optional: attach `dist/*` and package outputs to a GitHub Release; publish checksums

## Versioning policy

- Source of truth: git tags `v<major>.<minor>.<patch>` (optionally with prerelease suffix). Release automation should parse the tag and pass it to `build.ps1`/`pack-cli.ps1` via `-Version`.
- CI: `.github/workflows/x-cli-release.yml` tags pipeline publishes dist binaries + NuGet-style package with the tag version.
- Dry-run: trigger the same workflow via `workflow_dispatch` with a `version` input (e.g., `v0.1.0-rc.1`) to verify artifacts before tagging.
- Prerelease naming: use SemVer prerelease suffixes (e.g., `-alpha.1`, `-beta.1`, `-rc.1`) appended to the tag (`v1.2.0-rc.1`).
- Checksums: release workflow writes `dist/checksums.sha256`; validate locally with `Get-FileHash -Algorithm SHA256 <file>`.

## Repo layout notes

- x-cli source of truth lives under `Tooling/x-cli` (no longer treated as vendored)
- Repo-level wrappers (scripts/telemetry, scripts/common/invoke-repo-cli.ps1) should reference local schemas under `docs/schemas/x-cli`
- Keep .NET SDK pinned via `global.json` (if present) to avoid drift
- Dependencies: prefer deterministic restore; add `packages.lock.json` if you want locked transitive versions, otherwise restore from tagged commits to keep reproducibility
