# ghops Logs Schemas

This repository emits GitHub-CLI helper logs in JSON to support automation and diagnostics.

Schemas (versioned under `docs/schemas/v1/`):
- Unified logs: `ghops.logs/v1` (`docs/schemas/v1/ghops.logs.v1.schema.json`)
- Per-runner aggregate: `ghops.aggregate/v1` (`docs/schemas/v1/ghops.aggregate.v1.schema.json`)
- Per-runner summary: `ghops.summary/v1` (`docs/schemas/v1/ghops.summary.v1.schema.json`)

## Unified (ghops.logs/v1)
- File: `ghops-logs-all/all-logs.json`
- Structure:
  - `schema`: `ghops.logs/v1`
  - `meta`: `{ runId, sha, repo }`
  - `entries[]` objects with:
    - `origin`: `bash` or `ps`
    - `name`: `pr-create`, `run-watch`, `run-rerun`, `artifacts-download`, `release-tag`
    - `dryRun`, `repo`, `context{...}`, `commands[]`

Example snippet:
```json
{
  "schema": "ghops.logs/v1",
  "meta": { "runId": 12345, "sha": "deadbeef", "repo": "LabVIEW-Community-CI-CD/x-cli" },
  "entries": [
    {
      "origin": "bash",
      "name": "pr-create",
      "dryRun": true,
      "repo": "LabVIEW-Community-CI-CD/x-cli",
      "context": { "branch": "feat/json", "base": "develop", "labels": ["ci","bootstrap"] },
      "commands": ["git fetch origin develop", "gh pr create -R …"]
    }
  ]
}
```

## Aggregate (ghops.aggregate/v1)
- Files: `ghops-logs/aggregate.json`, `ghops-logs-ps/aggregate-ps.json`
- Structure: `{ files: { "<name>.json": { dryRun, repo, commands[], … } } }`

## Summary (ghops.summary/v1)
- Files: `ghops-logs/summary.json`, `ghops-logs-ps/summary-ps.json`
- Structure: `{ "<name>.json": { commands, dryRun, repo, … } }`

## Validation
CI validates:
- Unified `all-logs.json` against `ghops.logs/v1`.
- Per-runner aggregates and summaries against their schemas (shape and types).

## Changelog
- v1 (initial): unified entries with common context across bash/PowerShell; arrays supported for labels; schemas published under `docs/schemas/v1/`.

## Sample Consumers
- PowerShell summary (local):
  - `powershell -File scripts/ghops/tools/all-logs-summary.ps1 -Input ghops-logs-all/all-logs.json`
  - JSON mode: `powershell -File scripts/ghops/tools/all-logs-summary.ps1 -Input ghops-logs-all/all-logs.json -Json > summary-local.json`
- GitHub Actions (Node): `actions/github-script` can parse `all-logs.json` and compose PR comments; see the `ghops-smoke` workflow for an example.
