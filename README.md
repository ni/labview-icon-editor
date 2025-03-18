# LabVIEW Icon Editor  
[![Build VI Package](https://github.com/ni/labview-icon-editor/actions/workflows/build-vi-package.yml/badge.svg)](https://github.com/ni/labview-icon-editor/actions/workflows/build-vi-package.yml)  
> **Latest Pull Request:** [GitHub Action to Build and Release the Icon Editor](https://github.com/ni/labview-icon-editor/pull/158)



## Overview
This repository hosts the source for the **LabVIEW Icon Editor**. It includes PowerShell tooling to streamline CI/CD and packaging, plus reference workflows for **GitHub Actions** and **self-hosted runners**. Our goal is to collaborate with fellow software engineers to evolve and improve this solution.



## Key Components
1. **Source Files**  
   Source code for customizing and extending the Icon Editor.

2. **PowerShell Automation**  
   - Built on [G-CLI](https://github.com/G-CLI/G-CLI)  
   - Handles packaging and distribution tasks  
   - Can be easily integrated into existing DevOps pipelines

3. **GitHub Actions using PowerShell Automation**  
   - [Development Mode Toggle](https://github.com/ni/labview-icon-editor/actions/workflows/development-mode-toggle.yml)  
   - [Build VI Package](https://github.com/ni/labview-icon-editor/actions/workflows/build-vi-package.yml)  
   - [Run Unit Tests](https://github.com/ni/labview-icon-editor/actions/workflows/run-unit-tests.yml)



## How developing a feature looks like
1. **Clone or Fork** this repo.  
2. Review the [**CONTRIBUTING**](CONTRIBUTING.md) guidelines to find out how to get assigned to an issue.
3. Pick 1 workflow:
   1. [Manual](./docs/manual-instructions.md)
   2. [Powershell Tools](./docs/powershell-cli-instructions.md)
   3. [PowerShell Tools on Self-Hosted Runner](docs/powershell-cli-github-action-instructions.md) 
4. [Enable Development Mode](docs/actions/development-mode-toggle.md) **or** follow the steps to [Edit the source manually](./docs/manual-setup.md)
5. Develop the feature on your fork. The way you test your changes will depend on the workflow you chose.
6. Submit a pull request to the feature branch.
7. The *Technical Steering Commitee* and *Open Source Program Manager* will review the pull request.

   **Technical Steering Committee:**
      - [@JayKayAce](https://github.com/JayKayAce)
      - [@crossrulz](https://github.com/crossrulz)
      - [@neilpate](https://github.com/neilpate)
      - [@j-medland](https://github.com/j-medland)
      - @markballa
      - [@RobustoSystems](https://github.com/RobustoSystems)

   **NI Open Source Program Manager:**
      - [@svelderrainruiz](https://github.com/svelderrainruiz) -   sergio.velderrain@emerson.com
     
8. Once approved, your change will be merged to the develop branch automatically.

>  **Thats it! your feature or bugfix (combined with many others!!) will follow the [GitFlow model](https://nvie.com/posts/a-successful-git-branching-model/) and a test plan maintained by NI and the LabVIEW Community will be executed before merging into main.** 

## Documentation

- **[Build VI Package](docs/ci/actions/build-vi-package.md)**
   This document is designed to help maintainers, contributors, and engineers automate the release process for LabVIEW-based projects.

- **[Development Mode Toggle](docs/ci/actions/development-mode-toggle.md)**
   Explains how to use and customize the **Development Mode Toggle** workflow, which lets you enable or disable a “development mode” on a self-hosted GitHub Actions runner.
   
- **[Multichannel Release Workflow](docs/ci/actions/multichannel-release-workflow.md)**
   This guide focuses on the **release workflow**, specifically how we handle **multiple pre-release channels** (Alpha, Beta, RC) in addition to final versions.

- **[Runner Setup Guide](docs/ci/actions/runner-setup-guide.md)**
   Explains how to locally set up and run the **LabVIEW Icon Editor** workflows on a **self-hosted runner** using **GitHub Actions**.

- **[Injecting Owner/Repo Into VI Package](docs/actions/injecting-repo-org-to-vi-package.md)**
   This document explains how we leverage **PowerShell** scripts and **GitHub Actions** to insert **repository** and **organization** metadata into the LabVIEW Icon Editor’s VI Package, ensuring each build is **unique** and **traceable**.

- **[Troubleshooting & FAQ](docs/ci/troubleshooting-faq.md)**
provides a collection of common **troubleshooting** scenarios (with solutions) and a **FAQ** (Frequently Asked Questions) for the LabVIEW Icon Editor GitHub Actions workflows.

## Contributing
- **[CONTRIBUTING](CONTRIBUTING.md)** – Guidelines for submitting patches, feature requests, and bug fixes.  
- **[LICENSE](LICENSE)** – Details on how this project is licensed.


### Thank You!
Your contributions help us refine and extend the Icon Editor’s capabilities. We appreciate your collaboration and look forward to your ideas, feedback, and pull requests.
