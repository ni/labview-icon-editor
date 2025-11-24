# ADR Overview

This repository uses Architecture Decision Records under `docs/adr/`, named `ADR-YYYY-NNN-title.md`. See `adr-index.md` for catalog and `adr-template*.md` for formats.

## Current ADRs (high level)
- ADR-2025-001-adopt-adrs-agent-yaml: Establishes ADRs + `agent.yaml` as single source of truth for agent behavior and governance.
- ADR-2025-002-cla-gate-enforcement: Org-level reusable CLA gate with manifest-driven checks.
- ADR-2025-003-dev-mode-composite-helper: LabVIEW dev-mode bind/unbind composite with JSON status and Force/dry-run behavior.
- ADR-2025-004-dev-mode-intent-shim: Agent-only dev-mode intent shim (policy/intent layer) that delegates to the existing PowerShell binder; partially implemented and gated.

Use `adr-index.md` for links and status lifecycle.
