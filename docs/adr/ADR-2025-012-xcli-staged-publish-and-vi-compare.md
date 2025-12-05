# ADR: x-cli Staged Publish, RunnerProfile Gating, and VI Compare Artifacts

- **ID**: ADR-2025-012  
- **Status**: Accepted  
- **Date**: 2025-11-17

## Context
- The lab now routes LabVIEW, vipmcli, and g-cli orchestration through x-cli so PowerShell entry points can remain deterministic (emulated providers) while still allowing “real tools” validation paths.
- RunnerProfile metadata advertises when a machine has the *real-tools* capability. We gate telemetry, matrix profiles, and vi-compare session bundles on those runners to avoid uploading unverified artifacts.
- The Stage → Validate → QA → Upload helpers and VS Code tasks implement the staged publish pipeline; publish-plan scenarios (`tools/Invoke-XCliTestPlanScenario.ps1`) exercise the same flow.

## Decision
- Always stage x-cli build outputs before invoking validation or QA/Upload steps. Record `stage-info.json` and keep the latest stage per channel.
- During validation, extract the staged artifact, run the LabVIEW smoke matrix via x-cli, and emit a `vi-compare-<run-id>` session bundle. Attach bundle paths to `stage-info.assets` so later tasks can copy/share them.
- QA promotion copies both the staged artifact and the vi-compare bundle to the configured QA root; uploads refuse to re-run on a previously uploaded stage.
- Real-tools runners shall supply telemetry summaries, full matrix coverage, and a vi-compare session bundle; otherwise validation fails early.
- Legacy direct-upload scripts (e.g., `tools/icon-editor/Publish-LocalArtifacts.ps1`) are retired in favor of the gated helpers. VS Code exposes discrete Stage/Test/Promote/Upload tasks plus publish-plan scenario tasks.

## Consequences
- Publish infrastructure can enforce “real-tools” coverage by failing validation when bundles or telemetry are missing.
- Developers can run either the discrete tasks (`Tools: Stage x-cli artifact`, `Tools: Validate x-cli artifact`, `Tools: Promote x-cli artifact`, `Tools: Upload x-cli artifact`) or the publish-plan tasks to exercise the entire pipeline locally.
- QA drops and GitHub releases now include vi-compare session zips sourced from the validation assets, keeping LabVIEW diff evidence attached to every staged build.

## x-cli workflow surface
x-cli now exposes a canonical command surface for every LabVIEW/vipmcli activity. Each workflow can be invoked directly via `dotnet run --project tools/x-cli-develop/... -- <workflow> --request <json>` or through `tools/codex/Invoke-XCliWorkflow.ps1`, which sets the repo root/env vars for Codex.

