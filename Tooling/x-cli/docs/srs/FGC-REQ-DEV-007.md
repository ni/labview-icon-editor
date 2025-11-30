# FGC-REQ-DEV-007 - Model and dataset version control
Version: 1.0

## Description
The repository shall version control model training assets. Small metadata—text or configuration files with an uncompressed size of ≤1 MiB (1,048,576 bytes)—shall reside in Git. Large artifacts—binary assets exceeding 100 MiB (104,857,600 bytes)—shall use Git LFS or an external registry. Files between 1 MiB and 100 MiB may remain in Git but Git LFS is recommended to avoid repository bloat. Dataset snapshots stored outside the repository shall record SHA-256 checksums. Size thresholds use mebibytes (MiB; 1 MiB = 1,048,576 bytes). Commit summaries, tags, and metrics files capture context for each validated model.

## Rationale
Consistent versioning ensures reproducibility and traceability of model artifacts across environments.

## Verification
Method(s): Test | Demonstration | Inspection
Acceptance Criteria:
- AC1. Objective pass/fail evidence exists for RQ1.

## Statement(s)
- RQ1. The system shall manage models and datasets according to docs/model-version-control.md.

## Attributes
Priority: Medium
Owner: QA
Source: Team policy
Status: Proposed
Trace: docs/model-version-control.md
