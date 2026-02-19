# CI Debt Remediation Playbook

This playbook is the deterministic remediation guide used by CI debt analysis.

## Signature: `powershell-lint.git-missing`
- Symptom: `PowerShell Lint` fails with `git was not found on PATH`.
- Detection rule: Job contains one of the signature fragments in `signatures.json`.
- Fix: Install `git` and ensure PATH setup is correct in the failing environment.
- Prevention: `CI Debt Policy Gate / Root Cause Contract` rejects legacy git-shim assumptions in critical scripts.

## Signature: `powershell-lint.new-issues`
- Symptom: `PowerShell Lint` reports newly introduced PSScriptAnalyzer findings.
- Detection rule: Lint log contains `New PSScriptAnalyzer issues detected` / baseline failure fragments.
- Fix: Rename/refactor offending functions or code paths to satisfy analyzer rules, then rerun lint.
- Prevention: Keep analyzer-clean changes in PRs and update baseline only through approved baseline update flow.

## Signature: `verify-iepaths.setup-failed`
- Symptom: `Verify IE Paths Gate` fails during setup and no clear reason is surfaced.
- Detection rule: Setup/fallback/exit fragments detected in the gate job log.
- Fix: Emit classified setup diagnostics and always upload `verify-iepaths` artifact.
- Prevention: `CI Debt Policy Gate / Root Cause Contract` requires setup diagnostics contract in `ci-composite.yml`.

## Signature: `pipeline-contract.cascade-failure`
- Symptom: `Pipeline Contract` fails with mixed root cause and cascaded statuses in one opaque line.
- Detection rule: Contract failure fragments plus upstream failure references.
- Fix: Emit `Required job verdict`, `Root-cause failures`, and `Cascaded/skipped jobs` explicitly.
- Prevention: `CI Debt Policy Gate / Root Cause Contract` validates contract output markers in workflow definition.

## Training Loop
1. Capture run evidence (`Invoke-CiDebtAnalysis.ps1`) for failing run IDs.
2. Match incidents against signatures.
3. If an incident is unknown, add:
- one new signature entry,
- one fixture update,
- one playbook entry.
4. Re-run fixture tests before closing remediation PR.