| Workflow | Command / Request | VS Code task | Notes |
| --- | --- | --- | --- |
| VI compare replay | `vi-compare-run --request configs/vi-compare-run-request.json` | `Tools: Run VI Compare (x-cli)` and `Tools: Replay VI compare scenario` | Drives `tools/icon-editor/Replay-ViCompareScenario.ps1`, honors per-flag suppression toggles, writes `vi-comparison-summary.json` + bundle zip. |
| VI compare verification | `vi-compare-verify --summary <summary.json>` | `Tools: Verify VI compare (x-cli)` | Parses the summary to ensure LVCompare HTML reflects the requested flags; use this to gate “fully suppressed” compares. |
| VI Analyzer run | `vi-analyzer-run --request configs/vi-analyzer-request.json` | `Tools: Run VI Analyzer (x-cli)` | Shells into `Invoke-VIAnalyzer.ps1`, writes `vi-analyzer.json`, captures CLI logs. |
| VI Analyzer verification | `vi-analyzer-verify --labview-path <LabVIEW.exe>` | `Tools: Verify VI Analyzer (x-cli)` | Lightweight CLI check to ensure LabVIEWCLI/analyzer plug-in is installed. |
| vipmcli dependency apply | `vipm-apply-vipc --request configs/vipm-apply-request.json` | `Tools: vipmcli build (x-cli)` (apply path) / `Tools: Smoke vipmcli apply` | Calls `Replay-ApplyVipcJob.ps1`; the repo ships a stub `.github/actions/apply-vipc/ApplyVIPC.ps1` until the real action is vendored. |
| vipmcli package replay | `vipm-build-vip --request configs/vipm-build-request.json` | `Tools: Smoke vipmcli package` | Replays the “Build VI Package” job (release notes, VIPB updates, packaging). |
| vipmcli build | `vipmcli-build --request configs/vipmcli-build-request.json` | `Tools: Smoke vipmcli build` | Wraps `Invoke-VipmCliBuild.ps1`, syncing the vendor snapshot, applying VIPCs, and running the vipmcli build. |
| PPL build | `ppl-build --request configs/ppl-build-request.json` | `Tools: PPL Build (x-cli)` | Routes to `.github/actions/build-lvlibp/Build_lvlibp.ps1` for per-bitness packed project builds. |
| Stage/Test/Promote/Upload | `Stage-XCliArtifact.ps1`, `Test-XCliReleaseAsset.ps1`, `Promote-XCliArtifact.ps1`, `Upload-XCliArtifact.ps1` (driven via VS Code tasks) | `Tools: Stage/Validate/Promote/Upload x-cli artifact` | Orchestrate the gated publish pipeline; publish-plan scenarios run these in sequence. |

### Required environment variables
Real-tool invocations require the following environment to be present (Codex tasks set them automatically; document them here for clarity):

- `XCLI_ALLOW_PROCESS_START=1` – required for x-cli to spawn LabVIEW processes. Without this env, runs fall back to dry-run.
- `XCLI_REPO_ROOT=<repo path>` – resolves relative paths in request JSON (Codex helper sets this to `${workspaceFolder}`).
- `XCLI_LABVIEW_INI_PATH` and `XCLI_LOCALHOST_REQUIRED_PATH` – needed for `labview-devmode-*` and vi-compare replay to confirm `LocalHost.LibraryPaths` maps the repo root.
- `XCLI_PWSH` – optional override when the runner needs a specific `pwsh.exe`.
- `XCLI_STAGE_CHANNEL`, `XCLI_QA_DESTINATION`, `XCLI_UPLOAD_MODE` – control Stage/Test/Promote/Upload destinations; exposed via VS Code task prompts.
- vipmcli workflows also expect the CLI binaries to be in `PATH` (g-cli and vipmcli providers).

### Codex playbook
When Codex (or a human operator) exercises the workflows end-to-end, follow this checklist:

1. **Replay / verify VI compare**
   - Run `Tools: Replay VI compare scenario` (or `pwsh tools/codex/Invoke-XCliWorkflow.ps1 -Workflow vi-compare-run -RequestPath configs/vi-compare-run-request.json`).
   - Optional: run `vi-compare-verify --summary <summary>` to ensure suppression flags match the HTML.
2. **VI Analyzer**
   - Use `Tools: Run VI Analyzer (x-cli)` for a full analyzer run; use `Tools: Verify VI Analyzer (x-cli)` first to ensure LabVIEWCLI is provisioned.
3. **vipmcli dependency apply / package replay**
   - `Tools: Smoke vipmcli apply` (prepare-only or execute) ensures `.vipc` bundles apply via g-cli.
   - `Tools: Smoke vipmcli package` replays the Build VI Package job; `Tools: Smoke vipmcli build` routes into `Invoke-VipmCliBuild.ps1`.
4. **Publish pipeline**
   - Run `Tools: Stage x-cli artifact`, `Tools: Validate x-cli artifact`, `Tools: Promote x-cli artifact`, and `Tools: Upload x-cli artifact` (or the publish-plan tasks) to exercise the staging/QA/upload flow. These scripts automatically pick up the vi-compare bundles produced during validation.

Codex agents should always use the x-cli workflows (or Invoke-XCliWorkflow helper) instead of invoking the PowerShell scripts directly; the helper sets the required env vars and reduces drift between local runs and CI.

