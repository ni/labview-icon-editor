# ADR 0001: Harden AGENTS.md Contract Enforcement

- Status: Accepted
- Date: 2025-08-28
- Deciders: x-cli maintainers
- Tags: process, governance

## Context
`AGENTS.md` defines the normative contract for autonomous agents working in this
repository. Today the contract relies on human diligence; gaps in enforcement
allow drift between intent and practice. Key pain points include:

- Digest of `AGENTS.md` may be omitted or computed inconsistently.
- The Agent Checklist is optional and often forgotten.
- "Preventative Measures" section is empty unless generated manually from
  `codex_rules`.
- Commit messages follow a template but are not validated.

## Decision
Adopt a hardened contract with explicit enforcement hooks:

1. **Digest in PRs** – pull requests MUST include the `AGENTS.md` SHA256 digest
   line as described in the contract. Future CI will reject PRs missing or
   mismatching the digest.
2. **Agent Checklist** – PR bodies MUST contain the full Agent Checklist block.
   Automation will fail if the checklist is absent.
3. **Preventative Measures source** – the `Preventative Measures` section is
   sourced from the auto‑generated `codex_rules` output. Any manual edits will be
   overwritten.
4. **Commit message policy** – commits MUST follow the template defined in
   `AGENTS.md` including summary length and the `codex:` metadata line. A linter
   will enforce the format.

## Consequences
- Strengthens alignment between documentation and practice.
- Requires new CI checks and tooling to validate digests, checklist presence,
  codex rules generation, and commit messages.
- Contributors must compute the digest and include the checklist manually until
  automation is in place.

