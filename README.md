# LabVIEW Icon Editor

[![Build VI Package](https://github.com/ni/labview-icon-editor/actions/workflows/build-vi-package.yml/badge.svg)](https://github.com/ni/labview-icon-editor/actions/workflows/build-vi-package.yml)


---

## Table of Contents
1. [Overview](#overview)  
2. [Key Components](#key-components)  
3. [Getting Started & Contributing](#getting-started)  
4. [Feature & Experiment Workflows](#feature-dev-workflow)  
5. [Documentation](#documentation)  
6. [Technical Steering Committee](#steering-committee)  
7. [License & CLA](#license-cla)  
8. [Contact & Discord](#contact-discord)

---

<a name="overview"></a>
## 1. Overview

This repository hosts the **open-source LabVIEW Icon Editor** under an **MIT license**. Whenever **LabVIEW** is built for an official release, it automatically pulls the **latest** Icon Editor from this repo’s `main` branch. This means that **your contributions**—whether features, bug fixes, or documentation—can become part of **official LabVIEW distributions** (currently focusing on **LabVIEW 2021–2025**).

### Current Pre-Release
- **Green default theme** for testing (feel free to revert/customize!)  
- LabVIEW **2021–2025** version specificity is important for technical reasons within this editor’s packaging approach.

NI is eager to see **community collaboration** drive improvements, ensuring the Icon Editor remains robust and innovative.

---

<a name="key-components"></a>
## 2. Key Components

1. **Source Files**  
   - Entirely **VI-based**, enabling customizations and enhancements to the Icon Editor’s UI and functionality.

2. **PowerShell Automation**  
   - Built on [G-CLI](https://github.com/G-CLI/G-CLI).  
   - Handles build, packaging, and release tasks.  
   - Easily integrated into DevOps (GitHub Actions, self-hosted runners).

3. **CI/CD Workflows**  
   - [Build VI Package](https://github.com/ni/labview-icon-editor/actions/workflows/build-vi-package.yml)  
   - [Development Mode Toggle](https://github.com/ni/labview-icon-editor/actions/workflows/development-mode-toggle.yml)  
   - [Run Unit Tests](https://github.com/ni/labview-icon-editor/actions/workflows/run-unit-tests.yml)

These pipelines produce **.vip** artifacts so anyone can install and test changes in their **LabVIEW 2021–2025** environment.

---

<a name="getting-started"></a>
## 3. Getting Started & Contributing

We welcome **code** and **non-code** contributions—everything from bug fixes and performance tweaks to testing `.vip` files or improving documentation.

- **Must sign a CLA**: For external contributors, we require a Contributor License Agreement before we can merge your pull requests.  
- **Steering Committee**: A group of NI staff + community experts steers features. If an issue is labeled "`Workflow: Open to contribution`," it’s ready for external work.  
- **Fork or Clone**: Start by forking (or cloning) this repo. Then pick an issue or propose a feature.  
- **Experiments**: If you have a **long-lived** or large-scale feature (spanning weeks or months), see [EXPERIMENTS.md](docs/ci/experiments.md). Experimental branches might require special approval before `.vip` distribution is enabled.

For more details on the standard process, see our [CONTRIBUTING.md](CONTRIBUTING.md).

---

<a name="feature-dev-workflow"></a>
## 4. Feature & Experiment Workflows

### Standard Feature Workflow

1. **Check or Create an Issue**  
   - If you have an idea, discuss it on [Discord](#contact-discord) or open a GitHub Discussion.  
   - Once it’s approved, the Steering Committee labels it "**Workflow: Open to contribution**."

2. **Assignment**  
   - Comment on the issue expressing interest in developing the feature.  
   - The Steering Committee (or a maintainer) assigns you.

3. **Branch Setup**  
   - A feature branch is created.  
   - Fork + clone the repo, checkout the feature branch, implement changes.

4. **Build & Test**  
   - Decide between [Manual Setup](./docs/manual-instructions.md) or [PowerShell Scripts](./docs/powershell-cli-instructions.md).  
   - Our CI pipeline generates a `.vip` so others can confirm your feature works in **LabVIEW 2021–2025**.

5. **Pull Request**  
   - Open a PR referencing the issue.  
   - Sign the CLA if needed.  
   - The Steering Committee + maintainers review, test, and iterate.

6. **Merge & Release**  
   - Once approved, your changes merge into `develop` or a typical short-lived branch.  
   - Eventually, everything merges to `main`, ready for the **official** LabVIEW build cycle.

### Experimental Branch Workflow

For **long-running** or **complex** features, see [EXPERIMENTS.md](docs/ci/EXPERIMENTS.md). 
- **Docker VI Analyzer** & CodeQL run automatically on experimental branches, but distributing `.vip` artifacts requires NI’s **manual approval** (“approve-experiment” event).  
- Alpha/Beta/RC sub-branches are optional for staging within the experiment.  
- Final merges also go through the Steering Committee.

---

<a name="documentation"></a>
## 5. Documentation

Check out our docs folder for detailed guides:

- **[Build VI Package](docs/ci/actions/build-vi-package.md)** – Automate release processes for LabVIEW-based projects (2021–2025).  
- **[Development Mode Toggle](docs/ci/actions/development-mode-toggle.md)** – Enable/disable dev mode on a self-hosted runner.  
- **[Multichannel Release Workflow](docs/ci/actions/multichannel-release-workflow.md)** – Handle alpha, beta, RC channels, plus final versions.  
- **[Runner Setup Guide](docs/ci/actions/runner-setup-guide.md)** – Steps for self-hosted runners with GitHub Actions.  
- **[Injecting Owner/Repo Into VI Package](docs/actions/injecting-repo-org-to-vi-package.md)** – Add unique repo/org metadata to .vip.  
- **[Troubleshooting & FAQ](docs/ci/troubleshooting-faq.md)** – Common issues, solutions, frequently asked questions.  
- **[Experiments.md](docs/ci/experiments.md)** – Detailed instructions for the GitFlow-like model for long-lived experimental features.  
- **[Maintainers_Guide.md](docs/ci/actions/maintainers-guide.md)** – Admin tasks for “approve-experiment” workflow dispatch, BDFL overrides, final merges.
- **[Troubleshooting_Experiments.md](docs/ci/actions/troubleshooting-experiments.md)** – Common pitfalls specific to experimental branches.  
- **[Governance.md](./GOVERNANCE.md)** – Steering Committee, BDFL, and membership structure.

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

They review incoming PRs, decide on feature readiness, and merge changes once they pass testing. For **long-lived experiment** branches, see [EXPERIMENTS.md](docs/ci/experiments.md) for how they approve final merges or partial merges.

---

<a name="license-cla"></a>
## 7. License & CLA

- **MIT License**: The Icon Editor code is available under [MIT](LICENSE).  
- **Contributor License Agreement (CLA)**: Before merging external pull requests, we’ll ask you to sign a CLA to confirm we can distribute your code as part of LabVIEW.  

By contributing, you agree to license your work under these terms so NI and the LabVIEW community can incorporate improvements into future distributions.

---

<a name="contact-discord"></a>
## 8. Contact & Discord.

Have questions or want to discuss an idea in real-time?

- **Discord Server**: [Join here](https://discord.gg/q4d3ggrFVA). You can brainstorm features, ask about the labeling workflow, or get quick help from fellow contributors.  
- **GitHub**: Use Issues, Discussions, or open a Pull Request directly.  

### Thanks for Contributing!
Your submissions—whether bug fixes, docs, or experimental features—directly shape the **LabVIEW Icon Editor** for **LabVIEW 2021–2025** and beyond. We appreciate your collaboration and look forward to your ideas!

---