> Root-agent shim: `tools/codex/Invoke-LabVIEWOperation.ps1 -Operation <scenario> -RequestPath <json>` is a thin wrapper over `Invoke-XCliWorkflow.ps1`. Feed it the scenario name (`vi-compare`, `vi-analyzer`, `vipmcli-build`, `vipm-apply-vipc`, `ppl-build`) and the JSON payload, and it dispatches the correct x-cli subcommand — no additional LabVIEW/vipmcli reasoning required.

### Release gate
- `tools/validation/Invoke-AgentValidation.ps1 -PlanPath configs/validation/agent-validation-plan.json` runs the canonical validation matrix (compare, analyzer, vipmcli apply/build, PPL). Use the VS Code task “Release: Validate LabVIEW agent” before cutting a release.
- `.github/workflows/agent-validation.yml` runs the same script for every PR/push to `release/*` or `rc/*` branches on a self-hosted Windows runner. Make this workflow a required status check so no release-candidate merge happens without a green validation plan.

## Reference artifact: `vi-compare-19121405725.zip`
The historical bundle we are mirroring lives at `C:\codex\home\runner\work\icon-editor-lab\vi-compare-19121405725.zip`. It unpacks to:

```
vi-diff-manifest.json
vi-compare-artifacts/
└── compare/
    └── pair-01/
        ├── _agent/
        │   └── labview-pid.json
        ├── cli-images/
        │   ├── cli-image-00.png
        │   ├── cli-image-01.png
        │   ├── cli-image-02.png
        │   └── cli-image-03.png
        ├── compare-report.html
        ├── compare-report_files/
        │   ├── 0_0_1.png
        │   ├── 0_0_2.png
        │   ├── 1_0_0_3849_1.png
        │   ├── 1_0_0_3849_2.png
        │   └── support/
        │       ├── checked-image.png
        │       ├── style.css
        │       └── unchecked-image.png
        ├── lvcli-stdout.txt
        ├── lvcli-stderr.txt
        └── lvcompare-capture.json
```

Key takeaways for future bundles:
- `vi-diff-manifest.json` summarizes the requested pairs and should match the request payload sent to `Invoke-ViCompareLabVIEWCli.ps1`.
- Each `pair-XX` folder contains the LVCompare HTML report, capture JSON, CLI screenshots, and raw stdout/stderr logs. Ensuring these files exist for every pair is the success criterion for the Stage/Test pipeline.
- The `_agent/labview-pid.json` crumb captures host runtime metadata (PID, timestamps) and shall accompany the session bundle for traceability.

When `tools/Bundle-ViCompareSession.ps1` runs (either directly or via the `Tools: Bundle vi-compare session` task), it copies the latest validation bundle from `.tmp-tests/xcli-stage/<channel>/<stamp>/<stamp>-vi-compare-session.zip` into a top-level `vi-compare-<stamp>.zip`, replicating the structure shown above. Use `vi-compare-19121405725.zip` as the canonical reference when reviewing bundle completeness.

## VI compare replay (local scenario)
- Use the VS Code task `Tools: Replay VI compare scenario` to run `tools/icon-editor/Replay-ViCompareScenario.ps1`.
- Default scenarios:
    - `${workspaceFolder}/scenarios/sample/vi-diff-requests.json` (MissingInProject smoke pair).
    - `${workspaceFolder}/scenarios/vi-attr/vi-diff-requests.json` (attribute change harness copied from `compare-vi-cli-action/fixtures/vi-attr`).
