# Requirements Traceability Matrix (pilot)

| ID | Section | Text | Priority | Verification (primary) | Downstream |
| --- | --- | --- | --- | --- | --- |
| TRW-001 | 9.1 Workflow Triggering & Scope | The workflow shall run only in response to a workflow_run of CI Pipeline. | High | Inspection (Inspection, Demonstration) | .github/workflows/draft-release.yml |
| TRW-002 | 9.1 Workflow Triggering & Scope | The workflow shall proceed only when workflow_run.conclusion == success. | High | Test (Test) | .github/workflows/draft-release.yml |
| TRW-003 | 9.1 Workflow Triggering & Scope | The workflow shall proceed only when the upstream event is push. | High | Test (Test) | .github/workflows/draft-release.yml |
| TRW-004 | 9.1 Workflow Triggering & Scope | The workflow shall evaluate head_branch against an allow-list (main, develop, release-alpha/*, release-beta/*, release-rc/*) with configurable extensions. | High | Analysis (Analysis, Test) | .github/workflows/draft-release.yml |
| TRW-005 | 9.1 Workflow Triggering & Scope | For branches outside the allow-list, the workflow shall terminate as a no-op and perform no tag or release. | High | Test (Test) | .github/workflows/draft-release.yml |
| TRW-006 | 9.1 Workflow Triggering & Scope | The workflow shall ensure at most one run per commit SHA using a concurrency group keyed by the SHA. | High | Inspection (Inspection, Demonstration) | .github/workflows/draft-release.yml |
| TRW-006B | 9.1 Workflow Triggering & Scope | When a new run starts for the same commit SHA, cancel any in-progress run (cancel-in-progress policy). | High | Inspection (Inspection, Demonstration) | .github/workflows/draft-release.yml |
| TRW-006C | 9.1 Workflow Triggering & Scope | The workflow shall log the configured concurrency policy (including group) at start for traceability. | High | Inspection (Inspection, Demonstration) | .github/workflows/draft-release.yml |
| TRW-010 | 9.2 Versioning & Bump Logic | The workflow shall compute next version from last reachable tag, parsed semver, and commit count as BUILD. | High | Analysis (Analysis, Test) | .github/actions/compute-version |
| TRW-011 | 9.2 Versioning & Bump Logic | When no previous tag exists, the base version shall default to 0.1.0 before bump rules. | Medium | Test (Test) | .github/actions/compute-version |
