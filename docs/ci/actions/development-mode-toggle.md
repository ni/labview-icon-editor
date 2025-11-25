# Development Mode Toggle

This document explains how to use and customize the **Development Mode Toggle** workflow, which lets you enable or disable a “development mode” on a self-hosted GitHub Actions runner. It is particularly aimed at developers contributing to NI’s (National Instruments) LabVIEW-based open-source projects.

## 1. Overview

### What Is “Development Mode”?
In LabVIEW-centric projects, “development mode” usually refers to a runner state that enables additional debugging or specialized project setup. For instance, you might need to move specific set of files from Program Files, or set a Token on the LabVIEW.ini of a specific LabVIEW version before running your workflow. Turning “dev mode” on/off allows you to toggle these specialized settings quickly in order to switch your system to a state where you can install the VI Package in order to test your change and to distribute it for others to test as well.

### Purpose of This Workflow
- Makes it easy for collaborators to set a **self-hosted runner** (their own machine or a shared one) to a special “development” state without having to do it manually, taking into consideration that this will have to happen multiple times in the development phase.
- Can be triggered manually (via `workflow_dispatch`) or from other workflows (via `workflow_call`).
- Lets you quickly switch back to a **testable** state when you’re done coding so you can install the final VI Package to test your change.
- Allows collaborators to **experiment with or update the order of operations** in the underlying PowerShell scripts on their own fork, then propose those changes via pull requests if they happen to improve our overall process.

**Note**: Contributors who fork this repository can keep their local copy of `.github/workflows/development-mode-toggle.yml` and its associated PowerShell scripts up to date by frequently pulling changes from the upstream repository. Likewise, if they make improvements to the scripts in their fork, they can open a pull request to merge those improvements back upstream.

## 2. Usage

You do **not** need to copy/paste the entire workflow snippet here, as it’s already in your repo (“Development mode toggle”). Instead, here is a conceptual usage overview:

1. **Triggering Manually**
   - Go to the “Actions” tab on your (or your fork’s) GitHub repository.
   - Select the **“Toggle Development Mode”** workflow.
   - Click “Run workflow” and choose either `enable` or `disable` from the dropdown.
   - This will execute the PowerShell scripts ([`Set_Development_Mode.ps1`](../../../scripts/set-development-mode/Set_Development_Mode.ps1) or [`RevertDevelopmentMode.ps1`](../../../scripts/revert-development-mode/RevertDevelopmentMode.ps1)) on the **target self-hosted runner** (your personal machine or a shared machine).

2. **Important Note for Testing**
   - If your system is set to dev mode (`enable`), you won’t be able to open the icon editor after you install the VI Package.
   - **Once you finish coding** or making changes, **switch back** (`disable`) to a normal testable state to be able to install the VI Package and test your change.

3. **Triggering from Another Workflow**
   - Use a `workflow_call` reference (detailed examples below).
   - Pass the input parameter `mode` set to `enable` or `disable`.
   - The runner that calls it will be the one switched into (or out of) dev mode.

## 3. Examples: Calling This Workflow

Below are **three** ways to invoke this workflow. Each approach sets `mode` to either `enable` or `disable`.

### 3.1 Call from Another Workflow in the Same Repository

If you have another workflow file (e.g., `my-other-workflow.yml`) in the same repo, you can reference “Development mode toggle” by its local path:

    # my-other-workflow.yml
    name: "My Other Workflow"

    on:
      workflow_dispatch:

    jobs:
      call-dev-mode:
        runs-on: [self-hosted-windows-lv]
        steps:
          - name: Invoke Dev Mode Toggle (enable)
            uses: ./.github/workflows/development-mode-toggle.yml
            with:
              mode: enable

1. `uses: ./.github/workflows/development-mode-toggle.yml` – Tells GitHub to run a local reusable workflow found in your repo.
2. `with:` – Passes inputs to that workflow. Here, `mode: enable`.

### 3.2 Call from Another Repository (Direct GitHub Reference)

If you store “Development mode toggle” in a separate public repo, you can reference it by the GitHub org/repo and the specific path/branch:

    name: "Cross-Repo Dev Mode Toggle"

    on:
      workflow_dispatch:

    jobs:
      remote-dev-mode:
        runs-on: [self-hosted-windows-lv]
        steps:
          - name: Use remote Dev Mode Toggle
            uses: <owner>/<repo>/.github/workflows/development-mode-toggle.yml@main
            with:
              mode: disable

1. Replace `<owner>/<repo>` with the actual GitHub account and repository name (for example, `ni/my-shared-workflows`).
2. The suffix `@main` indicates which branch/ref to fetch. You can also use a tag or commit SHA.
3. Inputs like `mode` are passed the same way.

### 3.3 Call from a Fork

If a collaborator forked your original repo, they might keep the workflow in their own fork. They can reference that fork directly:

    name: "Forked Dev Mode Example"

    on:
      workflow_dispatch:

    jobs:
      forked-workflow-call:
        runs-on: [self-hosted-windows-lv]
        steps:
          - name: Call Dev Mode Toggle from My Fork
            uses: <your-fork>/<repo>/.github/workflows/development-mode-toggle.yml@my-feature-branch
            with:
              mode: enable

Here, you might see something like `githubuser/labview-icon-editor-fork/.github/workflows/development-mode-toggle.yml@feature-xyz`. Again, you pass the `mode` input as needed. Whenever upstream changes are made to the scripts, the fork owner can **pull** to update their local `.github/workflows/development-mode-toggle.yml` file.

---

## 4. Customization

All “dev mode” logic resides in two PowerShell scripts located under `scripts`:

- **[`Set_Development_Mode.ps1`](../../../scripts/set-development-mode/Set_Development_Mode.ps1)** – Called when mode is `enable`.
- **[`RevertDevelopmentMode.ps1`](../../../scripts/revert-development-mode/RevertDevelopmentMode.ps1)** – Called when mode is `disable`.

These scripts currently do things like update environment variables, configure LabVIEW paths, or install certain dependencies. **To change** how “dev mode” behaves, **edit those scripts** directly. 

### Pull Requests with Script Updates
Collaborators are free to:
1. **Modify** [`Set_Development_Mode.ps1`](../../../scripts/set-development-mode/Set_Development_Mode.ps1) or [`RevertDevelopmentMode.ps1`](../../../scripts/revert-development-mode/RevertDevelopmentMode.ps1) on their forks.
2. **Enable dev mode** on their self-hosted runner (via their fork), capturing the GitHub Actions logs as proof that their changes worked as intended.
3. **Open a Pull Request** to merge these script changes back into the upstream repository, referencing the successful action logs as additional evidence.

---

## 5. Additional Resources
- Refer to your README.md for details on setting up your runner (LabVIEW requirements, etc.).
- GitHub Docs: https://docs.github.com/en/actions/using-workflows/reusing-workflows#calling-a-reusable-workflow

---

