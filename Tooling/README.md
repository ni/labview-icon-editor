# Tooling

This folder contains PowerShell scripts used for local CI parity, packaging, and developer workflows.

Common entrypoints:
- `Run-ViValidate.ps1`  
  Runs the fast pylavi `vi_validate` gate only. Uses `.lvversion` as the canonical LabVIEW version.  
  Example: `pwsh -NoProfile -File .\\Tooling\\Run-ViValidate.ps1`  
  Profiles: `-ViValidateProfile strict|legacy|both`, optional `-ViValidateReportOnly`, `-ViValidateSkipVersionGate`.
  Optional absolute-path focus: set `LVIE_PYLAVI_ABSOLUTE_PATH_ROOTS` (semicolon-delimited) to flag specific roots without committing sensitive paths. CI redacts configured roots in logs and the uploaded pylavi log artifact, uploads a redacted top-offenders report (`pylavi-validate-offenders-<label>`), and prints a top-offenders table in the step summary.
- `Run-CICompositeLocal.ps1`  
  Local CI parity run (Verify IE Paths, VIPC, missing-in-project, unit tests, PPLs, VIP build).  
  Example: `pwsh -NoProfile -File .\\Tooling\\Run-CICompositeLocal.ps1 -EnsureCleanState`  
  Note: Direct execution is deprecated; use `Invoke-WorktreeOrchestrator.ps1` for worktree-aware runs.
- `Run-CICompositeLocal-Auto.ps1`  
  Retry loop for local CI parity with adaptive timeouts.  
  Example: `pwsh -NoProfile -File .\\Tooling\\Run-CICompositeLocal-Auto.ps1 -EnsureCleanState -MaxAttempts 5`
- `Invoke-WorktreeOrchestrator.ps1`  
  Resolves worktree policy/root, builds runner-cli in the selected worktree, and can invoke local CI parity.  
  Example: `pwsh -NoProfile -File .\\Tooling\\Invoke-WorktreeOrchestrator.ps1 -Run -RunArgs -LabVIEWVersion 2021 -EnsureCleanState`
- `Get-PylaviOffenders.ps1`  
  Summarizes the latest pylavi offenders report for agent handoffs or automation.  
  Example: `pwsh -NoProfile -File .\\Tooling\\Get-PylaviOffenders.ps1`  
  Optional: `-AsJson`, `-Top 20`, `-Label legacy`, `-OutputPath out.json`, `-WriteSummary`, `-Quiet`, `-FetchLatest`, `-ValidateExists`, `-FailOnEmpty`, `-FailOnFindings`, `-FailOnThreshold 0`.  
  Deterministic: `-Sha <commit>` selects `pylavi-offenders.<sha>.json` (local or fetched); `-RunId <id>` + `-FetchLatest` targets a specific workflow run.  
  `-FetchLatest` pulls the CI artifact automatically (requires `GH_TOKEN`/`GITHUB_TOKEN` with `actions:read`).
- `Fetch-PylaviOffenders.ps1`  
  Downloads the latest pylavi offenders artifact from CI into `TestResults\agent-logs`.  
  Example: `pwsh -NoProfile -File .\\Tooling\\Fetch-PylaviOffenders.ps1 -Branch develop`  
  Deterministic: `-Sha <commit>` or `-RunId <id>` to pin a specific workflow run.  
  Uses `GH_TOKEN` or `GITHUB_TOKEN` (needs `actions:read`).
- `runner-cli`  
  Cross-platform helper for version-gate and pylavi scans (see `Tooling/runner-cli`).  
  Example: `runner-cli version-gate --repo-root .`  
  Example: `runner-cli pylavi scan --config Tooling/pylavi/vi-validate.yml --report-only`  
  Example: `runner-cli pylavi summarize --repo-root .`  
  Example: `runner-cli pylavi fetch --repo <owner/name> --branch develop`

Related config:
- `pylavi/vi-validate.yml`  
  Strict configuration for `vi_validate` (paths, skips, policy). The LabVIEW version is injected at runtime from `.lvversion`.
- `pylavi/vi-validate-legacy.yml`  
  Legacy scope for `vi_validate` (typically absolute-path checks only).
