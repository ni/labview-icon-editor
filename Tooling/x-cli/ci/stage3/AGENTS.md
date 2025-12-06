Status: Active
Normative scope: Stage 3 – Self-hosted Windows
Hard dependency: MUST consume Stage 2 artifacts and manifest.

Stage 3 — Execution Steps (Normative)
Step | Description | Success Criteria
---- | ----------- | ----------------
0. Gate | Ensure `telemetry/manifest.json`, `telemetry/summary.json`, and `dist/x-cli-win-x64` exist; run `scripts/validate-manifest.ps1` to verify SHA-256 against the manifest. | Gate passes only if files exist and checksums match; otherwise job fails fast.
1. Validation | Verify Windows runner prerequisites (.NET SDK, PowerShell modules). | All pre-checks pass.
2. Test | Run Windows unit/integration tests and smoke test the Stage 2 cross-published `win-x64` artifact. If `telemetry/summary.json` reports `win_x64_smoke: failure` or platform-specific changes (e.g., new P/Invoke bindings) are detected, rebuild natively on Windows and emit a warning. | Tests and smoke PASS; rebuild triggered when criteria met.
3. Telemetry diff & publish (dry‑run by default) | Compute diff vs previous telemetry stored in `telemetry/history` (bootstrap if none) and write diagnostics. Stage 3 defaults to dry‑run (no Discord post). When explicitly enabled (e.g., `DISCORD_PUBLISH == '1'` with a valid webhook), a summary MAY be posted. | Diff stored in `telemetry/history` or baseline established; diagnostics saved; optional Discord post when gated.

Gating rule: Stage 3 fails immediately if required artifacts are missing or checksum verification fails.
Native rebuild criteria:
- Stage 2 telemetry marks `win_x64_smoke` as `failure`.
- Platform-specific changes require validation beyond cross-published binaries.
<a id="sec-requirements"></a>
Requirements (IDs)
ID      Requirement
AGENT-REQ-DEP-001       Stage 3 SHALL run only after Stage 2 completes successfully (e.g., `needs: stage2_ubuntu_ci` or `if: github.event.workflow_run.conclusion == 'success'`) and MUST fail if telemetry/manifest.json or telemetry/summary.json or dist/x-cli-win-x64 is absent/invalid at Step 0: Gate.
AGENT-REQ-TEL-003       Stage 3 SHALL compute/persist a statistical comparison vs previous telemetry; on first run it SHALL bootstrap a baseline.
AGENT-REQ-NOT-004       Stage 3 SHALL default to dry‑run and SHALL surface gating state (`publish`/`webhook`) in the job summary. When explicitly enabled and a webhook is present, it MAY post a run summary including pass/fail, regressions, and links to artifacts.
