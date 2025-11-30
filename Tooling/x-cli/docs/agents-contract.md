# AGENTS Contract Quickstart

The `AGENTS.md` file defines the contract for autonomous contributors. [ADR 0001](adr/0001-agents-contract-hardening.md) records decisions to harden its enforcement, and [ADR 0003](adr/0003-agents-hierarchy.md) clarifies how nested `AGENTS.md` files extend or override root guidance.

## Quickstart
- Read the root [`AGENTS.md`](../AGENTS.md) to understand required metadata and
  workflow.
- Include the **Agent Checklist** and a digest line for every `AGENTS.md` you touch in the PR body.
- Generate each digest line with `./scripts/gen-agent-digest.sh <path>`.
- Follow the commit message template and include the `codex:` metadata line.
- Preventative Measures are generated from `codex_rules`; avoid manual edits.

These rules apply to all files unless a more deeply nested `AGENTS.md` explicitly changes them. If a subdirectory contains its own `AGENTS.md`, follow both sets of instructions; deeper files take precedence over higher-level ones per [ADR 0003](adr/0003-agents-hierarchy.md).

### Example: nested `AGENTS.md` precedence
Suppose you edit `src/util/helpers.cs`. The repository root has an `AGENTS.md`, `src/` contains another, and `src/util/` includes a third. You must honor instructions from all three files, but conflicting guidance is resolved by depth: `src/util/AGENTS.md` overrides `src/AGENTS.md`, which in turn extends the root `AGENTS.md`.

## agents-contract-check workflow

Pull requests run the `agents-contract-check` workflow to verify:

1. The description contains a `## Agent Checklist` section with at least one
   checkbox (`- [ ]` or `- [x]`).
2. Each `AGENTS.md` digest line matches the SHA256 digest of its file. The workflow
   currently validates the root `AGENTS.md`.

### Fixing failures

If a check fails:

- **Checklist missing**: add a `## Agent Checklist` heading to the PR body and
  include at least one checkbox item.
- **Digest mismatch**: generate digest lines and update the PR body:

  ```bash
  ./scripts/gen-agent-digest.sh AGENTS.md
  ./scripts/gen-agent-digest.sh docs/AGENTS.md  # if changed
  ```

  Include each output line exactly in the PR body. Example with multiple files:

  ```
  AGENTS.md digest: SHA256 <root-digest>
  docs/AGENTS.md digest: SHA256 <docs-digest>
  ```

The workflow writes details to `artifacts/agents-contract-validation.jsonl`.
