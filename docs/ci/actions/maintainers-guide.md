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
   (for example, `issue-123-fix-toolbar`). Branch names **must** include
   `issue-<number>`.
3. Set the linked issue's **Status** field to **In Progress**. The
   [`issue-status` job](../../../.github/workflows/ci-composite.yml)
   enforces the branch naming and status requirements, skipping most jobs when
   either condition is not met.
4. Push the branch to the main repository and open a pull request targeting
   `develop` (or another appropriate branch).
5. Run unit tests or scripted checks locally whenever possible.
6. Ensure CI passes and obtain at least one maintainer approval before merging.
7. After merging, delete the source branch to keep the repository tidy.

## Workflow Administration

- **Approve experiment branches** – When an experiment branch should publish
  artifacts (VIPs), run the `approve-experiment` workflow in GitHub Actions.
  Coordinate with the NI Open-Source Program Manager (OSPM) before execution.
- **Finalize experiment merges** – Prior to merging an experiment branch into
  `develop`, apply an appropriate version label (major/minor/patch) and remove
  any temporary settings or `NoCI` labels. A `NoCI` label causes the CI
  workflow to skip all jobs, so clear it before running final tests. The OSPM
  or designated NI staff typically gives the final approval.
- **Hotfix branches** – For critical fixes on an official release, create or
  approve a `hotfix/*` branch targeting `main`. After merging into `main`, merge
  the changes back into `develop` to keep branches synchronized.
- **Documentation updates** – When workflows change, update related
  documentation in the `/docs` directory as part of the same pull request.

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
