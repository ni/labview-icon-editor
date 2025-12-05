# Architecture Decision Records (ADR) — Conventions

**Where**: keep ADRs in `docs/adr/`. One ADR per file, immutable after acceptance except for status header and change log.

**Naming**: `ADR-YYYY-NNN-title.md` (e.g., `ADR-2025-001-use-oidc.md`).

**Status lifecycle**
- **Proposed** — PR open for review.
- **Accepted** — merged after consensus (or decision authority sign‑off).
- **Rejected** — documented and closed.
- **Deprecated** — discouraged for new work; still in effect somewhere.
- **Superseded** — replaced by another ADR (link both ways).

**When to write an ADR**
- Choosing significant technologies, patterns, protocols, data models.
- Changes that affect quality attributes (security, reliability, performance, maintainability, cost).
- Standards and policies teams shall follow.

**Good practice**
- Keep decisions small and focused; prefer several small ADRs to one omnibus record.
- Tie each ADR to requirements and tests (traceability).
- Record consequences and rollback up front.
- Use measurable success criteria.
- Cross‑link related ADRs and issues.

See `adr-template.md` for the full template and `adr-template-lite.md` for a 1‑page version.

## Catalog
- ADR-2025-001 - [Adopt ADRs and repository-root `agent.yaml`](ADR-2025-001-adopt-adrs-agent-yaml.md).
- ADR-2025-002 - [CLA gate enforcement and manifest handling](ADR-2025-002-cla-gate-enforcement.md).
- ADR-2025-003 - [Bind/Unbind LabVIEW Development Mode via Composite Helper](ADR-2025-003-dev-mode-composite-helper.md).
- ADR-2025-004 - [Agent-Only Dev-Mode Intent Shim](ADR-2025-004-dev-mode-intent-shim.md).
- ADR-2025-005 - [Integration Engine CLI entrypoint and managed mode](ADR-2025-005-integration-engine-cli.md).
- ADR-2025-006 - [VIPB JSON tool](ADR-2025-006-vipb-json-tool.md).
- ADR-2025-007 - [LVPROJ JSON tool](ADR-2025-007-lvproj-json-tool.md).
- ADR-2025-008 - [Requirements Summarizer](ADR-2025-008-requirements-summarizer.md).
- ADR-2025-009 - [DevMode Agent CLI](ADR-2025-009-dev-mode-agent-cli.md).
- ADR-2025-010 - [Centralized log stash for build/test workflows](ADR-2025-010-log-stash.md).
- ADR-2025-011 - [Repository layout and tooling placement](ADR-2025-011-repo-structure.md).
- ADR-2025-012 - [x-cli staged publish, RunnerProfile gating, and VI compare artifacts](ADR-2025-012-xcli-staged-publish-and-vi-compare.md).
- ADR-2025-013 - [Common probe/build/cache strategy for repo CLIs](ADR-2025-013-common-probe-build-cache.md).
- ADR-2025-014 - [LabVIEW Source Distributions manifests and verification](ADR-2025-014-labview-source-distributions.md).
- ADR-2025-015 - [Source Distribution → PPL orchestration via OrchestrationCLI](ADR-2025-015-sd-ppl-labviewcli-orchestration.md).
- ADR-2025-016 - [Bundle minimal tooling in Source Distribution for VS Code use](ADR-2025-016-tooling-included-in-source-distribution.md).
- ADR-2025-017 - [Ollama locked executor for scripted builds](ADR-2025-017-ollama-locked-executor.md).
- ADR-2025-018 - [Automate self-signed TLS cert generation for App Gateway backends](ADR-2025-018-appgw-selfsigned-automation.md).
