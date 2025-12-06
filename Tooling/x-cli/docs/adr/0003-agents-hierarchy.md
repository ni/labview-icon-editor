# ADR 0003: AGENTS Hierarchy

- Status: Accepted
- Date: 2025-09-01
- Deciders: x-cli maintainers
- Tags: process, governance

## Context
`AGENTS.md` at the repository root defines the canonical contract for autonomous agents. Subdirectories sometimes need additional guidance or exceptions. Without a documented hierarchy, updates to the root contract can drift from subordinate `AGENTS.md` files and confuse contributors.

## Decision
- The root `AGENTS.md` is the authoritative source for agent instructions.
- Nested `AGENTS.md` files may **extend** or **override** the root contract for files within their directory tree.
- When instructions conflict, the most deeply nested `AGENTS.md` takes precedence.
- Whenever the root contract changes, maintainers MUST:
  - Review all subordinate `AGENTS.md` files.
  - Update or reaffirm each subordinate file so its guidance remains consistent with the root contract.
  - Document any extensions or overrides explicitly.

## Consequences
- Clarifies how nested `AGENTS.md` files interact with the canonical contract.
- Requires ongoing maintenance to keep subordinate files aligned after root changes.
- Reduces ambiguity for contributors working in scoped directories.

## References
- [AGENTS Contract Quickstart](../agents-contract.md#quickstart)