- Task prompts for the VI compare noise profile (`full`, `reduced`, or `none`) and individual LVCompare suppression switches (`-noattr`, `-nofp`, `-nofppos`, `-nobd`, `-nobdcosm`); the selected values are surfaced in the replay summary and bundled artifacts.
- Outputs land in `.tmp-tests/vi-compare-replays/<name>`; bundle zip is written to `.tmp-tests/vi-compare-bundles/vi-compare-<name>.zip`.
- VI compare replay requires LabVIEW 2025 (or newer) because VI Comparison reports are only generated by 2025+ builds.
- The CLI probe validates LabVIEW 2025 readiness by reading `LocalHost.LibraryPaths` in `LabVIEW.ini`. Dev-mode shall map the repo root directly (e.g., `C:\codex\home\runner\work\icon-editor-lab`). Missing or mismatched entries shall force replay into dry-run with a remediation warning.
- When x-cli executes real LabVIEW dev-mode operations (`labview-devmode-*` subcommands), it now enforces the same `LocalHost.LibraryPaths` requirement. Runners shall provide `XCLI_LABVIEW_INI_PATH` (pointing at the active LabVIEW install) and ensure the repo root matches `XCLI_LOCALHOST_REQUIRED_PATH`/`--lvaddon-root`; otherwise x-cli aborts with a remediation error before attempting the operation.
- x-cli exposes `vi-compare-verify --summary <path>` to inspect the generated `vi-comparison-summary.json`, locate each `compare-report.html`, and ensure the “Included Attributes” list reflects the requested suppression flags (checked when included, unchecked when ignored). Use this command to gate fully suppressed compare runs (e.g., verifying all ignorables are unchecked in the HTML).
- For NI VI Analyzer coverage, x-cli provides `vi-analyzer-verify --labview-path <path>` which shells into `LabVIEWCLI.exe` with the RunVIAnalyzer operation. It requires the LabVIEW install path (folder or `LabVIEW.exe`) and fails with a remediation message when the CLI/analyzer plug-in is missing, ensuring analyzer runs only execute on provisioned machines.
- Analyzer suites can be driven entirely through x-cli via `vi-analyzer-run --request <json>`. The request describes the config, output root, LabVIEW version/bitness, and optional report/result paths; x-cli resolves the repo root, launches `Invoke-VIAnalyzer.ps1`, and emits the resulting `vi-analyzer.json` in the command output. Provide `XCLI_ALLOW_PROCESS_START=1` (and optionally `XCLI_REPO_ROOT`) when invoking real runs.
- VI compare execution now lives behind `vi-compare-run --request <json>`, which shells into `Replay-ViCompareScenario.ps1`, honors suppression flags/noise profiles, and emits the `vi-comparison-summary.json` + bundle metadata. Use this command (instead of manually calling the PowerShell helper) whenever Codex/CI should compare real VIs.
- vipmcli/g-cli orchestration now flows through x-cli as well:
  - `vipm-apply-vipc --request <json>` calls `Replay-ApplyVipcJob.ps1` with the requested workspace, VIPC path, and toolchain (g-cli or vipmcli) so dependency installs can be replayed locally and in CI.
  - `vipm-build-vip --request <json>` launches `Replay-BuildVipJob.ps1`, letting runners rebuild VI Packages via the g-cli/vipmcli toolchains with the same inputs as the GitHub job (release notes, provider overrides, and build inputs.).
- `vipmcli-build --request <json>` wraps `Invoke-VipmCliBuild.ps1`, enabling local/CI vipmcli builds (sync vendor fork, apply VIPCs, run the vipmcli build) with the same version/build inputs as automation.
- `ppl-build --request <json>` targets `.github/actions/build-lvlibp/Build_lvlibp.ps1` so packed project libraries (lvlibp) can be rebuilt per bitness straight from x-cli, independent of the larger vipmcli workflow.
- Codex entry point: `tools/codex/Invoke-XCliWorkflow.ps1` wraps all request-driven subcommands (`vi-compare-run`, `vi-analyzer-run`, `vipm-apply-vipc`, `vipm-build-vip`, `vipmcli-build`, `ppl-build`, stage/test/promote/upload flows), so agents simply edit a JSON template and run the helper (`pwsh … Invoke-XCliWorkflow.ps1 -Workflow vi-compare-run -RequestPath configs/vi-compare-run-request.json`).
- Each request JSON lives under `configs/` (sample files provided) and can be triggered via the corresponding VS Code tasks or directly via `dotnet run … -- vipm-apply-vipc|vipm-build-vip`.
