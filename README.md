# LabVIEW Icon Editor  
[![Build VI Package](https://github.com/ni/labview-icon-editor/actions/workflows/build-vi-package.yml/badge.svg)](https://github.com/ni/labview-icon-editor/actions/workflows/build-vi-package.yml)  
> **Latest Pull Request:** [GitHub Action to Build and Release the Icon Editor](https://github.com/ni/labview-icon-editor/pull/158)

---

## Overview
This repository hosts the source for the **LabVIEW Icon Editor**. It includes PowerShell tooling to streamline CI/CD and packaging, plus reference workflows for **GitHub Actions** and **self-hosted runners**. Our goal is to collaborate with fellow software engineers to evolve and improve this solution.

---

## Key Components
1. **Source Files**  
   Source code for customizing and extending the Icon Editor.

2. **PowerShell Automation**  
   - Built on [g-cli](https://github.com/G-CLI/G-CLI)  
   - Handles packaging and distribution tasks  
   - Can be easily integrated into existing DevOps pipelines

3. **GitHub Actions using PowerShell Automation**  
   - [Development Mode Toggle](docs/actions/development-mode-toggle.md)  
   - [Build VI Package](https://github.com/ni/labview-icon-editor/actions/workflows/build-vi-package.yml)  
   - [Run Unit Tests](https://github.com/ni/labview-icon-editor/actions/workflows/run-unit-tests.yml)

---

## How developing a feature looks like
1. **Clone or Fork** this repo.  
2. Review the [**CONTRIBUTING**](CONTRIBUTING.md) guidelines to find out how to get assigned to an issue.
3. Pick 1 workflow:
   1. [Manual](./docs/manual-setup.md)
   2. [Powershell Tools](./docs/automated-setup.md)
   3. [PowerShell Tools on Self-Hosted Runner](./docs/ci-workflows.md) 
4. [Enable Development Mode](docs/actions/development-mode-toggle.md) **or** follow the steps to [Edit the source manually](./docs/manual-setup.md)
5. Develop the feature on your fork. The way you test your changes will depend on the workflow you chose.
6. Submit a pull request to the feature branch.
   
>    <img width="710" alt="image" src="https://github.com/user-attachments/assets/dc2b2feb-cff3-4166-a940-0c7f9329b964" />

>  Once the [Run Unit Tests](https://github.com/ni/labview-icon-editor/actions/workflows/run-unit-tests.yml)  GitHub Action has a green checkmark, a VI package will posted to the GitHub Action Artifact

7. The *Technical Steering Commitee* and *Open Source Program Manager* will review the pull request.

   **Technical steering committee:**
      - [@JayKayAce](https://github.com/JayKayAce)
      - [@crossrulz](https://github.com/crossrulz)
      - [@neilpate](https://github.com/neilpate)
      - [@j-medland](https://github.com/j-medland)
      - @markballa
      - [@RobustoSystems](https://github.com/RobustoSystems)

   **NI Open Source Program Manager:**
      - [@svelderrainruiz](https://github.com/svelderrainruiz) -   sergio.velderrain@emerson.com
     
8. Once merged, a self-hosted runner releases to the develop branch automatically.

>  **Thats it! your feature or bugfix (combined with many others!!) will follow the [GitFlow model](https://nvie.com/posts/a-successful-git-branching-model/) and a test plan maintained by NI and the LabVIEW Community will be executed before merging into main.** 
---
## Documentation
- **[Manual Setup & Distribution](./docs/manual-setup.md)**  
  Use this if you prefer manual configuration and packaging steps without automated tooling.

- **[Automated Setup & Distribution](./docs/automated-setup.md)**  
  Integrate with PowerShell scripts to build, test, and deploy either locally or via GitHub Actions.

- **[Fork-Friendly CI/CD Workflows](./docs/ci-workflows.md)**  
  Implement a customizable pipeline for your fork. Includes guidance on GPG signing, automated version bumps, and more.

---

## Contributing
- **[CONTRIBUTING](CONTRIBUTING.md)** – Guidelines for submitting patches, feature requests, and bug fixes.  
- **[LICENSE](LICENSE)** – Details on how this project is licensed.

---

### Thank You!
Your contributions help us refine and extend the Icon Editor’s capabilities. We appreciate your collaboration and look forward to your ideas, feedback, and pull requests.
