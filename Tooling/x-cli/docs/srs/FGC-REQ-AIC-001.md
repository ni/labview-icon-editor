# FGC-REQ-AIC-001 - Two-way Codex<->LLM handshake via ChatOps
Version: 1.1

## Statement(s)
- RQ1. The CI system shall expose a ChatOps command `/codex <verb>` that accepts user prompts and posts LLM replies in the same issue or pull-request thread.
- RQ2. The CI system shall provide a `/codex policy` command that reports allowed users, required label, allowed path globs, maximum patch lines, and a reference to `.codex/README.md`.

## Rationale
Establishes a foundation for mirrored AI CI using prompt engineering in a controlled, auditable channel.

## Verification
Method(s): Demonstration | Inspection
Acceptance Criteria:
- AC1. Commenting `/codex ping` yields `pong` in the same thread.
- AC2. Commenting `/codex say hello` yields an LLM response posted as a new comment.
- AC3. Commenting `/codex policy` yields a policy summary listing allowed users, required label, allowed globs, maximum patch lines, and a link to `.codex/README.md`.

## Attributes
Priority: High
Owner: DevOps
Source: Team policy
Status: Proposed
Trace: `.github/workflows/codex-2way.yml`, `scripts/codex_bridge.py`, `.codex/system/codex-bridge.md`
