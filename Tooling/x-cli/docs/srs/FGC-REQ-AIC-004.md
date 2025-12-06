# FGC-REQ-AIC-004 - Safe application of Codex proposals
Version: 1.0

## Statement(s)
- RQ1. On `/codex apply [<id>|latest]`, the agent shall validate the stored patch against path globs.
- RQ2. The agent shall validate the stored patch against file size limits.
- RQ3. The agent shall scan the stored patch for secret-like tokens.
- RQ4. The agent shall run the SRS linter on the stored patch.
- RQ5. The agent shall open a draft PR labeled `codex-proposal` only if validations pass.
- RQ6. The agent shall reject the patch and report diagnostics describing failed checks when any validation fails.

## Rationale
Prevents unsafe or low‑quality changes from entering the codebase, reports diagnostics for failed checks, and still enables rapid iteration.

## Verification
Method(s): Demonstration | Inspection
Acceptance Criteria:
- AC1. Applying a valid proposal creates a new branch, commits the patch, and opens a draft PR with labels `codex-proposal` and `needs-human-review`.
- AC2. A patch that violates the guardrails (size, disallowed path, secret‑like token, or failing SRS lint) is rejected, emits a diagnostic listing the failing validations, and no PR is opened.

## Attributes
Priority: Medium
Owner: QA
Source: Process policy
Status: Proposed
Trace: `.github/workflows/codex-2way.yml`, `scripts/codex_bridge.py`, `scripts/lint_srs_29148.py`
Maintenance: QA updates these attributes via version-controlled commits whenever values change.
