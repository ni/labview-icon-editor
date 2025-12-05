# ADR-2025-015: Source Distribution → PPL orchestration via OrchestrationCLI (LabVIEWCLI + g-cli bind)

## Status
Accepted

## Context
- We need a single flow to build the Source Distribution, then build the Editor Packed Library (PPL) from that SD, without manual steps.
- LabVIEWCLI is required for build specs; g-cli is preferred for bind/unbind (LocalHost.LibraryPaths) but should not drive builds in this flow.
- Prior ad-hoc scripts/tasks caused collisions (stale XCli, temp dir confusion, overlapping LabVIEW instances).
- We also want clear logging, temp hygiene, and a way to switch the runner (g-cli vs LabVIEWCLI) when needed.

## Decision
Add a new OrchestrationCLI subcommand (`sd-ppl-lvcli`) that:
- Uses g-cli **only** for bind/unbind of LocalHost.LibraryPaths.
- Uses **LabVIEWCLI** for both builds:
  - Build spec: “Source Distribution” (lv_icon_editor.lvproj, target “My Computer”).
  - Build spec: “Editor Packed Library” (same project/target, optionally against the extracted SD).
- Runs all phases **serially** with a per-run lock/guard to avoid concurrent LabVIEWCLI/g-cli activity.
- Enforces a **standard temp/log** location per run (user-local temp subfolder) and ensures log/extract dirs exist; fails fast if temp/log cannot be created. Supports overrides for LabVIEWCLI/LabVIEW path/port and temp/log roots. For packaged SD use, we expect callers to have short roots `C:\t` (temp/log/extract) and `C:\w` (worktrees) present and writable; the flow shall fail fast if they are missing/unwritable.
- Creates an **isolated git worktree** from the current HEAD under the temp root, runs the SD and PPL builds in that worktree, then copies Source Distribution/artifacts/PPL outputs back to the main repo before removing the worktree.
- After each build, calls QuitLabVIEW/close to release INI/VI references before the next phase.
- Binds/unbinds between contexts to avoid token conflicts (repo → extracted SD).
- Injects the pristine repo `lv_icon_editor.lvproj` into the Source Distribution before zipping (ignoring aliases/lvlps) so downstream consumers see an unchanged project file.
- When extracting, copies `scripts/` and `Tooling/` into the SD so the PPL build can run in-place from the artifact; creates the zip from the built Source Distribution if missing.
- Emits guardrails and observability: logs provenance (repo, CLI path, git SHA, RID), validates repo (.git present, not under Program Files), prunes stale locks before acquiring a new one, and keeps clear phase/heartbeat/duration logs (with LabVIEWCLI log paths).
- Optionally writes log-stash entries.
- Allows runner selection in VS Code via `sourceDistRunner` input; defaults to g-cli for x-cli flows, but this subcommand shall use LabVIEWCLI for builds by default.

## Implementation sketch
Subcommand flow (OrchestrationCLI):
0) Fail fast if repo is missing, lacks `.git`, or lives under Program Files; log provenance; clear stale lock (dead PID or >2h old).
1) Acquire lock; set TMP/TEMP/TMPDIR to standard temp folder.
2) Unbind current repo (g-cli bind/unbind helper).
3) Create isolated git worktree from current HEAD under `%TEMP%/labview-icon-editor/worktrees/<stamp>` (or fixed `C:\w` when provided/required; force-delete if exists; refuse reuse unless forced).
4) Bind worktree repo (g-cli).
5) Detect LabVIEW version **and bitness from the worktree VIPB**; resolve LabVIEW.exe and VI-server port for that pairing.
6) LabVIEWCLI `ExecuteBuildSpec` “Source Distribution”; log to temp/logs.
7) Quit LabVIEW/close via LabVIEWCLI; unbind worktree (g-cli).
8) Refresh Source Distribution contents with the pristine main-repo `lv_icon_editor.lvproj` (ignore aliases/lvlps), then ensure `builds/artifacts/source-distribution.zip` exists (zip the worktree Source Distribution if missing).
9) Extract zip to temp/extract (short root such as `C:\t\extract`); copy scripts/Tooling into the extracted root; flatten nested `w/<worktree>` folders into the extracted root so project references resolve.
10) Bind extracted SD (g-cli).
11) LabVIEWCLI `ExecuteBuildSpec` “Editor Packed Library”; log to temp/logs; close via LabVIEWCLI.
12) Quit LabVIEW/close; unbind extracted SD; copy SD/artifacts/PPL outputs back to the main repo; remove the worktree; release lock; optional temp cleanup.

Inputs:
- `--repo`, optional `--labview-path`, `--port`, `--log-dir` (default: user temp subfolder), `--timeout-sec`, `--allow-dirty`. `sd-ppl-lvcli` derives LabVIEW version/bitness from the VIPB by default; no bitness flag is required. For packaged SD usage, callers are expected to provide or pre-create short roots (`C:\t`, `C:\w`); otherwise the flow falls back to `%TEMP%` with the same short-path constraints.

Outputs:
- SD artifacts under `builds/` (manifest/csv/zip).
- PPL artifacts per build spec.
- Logs in temp/logs; summary/phase durations; provenance and LabVIEWCLI log paths captured; optional log-stash bundle.

## Alternatives considered
- Pure g-cli: rejected (LabVIEWCLI required for these build specs).
- Ad-hoc tasks/scripts: rejected (collision/lock issues, fragmented logging).
- LabVIEWCLI for bind/unbind: not preferred; g-cli remains for token writes.

## Consequences
- OrchestrationCLI grows a new subcommand; VS Code task 20 can point to it for an end-to-end SD→PPL run with a runner toggle.
- Reduced collisions by serializing phases, explicit close, and temp/log standardization.
- Clearer logs and easier CI reuse. 
- Successful runs (LV2021 64-bit): `sd-ppl-lvcli` built Source Distribution, refreshed zip with pristine lvproj, extracted SD with scripts/Tooling copied/flattened, and produced `resource/plugins/lv_icon.lvlibp`; logs under the per-run temp path (e.g., `%TEMP%\labview-icon-editor\sd-ppl-lvcli\20251129-215141757`).
