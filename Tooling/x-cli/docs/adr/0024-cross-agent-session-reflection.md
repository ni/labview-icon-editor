# ADR 0024: Cross-Agent Session Reflection

- Status: Accepted
- Date: 2025-09-27
- Deciders: x-cli maintainers
- Tags: agents, telemetry, process

## Context
Codex agents contribute in multiple sessions. Each session already emits a
mandatory “Cross‑Agent Telemetry Recommendation” block (per AGENTS contract).
However, we lack an explicit, lightweight practice to reflect on prior agents’
recommendations without biasing the current one.

## Decision
Introduce an ongoing “Cross‑Agent Session Reflection” practice:
- Each session first records its own “Cross‑Agent Telemetry Recommendation”.
- Only after writing its own recommendation, the agent briefly reviews the most
  recent prior recommendation(s) and records a short “Session Reflection”.
- Reflections capture agreements, deltas, and concrete next tweaks to the
  tooling/process (non‑blocking, 3–5 bullets max).

## Rationale
- Prevents anchoring on previous advice; preserves fresh signal.
- Creates a compact continuity thread across sessions without adding heavy
  ceremony or new gates.
- Supports incremental improvement of shared helpers (workflows, scripts,
  schemas) while keeping PRs focused.

## Implementation
- PR template: add a “Cross‑Agent Session Reflection” subsection reminding
  contributors to write their own recommendation first, then reflect.
- Optional: store reflections in `artifacts/` or PR body only; no gating.
- Aggregation: existing preview/sessions Markdown tooling may render reflection
  snippets in future reports (out of scope here).

## Consequences
- Clearer audit trail of how advice evolves across sessions.
- Minimal additional author effort; no CI gate added.

## Traceability
- Supports AGENTS Contract § Cross‑Agent Telemetry.
