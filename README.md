## Latest Pull Request
See [Pull Request #152](https://github.com/ni/labview-icon-editor/pull/152) for details on the new CI workflows and dev mode changes.

# LabVIEW Icon Editor

Welcome to the source code and automated build tools for the LabVIEW Icon Editor. Use this project as a foundation to create or customize your own icon editor in LabVIEW. If you want to propose updates or submit bug fixes for future versions of LabVIEW, please consult our [CONTRIBUTING](CONTRIBUTING.md) guidelines.

---

## Overview

This repository contains:
- Icon Editor Source Files: The core LabVIEW code for building or modifying the icon editor.
- PowerShell Tooling: Scripts for automating development mode toggles, building VI packages, and running unit tests.
- Local CI/CD Examples: References and YAML workflows (GitHub Actions) for self-hosted runners, including:
  - Development Mode Toggle
  - Build VI Package
  - Run Unit Tests

---

## Documentation

- [Manual Setup & Distribution](./docs/ManualSetup.md)  
  Explains how to manually configure your environment, edit the Icon Editor source, and create a distributable package.

- [Local CI/CD Workflows](./docs/CIWorkflows.md)  
  Covers using GitHub Actions (or a similar CI system) to automate testing, building, and toggling development mode on a self-hosted runner.

---

## Quick Links

- [CONTRIBUTING](CONTRIBUTING.md) – Guidelines for submitting changes.
- [LICENSE](LICENSE) – License information (if applicable).

---

## Getting Started

1. Check LabVIEW Version
   - This editor is built with LabVIEW 2021 SP1.
   - Other versions may require back-saving or updating the project.

2. Clone This Repo
    git clone https://github.com/username/labview-icon-editor.git

3. Consult the Docs
   - For manual editing or distributing the icon editor, see [Manual Setup & Distribution](./docs/ManualSetup.md).
   - For automated workflows, see [Local CI/CD Workflows](./docs/CIWorkflows.md).

Enjoy building and customizing your LabVIEW Icon Editor!
