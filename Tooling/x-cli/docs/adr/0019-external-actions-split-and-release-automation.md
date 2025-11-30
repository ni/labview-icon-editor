# ADR 0019: External Actions Split and Release Automation
- Status: Accepted
- Date: 2025-09-26

## Context
We previously hosted composite GitHub Actions inside this repo (PR comment poster, artifacts metadata loader). To enable reuse across repos and prepare for future Marketplace listings, we need independent, versioned distribution with minimal coupling to x-cli.

## Decision
- Split composites into two dedicated repositories and distribute via `@v1` tags:
  - `LabVIEW-Community-CI-CD/gha-post-pr-comment` (label‑gated PR comment action)
  - `LabVIEW-Community-CI-CD/gha-artifacts-metadata` (load run artifacts metadata)
- Add a post‑release workflow in each repo to update README badges/links (quiet mode, retry/backoff). Marketplace slug variables gate the update until listings exist.
- Switch this repo’s workflows to consume the external actions via `@v1` and remove local composites.

## Consequences
- In‑repo composites are removed to avoid duplication; CI references external actions.
- Rolling `v1` tags decouple adopters from patch/minor changes; exact tags remain available.
- Marketplace listing is deferred and tracked by issue #730 with stability/adoption criteria.

## Notes
- README badges and install snippets in x‑cli now point to the two external repos.
- The external repos include CodeQL, CI smoke, and post‑release README update workflows.
