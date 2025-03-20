# LabVIEW Icon Editor

[![Build VI Package](https://github.com/ni/labview-icon-editor/actions/workflows/build-vi-package.yml/badge.svg)](https://github.com/ni/labview-icon-editor/actions/workflows/build-vi-package.yml)  

> **Latest Pull Request:** [GitHub Action to Build and Release the Icon Editor](https://github.com/ni/labview-icon-editor/pull/158)  
>  
> **Pre-Release**: Icon Editor (green-default theme) supporting **LabVIEW 2021–2025**

---

## Table of Contents
1. [Overview](#overview)  
2. [Key Components](#key-components)  
3. [Getting Started & Contributing](#getting-started)  
4. [Feature Development Workflow](#feature-dev-workflow)  
5. [Documentation](#documentation)  
6. [Technical Steering Committee](#steering-committee)  
7. [License & CLA](#license-cla)  
8. [Contact & Discord](#contact-discord)  

---

<a name="overview"></a>
## 1. Overview

This repository hosts the **open-source LabVIEW Icon Editor** under an **MIT license**. Whenever **LabVIEW** is built for an official release, it automatically pulls the **latest** Icon Editor from this repo’s `main` branch. This means that **your contributions**—whether features, bug fixes, or documentation—can become part of official LabVIEW distributions.

### Current Pre-Release
- Supports **LabVIEW 2021–2025**  
- Default theme is **green** for testing (feel free to revert/customize!)  

NI is eager to see **community collaboration** drive improvements, ensuring the Icon Editor remains robust and innovative.

---

<a name="key-components"></a>
## 2. Key Components

1. **Source Files**  
   - Entirely **VI-based**, enabling customizations and enhancements to the Icon Editor’s UI and functionality.

2. **PowerShell Automation**  
   - Built on [G-CLI](https://github.com/G-CLI/G-CLI)  
   - Handles build, packaging, and release tasks  
   - Easily integrated into DevOps (GitHub Actions, self-hosted runners)

3. **CI/CD Workflows**  
   - [Build VI Package](https://github.com/ni/labview-icon-editor/actions/workflows/build-vi-package.yml)  
   - [Development Mode Toggle](https://github.com/ni/labview-icon-editor/actions/workflows/development-mode-toggle.yml)  
   - [Run Unit Tests](https://github.com/ni/labview-icon-editor/actions/workflows/run-unit-tests.yml)

These pipelines produce **.vip** artifacts so anyone can install and test changes in their local LabVIEW environment.

---

<a name="getting-started"></a>
## 3. Getting Started & Contributing

We welcome **code** and **non-code** contributions—everything from bug fixes and performance tweaks to testing `.vip` files or improving documentation. Key points:

- **Must sign a CLA**: For external contributors, we require a Contributor License Agreement before we can merge your pull requests.  
- **Steering Committee**: A group of NI staff + community experts steers features. If an issue is labeled "`Workflow: Open to contribution`," it’s ready for external work.  
- **Fork or Clone**: Start by forking (or cloning) this repo. Then pick an issue or propose a feature.

For more details, see our [CONTRIBUTING.md](CONTRIBUTING.md).

---

<a name="feature-dev-workflow"></a>
## 4. Feature Development Workflow

Here’s a quick overview of how a **feature** (or bug fix) moves from idea to merged code:

1. **Check or Create an Issue**  
   - If you have an idea, discuss it on [Discord](#contact-discord) or open a GitHub Discussion.  
   - Once it’s approved, the Steering Committee labels it "**Workflow: Open to contribution**."

2. **Assignment**  
   - Comment on the issue expressing interest in developing the feature.  
   - The Steering Committee (or a maintainer) assigns you, confirming you can begin.

3. **Branch Setup**  
   - A feature branch is created (either manually by maintainers or via an automated process).  
   - Fork + clone the repo, checkout the feature branch, and implement your changes.

4. **Build & Test**  
   - Decide between using the [Manual](./docs/manual-instructions.md) approach, or automated via [PowerShell Scripts](./docs/powershell-cli-instructions.md).  
   - The CI pipeline will generate a `.vip` so others can confirm your feature works in LabVIEW 2021–2025.

5. **Pull Request**  
   - Open a PR referencing the issue.  
   - If needed, sign the **Contributor License Agreement** (CLA).  
   - The Steering Committee + maintainers review your code, run tests, and iterate.

6. **Merge & Release**  
   - Once approved, your changes merge into `develop` or a similar branch following [GitFlow](https://nvie.com/posts/a-successful-git-branching-model/).  
   - Eventually, everything merges to `main`, ready for the **official** LabVIEW build cycle.

---

<a name="documentation"></a>
## 5. Documentation

Check out our docs folder for detailed guides:

- **[Build VI Package](docs/ci/actions/build-vi-package.md)** – Automate release processes for LabVIEW-based projects.  
- **[Development Mode Toggle](docs/ci/actions/development-mode-toggle.md)** – Enable/disable dev mode on a self-hosted runner.  
- **[Multichannel Release Workflow](docs/ci/actions/multichannel-release-workflow.md)** – Handle alpha, beta, RC channels, plus final versions.  
- **[Runner Setup Guide](docs/ci/actions/runner-setup-guide.md)** – Steps for self-hosted runners with GitHub Actions.  
- **[Injecting Owner/Repo Into VI Package](docs/actions/injecting-repo-org-to-vi-package.md)** – Add unique repo/org metadata to .vip.  
- **[Troubleshooting & FAQ](docs/ci/troubleshooting-faq.md)** – Common issues, solutions, frequently asked questions.

---

<a name="steering-committee"></a>
## 6. Technical Steering Committee

- [@JayKayAce](https://github.com/JayKayAce)  
- [@crossrulz](https://github.com/crossrulz)  
- [@neilpate](https://github.com/neilpate)  
- [@j-medland](https://github.com/j-medland)  
- @markballa  
- [@RobustoSystems](https://github.com/RobustoSystems)

**NI Open Source Program Manager**: [@svelderrainruiz](https://github.com/svelderrainruiz) – sergio.velderrain@emerson.com

They review incoming PRs, decide on feature readiness, and merge changes once they pass testing. This committee is your go-to for major architectural questions or feature proposals.

---

<a name="license-cla"></a>
## 7. License & CLA

- **MIT License**: The Icon Editor code is available under [MIT](LICENSE).  
- **Contributor License Agreement (CLA)**: Before merging external pull requests, we’ll ask you to sign a CLA to confirm we can distribute your code as part of LabVIEW. This process is straightforward and only needs to be done **once**.

By contributing to this repository, you agree to license your work under the same MIT terms so that NI and the LabVIEW community can incorporate your improvements.

---

<a name="contact-discord"></a>
## 8. Contact & Discord

Have questions or want to discuss an idea in real-time?

- **Discord Server**: [Join here](https://discord.gg/q4d3ggrFVA). You can brainstorm features, ask about the labeling workflow, or get quick help from fellow contributors.  
- **GitHub**: Use Issues, Discussions, or open a Pull Request directly.  

### Thank You!
Your contributions—whether bug fixes, docs, or feature ideas—directly shape the future of the LabVIEW Icon Editor. We appreciate your collaboration and look forward to seeing what you create!
