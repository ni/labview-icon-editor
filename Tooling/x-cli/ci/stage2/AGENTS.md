Status: Active
Normative scope: Stage 2 – GitHub-hosted Ubuntu runner
Hard dependency: MUST publish artifacts and manifest consumed by Stage 3.

Stage 2 — Execution Steps (Normative)
| Step | Description | Success Criteria |
| ---- | ----------- | ---------------- |
| 1. Build & Test | Build solution and run tests (e.g., `dotnet build XCli.sln -c Release`, `dotnet test XCli.sln -c Release`). | Build and tests succeed; telemetry recorded. |
| 2. Publish artifacts | Produce linux-x64 and cross-published win-x64 binaries, normalized to `dist/x-cli-*`. | `dist/x-cli-linux-x64` and `dist/x-cli-win-x64` exist. |
| 3. Smoke test win-x64 | Run the cross-published `win-x64` binary under Wine (`wine dist/x-cli-win-x64 --version`); record outcome in `telemetry/summary.json` and emit a warning if it fails. | `telemetry/summary.json` field `win_x64_smoke` set to `success`; warning logged on failure. |
| 4. Generate manifest | Create `telemetry/manifest.json` with repo-relative paths and SHA-256 for required artifacts and `telemetry/summary.json`. Fail if `telemetry/summary.json` is missing. See [manifest integrity](../../docs/telemetry.md#manifest-integrity). | Manifest lists required entries with checksums. |
| 5. Validate manifest (gate) | Run `ci/stage2/validate-manifest.sh` after manifest generation and before uploading artifacts. | Job fails if `telemetry/manifest.json` is missing, malformed, missing required fields, or references nonexistent files. |
| 6. Upload artifacts | Upload `dist/` and `telemetry/` bundles for Stage 3. | Artifacts available for Stage 3 download. |

Gating rule: Stage 2 FAILS if `telemetry/summary.json` is missing or `telemetry/manifest.json` is missing, malformed, or required artifacts are absent.
Smoke test failures do not gate the job but trigger a warning and mark `win_x64_smoke` as `failure` in telemetry so Stage 3 can rebuild natively.
<a id="sec-requirements"></a>
Requirements (IDs)
ID      Requirement
AGENT-REQ-ART-002       Stage 2 SHALL produce telemetry/manifest.json containing repo‑relative paths and SHA‑256 checksums for required artifacts/telemetry.
