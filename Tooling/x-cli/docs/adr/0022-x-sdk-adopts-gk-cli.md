# ADR 0022: x-sdk adopts GitKraken GK-CLI v3.1.37

- Date: 2025-09-26
- Status: Accepted


## Context
We want the external SDK (x-sdk) to provide a first-class developer experience for multi-repo workflows (work items, commits, PRs) without reinventing basic git plumbing. GitKraken's CLI (GK-CLI) provides a cohesive UX for work items and AI-assisted commit/PR flows and runs on macOS/Windows/Linux.

## Decision
- x-sdk SHALL leverage GitKraken GK-CLI v3.1.37 as the baseline tool for local developer workflows and optional CI checks.
- x-cli remains independent of GK-CLI. The dependency is constrained to the SDK and its docs/samples.
- Integration samples document installation, version pinning, and common commands (`gk auth login`, `gk work create`, `gk work commit --ai`, `gk work push`, `gk work pr create --ai`).

## Consequences
- Devs can use GK-CLI to manage multi-repo work items locally, then use x-sdk to orchestrate x-cli CI stages.
- CI samples may include a lightweight `gk version` check to verify availability but SHALL NOT block pipelines that do not require GK-CLI.

## Notes
- Installation references: Homebrew (macOS), Snap/DEB/RPM (Linux), Winget (Windows), or direct binaries from releases.
- Pin at v3.1.37 initially; future bumps shall update docs and samples together.

## Links
- GK-CLI repository: https://github.com/gitkraken/gk-cli/tree/v3.1.37
- SDK integration docs: `docs/integration/x-sdk/`

