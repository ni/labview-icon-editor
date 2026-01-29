# LabVIEW Icon Editor – Contributing Guide

The **LabVIEW Icon Editor** is now an open-source project to encourage collaboration between NI and the LabVIEW community. Every new build of LabVIEW will pull in the Icon Editor from this repo’s `main` branch, so your contributions (features, fixes, docs) can directly impact official LabVIEW distributions. The direction of the Icon Editor (which new features are added or omitted) is guided by a core team (Steering Committee) made up of NI staff and community volunteers – a “cathedral” style of development. **Your participation is critical**: some of the most important work comes from community members through ideas, code, and testing.

## Our Contributing Philosophy

This repo follows a typical fork-and-pull model on [GitHub](https://github.com/ni/labview-icon-editor). To contribute, you’ll need to fork the project, create a branch with your changes, and submit a pull request (PR) to the upstream repository. All contributors must adhere to our [Code of Conduct](CODE_OF_CONDUCT.md) and (if not an NI employee) sign the Contributor License Agreement (CLA) before we can merge your code.

We welcome both code and non-code contributions. Here are some ways to help:

- 🐛 **Bug Reports:** We can’t catch every issue. If you find a bug, first search the [issues list](https://github.com/ni/labview-icon-editor/issues) to see if it’s already reported. If not, [open a new issue](https://github.com/ni/labview-icon-editor/issues/new/choose) describing the problem so we can address it.
- 💬 **Q&A and Feedback:** Participate in discussions! If you have an idea for a new feature or changes, start a conversation on our [GitHub Discussions board](https://github.com/ni/labview-icon-editor/discussions/new?category=ideas) or join the community on [Discord](https://discord.gg/q4d3ggrFVA). Your feedback on planned features (see the [New Features discussions](https://github.com/ni/labview-icon-editor/discussions/categories/new-features)) is valuable.
- 🎬 **Tackle “Good First Issues”:** Check out issues labeled [**Good first issue**](https://github.com/ni/labview-icon-editor/labels/good%20first%20issue). These are entry-level tasks that are great for new contributors. You can comment on an issue to be assigned and start working on it.
- ✏️ **Improve Documentation:** Contributing to docs is just as important as code. If you spot outdated or unclear documentation, feel free to propose changes. Our documentation is in this repo and the companion [documentation site](https://ni.github.io/labview-icon-editor/) (you can use the “Edit this page” link on the docs site).

All interactions should be respectful and follow our [Code of Conduct](CODE_OF_CONDUCT.md).

## Getting Started

1. **Development Setup:** To build or test the project locally, you will need **LabVIEW 2021 (21.0)** (32-bit and 64-bit). This is the version the source is saved in for development purposes. *(The released VI Package targets LabVIEW 2021 (21.0) or later.)* You’ll also need **NI’s G-CLI** tool and the **VIPM API**:
   - **G-CLI (Command Line Interface Toolkit)** – *Provides the ability to run LabVIEW VIs from the command line.* This is distributed via VI Package; the version used in this project is included in our dependency file (see below).
   - **VI Package Manager (VIPM) API** – *Enables automation of VIPM for building and applying packages.* This is also included as a VI Package dependency.
   
   These dependencies (with exact versions) are defined in the `.github/actions/apply-vipc/runner_dependencies.vipc` file in this repo. **Before building the Icon Editor, open VIPM and apply `runner_dependencies.vipc`** to install all required packages (G-CLI, VIPM API, etc.) for both 32-bit and 64-bit LabVIEW. This ensures your environment matches the CI environment.
2. **Find an Issue or Feature:** If you have a new idea, start a discussion (as noted above) to get feedback from the maintainers and community. For bug fixes or minor improvements, feel free to open a PR directly, but for any significant change, it’s best to discuss first.
3. **Fork & Branch:** Fork the repository to your GitHub account and then clone it locally. Create a new branch for your work. For features, use the issue number in the name (e.g., `issue-123-add-xyz-tool`); for bug fixes, a descriptive prefix like `bugfix/fix-crash-on-load` is fine.
4. **Follow Workflow:** We use a branching strategy where official development happens on feature branches and merges go first into `develop`, then through pre-release branches (e.g. `release-alpha`, `release-beta`, `release-rc`) before merging into `main` for the final release. External contributors will typically collaborate on feature branches created by NI maintainers (once an issue is approved and labeled "Open to contribution"). If you’re working on a fork, you can still develop on your own branch and submit a PR to the appropriate branch in the main repo.
5. **Write and Test Code:** Make your changes in LabVIEW. If you’ve applied the dependencies and run the `Tooling\Prepare LV to Use Icon Editor Source.vi` (or used the PowerShell scripts to set development mode), you can open `lv_icon_editor.lvproj` and begin editing the VIs. We encourage writing or updating tests if applicable (see `Test` folder or ask maintainers how to run tests – we have a CLI script `RunUnitTests.ps1` that uses the included testing framework).
6. **Commit Guidelines:** Commit messages should be clear. Please **sign off** your commits (this adds a `Signed-off-by:` line to your commit message, indicating you agree to the Developer Certificate of Origin). If using Git from command line, `git commit -s` will do this. Ensure each commit builds and passes tests.
7. **Submit a Pull Request:** Push your branch to your fork and open a PR against this repository. In the PR description, clearly explain the purpose of the change, what was changed, and reference any issue it addresses (e.g., “Closes #123”). Include any relevant testing steps or screenshots. A good PR description has:
   - **Purpose** – Why is this change being made?
   - **Changes Made** – What did you do? 
   - **Issue Reference** – Link the issue number if one exists.
   - **Testing** – How can reviewers test or reproduce the change?
8. **Respond to Feedback:** Maintainers will review your PR. You may see comments requesting changes or asking questions. This is a normal part of the process. Update your code as needed and push new commits; they will automatically be added to the PR.
9. **CI Builds:** When you open a PR, our continuous integration will automatically attempt to build the VI Package and run tests. You’ll see a check for the **CI Pipeline (Composite)** workflow with a job named **Build VI Package** – if it fails, inspect the logs (e.g., missing dependencies or failing tests) and update your code. Successful CI will produce a `.vip` artifact that maintainers and you can download to test your changes in LabVIEW.

> Note: When opening a PR, apply exactly one release label (major, minor, or patch) to request the version bump. The CI pipeline will fail if no label (or multiple labels) are set, since it relies on a single label to determine the new version.

*(Note: Our GitHub Actions use a self-hosted runner with LabVIEW, so external contributors **do not need** to have their own LabVIEW runner to get a build. The CI will handle building the package.)*
10. **Merge Process:** Once your contribution is approved, a maintainer will merge it. We typically merge into the `develop` branch. Your changes will be bundled into the next release that goes to `main`. If your contribution is large or part of an experimental feature, it might live in a longer-running branch (maintainers will advise in such cases).

## Feature Requests & Enhancements

If you have an idea for a new feature or a significant change, please start by creating a discussion in the [**New Features** category](https://github.com/ni/labview-icon-editor/discussions/categories/new-features) rather than directly opening an issue or PR. In your discussion post, describe the problem your idea would solve or the use-case it would enable. The core team and community can then provide feedback and determine if it aligns with the project’s goals. 

After discussion, if the idea is accepted for development, the maintainers will label an issue for it (and often create a feature branch as described in the workflow above). You can then proceed to implement the feature on that branch via a pull request.

**Remember:** We’d hate for you to invest time in a feature that might not fit, so always get buy-in through a discussion first. The Steering Committee (project leads) ultimately decides which enhancements become part of the official Icon Editor, but they heavily weigh community interest and input.

## Pull Request Guidelines

When submitting a pull request, follow these guidelines to streamline reviews:

1. **Title:** Use a short, descriptive title for your PR that summarizes the change.
2. **Description:** Fill out the PR template or include details covering:
   - **Purpose:** Why this change is needed (problem it fixes or feature it adds).
   - **Changes Made:** What you changed. If it’s a bug fix, describe the root cause and solution. If it’s a new feature, summarize how it works.
   - **Related Issues:** Reference any issue numbers (e.g., “Closes #123”).
   - **Testing:** Explain how you tested the changes. Include steps for reviewers to test, and mention any specific areas to focus on.
3. **Commit Sign-off:** As mentioned, ensure your commits are signed off (DCO). Also, make sure each commit in the PR is self-contained and the overall branch history can be cleanly merged or squashed as the maintainers see fit.

Be patient and responsive during the review. We might ask you to make changes – that’s part of making sure the contribution is robust and fits well with the codebase.

## Reporting Issues

When opening an issue (bug report or documentation issue), please provide as much detail as possible to help us understand and reproduce the problem:

- **Title:** A clear, concise title that summarizes the issue.
- **Description:** Explain the issue in detail. For a bug, describe what happens and what you expected to happen instead.
- **Steps to Reproduce:** List the steps or include a VI (or sequence of actions in LabVIEW) that reproduces the issue.
- **Environment:** Include your OS, LabVIEW version (e.g., 2021 64-bit), and any other relevant system info.
- **Screenshots:** If applicable, add screenshots or error messages to illustrate the problem.

Well-written issues help us resolve problems faster. And if you’re up for it, after reporting a bug you might try to fix it and submit a PR!

## Governance and Code of Conduct

This project is governed under NI’s open source guidelines. We have a Steering Committee that oversees major decisions and a group of maintainers who handle day-to-day management. For more details on how the project is managed, see [GOVERNANCE.md](GOVERNANCE.md). By participating in this project, you agree to abide by the standards of our [Code of Conduct](CODE_OF_CONDUCT.md). 

Thank you for contributing to the LabVIEW Icon Editor! Your ideas, code, and effort help shape a better tool for all LabVIEW users.
