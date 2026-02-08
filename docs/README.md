# Documentation Index

This directory collects guides and references for working with the LabVIEW Icon Editor.

## General Guides

- [Manual Setup Instructions](manual-instructions.md)
- [Automated Setup Instructions](automated-setup.md)
- [PowerShell CLI GitHub Action Instructions](powershell-cli-github-action-instructions.md)
- [PowerShell Dependency Scripts](powershell-dependency-scripts.md)
- [CI Workflows Overview](ci-workflows.md)
  - Canonical source for release/publication policy (including active `develop` prerelease automation and manual backfill controls).
- [VI Package Pre-Release Requirements](vip-prerelease-requirements.md)
  - Normative contract for `develop` prerelease publication behavior and workflow interfaces.
  - Acceptance matrix: [vip-prerelease-requirements-v1-acceptance.md](vip-prerelease-requirements-v1-acceptance.md)
  - Trace matrix: [vip-prerelease-requirements-v0-to-v1-trace.md](vip-prerelease-requirements-v0-to-v1-trace.md)
- [Runner CLI Requirements](runner-cli-requirements.md)
  - `runner-cli.yml` consolidates runner-cli build/test/smoke and Docker validation (see CI Workflows Overview).

## CI and Advanced Topics

- [Experiments Guide](ci/experiments.md)
- [Troubleshooting & FAQ](ci/troubleshooting-faq.md)
- [Composite Actions](ci/actions/README.md)
  - [Build VI Package](ci/actions/build-vi-package.md)
  - [Development Mode Toggle](ci/actions/development-mode-toggle.md)
  - [Injecting Repo/Org to VI Package](ci/actions/injecting-repo-org-to-vi-package.md)
  - [Maintainer's Guide](ci/actions/maintainers-guide.md)
  - [Multichannel Release Workflow](ci/actions/multichannel-release-workflow.md)
  - [Runner Setup Guide](ci/actions/runner-setup-guide.md)
  - [Troubleshooting Experiments](ci/actions/troubleshooting-experiments.md)
