# Editor Position Automated Test Procedure (ISO/IEC/IEEE 29119-3 §8.4)

- Procedure ID: `PRO-AUTO-EDITORPOS-001`
- Applicable requirements: UT-002, NF-002
- Test case specification: `docs/testing/specs/editor-position-tcs.md`
- Executor: automation (self-hosted LabVIEW runner)

## Start Conditions
- Environment: LabVIEW 2021 on `test-2021-x64` and `test-2021-x86`; repository checked out at target commit.
- Pre-conditions: clean INI/config state for the editor; virtual display bounds set to defaults; no stale persisted coordinates.
- Data: fixture INI states for in-bounds, out-of-bounds, oversized, and corrupt entries.

## Procedure Steps (ordered)
1) Run `Test/Unit Tests/Editor Position/Test Window Position.vi` on x64, then x86 using clean INI.
2) Run `Test/Unit Tests/Editor Position/Position Out of Bounds Test.vi` on x64, then x86 using invalid/corrupt INI inputs.
3) Capture resulting persisted coordinates after each test; store logs and `test-results.json`.
4) Map observed behavior to coverage items P1–P7 in `docs/testing/specs/editor-position-tcs.md` (in-bounds, negative origin, oversized, edge proximity, corrupt/missing values, resolution change, cross-session durability).

## Expected Results
- Positions and sizes are clamped within the active work area; defaults applied when inputs are corrupt; no drift across runs or resolutions.

## Stop / Wrap-up
- Stop criteria: suite completion or first blocking defect.
- Wrap-up: archive logs, persisted INI snapshots, and `test-results.json`; update status/completion report; attach artifacts to PR/tag run.
