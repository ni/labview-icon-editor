# NI Open Source Initiative Bylaws

*Last Updated: March 21, 2025*

**Lightweight governance guidelines for National Instruments (NI) open source projects** – This document outlines how NI’s open source projects are managed in a transparent, collaborative way. It is intended for both external contributors and NI internal maintainers across all NI open source repositories (not just LabVIEW-related projects). These bylaws are not formal legal rules, but rather a common understanding to help our community work together effectively.

## Table of Contents
- [Scope and Purpose](#scope-and-purpose)
- [Roles and Responsibilities](#roles-and-responsibilities)
  - [NI Open Source Program Managers](#ni-open-source-program-managers)
  - [Steering Committee](#steering-committee)
  - [Project Maintainers](#project-maintainers)
  - [Contributors](#contributors)
- [Governance and Decision-Making](#governance-and-decision-making)
  - [Technical Decisions and Changes](#technical-decisions-and-changes)
  - [Project Proposals and New Repositories](#project-proposals-and-new-repositories)
  - [Meetings and Communication](#meetings-and-communication)
- [Contribution Process](#contribution-process)
- [Code of Conduct and Enforcement](#code-of-conduct-and-enforcement)
- [Amending These Bylaws](#amending-these-bylaws)

## Scope and Purpose

These bylaws apply to all open source projects under the NI GitHub organization. They provide a framework for how decisions are made, how contributors interact, and how leadership roles function across projects. Every NI open source repository (for example, the LabVIEW Icon Editor and others) should follow these guidelines, ensuring consistency and fairness in how we collaborate.

The purpose of this document is to make governance clear and accessible. It describes who is responsible for what (from NI Open Source Program Managers to volunteer contributors) and how we work together. By keeping our governance lightweight and transparent, we encourage broad participation and smooth project operations. **Everyone – NI employees, community members, and users – should feel empowered to contribute and understand how decisions are made.**

## Roles and Responsibilities

Our open source community includes various roles, each with specific responsibilities. We emphasize clarity in these roles so that everyone knows how to participate and who to turn to for guidance or decisions. NI Open Source Program Managers and the Steering Committee have special leadership duties, while Maintainers and Contributors handle the day-to-day development and collaboration.

### NI Open Source Program Managers

NI Open Source Program Managers (OSPMs) are NI employees who oversee the health and process of NI’s open source initiatives. They act as coordinators and facilitators rather than traditional “bosses.” Their responsibilities include:

- **Strategic Oversight:** Ensuring that each project aligns with NI’s open source strategy and values. OSPMs help decide, in coordination with the Steering Committee, which projects to open source and how they evolve.
- **Support & Resources:** Providing maintainers and contributors with the support they need. This can include arranging access to tools, facilitating CI/CD resources, and helping with things like licensing or legal questions.
- **Process Stewardship:** Making sure projects adhere to these bylaws and follow consistent processes. For example, OSPMs check that every repo has necessary files like a [README.md](README.md), [CONTRIBUTING.md](CONTRIBUTING.md), and [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md).
- **Facilitating Decisions:** Assisting in decision-making when consensus is difficult to reach. OSPMs do not typically dictate technical decisions, but they help the community come to an agreement. In rare cases (e.g. a stalemate), an OSPM may act as a tie-breaker or appoint a mediator.
- **Code of Conduct Enforcement:** Alongside the Steering Committee, ensuring the community stays welcoming and respectful. If serious issues arise (like a violation of the Code of Conduct), OSPMs help investigate and resolve them per the guidelines in [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md).

Overall, NI Open Source Program Managers are champions of open source culture within NI. They bridge internal NI teams and the external community, making sure contributors have a positive experience. They also handle any internal NI requirements (such as legal compliance or contributor license agreements) behind the scenes so that contributors can focus on what they do best.

### Steering Committee

The **Steering Committee** is a group of experienced project leaders (both NI staff and, optionally, community experts) who guide the technical direction and governance of NI open source projects. This committee works as a team to make collaborative decisions for the benefit of the projects and community. Key aspects of the Steering Committee’s role:

- **Composition:** The committee typically includes NI Open Source Program Manager(s), lead maintainers from important projects, and possibly notable external contributors. Membership is based on merit and interest – individuals who have demonstrated commitment and expertise may be invited to join. We aim for a mix of NI insiders and community members to balance perspectives.
- **Technical Guidance:** Steering Committee members collectively set the overall vision and priorities for projects. They evaluate proposals for major new features or new open source releases. For example, if someone proposes a significant change or a new repository to be open-sourced, the Steering Committee will discuss its fit with our goals.
- **Decision Authority:** The committee makes decisions on high-level or cross-project matters. Wherever possible, decisions are made by consensus (general agreement). If consensus can’t be reached, the committee may call a simple majority vote among members to decide. The tone is collaborative – formal votes are a last resort. The Steering Committee’s goal is to reflect community input in all decisions.
- **Issue Triage & Workflow:** In practice, the Steering Committee might help triage important issues or designate certain issues as high priority. In some projects, they label issues as “Workflow: Open to contribution” (or similar) to signal that external contributors are welcome to work on them. They also review and approve significant changes: for instance, final review of a major pull request or deciding when a feature is ready to merge. Steering Committee approval may be required for changes that affect multiple projects or have broader impact.
- **Mentorship & Community Health:** Members serve as mentors and leaders in the community. They help new contributors find their footing, encourage diverse input, and ensure that discussions remain productive and respectful. If conflicts arise among contributors or maintainers, the Steering Committee can step in to mediate (always with reference to our Code of Conduct).

The Steering Committee is essentially the “brain trust” of NI’s open source efforts. However, it operates openly: discussions and decisions should be visible to the community (through meeting notes, GitHub issues, or other public forums). This transparency helps build trust. The committee does not control day-to-day development – that’s up to maintainers and contributors – but it provides guidance and oversight to keep projects on track with their objectives.

### Project Maintainers

Project Maintainers are the people with direct responsibility for the upkeep of a specific repository. Maintainers can be NI employees or community members (or both). They have write access to the repository (i.e., they can merge pull requests) and are expected to drive the project forward. Responsibilities of maintainers include:

- **Code Review & Merging:** Reviewing contributions (pull requests) from the community and other team members. Maintainers ensure that code meets quality standards, is well-tested, and aligns with the project’s goals. They merge changes into the codebase when they are satisfied with the contribution.
- **Guiding Contributors:** Acting as the first point of contact for contributors. Maintainers should respond to issues and questions, label and organize issues appropriately, and help contributors understand the development workflow (for example, referring them to [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines).
- **Upholding Standards:** Enforcing project standards for code style, documentation, and testing. They use tools and workflows (such as continuous integration checks defined in the repository’s [workflows](.github/workflows/) directory) to automate quality control. Maintainers make sure all tests pass and that each contribution doesn’t break the build or introduce licensing issues.
- **Planning & Roadmap:** Collaborating on the project’s direction. Maintainers often propose new features or enhancements and discuss them with the community. They maintain a rough roadmap (which might be documented in issues, a `ROADMAP.md`, or simply via milestones in the issue tracker) so that contributors know where the project is heading.
- **Coordination with Steering Committee:** For big decisions or uncertain areas, maintainers loop in the Steering Committee. While maintainers handle most day-to-day decisions, they recognize when an issue needs broader input (for example, a change that could affect multiple NI projects or that might be controversial). In those cases, maintainers will raise the topic with the Steering Committee for guidance.

### Contributors

Contributors include anyone in the community who contributes to the project in any form – this could be code, documentation, design suggestions, or answering questions. Contributors do not have commit rights to the repository (unless they later become maintainers), but their role is vital. Responsibilities and expectations for contributors:

- **Follow Guidelines:** Adhere to the contribution guidelines outlined in [CONTRIBUTING.md](CONTRIBUTING.md). This includes following the code style, writing good commit messages, and respecting the decisions of maintainers.
- **Engage in Discussions:** Before making significant changes, contributors should discuss ideas in GitHub issues or discussions. This collaborative approach helps ensure that efforts are aligned with project needs and avoids duplication of work.
- **Be Responsive:** If a maintainer or reviewer provides feedback on a contribution (e.g., code review comments on a pull request), the contributor should be responsive and update the contribution accordingly.
- **Code of Conduct:** Contributors must abide by the project’s [Code of Conduct](CODE_OF_CONDUCT.md) in all project-related communications. This ensures a welcoming and respectful environment for everyone.

Contributors who show dedication, good judgment, and quality work may be considered for elevation to Maintainer status over time.

## Governance and Decision-Making

In this section we outline how decisions are made and documented.

### Technical Decisions and Changes

For day-to-day changes (like fixing bugs, adding minor features, refactoring code), project maintainers can make decisions and accept pull requests following the normal review process. Maintainers should use their best judgment and consult others when a change could be contentious.

For larger technical decisions (e.g., adopting a new major dependency, significant architecture changes, or any change that could impact multiple projects), the Steering Committee should be consulted. Often, these decisions will be discussed in an issue or a discussion thread. The goal is to reach consensus among active maintainers and, when needed, Steering Committee members. If consensus cannot be reached on a major decision, the Steering Committee will vote or otherwise decide as described under **Decision Authority** above.

All decisions (even if made in meetings or privately) that affect the project should be documented openly – typically via the issue tracker or in meeting notes posted to the repository. This ensures transparency.

### Project Proposals and New Repositories

New project proposals (for entirely new open source tools or libraries under NI) go through the Steering Committee. The proposal should outline the project’s scope, goals, and how it fits into the broader NI open source ecosystem. The Steering Committee will discuss and either approve the creation of a new repository or provide feedback. Once approved, the new repository should adopt these governance guidelines from the start.

If a community member wants to donate or contribute an existing project to the NI organization, this is also discussed and decided by the Steering Committee, with input from NI’s Open Source Program Managers to ensure licensing and CLA compliance.

### Meetings and Communication

Most technical collaboration happens in the open – via GitHub issues, pull requests, and discussion forums. However, the maintainers and Steering Committee may hold periodic meetings (for example, a monthly sync-up call or an annual roadmap planning meeting). If meetings occur:
- They should be announced to the community in advance when possible.
- An agenda should be posted (e.g., in a discussion thread or Google doc) so others can provide input.
- Notes or minutes from the meeting should be shared publicly (posted in the repository or wiki).
- Decisions made in meetings are not final until summarized publicly – this gives community members a chance to voice feedback asynchronously if they couldn’t attend.

Day-to-day communication: We use GitHub for most discussions. Some quick questions might be discussed in chat (e.g., Discord), but any decision or important context from chat should be captured in an issue or discussion post so it’s searchable and archived.

## Contribution Process

Our contribution process is designed to be as simple as possible while ensuring quality and coordination:
1. A contributor forks the repo and makes a change in a feature branch.
2. The contributor submits a pull request.
3. Continuous integration (CI) runs automated tests and build workflows on the PR.
4. Maintainers review the PR. They may ask for changes or approve it.
5. Once the PR is approved (and CI is passing), a maintainer merges it into the `develop` branch (or appropriate branch as per project workflow).
6. Changes in `develop` will be included in the next release. At release time, maintainers merge `develop` into `main` (after bumping version numbers, etc.), and create a tagged release.

Contributors should ensure they sign the CLA (if external) and sign off their commits (DCO) as described in CONTRIBUTING.md. All code contributions are assumed to be under the project’s license (MIT, unless otherwise specified).

For significant changes, as noted, discuss in an issue or forum first. This helps align contributions with project roadmap and avoids duplicate efforts.

## Code of Conduct and Enforcement

All participants in the project must adhere to the project’s [Code of Conduct](CODE_OF_CONDUCT.md). This is essential to maintaining a healthy, welcoming community. Instances of abusive, harassing, or otherwise unacceptable behavior may be reported to the project maintainers or NI’s Open Source Program Managers.

Enforcement of the code of conduct will be a joint effort between the Steering Committee and the OSPMs. Consequences for violations may include a warning, temporary ban, or in severe cases, permanent removal from the community, depending on the offense and in accordance with the Code of Conduct’s escalation process.

## Amending These Bylaws

These governance guidelines can evolve as the project grows. Amendments can be proposed by opening an issue or pull request against this `GOVERNANCE.md` file. The Steering Committee will review proposed changes, and after discussion (and community input), decide whether to adopt them. We aim to keep governance lightweight, so changes will be made cautiously and with consensus.

Any update to this document will be notated with the date of change and a summary of what was changed, to maintain a revision history.
