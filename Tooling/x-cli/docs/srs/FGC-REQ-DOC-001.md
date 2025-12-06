# FGC-REQ-DOC-001 - Single source of truth for process docs
Version: 1.0

## Statement(s)
- RQ1. The project shall maintain a **single canonical copy** of the Waterfall process documentation.
- RQ2. The project shall maintain a **single canonical copy** of the Agents contract.
- RQ3. Any secondary copies shall be marked as stubs that point to the canonical file.

## Rationale
Prevents drift and confusion from duplicated docs; aligns with contract-grade documentation and traceability.

## Verification
Method(s): Demonstration | Inspection
Acceptance Criteria:
- AC1. `docs/WATERFALL.md` contains required anchors and is referenced by a stub `WATERFALL.md` at the repository root.
- AC2. `/AGENTS.md` is canonical and `docs/AGENTS.md` is a short stub that clearly points to `/AGENTS.md`.
- AC3. Workflow **Docs — Canonical Sources Gate** passes on PRs; it fails if an additional canonical copy appears or a stub diverges from the template.

## Attributes
Priority: High
Owner: DevEx
Status: Proposed
Trace: `.github/workflows/docs-canonical-gate.yml`, `scripts/check_docs_canonical.py`, `tests/test_docs_canonical.py`
