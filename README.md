[![Build VI Package](https://github.com/ni/labview-icon-editor/actions/workflows/build-vi-package.yml/badge.svg)](https://github.com/ni/labview-icon-editor/actions/workflows/build-vi-package.yml)

## Latest Pull Request 
[GitHub Action to Build and release the Icon Editor](https://github.com/ni/labview-icon-editor/pull/158)

# LabVIEW Icon Editor

Welcome to the open-source **LabVIEW Icon Editor**. If you want to propose updates or submit bug fixes for the next shipping version of LabVIEW, please consult our [CONTRIBUTING](CONTRIBUTING.md) guidelines.

---

## Overview

This repository contains:
- Icon Editor Source Files: LabVIEW core files required for building or modifying the Icon Editor.
- PowerShell Tooling: Automation scripts using [g-cli](https://github.com/G-CLI/G-CLI) that replaces the manual tasks of distributing the Icon Editor as a VI Package. 
- Local CI/CD Examples: References and YAML workflows (GitHub Actions) for self-hosted runners using the PowerShell Tooling, including:
  - [Development Mode Toggle](docs/actions/development-mode-toggle.md)
  - [Build VI Package](https://github.com/ni/labview-icon-editor/actions/workflows/build-vi-package.yml)
  - [Run Unit Tests](https://github.com/ni/labview-icon-editor/actions/workflows/run-unit-tests.yml)

---

## Documentation

- [Manual Setup & Distribution](./docs/manual-setup.md) 
  Provides manual steps to *configure*, *edit*, and distribute the LabVIEW Icon Editor without using automation *(e.g. PowerShell scipts, GitHub Actions)*.

- [Automated Setup & Distribution](./docs/automated-setup.md)
  Describes how to build, test, and distribute the LabVIEW Icon Editor using PowerShell. You can run these scripts locally on your development or self-hosted runner, or within GitHub Actions.

- [Fork-Friendly Icon Editor CI/CD Workflow](./docs/ci-workflows.md)   Explains how to automate *building*, *testing*, *distributing*, and *releasing* your version of the Icon Editor using your fork and a self-hosted runner, it includes features such as **fork-friendly GPG signing toggles**, and **automatic version bumping** (using labels).

---

## Quick Links

- [CONTRIBUTING](CONTRIBUTING.md) – Guidelines for submitting changes.
- [LICENSE](LICENSE) – License information (if applicable).

---

Enjoy building and customizing your LabVIEW Icon Editor!
