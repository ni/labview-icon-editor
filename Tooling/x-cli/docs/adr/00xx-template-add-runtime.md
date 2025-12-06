# ADR 00xx: Add <Runtime/Tool> to Base Image

- **Status:** Proposed
- **Date:** YYYY-MM-DD
- **Deciders:** x-cli maintainers
- **Tags:** environment, runtime

## Context
- Who needs it (agents/repos)?
- Why setup-time install is insufficient (performance? reliability? security?)

## Decision
- Version(s) to pin
- Expected path(s)/env vars
- Image size impact, security considerations, ownership for updates

## Alternatives
- Setup-time install in agent
- Separate utility image
- Do nothing

## Rollout
- Publishing plan
- Upgrade cadence / deprecation policy
- Validation steps

## Traceability
- Affected SRS IDs:
- Related tests:
- Register new requirements via `src/SrsApi`.

## Consequences
- Pros/cons and risks
