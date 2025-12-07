# Documentation Index

This directory collects guides and references for working with the LabVIEW Icon Editor.

## 🚀 Quick Start (Read These First)

**New agents/developers start here**:

1. **[../README.md](../README.md)** - Main repository overview, VS Code tasks, Ollama setup
2. **[vscode-tasks.md](vscode-tasks.md)** - Complete VS Code task catalog with descriptions
3. **[x-cli-overview.md](x-cli-overview.md)** - ⭐ **Comprehensive x-cli guide** (platform support, workflows, troubleshooting)
4. **[vi-history-suite-overview.md](vi-history-suite-overview.md)** - ⭐ **VI History comparison complete guide**
5. **[adr/ADR-2025-011-repo-structure.md](adr/ADR-2025-011-repo-structure.md)** - Repository layout rationale

## 📦 Build & Release Tools

- **[x-cli-overview.md](x-cli-overview.md)** - **START HERE for x-cli** - Platform support, building, usage, troubleshooting
- **[../MAINTAINING-x-cli.md](../MAINTAINING-x-cli.md)** - x-cli build, test, and release procedures (Windows + Linux binaries)
- **[x-cli-playbook.md](x-cli-playbook.md)** - Practical x-cli workflows and examples
- **[vscode-tasks.md](vscode-tasks.md)** - All VS Code tasks explained (Tasks 01-34)

## 🔍 Testing & Quality Assurance

- **[vi-history-suite-overview.md](vi-history-suite-overview.md)** - VI History comparison suite complete guide
- **[VI-HISTORY-SUITE-SPECIFICATION.md](VI-HISTORY-SUITE-SPECIFICATION.md)** - Detailed VI History specifications
- **[vscode-tasks-traceability.md](vscode-tasks-traceability.md)** - Task traceability matrix

## 🐳 Ollama Executor & Automation

- **[ollama-parity-quickstart.md](ollama-parity-quickstart.md)** - Ollama executor quickstart and simulation mode
- **[github-actions-ollama-executor.md](github-actions-ollama-executor.md)** - GitHub Actions integration
- **[adr/ADR-2025-017-ollama-locked-executor.md](adr/ADR-2025-017-ollama-locked-executor.md)** - Ollama decision rationale
- **[adr/ADR-2025-018-ollama-cross-compilation-simulation.md](adr/ADR-2025-018-ollama-cross-compilation-simulation.md)** - Simulation mode design

## 🏗️ Architecture & Decisions

- **[adr/adr-index.md](adr/adr-index.md)** - Architecture Decision Records index
- **[adr/ADR-2025-011-repo-structure.md](adr/ADR-2025-011-repo-structure.md)** - Repository structure rationale
- **[orchestration-compat-test-matrix.md](orchestration-compat-test-matrix.md)** - Orchestration compatibility matrix

## 📋 Requirements & Compliance

- **[requirements/requirements.csv](requirements/requirements.csv)** - ISO/IEC/IEEE 29148 requirements
- **[requirements-analysis.md](requirements-analysis.md)** - Requirements analysis methodology
- **[../reports/requirements-summary.md](../reports/requirements-summary.md)** - Auto-generated requirements summary

## General Setup Guides

- [Manual Setup Instructions](manual-instructions.md)
- [Automated Setup Instructions](automated-setup.md)
- [Python Environment Setup](python-env.md)
- [PowerShell CLI GitHub Action Instructions](powershell-cli-github-action-instructions.md)
- [PowerShell Dependency Scripts](powershell-dependency-scripts.md)
- [Self-Hosted Runner Setup](setup-self-hosted-runner.md)

## CI Workflows & Actions

- [CI Workflows Overview](ci-workflows.md)
- [Experiments Guide](ci/experiments.md)
- [Troubleshooting & FAQ](ci/troubleshooting-faq.md)
- [OS Troubleshooting](OS-TROUBLESHOOTING.md)
- **Composite Actions**: [ci/actions/README.md](ci/actions/README.md)
  - [Build VI Package](ci/actions/build-vi-package.md)
  - [Development Mode Toggle](ci/actions/development-mode-toggle.md)
  - [Injecting Repo/Org to VI Package](ci/actions/injecting-repo-org-to-vi-package.md)
  - [Maintainer's Guide](ci/actions/maintainers-guide.md)
  - [Multichannel Release Workflow](ci/actions/multichannel-release-workflow.md)
  - [Runner Setup Guide](ci/actions/runner-setup-guide.md)
  - [Troubleshooting Experiments](ci/actions/troubleshooting-experiments.md)

## 🔑 Key Concepts

### Platform Support

- **Windows**: LabVIEW builds, VIPM packages, PPL generation (Windows-only, requires LabVIEW 2021 SP1)
- **Linux**: x-cli binaries, CI validation, Docker/Ollama workflows
- **Cross-platform**: x-cli builds both Windows and Linux binaries from single source

### CLI Invocation

**Always use the wrapper**:
```powershell
pwsh scripts/common/invoke-repo-cli.ps1 -Cli XCli -- <command>
```

See [x-cli-overview.md](x-cli-overview.md#wrapper-script-invoke-repo-clips1) for details.

### VS Code Tasks

- **01-09**: Core builds and verification
- **10-19**: Development tools and utilities  
- **20-29**: Advanced builds (SD, PPL, worktrees)
- **30-39**: Ollama locked executor tasks

Complete catalog: [vscode-tasks.md](vscode-tasks.md)

## 📁 Documentation Structure

```
docs/
├── README.md                       # This index
├── x-cli-overview.md               # ⭐ x-cli comprehensive guide
├── x-cli-playbook.md               # x-cli workflows
├── vi-history-suite-overview.md    # ⭐ VI History guide
├── vscode-tasks.md                 # VS Code tasks reference
├── ollama-parity-quickstart.md     # Ollama quickstart
├── adr/                            # Architecture decisions
│   ├── adr-index.md
│   ├── ADR-2025-011-repo-structure.md
│   ├── ADR-2025-017-ollama-locked-executor.md
│   └── ADR-2025-018-ollama-cross-compilation-simulation.md
├── requirements/                   # Requirements artifacts
├── schemas/x-cli/                  # Telemetry schemas
└── ci/                             # CI-specific docs
```

## 🆘 Need Help?

1. **Check this index** for relevant documentation
2. **Read the overview** for your topic (x-cli, VI History, etc.)
3. **Try the quickstart** for step-by-step guidance
4. **Check troubleshooting sections** in overview documents
5. **Open an issue** if documentation is unclear

---

**Maintainers**: Repository contributors  
**Last Updated**: 2025-12-06
