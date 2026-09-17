# Contributing to LabVIEW Icon Editor

We welcome both code and non-code contributions — from adding new features or fixing bugs to improving documentation and testing. Your contributions can ship directly in official LabVIEW releases.

---

## Table of Contents

- [Ways to Contribute](#-ways-to-contribute)
- [Getting Started](#-getting-started)
- [Reporting Bugs](#-reporting-bugs)
- [Suggesting Features](#-suggesting-features)
- [Joining Discussions](#-joining-discussions)
- [Testing](#-testing)
- [Contributing Code](#-contributing-code)
  - [Contributor License Agreement (CLA)](#contributor-license-agreement-cla)
  - [Development Setup](#development-setup)
  - [Branching Strategy](#branching-strategy)
  - [Standard Feature Workflow](#standard-feature-workflow)
  - [Experimental Feature Workflow](#experimental-feature-workflow)
  - [Pull Request Guidelines](#pull-request-guidelines)
- [Coding Standards](#-coding-standards)
  - [General LabVIEW (G Code) Guidelines](#general-labview-g-code-guidelines)
  - [Making Changes to G Code](#making-changes-to-g-code)
  - [Commit Guidelines](#commit-guidelines)
  - [VI Analyzer Tests](#vi-analyzer-tests)
- [CI/CD Pipeline](#-cicd-pipeline)
- [Review Process](#-review-process)
- [Repository Structure](#-repository-structure)
- [Governance](#-governance)
- [Communication Channels](#-communication-channels)

---

## 🤝 Ways to Contribute

You don't need to write code to make a meaningful contribution. Here are all the ways you can participate:

| Contribution | Description |
|---|---|
| **Report a bug** | Found something broken? Start a [discussion](https://github.com/ni/labview-icon-editor/discussions/new/choose) describing the problem |
| **Suggest a feature** | Have an idea? Post in [New Features discussions](https://github.com/ni/labview-icon-editor/discussions/categories/new-features) |
| **Join discussions** | Share your expertise in [GitHub Discussions](https://github.com/ni/labview-icon-editor/discussions) or on [Discord](https://discord.gg/q4d3ggrFVA) |
| **Test changes** | Install pre-release packages from CI and report your findings |
| **Improve documentation** | Fix typos, clarify instructions, or update the [docs site](https://ni.github.io/labview-icon-editor/) |
| **Tackle a good first issue** | Check issues labeled [`Good first issue`](https://github.com/ni/labview-icon-editor/labels/good%20first%20issue) — great for new contributors |
| **Write code** | Fix bugs, implement features, or improve performance |

---

## 🚀 Getting Started

1. **Explore the repo** — Browse the [README](https://github.com/ni/labview-icon-editor#readme) and [docs](https://github.com/ni/labview-icon-editor/tree/develop/docs) to understand the project
2. **Check open issues** — Look for issues labeled [`Workflow: Open to Contribution`](https://github.com/ni/labview-icon-editor/issues?q=is%3Aissue+state%3Aopen+label%3A%22Workflow%3A+Open+to+contribution%22) or [`Good first issue`](https://github.com/ni/labview-icon-editor/labels/good%20first%20issue)
3. **Join the conversation** — Introduce yourself on [Discord](https://discord.gg/q4d3ggrFVA) or [GitHub Discussions](https://github.com/ni/labview-icon-editor/discussions)

### Prerequisites

- **LabVIEW 2020 (20.0)** or newer (LabVIEW 2025+ recommended for development)
- **VIPM** (VI Package Manager) for installing packages and dependencies
- **LUnit** (installed via VIPM) for running unit tests
- A **GitHub account**

---

## 🐛 Reporting Bugs

Before opening a new report, search the [issues list](https://github.com/ni/labview-icon-editor/issues) and [open discussions](https://github.com/ni/labview-icon-editor/discussions) to check if it's already reported.

If not, [start a new discussion](https://github.com/ni/labview-icon-editor/discussions/new/choose) with:

- A clear, concise title
- Detailed description — what happens vs. what you expected
- Steps to reproduce (include a VI or sequence of actions if possible)
- Environment info — OS, LabVIEW version (e.g., 2021 64-bit)
- Screenshots or error messages if applicable

---

## 💡 Suggesting Features

Have an idea for a new feature or significant change?

1. **Start a discussion** in the [New Features category](https://github.com/ni/labview-icon-editor/discussions/categories/new-features) — always get buy-in before investing time in implementation
2. Describe the problem your idea would solve or the use case it would enable
3. The Steering Committee and community provide feedback and determine alignment with project goals
4. If accepted, repo owners label an issue and create a feature branch for implementation

---

## 💬 Joining Discussions

GitHub Discussions is the place for design proposals, Q&A, and community conversation:

- Share use cases and real-world experience
- Provide feedback on [planned features](https://github.com/ni/labview-icon-editor/discussions/categories/new-features)
- Ask questions about the editor
- Help other community members

Visit the [Discussions tab](https://github.com/ni/labview-icon-editor/discussions) to get started.

---

## 🧪 Testing

Testing is one of the most valuable contributions you can make:

- **Test pre-release packages** — CI builds a `.vip` artifact for every PR; download and install it to validate changes
- **Test open PRs** — Install packages built from contributor branches to verify fixes
- **Report regressions** — If something that used to work is now broken, let us know

---

## 💻 Contributing Code

### Contributor License Agreement (CLA)

External contributors must sign NI's Contributor License Agreement **once per GitHub account** before a PR can be merged. A bot will prompt you automatically on your first pull request. The CLA ensures NI has rights to distribute your code under MIT, and you retain rights to your contributions. The CLA is required for code contributions intended to ship with LabVIEW — it is not needed for issues, discussions, or testing.

### Development Setup

1. **Fork** the [labview-icon-editor](https://github.com/ni/labview-icon-editor) repository to your GitHub account
2. **Clone** your fork locally
3. Install **LabVIEW 2020+** (2025+ recommended) and **VIPM**
4. Install dependencies by applying `icon-editor-developer.vipc` via VIPM
5. Run `Tooling\Prepare LV to Use Icon Editor Source.vi` (or use the PowerShell scripts for dev mode) to set up your environment
6. Open `lv_icon_editor.lvproj` in LabVIEW to start developing

> **Note:** You can run `lv_icon.vi` from the project for testing, but it won't be the active icon editor in the IDE. To test in the IDE, build the PPL and VI Package, then install the package.

For detailed setup instructions, see [manual-instructions.md](https://github.com/ni/labview-icon-editor/blob/develop/docs/manual-instructions.md) or the script-driven [automated-setup.md](https://github.com/ni/labview-icon-editor/blob/develop/docs/automated-setup.md).

### Branching Strategy

The repository uses a multi-tier branching model aligned with the LabVIEW release cycle:

```
  Your Fork                        Upstream (ni/labview-icon-editor)
  ────────                         ─────────────────────────────────

  your-branch ──► PR ──►           feature/<issue#>-<description>
                                      │
                                      ▼
                                    develop  (accepts contributions year-round)
                                      │
                                      │  March & September
                                      │  (~ 3 months before LabVIEW release)
                                      ▼
                                   release-rc  (pre-release validation)
                                      │
                                      ▼
                                    main  (release-ready, final artifacts built here)
                                      │
                                      ▼
                                   LabVIEW Release
```

| Branch | Purpose | Who Merges |
|---|---|---|
| **`main`** | Release branch — final `.vip` packages are built from here. Only updated during release windows. | Repo Owners / NI |
| **`release-rc`** | Pre-release validation branch — release candidates are tested here before promotion to `main`. | Repo Owners |
| **`develop`** | Integration branch — accepts community contributions year-round. This is where approved features land. | Repo Owners |
| **`feature/<issue#>-<desc>`** | Feature branches — created by repo owners for approved issues. Your PRs target these. | Contributors |
| **`experiment/<name>`** | Long-running experimental branches for major features (see [below](#experimental-feature-workflow)). | Repo Owners + Contributors |

#### Release Integration Schedule

Changes from `develop` are promoted through `release-rc` to `main` **twice a year**, approximately three months before each LabVIEW release:

| Integration Window | LabVIEW Release | What Happens |
|---|---|---|
| **March** | Q3 release (June/July) | Feature freeze on `develop`; approved changes flow through `release-rc` to `main`; final artifacts built and validated |
| **September** | Q1 release (next year) | Feature freeze on `develop`; approved changes flow through `release-rc` to `main`; final artifacts built and validated |

> **What this means for contributors:** You can submit PRs to feature branches at any time. Your changes will be reviewed, merged into `develop`, and then included in the next integration window.

### Standard Feature Workflow

1. **Propose & discuss**
   - Start by proposing your idea via [GitHub Discussions](https://github.com/ni/labview-icon-editor/discussions) or by opening an issue
   - Discussing first helps refine the idea and get feedback

2. **Issue approval & assignment**
   - Once approved, repo owners label the issue `Workflow: Open to Contribution`
   - Comment on the issue to volunteer — a repo owner will assign it to you
   - Repo owners create a branch named `feature/<issue number>-<short-description>` and mark the issue status as `In Progress` (CI only runs when this gate passes)

3. **Develop**
   - Fork the repo, clone your fork, and check out the feature branch
   - Apply dependencies and set up dev mode (see [Development Setup](#development-setup))
   - Make your changes in LabVIEW following the [coding standards](#-coding-standards)

4. **Test**
   - Test the editor manually in LabVIEW to verify your changes work
   - Run unit tests via LUnit (see `Test/` folder)
   - Build the PPL and VI Package, install it, and test in the IDE

5. **Submit a Pull Request**
   - Push your branch to your fork and open a PR targeting the feature branch in the upstream repo
   - Link the issue in the PR description (e.g., "Closes #123")
   - Apply exactly **one release label** (`major`, `minor`, or `patch`) — CI will fail without it
   - Fill out the PR template completely (see [PR Guidelines](#pull-request-guidelines))

6. **CI builds & review**
   - CI automatically builds a `.vip` package with your changes
   - Repo owners and the community can install this package to test your contribution
   - Respond to review feedback and push updates

7. **Merge & release**
   - After approval, your PR is merged into `develop`
   - During the next integration window, `develop` flows through `release-rc` to `main`
   - Your contribution ships in the corresponding LabVIEW release

### Experimental Feature Workflow

For very large or long-term contributions, NI may use an `experiment/<feature-name>` branch:

- The experiment branch lives in the **main repository** (not a fork) so CI can run on it
- Multiple collaborators can work in parallel on the feature
- Regular merges from `develop` keep the experiment branch up-to-date
- **Automated code scanning** (Docker-based VI Analyzer, GitHub CodeQL) runs on every commit/PR
- **Manual approval for builds** — publishing a `.vip` from an experiment branch requires an NI repo owner to manually trigger the `approve-experiment` workflow
- **Optional sub-branches** — teams can create `alpha`, `beta`, or `rc` sub-branches for staged testing
- When complete, the experiment branch is reviewed and merged into `develop` following Steering Committee approval

See [EXPERIMENTS.md](https://github.com/ni/labview-icon-editor/blob/develop/docs/ci/experiments.md) for full guidelines.

### Pull Request Guidelines

Every PR must include:

- **Purpose** — why this change is needed
- **Changes made** — what was added, modified, or fixed
- **Issue reference** — link the issue number (e.g., "Closes #123")
- **Testing** — how you tested the changes, steps for reviewers to reproduce
- **Visual aids** — screenshots or diagrams if applicable
- **Release label** — apply exactly one: `major`, `minor`, or `patch`

**PR Checklist:**
- [ ] Commits are signed off (`git commit -s`)
- [ ] Changes are based on the appropriate feature branch
- [ ] PR targets the correct branch in the upstream repo
- [ ] Exactly one release label is applied
- [ ] Built and tested the VI Package locally
- [ ] NI has your CLA on file

---

## 📐 Coding Standards

### General LabVIEW (G Code) Guidelines

- Follow **NI LabVIEW style guidelines** and Icon Editor design patterns
- Keep block diagrams **clean and readable** — use proper wire routing, avoid overlapping wires, and maintain left-to-right data flow
- Use **descriptive VI and class names** — names should clearly communicate purpose
- Add **inline documentation** — use free labels and VI descriptions to explain non-obvious logic
- Keep VIs **small and focused** — each VI should do one thing well
- Use **type definitions** for clusters and enums that may change
- Maintain backward compatibility — source is saved in **LabVIEW 2020 (20.0)** format
- Write or update tests when adding or changing functionality (see `Test/` folder)

### Making Changes to G Code

1. **Set up dev mode** — Run `Tooling\Prepare LV to Use Icon Editor Source.vi` or use the PowerShell scripts
2. **Open the project** — Load `lv_icon_editor.lvproj` in LabVIEW
3. **Locate the VI** — Navigate the project tree. Key directories:
   - `resource/plugins/` — Icon Editor plugin VIs
   - `vi.lib/LabVIEW Icon API/` — Icon API library
   - `Test/` — Unit tests (LUnit)
   - `Tooling/` — Build and automation utilities
4. **Edit the block diagram** — Follow the style guidelines above
5. **Save for the correct version** — Always save VIs in LabVIEW 2020 (20.0) format
6. **Test locally** — Run unit tests via LUnit, build the package, and install to test in the IDE

> **Important:** LabVIEW files are binary, so standard text-based diffs don't work. Use clear PR descriptions and screenshots/visual aids to help reviewers understand your changes.

### Commit Guidelines

- Write **clear, descriptive commit messages**
- **Sign off** every commit — use `git commit -s` to add a `Signed-off-by:` line (Developer Certificate of Origin)
- Ensure each commit builds and passes tests
- Keep commits self-contained so the branch history can be cleanly merged or squashed

### VI Analyzer Tests

The CI pipeline runs **VI Analyzer (VIA)** tests to enforce code quality. The configuration is defined in `lv_icon_editor.viancfg` at the repo root.

**What VI Analyzer checks:**

- Block diagram cleanliness and style compliance
- Proper error handling
- Unused code and dead code
- Naming conventions
- Performance issues
- Documentation completeness

**Running VI Analyzer locally before submitting a PR:**

1. Open LabVIEW and go to **Tools → VI Analyzer → Analyze VIs...**
2. Load the configuration file: `lv_icon_editor.viancfg`
3. Select the VIs you've modified
4. Run the analysis and fix any reported issues

> **Tip:** Running VI Analyzer locally before pushing saves CI time and avoids review delays.

---

## ⚙️ CI/CD Pipeline

The repository uses GitHub Actions for continuous integration. CI is orchestrated through composite workflows:

| Workflow | Purpose |
|---|---|
| `ci.yml` | Main CI pipeline — builds, tests, and validates PRs |
| `build-lvlibp-linux-container.yml` | Builds LVLIBP in a Linux LabVIEW Docker container |
| `build-lvlibp-windows-container.yml` | Builds LVLIBP in a Windows container |
| `build-lvlibp-windows-github-hosted.yml` | Builds LVLIBP on GitHub-hosted Windows runners |
| `Delete Old Workflow Runs.yml` | Cleanup old CI runs |
| `refresh-readme.yml` | Updates coding hours badge |

**Key CI behaviors:**

- CI builds a `.vip` artifact for every PR — download it to test changes
- The **issue-status gate** checks that the linked issue is marked `In Progress` — CI jobs skip if this gate fails
- PRs require exactly **one release label** (`major`, `minor`, or `patch`) — CI fails without it
- External contributors **do not need** their own LabVIEW runner — CI handles building on NI's self-hosted runners

> Your PR must pass **all CI checks** before it can be reviewed and merged.

For detailed CI documentation, see [CI Workflows](https://github.com/ni/labview-icon-editor/blob/develop/docs/ci-workflows.md) and [Composite Actions](https://github.com/ni/labview-icon-editor/blob/develop/docs/ci/actions/README.md).

---

## 📋 Review Process

Pull Requests are reviewed by repo owners and the Steering Committee:

- **Initial review** within 5–10 business days
- **Follow-up reviews** within 3–5 business days after revisions
- Once approved, PRs are merged promptly and queued for the next release cycle

---

## 📂 Repository Structure

```
labview-icon-editor/
├── .github/                    # CI workflows and GitHub config
│   └── workflows/              # GitHub Actions CI/CD pipelines
├── .vscode/                    # VS Code tasks (dev mode integration)
├── Test/                       # Unit tests (LUnit)
├── Tooling/                    # Build scripts, PowerShell automation, dev mode setup
├── docs/                       # Documentation, setup guides, CI docs
│   └── ci/                     # CI-specific docs (actions, experiments, troubleshooting)
├── resource/plugins/           # Icon Editor plugin VIs
├── vi.lib/LabVIEW Icon API/    # Icon API library
├── AGENTS.md                   # AI agent instructions
├── CODE_OF_CONDUCT.md          # Community code of conduct
├── CONTRIBUTING.md             # This file
├── GOVERNANCE.md               # Project governance model
├── INSTALL.md                  # Installation guide
├── LICENSE                     # MIT License
├── README.md                   # Project overview
├── icon-editor-developer.vipc  # VIPM dependency config for development
├── lv_icon_editor.lvproj       # Main LabVIEW project file
└── lv_icon_editor.viancfg      # VI Analyzer configuration
```

---

## 🏛️ Governance

The Icon Editor is maintained under an open-governance model:

- **Technical Steering Committee (SteerCo)** — NI staff and community members who oversee the project's direction, approve significant changes, and label issues for contribution
- **Repo Owners** — Handle code review, CI validation, merge approvals, and release tagging
- **NI** retains final decision authority for major direction and architecture changes

For full details, see [GOVERNANCE.md](https://github.com/ni/labview-icon-editor/blob/develop/GOVERNANCE.md).

All participants must follow the [Code of Conduct](https://github.com/ni/labview-icon-editor/blob/develop/CODE_OF_CONDUCT.md).

---

## 📡 Communication Channels

| Channel | Purpose |
|---|---|
| [GitHub Issues](https://github.com/ni/labview-icon-editor/issues) | Bug reports and feature tracking |
| [GitHub Discussions](https://github.com/ni/labview-icon-editor/discussions) | Design proposals, Q&A, feature ideas |
| [Discord](https://discord.gg/q4d3ggrFVA) | Real-time community collaboration |
| [Docs Site](https://ni.github.io/labview-icon-editor/) | Documentation and guides |

---

## License

The LabVIEW Icon Editor is licensed under the [MIT License](https://github.com/ni/labview-icon-editor/blob/develop/LICENSE). By contributing, you agree that your contributions can be distributed under the same MIT license and included in official LabVIEW releases.
