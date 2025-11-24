# Tag & Release Trigger Manual Test Procedure (ISO/IEC/IEEE 29119-3 §8.4)

- Procedure ID: `PRO-MAN-TRW-001`
- Applicable requirements: TRW-001
- Test case specification: `docs/testing/specs/trw-tag-release-tcs.md`
- Executor: Automation QA (manual)

## Start Conditions
- Environment: GitHub UI access with permissions to view CI runs; target branch under test available with upstream CI completion.
- Pre-conditions: At least two upstream `CI Pipeline` runs ready—one successful `workflow_run` from an allowed branch and one from a disallowed branch or failed conclusion.
- Data: URLs for upstream runs and corresponding downstream draft-release runs (or reruns).

## Procedure Steps (ordered)
1) Open upstream successful run (allowed branch) and trigger/review downstream draft-release workflow.
2) Verify gating per coverage items R1–R4: event is `workflow_run`; upstream conclusion `success`; upstream event `push`; `head_branch` in allowlist.
3) For disallowed/failed cases, confirm coverage items R5–R7: workflow exits with no tag/release actions, concurrency group prevents duplicate runs per SHA, and artifacts/checklist are present.
4) Capture evidence: screenshots or log excerpts showing gate decisions and any no-op outcomes.

## Expected Results
- Allowed branch with successful upstream run proceeds; disallowed or failed inputs exit safely with diagnostics; concurrency dedupes duplicate runs; TRW checklist artifact present.

## Stop / Wrap-up
- Stop criteria: all coverage items verified or blocking defect recorded.
- Wrap-up: attach evidence to PR/tag run, update `docs/requirements/TRW_Verification_Checklist.md` status, and log defects/waivers as needed.
