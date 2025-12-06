# Node Tooling Patterns (CI)

This repo standardizes Node usage in CI for fast, reproducible runs and minimal ad‑hoc installs.

## Goals
- Reproducible installs via `npm ci` with committed lockfiles
- Stable Node version (`20.x`) across workflows
- Cached installs with `actions/setup-node@v4`
- JSON schema validation with PowerShell `Test-Json` (no Ajv setup inline)

## Quick Checklist
- Commit `package.json` and `package-lock.json` for each tool under `tools/<name>`
- Use `actions/setup-node@v4` with:
  - `node-version: '20.x'`
  - `cache: 'npm'`
  - `cache-dependency-path: tools/<name>/package-lock.json` (or a multiline list for multiple tools)
- Install with `npm ci` (not `npm install`)
- Build with `npm run build` (or run directly if no build step)
- Validate JSON with PowerShell `Test-Json -SchemaFile`
- Gate outputs with `git diff --exit-code <paths>` where appropriate

## Reusable Snippet

```yaml
# Setup Node (with npm cache keyed to lockfiles)
- uses: actions/setup-node@v4
  with:
    node-version: '20.x'
    cache: 'npm'
    cache-dependency-path: |
      tools/module-index-ts/package-lock.json
      tools/rtm-verify-ts/package-lock.json

# Build and run a Node tool reproducibly
- name: Build <tool>
  run: |
    npm -C tools/<tool> ci
    npm -C tools/<tool> run build

- name: Run <tool>
  run: |
    node tools/<tool>/dist/index.js <args>

# Validate JSON outputs with PowerShell (Linux/Windows via pwsh)
- name: Validate <json> against <schema>
  shell: pwsh
  run: |
    $schema = '<path-to-schema.json>'
    $json   = '<path-to-json>'
    if (-not (Test-Path $schema)) { Write-Error "Schema not found: $schema"; exit 1 }
    if (-not (Test-Path $json))   { Write-Error "JSON not found: $json";     exit 1 }
    $ok = Test-Json -Json (Get-Content $json -Raw) -SchemaFile $schema
    if (-not $ok) { Write-Error "Schema validation failed for $json"; exit 1 }
    Write-Host "Schema validation passed: $json"
```

## Notes
- Prefer `npm -C tools/<tool> ...` or `--prefix tools/<tool>` to avoid changing CWD.
- For multiple tools in one job, either list all lockfiles under `cache-dependency-path` or run separate setup steps for isolation.
- Avoid ad‑hoc `npm install` or `npm init` in workflows; use committed lockfiles and `npm ci`.
- Keep schema validation in PowerShell unless a tool specifically owns validation in its language (e.g., Python tests using `jsonschema`).

## Examples in this Repo
- Module Index (TS): `tools/module-index-ts/` — generated `docs/module-index.json` and `docs/module-index.md` (see `.github/workflows/build.yml`).
- RTM Verify (TS): `tools/rtm-verify-ts/` — built and executed with `npm ci` + cache (see `.github/workflows/srs-gate.yml`).

