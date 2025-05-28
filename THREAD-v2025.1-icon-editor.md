# THREAD-v2025.1-icon-editor.md

title: "LabVIEW Icon Editor Governance Thread"
version: v2025.1
status: active
created: 2025-05-27
inherits-from: ni/labview-open-source-program THREAD-v2025.1-open-source-program.md

## purpose

Declare governance responsibilities for the LabVIEW Icon Editor as part of the LabVIEW open-source program. Aligns project practices with broader NI open-source policies and LabVIEW-specific tooling needs.

## roles

- **Maintainer**: Oversees code health, merge criteria, and roadmap alignment.
- **Release Lead**: Packages and tags project releases, coordinating with LabVIEW tooling.
- **Governance Contact**: Responds to sentinel checks, watchlist alerts, and policy updates.

## interfaces

- **Tools Consumed**:
  - LabVIEW open-source packaging scripts
  - SPDX license header validator
- **Governance Upstream**:
  - ni/labview-open-source-program

## watch-list

- ni/labview-icon-editor (self)
- Contributions from external collaborators flagged for review

## milestones

- THREAD-v2025.1 committed
- Integrated into labview-open-source-program watchlist
- Governance release `gov-v2025.1-icon-editor` published
- First sentinel scan passed

## notes

Updates to governance should align with THREAD updates upstream. Major shifts in project scope or contributor model require a new THREAD version.

## rules

- Governance-sensitive pull requests (such as those modifying `THREAD-*.md`, `SENTINEL-WATCHLIST.md`, or runbook files) must not be approved by the Program Architect.


