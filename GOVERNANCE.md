# NI Open Source Initiative Bylaws (Proposal from Sergio only, and not currently endorsed by NI)

Note: I wrote this document with the assistance of an AI deep research model in order to ensure this document is accurate with the rest of the documentation of the repo. There could be discrepancies, or you could see the narrative expand on a direction a "normal" LabVIEW end-user wouldnt expand to (e.g. using VI package manager optionally to install VI packages, etc..). This document is marked as a draft while we make sure that the AI assisted content has been thoroughly reviewed.

## Table of Contents
- [Introduction](#introduction)
- [Roles and Responsibilities](#roles-and-responsibilities)
  - [NI Open Source Program Manager](#ni-open-source-program-manager)
  - [Technical Steering Committee](#technical-steering-committee)
- [Contribution Workflows](#contribution-workflows)
  - [Standard Contribution Process](#standard-contribution-process)
  - [Experimental Branches for Large Features](#experimental-branches-for-large-features)
- [Decision-Making Authority and Governance](#decision-making-authority-and-governance)
- [CI/CD Integration and Release](#cicd-integration-and-release)
- [Community Expectations and Code of Conduct](#community-expectations-and-code-of-conduct)
- [Conclusion and Encouragement](#conclusion-and-encouragement)

---

## Introduction
Welcome to the **NI Open Source Initiative Bylaws**. This document serves as a transparent operational guide for how NI (National Instruments) open source projects are run. It is intended for both new contributors and Steering Committee members to understand how we collaborate, make decisions, and integrate contributions. The goal is to foster a **collaborative, transparent, and sustainable** environment where community contributions drive NI’s open source projects forward in harmony with NI’s product ecosystem.

Many NI open source repositories (for example, the [LabVIEW Icon Editor](https://github.com/ni/labview-icon-editor)) directly influence official NI products. Some NI products automatically pull code from these open source repos for their releases. This means **your contributions can become part of NI’s products**, reaching a wide audience. These bylaws clarify how that process works – from proposing changes, to getting them reviewed and merged, all the way to seeing them in production. We’ve written this in a lightweight tone and structured format to make it easy to navigate and understand.

Whether you’re a developer submitting a fix, or a Steering Committee member reviewing a major new feature, this guide will help us stay aligned. Below, we outline the roles involved, the contribution workflow, who has decision authority, how continuous integration (CI) ties in, and the expectations for everyone’s behavior. *Let’s build great things together, with openness and respect!* 🚀

---

## Roles and Responsibilities
Open collaboration works best when everyone understands the various roles and their responsibilities. NI’s open source projects are governed by a mix of NI employees and community members, each with clear duties. The two key roles in our governance model are the **NI Open Source Program Manager** and the **Technical Steering Committee**. We describe each below, along with how they interact. (In practice, there may be additional maintainers or contributors, but the following roles are central to decision-making and oversight.)

### NI Open Source Program Manager
The **NI Open Source Program Manager** is an NI-appointed person responsible for the overall health and direction of the open source project. They act as the bridge between NI’s internal teams and the external community. Their responsibilities include:

- **Strategic Oversight:** Ensuring that the project’s roadmap aligns with NI’s product and business goals. Major roadmap decisions or pivots are guided by the Program Manager on behalf of NI (a “BDFL”-style oversight), while day-to-day decisions are left to the community steering committee. In other words, the Program Manager has veto or final say on big-picture decisions to keep the project in sync with NI’s needs, but generally trusts the community for routine choices.
- **Facilitating Contributions:** Making sure external contributions can be integrated smoothly. This means removing blockers (e.g. clarifying requirements, providing resources) and ensuring legal prerequisites (like signing CLAs) are in place so contributions can be used in NI products.
- **Administrative Duties:** Overseeing repository settings, CI/CD credentials, and other admin aspects. They might trigger or approve special workflows (e.g., building artifacts for experimental branches).
- **Steering Committee Support:** They coordinate Steering Committee discussions, mediate disagreements, and ensure committee decisions are documented and followed. The Program Manager also has “final override” if there’s a critical need to keep the project aligned with NI’s obligations.

### Technical Steering Committee
Each NI open source project has a **Technical Steering Committee (TSC)**, composed of NI engineers and community contributors with proven expertise. The Steering Committee:

- **Triages and Roadmaps:** Decides which features or bug fixes are open to community contribution, labeling issues accordingly (e.g. “Workflow: Open to contribution”).
- **Reviews and Approves Code:** Oversees pull requests, ensuring each change meets the project’s standards and aligns with product goals. They provide constructive feedback and eventually approve merging the contributions.
- **Guides Project Direction:** The SC sets short- and mid-term priorities, in consultation with the NI Program Manager, balancing community interests with NI product timelines.
- **Membership & Appointments:** SC members are appointed by the NI Open Source Program Manager, often upon nomination by existing members. Active, high-quality contributors may be invited to join over time.

In short, the Steering Committee and the NI Program Manager partner to run the project: the SC handles daily technical decisions and merges, and the Program Manager ensures alignment with NI’s broader strategies and can step in with a final override if absolutely needed.

---

## Contribution Workflows

### Standard Contribution Process
For most contributions (small fixes, features, docs updates), we use a straightforward flow:

1. **Find or Propose an Issue:** See if there’s an existing issue labeled “[Workflow: Open to contribution](https://github.com/ni/labview-icon-editor/issues?q=is%3Aissue+label%3A%22Workflow%3A+Open+to+contribution%22)” or propose a new one by opening a GitHub Issue. Discuss your idea to ensure it’s in scope.
2. **Get Assigned:** Comment on the issue to volunteer; a Steering Committee member will assign it to you if it’s ready and you’re the first or best fit.
3. **Develop on a Fork or Branch:** Follow instructions in the repo’s [README.md](https://github.com/ni/labview-icon-editor/blob/main/README.md) and [CONTRIBUTING.md](https://github.com/ni/labview-icon-editor/blob/main/CONTRIBUTING.md) to set up your environment and create a branch or fork. Implement your changes, run tests locally, and prepare a pull request (PR).
4. **Open a Pull Request:** Once ready, open a PR targeting the appropriate branch (often `develop`). If it’s your first contribution, you’ll be asked to sign a Contributor License Agreement (CLA) if required. The CI pipeline will run tests.
5. **Review & Merge:** The Steering Committee and maintainers review your PR, request changes if needed, and once it’s approved and passes CI, they merge it. Congratulations!

For more details, see the project’s [CONTRIBUTING.md](https://github.com/ni/labview-icon-editor/blob/main/CONTRIBUTING.md) for step-by-step instructions.

### Experimental Branches for Large Features
Sometimes contributions are too large or long-running to fit a single PR workflow. In those cases, we use **experimental branches**:

1. **Proposal & Approval:** Pitch your big feature or concept to the Steering Committee. If approved, NI staff or an SC member will create an `experiment/<feature>` branch in the repo.
2. **Ongoing Work & CI:** You or a team can develop on this experiment branch, benefiting from CI (tests, etc.). By default, artifacts might not be automatically published until an NI admin triggers an “approve-experiment” workflow for safety.
3. **Periodic Check-Ins:** Steering Committee members monitor progress, give feedback, and ensure you stay on track. If needed, you can create sub-branches (e.g. alpha, beta, rc) under the experiment.
4. **Final Merge or Archive:** When finished (and approved), the experiment merges into `develop` or is archived if unsuccessful. See the [README.md](https://github.com/ni/labview-icon-editor/blob/main/README.md) or future `EXPERIMENTS.md` for more detailed instructions on the experimental workflow.

---

## Decision-Making Authority and Governance
Our governance model is **collaborative**:

- **Steering Committee**: Day-to-day technical decisions, approving community contributions, labeling issues. They aim for consensus among committee members.  
- **NI Program Manager (BDFL)**: Holds final override power to align with NI obligations or product roadmap. Rarely exercised but remains an option.
- **Maintainers**: Perform routine merges, manage CI, label minor issues. Larger or strategic changes require Steering Committee approval.
- **Contributors**: Propose and implement changes through the standard or experimental process, guided by the committee’s decisions and feedback.

If disagreements arise, the Steering Committee or maintainers escalate to the NI Program Manager. This structure balances open collaboration with product accountability. For more details about SC membership or how steering decisions get finalized, see the project’s [CONTRIBUTING.md](https://github.com/ni/labview-icon-editor/blob/main/CONTRIBUTING.md) or check if a dedicated `GOVERNANCE.md` exists in the repo.

---

## CI/CD Integration and Release
We use **Continuous Integration (CI)** on all pull requests:

- **Automated Testing**: Every PR triggers builds and tests (e.g., using GitHub Actions). Contributors can see results under the “Checks” tab on GitHub.
- **Artifact Generation**: On merges (or via manual approval in experimental branches), CI might produce `.vip` packages or other artifacts (like installers). See the [CI config files](https://github.com/ni/labview-icon-editor/tree/main/.github/workflows) for details.
- **Semantic Versioning**: Some repos automatically bump version numbers based on PR labels (`major`, `minor`, `patch`). The CI merges your code and tags a new release if needed.
- **Integration into NI Products**: Over time, changes from `develop`/`main` flow into official LabVIEW builds. NI ensures alignment with the product schedule. Your code can end up shipped with LabVIEW if it meets all requirements and merges in time.

The Steering Committee and maintainers watch CI outcomes. If tests fail, they’ll ask you to fix issues. This loop ensures consistent quality while speeding up development.

---

## Community Expectations and Code of Conduct
We want an open, respectful, and helpful community. By participating in NI’s open source projects, you agree to follow our [Code of Conduct](https://github.com/ni/labview-icon-editor/blob/main/CODE_OF_CONDUCT.md), which covers:

- **Inclusive Communication**: Treat others with respect, offer constructive feedback, and avoid personal attacks or discriminatory language.
- **Collaboration**: Help maintain a supportive environment for all skill levels. Offer assistance, clarify confusion, and share knowledge.
- **Reporting Violations**: If you see misconduct or feel uncomfortable, follow the reporting guidelines in the [Code of Conduct](https://github.com/ni/labview-icon-editor/blob/main/CODE_OF_CONDUCT.md). Maintainers and the Steering Committee will handle concerns discreetly.

NI enforces the Code of Conduct to ensure everyone has a positive experience. Serious or repeated violations may lead to removal from the community or further steps outlined in the code.

---

## Conclusion and Encouragement
**Thank you** for reading the NI Open Source Initiative Bylaws. We believe in a transparent approach where contributors and the Steering Committee collaboratively shape our projects. By following these guidelines, we can maintain a healthy balance of innovation, product alignment, and community-driven development.

In summary:

- **NI Program Manager**: Oversees alignment with NI’s roadmap, provides final override if necessary.  
- **Steering Committee**: Trusted advisors, approves major changes, co-gatekeepers for merges.  
- **Maintainers**: Handle day-to-day operations, merges, and CI checks for non-critical PRs.  
- **Contributors**: You! Propose or pick issues, open PRs, get feedback, and become part of the LabVIEW ecosystem.

We appreciate every effort—no matter how big or small. If you have questions, check out:

- [README.md](https://github.com/ni/labview-icon-editor/blob/main/README.md) for a project overview
- [CONTRIBUTING.md](https://github.com/ni/labview-icon-editor/blob/main/CONTRIBUTING.md) for submission steps
- [CODE_OF_CONDUCT.md](https://github.com/ni/labview-icon-editor/blob/main/CODE_OF_CONDUCT.md) for community guidelines

Happy collaborating, and welcome to the NI open source community!
