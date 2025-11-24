# CLA Signing Process

This process explains how a contributor gets cleared to contribute (for all repos that use the org-level CLA gate).

## For contributors
1) Open a CLA intake issue using the `CLA Intake` template.  
2) Fill in: GitHub handle, CLA type (individual/corporate), CLA version, signed-on date (YYYY-MM-DD), evidence link/ID, and contact email (optional).  
3) Wait for a CLA Reviewer to verify and update the manifest. You’ll be notified when it’s done.  
4) After your entry is active in the manifest, open or re-run your PR; the `cla-gate` check will pass.

## For CLA reviewers
1) Validate the evidence and identity in the intake issue.  
2) Add or update the contributor entry in the org-level `cla-manifest` (required fields: `github`, `cla_type`, `cla_version`, `signed_on`, `status`, `evidence_ref`).  
3) Keep `status=active` only when verified. If a newer CLA replaces the prior one, set the old entry to `status=superseded` and add the new entry/version as `status=active`. Use `status=inactive` only for identity corrections (e.g., wrong handle) or terminated corporate coverage.  
4) Merge the manifest change via PR (CODEOWNERS + branch protection apply).  
5) Reply on the intake issue to confirm activation (or request fixes).

## Enforcement checkpoints
- PRs: `cla-gate` fails if the PR author or any non-bot commit author lacks an active entry.  
- Issue assignment (soft): triage may add `needs-cla` and share this process; no code review until CLA is active.  
- Branch protection: protected branches require `cla-gate` to pass before merge.

## Notes
- CLA applies org-wide for all repos using `cla-gate`.  
- Evidence refs point to storage outside the repo; do not attach signed documents here.  
- The CLA is treated as irrevocable for contributions; do not honor “withdraw” requests—use `superseded` for new versions, and reserve `inactive` for identity fixes or corporate termination.
- If a handle changes or is duplicated, update the manifest and note the change in the intake issue.
