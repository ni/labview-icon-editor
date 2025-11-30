# Archive — Deprecated Documents

This folder retains documents that no longer apply to the current, minimal x-cli
pipeline. Items here are preserved for historical reference only. They are not
normative and should not be used as implementation guidance.

Why documents move here
- The associated workflows or processes were removed (e.g., legacy orchestration flows).
- Guidance is obsolete, unmaintained, or conflicts with the simplified CI.

Re-introducing content
- Open a PR that proposes moving a file back out of `docs/archive/`.
- Include:
  - A short rationale tied to current needs.
  - SRS/ADR references that govern the behavior.
  - Tests or CI gates proving the behavior is enforced.
- Ownership should align with the Workflow Ownership Matrix in `docs/workflows-inventory.md`.

Tracking issue
- Cleanup plan and owners are tracked in issue #728:
  https://github.com/LabVIEW-Community-CI-CD/x-cli/issues/728

Notes
- Archived docs may point to removed workflows. Treat these as historical context only.
- If a link in the repo points here, consider updating it to the live docs once a
  replacement exists.
