# Maintainers Technical Guide

This guide is a technical reference for maintainers working in the LabVIEW Icon
Editor repository. It outlines the workflows and GitHub Actions used to manage
branches, run continuous integration (CI), and finalize releases. In addition to
the steps below, maintainers are expected to triage issues, keep dependencies up
to date, and ensure that published guidance across the repository remains
current.

## Maintainer Responsibilities

- **Issue Triage** – Label new issues, confirm reproduction steps, and mark
  items that are ready for community contribution.
- **Branch Hygiene** – Delete merged branches, keep `develop` rebased on
  `main`, and close stale pull requests after consultation with the author.
- **CI Upkeep** – Periodically review workflow runs and update GitHub Actions
  versions or build scripts when they go out of support.
- **Community Support** – Respond to discussion threads and provide direction
  to contributors in pull requests and issues.

## Feature Branch Workflow

1. Confirm the related GitHub issue is approved for work.
2. Create a branch from `develop` named `issue-<number>-<short-description>`
   (for example, `issue-123-fix-toolbar`). This naming is recommended for
   traceability, but CI no longer requires it.
3. Ensure the branch matches CI trigger patterns and open a pull request targeting
   `develop` (or another appropriate branch).
4. Run unit tests or scripted checks locally whenever possible.
5. Ensure CI passes and obtain at least one maintainer approval before merging.
6. For PRs targeting `develop` that drive prerelease publication, merge with a merge commit (`gh pr merge <pr-number> --merge --delete-branch`) and avoid squash/rebase.
7. After merging, delete the source branch to keep the repository tidy.

## Workflow Administration

- **Approve experiment branches** – When an experiment branch should publish
  artifacts (VIPs), run the `approve-experiment` workflow in GitHub Actions.
  Coordinate with the NI Open-Source Program Manager (OSPM) before execution.
- **Finalize experiment merges** – Prior to merging an experiment branch into
  `develop`, apply exactly one canonical version label (`Version Increment:
  Major`, `Version Increment: Minor`, or `Version Increment: Patch`) and remove
  any temporary settings. Compatibility aliases (`major`, `minor`, `patch`)
  remain accepted during migration. The OSPM or designated NI staff typically
  gives the final approval.
- **Hotfix branches** – For critical fixes on an official release, create or
  approve a `hotfix/*` branch targeting `main`. After merging into `main`, merge
  the changes back into `develop` to keep branches synchronized.
- **Documentation updates** – When workflows change, update related
  documentation in the `/docs` directory as part of the same pull request.

## Stale Issue Automation

- Workflow: `.github/workflows/stale-issues.yml`
- Schedule: daily UTC run plus manual `workflow_dispatch`
- Scope: issues only (`days-before-pr-stale` and `days-before-pr-close` are
  disabled)
- Policy: mark issues stale after 45 inactive days and close after 14
  additional inactive days
- Stale label: `Workflow: Stale` (created/updated automatically before each run)
- Exempt labels:
  - `Workflow: Actively discussing`
  - `Workflow: NI Approves`
  - `Workflow: Requires R&D clarification`
  - `Workflow: Open to contribution`
  - `Issue group: Added to agenda`
  - `good first issue`

Recovery and override:
1. If an issue was marked stale but should stay open, add context in a comment
   or edit the issue; stale status is removed automatically when activity occurs.
2. If an issue was auto-closed but should remain open, reopen the issue and
   add updated context.
3. If a class of issues should never go stale, apply one of the exempt labels
   above (or extend the workflow exempt list in a PR).

Debug-only/manual validation:
- Run `stale-issues.yml` with `debug_only=true` to preview candidates without
  mutation.

## Label Compatibility Policy

- Canonical label taxonomy is immediate:
  - Release: `Version Increment: Major|Minor|Patch`
  - Issue type: `Issue group: Bug`, `Type: Enhancement`
  - Stale lifecycle: `Workflow: Stale`
- Compatibility aliases remain accepted for two release cycles:
  - `major`, `minor`, `patch`, `bug`, `enhancement`
- Alias retirement is documented but not auto-enforced in this phase.
- Use `labels-sync.yml` to create/update contract labels from
  `.github/labels/label-contract.json`.
- Resolve the repository for `gh` commands:
  - `$repo = pwsh -NoProfile -File .\Tooling\Resolve-GitHubRepo.ps1`
  - `GH_REPO` is optional override and takes precedence when maintainers need to target a specific repo.

## Label Metadata Automation

- Daily audit workflow: `.github/workflows/label-metadata-audit.yml`
  - Reports unlabeled PRs/issues, alias-only usage, conflicts, and missing stale
    exempt labels.
  - Uploads JSON artifact: `label-metadata-audit`.
- Event normalization workflow: `.github/workflows/label-metadata-normalize.yml`
  - Triggered by `pull_request_target` and `issues` events.
  - Defaults to `warn` mode before enforcement date; supports manual
    `workflow_dispatch` override (`mode=warn|enforce`).
  - Adds canonical labels when alias-only labels are found and applies default
    release/type labels when missing.
- Enforcement gate: `.github/workflows/label-metadata-gate.yml`
  - Required PR context name: `Label Metadata Gate / PR Release Label Contract`.
  - PR rule: exactly one normalized release bump family (`major|minor|patch`).
  - Issue rule: exactly one normalized issue type family (`bug|enhancement`);
    aliases are accepted during transition.

## Pull Request Review Checklist

- The pull request references a tracked issue and targets the correct branch.
- Commit messages are clear and follow repository conventions.
- CI jobs complete successfully and any failures are explained.
- Documentation and tests are added or updated as needed.

## Release Preparation

Maintainers ensure that `develop` remains in a releasable state:

1. Verify version labels and changelog entries reflect upcoming changes.
2. Confirm that CI is green on `develop` and `main`.
3. Coordinate with release engineers or the OSPM to merge into `main` and
   publish packages when a release is planned.

## Additional Resources

- Repository governance is described in [GOVERNANCE.md](../../../GOVERNANCE.md).
- Action-specific documentation is available in this directory's other guides.
