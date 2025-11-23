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
- Standards and policies teams must follow.

**Good practice**
- Keep decisions small and focused; prefer several small ADRs to one omnibus record.
- Tie each ADR to requirements and tests (traceability).
- Record consequences and rollback up front.
- Use measurable success criteria.
- Cross‑link related ADRs and issues.

See `adr-template.md` for the full template and `adr-template-lite.md` for a 1‑page version.
