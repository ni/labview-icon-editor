# ModuleIndex (C#)

A minimal C# generator for the Module Index.

- Scans these roots (when present): `src/XCli`, `src/Telemetry`, `src/SrsApi`, `scripts`
- Matches comment lines starting with `// ModuleIndex:` or `# ModuleIndex:` in `.cs`, `.py`, `.ps1`, `.sh`
- Outputs:
  - `docs/module-index.json` (source of truth; gated in CI)
  - `docs/module-index.md` (human-readable; non-blocking in CI)

## Usage

Run from the repo root:

```
dotnet run --project src/Tools/ModuleIndex/ModuleIndex.csproj \
  --json-out docs/module-index.json \
  --md-out   docs/module-index.md
```

Optional:
- `--root <path>`: alternate repo root

Notes:
- The generator preserves the previous `generatedAt` timestamp (when JSON exists) to avoid noisy diffs in PRs.
- CI gates only on JSON; Markdown diffs are shown as a warning in the job log.
