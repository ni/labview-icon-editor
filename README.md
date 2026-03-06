# LabVIEW Icon Editor

[![CI Status](https://img.shields.io/github/actions/workflow/status/ni/labview-icon-editor/ci-composite.yml?branch=main)](https://github.com/ni/labview-icon-editor/actions/workflows/ci-composite.yml)
[![Latest Release](https://img.shields.io/github/v/release/ni/labview-icon-editor?label=release)](https://github.com/ni/labview-icon-editor/releases/latest)
[![Discord Chat](https://img.shields.io/discord/1319915996789739540?label=Discord&logo=discord&style=flat)](https://discord.gg/q4d3ggrFVA)
[![License: MIT](https://img.shields.io/github/license/ni/labview-icon-editor?style=flat)](LICENSE)
![Coding hours](https://img.shields.io/endpoint?url=https://raw.githubusercontent.com/ni/labview-icon-editor/metrics/badge.json)
![LabVIEW Version](https://img.shields.io/badge/LabVIEW-2020-FEDE06)
---

## 🗂 Table of Contents

**For LabVIEW Users:**

- [Overview](#-overview)
- [Installation](#-installation)

**For Contributors:**

- [Key Components](#-key-components)
- [Getting Started (Contributing)](#-getting-started--contributing)
- [Feature & Experiment Workflows](#-feature--experiment-workflows)
- [Documentation](#-documentation)
- [License & CLA](#-license--cla)
- [Contact & Community](#-contact--community)

---

## 📌 Overview

The **LabVIEW Icon Editor** is an open-source, MIT-licensed tool for creating and editing VI icons, delivered as a VI Package. Each official **LabVIEW** release automatically includes the latest Icon Editor from this repository’s `main` branch (the next integration is targeting **LabVIEW 2026 Q3**).

In practice, **your contributions** – whether new features, fixes, or improvements – can become part of the Icon Editor shipped with LabVIEW itself. The source code is maintained in **LabVIEW 2020 (20.0)** format for broad compatibility, and the released VI Package is built and validated against **LabVIEW 2020 (20.0)**.

- 🛠 **Built in LabVIEW (“G” code)** – All editor functionality is implemented as LabVIEW VIs (graphical code).
- 📁 **Compatibility Target** – Source is stored in LabVIEW 2020 (20.0) format for development, and the distributed packages target LabVIEW 2020 (20.0).
- ⚙️ **CI Pipeline** – **GitHub Actions** orchestrate PowerShell-based workflows for testing, building, and publishing the `.vip` package. The LabVIEW version is enforced via `.lvversion` (mismatches fail fast in CI and local parity scripts unless explicitly overridden).
- 🔄 **Modern Development Practices** – This project helped pioneer NI’s open-source CI/CD patterns, and its infrastructure will migrate to a centralized toolkit for future LabVIEW projects.

NI’s open-source initiative encourages **community collaboration** on this project to continuously improve the Icon Editor and streamline LabVIEW development workflows.

---

## 📦 Installation

> **Prerequisites:**
> • LabVIEW 2020 (20.0) or newer
> • VI Package Manager (VIPM) installed
> • *(Development note: Source code is saved in LabVIEW 2020 (20.0) for building and backward compatibility.)*

1. **Download** the latest `.vip` installer from the [Releases page](https://github.com/ni/labview-icon-editor/releases/latest).
2. **Open VIPM** (VI Package Manager).
3. **Install** the package by double-clicking the downloaded `.vip` file or using *File ▶ Open Package* in VIPM.
4. **Verify** the installation by launching LabVIEW, creating a new VI, and opening the Icon Editor (e.g. right-click the VI icon and choose *Edit Icon*).

For additional details and troubleshooting tips, see [INSTALL.md](INSTALL.md).

---

## 🧩 Key Components

1. **Source Code (VIs)** – The editor’s functionality is implemented entirely in LabVIEW, as a collection of VIs organized into a project. This includes the UI and logic for icon editing.
2. **PowerShell Automation** – A suite of PowerShell scripts (built on the [G-CLI package](https://github.com/G-CLI/G-CLI), a VIPM dependency included in `runner_dependencies.vipc`) supports repeatable build and test tasks. These scripts allow running LabVIEW build steps and packaging from the command line, ensuring consistent results between local development and CI. G-CLI is a third-party dependency and is not affiliated with NI.
3. **CI/CD Workflows** – GitHub Actions workflows are provided for common tasks:
   - **Build VI Package** – Compiles the source and produces a `.vip` artifact (VI Package).
   - **Run Unit Tests** (now part of the main CI pipeline) – Executes automated tests to verify the Icon Editor’s behavior in a clean LabVIEW environment.
   Additional details on these pipelines are in [CI Workflows](docs/ci-workflows.md) and the [CI Workflow (Multi-Channel Release Support)](docs/powershell-cli-github-action-instructions.md).

---

## 🚀 Getting Started & Contributing

We welcome both **code** and **non-code** contributions – from adding new features or fixing bugs to improving documentation and testing.

- 📑 **Contributor License Agreement (CLA)** – External contributors must sign NI’s CLA before a pull request can be merged (this will be prompted automatically on your first PR). The CLA ensures NI has rights to distribute your code under MIT, and you retain rights to your contributions.
- 🧭 **Steering Committee** – A small group of NI maintainers and community members governs the project’s direction. They approve significant changes and label issues as “Workflow: Open to contribution” once an idea is ready for external work.
- 🔄 **Find an Issue to Work On** – Check the issue tracker for issues labeled “[Workflow: Open to contribution]” – these are tasks approved for community development. Comment on the issue to volunteer, and a maintainer will assign it to you and create a branch named `feature/<issue number>-<short-description>` if one doesn’t exist, marking the issue’s Status as `In Progress` so CI will run.
- 🧪 **Long-Running Features** – Major features that might span weeks or months can be developed on special `experiment/` branches with more rigorous CI (security scans, gated releases). See [EXPERIMENTS.md](docs/ci/experiments.md) for details on how experimental feature branches work.

For detailed contribution guidelines (branching strategy, coding style, etc.), please see the [CONTRIBUTING.md](CONTRIBUTING.md) document. The `/docs` folder also contains setup guides and technical notes (summarized below).

---

## 🌱 Feature & Experiment Workflows

**Standard Feature Contribution Workflow:**

1. **Propose & Discuss** – Start by proposing your idea via [GitHub Discussions](https://github.com/ni/labview-icon-editor/discussions) or by opening an issue. Discussing first helps refine the idea and get feedback.
2. **Issue Approval & Assignment** – Once the idea is approved, maintainers label the issue `Workflow: Open to contribution`. After you volunteer, a maintainer assigns the issue and sets up a branch such as `feature/<issue number>-<short-description>`, ensuring the issue is marked `In Progress`. The workflow defined in [ci-composite.yml](.github/workflows/ci-composite.yml) triggers, but its jobs run only when the `issue-status` gate passes (branch pattern `issue-<number>` and issue Status `In Progress`). Runs failing this gate appear in GitHub Actions but skip subsequent jobs.
3. **Development Setup** – Fork the repository and clone your fork. Check out the feature branch. Prepare your LabVIEW environment (recommend LabVIEW 2025 (25.0) or newer with required dependencies applied). You can develop straight from the project.
**NOTE:** You will be able to run the lv_icon.vi from the project, but it will not be the active icon editor in the IDE. It is recommended to build the PPL and VI Package and install the package to test in the IDE.
4. **Implement & Test** – Develop your changes using LabVIEW. Test the editor manually in LabVIEW to ensure your changes work. Run any available unit tests.
5. **Submit a Pull Request** – Open a PR linking to the issue. Our CI will automatically run and **build a `.vip` package** with your changes for testing. Maintainers and others can install this pre-release package to test your contribution. Iterate on any review feedback.
6. **Merge & Release** – Once your contribution is approved, it will be merged into the `develop` branch. During the next release cycle, `develop` is merged into `main` and a new official Icon Editor version is released. At that point, your contribution is on track to ship with the next LabVIEW release.

**Experimental Feature Workflow:**

For very large or long-term contributions, NI may use an `experiment/<feature-name>` branch:

- The experiment branch lives in the main repository (so CI can run on it) and allows multiple collaborators to work in parallel on the feature. Regular `develop` branch merges into the experiment keep it up-to-date with ongoing changes.
- **Automated code scanning** (e.g. Docker-based VI Analyzer and GitHub CodeQL) runs on every commit/PR to the experiment branch, catching issues early.
- **Manual approval for builds** – By default, publishing a build from an experiment branch is disabled. An NI maintainer must manually trigger an “approve-experiment” workflow to generate a distributable `.vip` for testing. This ensures experimental builds aren’t widely released without review.
- **Optional sub-branches** – The team can create sub-branches like `alpha`, `beta`, or `rc` under the experiment branch for staged testing releases (e.g. `experiment/feature/alpha`). These follow a multichannel release approach for gradual testing.
- **Integration** – When the feature is complete, the experiment branch is reviewed and then merged into `develop` (and later into `main`) following Steering Committee approval. If an experiment is aborted or partially finished, it may be archived or selectively merged as appropriate.

*(See [EXPERIMENTS.md](docs/ci/experiments.md) for full guidelines on experimental branches.)*

---

## 📚 Documentation

In-depth documentation and reference guides are located in the `/docs` directory. A complete index is available in [docs/README.md](docs/README.md). Notable documents include:

- **Build & CI Guides:** How to build the Icon Editor and use continuous integration tools. For local setup, see [manual-instructions.md](docs/manual-instructions.md) or the script-driven [automated-setup.md](docs/automated-setup.md). CI pipelines are covered in [CI Workflows](docs/ci-workflows.md) and the [CI Workflow (Multi-Channel Release Support)](docs/powershell-cli-github-action-instructions.md). Reference scripts are listed in [PowerShell Dependency Scripts](docs/powershell-dependency-scripts.md). Packaging and runner configuration are detailed in [Build VI Package](docs/ci/actions/build-vi-package.md) and the [Runner Setup Guide](docs/ci/actions/runner-setup-guide.md).
- **Composite Actions:** Summary of the repository's reusable GitHub Actions is available in [Composite Actions](docs/ci/actions/README.md).
- **Advanced Workflows:** Details on complex release processes and branching strategies. For example, the [Multichannel Release Workflow](docs/ci/actions/multichannel-release-workflow.md) explains alpha/beta/RC release branches, and [EXPERIMENTS.md](docs/ci/experiments.md) covers long-running feature branches. Maintainers can refer to the [Maintainer's Guide](docs/ci/actions/maintainers-guide.md) for internal release duties.
- **Troubleshooting:** If you encounter issues, see the [Troubleshooting & FAQ](docs/ci/troubleshooting-faq.md) for common problems (environment setup, build failures, etc.). There is also a specialized [Experiments Troubleshooting](docs/ci/actions/troubleshooting-experiments.md) guide for experimental branch issues.
- **Project Governance:** This project adheres to NI’s open-source governance model. See [GOVERNANCE.md](GOVERNANCE.md) for roles and decision-making processes, and refer to our [Code of Conduct](CODE_OF_CONDUCT.md) for community interaction guidelines.

---

## 📄 License & CLA

This project is distributed under the **MIT License** – see the [LICENSE](LICENSE) file for details. By contributing to this repository, you agree that your contributions can be distributed under the same MIT license and included in official LabVIEW releases. (In practice, this means you’ll be asked to sign a simple Contributor License Agreement on your first pull request, confirming you are okay with NI using your contributions in LabVIEW.)

---

## 💬 Contact & Community

- 🗨️ **Discord Chat:** Join our [Discord server](https://discord.gg/q4d3ggrFVA) to ask questions, get help, or discuss ideas in real time with NI developers and the community.
- 📣 **GitHub Discussions:** For longer-form discussions, proposals, or Q&A, visit our [GitHub Discussions](https://github.com/ni/labview-icon-editor/discussions). It’s a great place to propose new features or improvements and get community feedback.

---

### 🙏 Thanks for Contributing!

Your ideas, testing, and code contributions directly shape the Icon Editor experience across the LabVIEW community. Thank you for helping improve this tool for the entire LabVIEW community!

