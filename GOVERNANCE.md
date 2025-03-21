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

In short, maintainers keep the project healthy and moving. They are trusted members who have demonstrated ability to manage the codebase responsibly. Their actions are always in service of the community – maintainers are there to enable contributions, not to block them. By being accessible and responsive, maintainers make it easier for newcomers to join and for the project to benefit from outside ideas.

### Contributors

**Contributors** are anyone in the community who contributes to the project in any way. This includes writing code or documentation, filing bug reports, participating in discussions, or giving feedback. Contributors can be external community members or NI employees acting outside of a formal maintainer role. Here’s what we expect (and appreciate) from contributors:

- **Follow Contribution Guidelines:** Before contributing code or documentation, contributors should read the [CONTRIBUTING.md](CONTRIBUTING.md) for the project. This will explain how to set up the environment, the coding standards, how to run tests, and the process for submitting changes. By following these guidelines, contributions can be reviewed and accepted faster.
- **Open Collaboration:** We encourage contributors to discuss their ideas by opening issues or joining existing discussions. If you have a big idea or a feature request, feel free to start a conversation about it. In some cases, the Steering Committee or maintainers might suggest writing a proposal or design document (for example, adding an entry to an upcoming `EXPERIMENTS.md` for major experimental features) – but for most enhancements, a simple issue conversation is enough.
- **Quality and Testing:** Contributors should ensure their work meets the project’s quality standards. This means writing clear code (or docs), and including tests for new functionality when appropriate. Our automated CI checks (see the project’s [workflows](.github/workflows/) for details on builds and tests) will run on each pull request to help validate this. Don’t worry – maintainers will help if something fails or if changes are needed.
- **Respect and Professionalism:** All contributors must adhere to our [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md). In practice, this means being respectful in communications, providing constructive feedback, and being open to feedback on your own contributions. Healthy, civil discussions are key to a thriving community. If you’re not sure about something, ask! We’re all here to learn and improve the project together.

Every contribution, no matter how small, is valuable. Whether you found a typo in the documentation or you’re adding a major new feature, you are part of the community. We thank our contributors by acknowledging them in release notes or README, and outstanding contributors may be invited to become maintainers or even join the Steering Committee over time. Our goal is to make contributing rewarding and fun, with as little friction as possible.

## Governance and Decision-Making

We strive for a governance model that is lightweight and responsive. Most daily decisions are made by those closest to the work (maintainers and contributors). Larger decisions that affect the direction of a project or the NI open source ecosystem as a whole involve the Steering Committee and Program Managers. The guiding principle is **consensus and transparency**: we prefer to discuss things openly and come to agreement, rather than impose rules from the top down.

### Technical Decisions and Changes

For technical decisions within a project (like implementing a new feature, changing a dependency, modifying architecture, etc.), the process generally works as follows:

- **Proposal and Discussion:** Ideas can come from anyone. Typically, a contributor or maintainer will open a GitHub Issue or Discussion thread to propose a significant change. This is a space to discuss the idea’s merits, alternatives, and potential impacts. Everyone is welcome to voice opinions, and we especially encourage input from those who would be affected by the change (users of the project, other maintainers, etc.).
- **Seeking Consensus:** Maintainers aim to build consensus on the proposal. If most people agree and no one has strong objections, we consider that a consensus. The idea may be refined through feedback during this stage. Small changes can reach consensus quickly, while bigger ones might need more time and input.
- **Steering Committee Input (if needed):** If a proposal is particularly large in scope, risky, or affects multiple projects, the Steering Committee will get involved. They might join the discussion in the issue, or discuss it in a Steering Committee meeting and then post their recommendations. The committee’s role here is to ensure the change aligns with project goals and to raise any high-level concerns.
- **Decision and Implementation:** In most cases, maintainers will make the call to move forward with a change once there’s general agreement. They might say “We’ve incorporated feedback and it looks like we have consensus to proceed.” Then the change can be implemented (e.g., a contributor is asked to create a PR, or if one already exists, it’s updated and reviewed). If there are lingering disagreements, maintainers and possibly the Open Source Program Manager will work to address them. As a last resort, if consensus isn’t reached, a majority vote among the Steering Committee or a decision by the Program Manager/Lead Maintainer can be used to finalize the direction.
- **Documentation of Decision:** Any major decision should be documented for posterity. This could be done by updating relevant documentation (like adding an entry to `CHANGELOG.md` or an upcoming `EXPERIMENTS.md` if the feature is experimental, or simply leaving the issue open with a summary of the final decision). Transparency is critical – even decisions made after lengthy debate should be clearly communicated to everyone.

The above process is meant to be natural and not overly bureaucratic. Many changes, especially minor ones, will flow through quickly with maintainers merging pull requests once tests pass and reviews are done. We mostly invoke the formal “decision-making” steps for big matters where community input is important. Our default is trust: we trust maintainers to handle routine decisions, and maintainers trust contributors to submit improvements in good faith. When in doubt, open communication ensures we get it right.

### Project Proposals and New Repositories

From time to time, NI (or community members in partnership with NI) may want to open source a new project or create a new repository under the NI GitHub organization. The process for proposing a new project or significant initiative is as follows:

1. **Draft a Proposal:** The person or team proposing the new project should draft a brief description of the project’s scope, goals, and why it should be open-sourced. This could be done in a GitHub Discussion or a document shared with the Steering Committee. (Eventually, we may have a template for such proposals or an `EXPERIMENTS.md` to capture ideas that are being tried out.)
2. **Review by Program Managers and Steering Committee:** NI Open Source Program Managers will review the proposal first to ensure it aligns with NI’s strategy and resources (for example, verifying that NI can support the project long-term, or that it doesn’t conflict with any licensing concerns). Then the Steering Committee will evaluate the technical merits and community interest. Key questions include: Is there a clear benefit to open sourcing this? Are there maintainers available to steward it? Does it fit well with our other projects?
3. **Community Input:** If appropriate, the proposal may be shared publicly (for example, if it’s an addition to an existing product line or something users have asked for). Community feedback can be gathered via comments. This isn’t always necessary (for example, if NI decides to open source an internal tool, the initial decision might be mostly internal), but we prefer to gauge interest whenever possible.
4. **Decision:** The Steering Committee, with recommendation from the Program Managers, will make the final call. If there’s strong agreement, the project gets a green light. The decision will be documented (through meeting notes or an announcement in the Discussions forum of a relevant repo). If the proposal is declined or postponed, we will communicate the reasons to maintain transparency.
5. **Bootstrap the Project:** If approved, initial repository setup will be done. This includes creating the repo (under github.com/ni), adding standard files like README, CONTRIBUTING, LICENSE, CODE_OF_CONDUCT, etc., and populating it with the initial code drop. The new project will then follow the same bylaws as others. The proposers might become the first maintainers, and the Steering Committee will oversee its integration into the broader NI open source ecosystem.

For major new features within an existing project, a lighter version of the above may occur: for example, the maintainers and Steering Committee might treat a big new subsystem as an “experimental feature”. They could use an `EXPERIMENTS.md` (if available) to outline the plan and get feedback, then develop it in a separate branch or behind a feature flag until it’s stable.

In summary, new ideas are welcome! We just ensure there’s enough discussion and planning so that new projects or features start off on the right foot, with community buy-in and clarity on who will maintain them.

### Meetings and Communication

**Communication is open by default.** The majority of project communication happens in public channels, primarily on GitHub:
- **Issues and Discussions:** We use GitHub Issues to track bugs, tasks, and proposals. GitHub Discussions (if enabled on the repo) or external forums can be used for broader conversations, Q&A, or brainstorming. Everyone is free to participate here, and all significant technical discussions should be documented in these channels so others can follow along.
- **Pull Request Feedback:** Code review comments in pull requests are another key form of communication. We keep these constructive and on-topic. It’s fine to have detailed technical debates in PRs — that ensures decisions around code changes are captured in context.

The Steering Committee and Program Managers may also have periodic meetings to coordinate across projects:
- **Steering Committee Meetings:** These might be monthly or quarterly (depending on need). In the spirit of transparency, we aim to at least partially conduct these in the open. For example, the committee might meet via a call (with internal notes), but then publish a summary of decisions/outcomes publicly. If feasible, some meetings could even be open to observers or have an open portion for community questions.
- **Meeting Notes:** All decisions or important points from Steering Committee meetings will be posted in a public place (such as a `governance` repo, a `MEETINGS.md` file, or a Discussion post). This way, even community members who weren’t present can stay informed about what was discussed and decided.
- **Ad-hoc Discussions:** Program Managers and maintainers sometimes need to discuss things in real time (for example, via an NI-internal channel or a private Slack) – especially for urgent issues like security disclosures or incidents. However, any decisions affecting the project will be brought back to the public channels as soon as possible. We avoid “closed-door” decision making; even if initial discussion is private, the outcome should be shared openly once ready.

Additionally, NI may provide or support certain communication platforms for the community:
- **Chat (Discord/Slack):** For more casual or quick exchanges, we might use a public chat channel (for instance, some projects have a Discord server or NI Community forum). These are great for user support, quick questions, or brainstorming. They do not replace GitHub for decision-making, but they help build community.
- **Mailing Lists/Newsletter:** If appropriate, a mailing list or periodic newsletter could be used to update interested people on project progress, releases, and upcoming discussions. Subscribing to these would be optional for those who prefer email updates.

In all communications, we remind everyone to keep the tone friendly, professional, and inclusive. Disagreements are fine, but we debate ideas, not personalities. Our [Code of Conduct](CODE_OF_CONDUCT.md) applies in all forums. If you witness or experience any harassment or improper behavior, report it to the maintainers or Program Managers — we will address it confidentially and seriously.

Effective communication ensures that everyone moves in the same direction and feels included. We encourage questions, suggestions, and even constructive criticism. Good ideas can come from anywhere, and by communicating openly, we increase the chances of catching them.

## Contribution Process

Each NI open source repository provides specific instructions for contributing (see the project’s individual [CONTRIBUTING.md](CONTRIBUTING.md) file for details). However, there are common principles across all projects, which we summarize here for clarity. The contribution process is designed to be as straightforward as possible:

1. **Find an Issue or Idea:** To start contributing code or documentation, find something you’d like to work on. This could be an open issue labeled “help wanted” or “good first issue,” or maybe you have a new idea to propose. Maintainers and the Steering Committee often label issues (e.g., `Workflow: Open to contribution`) to signal that community contributions are welcome on those. If you have a totally new idea, consider opening a new issue to discuss it first.
2. **Fork & Branch:** Fork the repository to your own GitHub account and create a new branch for your work (or if you have push access as a maintainer, create a feature branch on the main repo). Give the branch a descriptive name (e.g., `feature/add-plot-widget` or `bugfix/fix-memory-leak`).
3. **Write Code or Content:** Implement your changes following the project’s coding standards and style. If adding a feature or fixing a bug, try to include tests that verify the behavior (if the project has a test suite). For documentation changes, ensure clarity and proper formatting. Don’t forget to run the project locally if applicable, to manually test your changes.
4. **Continuous Integration Checks:** When you push your changes and open a Pull Request (PR), automated workflows will run (usually visible in the PR checks section). These might include building the project, running unit tests, linting the code style, etc. Our CI is configured via GitHub Actions workflows (see the YAML files in the [workflows](.github/workflows/) directory for what’s being checked, such as build verification and unit tests). Ensure your changes pass these checks. If something fails, you can push additional commits to fix the issues – maintainers can help interpret failures if you’re stuck.
5. **Pull Request Review:** Maintainers (and possibly other community members) will review your PR. They might request changes or provide feedback. This is a normal part of the process to maintain quality and consistency. Try to respond to feedback in a timely manner by making the requested updates or discussing further if you disagree (politely, of course). Remember, we’re all aiming to improve the project together.
6. **Approval and Merge:** Once your contribution is reviewed and approved (usually at least one maintainer will approve it), it will be merged into the codebase. We prefer the “squash and merge” approach for external contributions – this keeps the history clean – but maintainers will choose whatever method makes sense for the project. You’ll get credit in the commit history and release notes. Congratulations, you’ve contributed!
7. **Continuous Improvement:** After merge, if any issues arise (maybe a bug was found in your feature, or a follow-up change is needed), don’t be discouraged. We will work together to address them. Open source is an iterative process. Similarly, even if your PR isn’t accepted initially, we appreciate the effort – maintainers will explain why and often suggest how you might adjust it for future consideration.

Beyond code, you can contribute by helping with documentation, answering questions from other users, or sharing ideas. All forms of contribution are valuable. For large contributions or changes, you might be asked to sign an NI Contributor License Agreement (CLA) to confirm you are entitled to contribute the code – see the project’s contributing guidelines for how NI handles CLAs. (Typically, when you open a PR for the first time, a bot will check this and provide instructions if a CLA signature is needed.)

Our goal is to make contributing easy and rewarding. We welcome first-time contributors and will happily mentor you through your initial contributions. The community thrives when more people get involved, so we aim to eliminate unnecessary barriers. If anything in the contribution process is unclear or not working, please let us know – we are open to adjusting our process based on contributor feedback.

## Code of Conduct and Enforcement

All NI open source projects adhere to a common **Code of Conduct** (see [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md) in this repository). This is a vital part of our community guidelines. It sets the expectation that everyone interacts with respect and professionalism. We absolutely want our projects to be welcoming spaces for all developers and users.

**Key points of the Code of Conduct:**
- Be respectful and inclusive. Discrimination, harassment, or abusive behavior will not be tolerated.
- Communicate with empathy. Remember there are real people behind the comments and code. Try to understand differing viewpoints and handle disagreements civilly.
- Focus on what is best for the community and project. We’re all here to make the software better and help each other.

If someone’s behavior violates these principles, we have a clear path to address it:
- **Reporting Issues:** Anyone who experiences or witnesses a Code of Conduct violation should feel safe to report it. The Code of Conduct file provides contact information (often an email for the maintainers or NI Open Source Program Manager). You can also privately contact an NI Open Source Program Manager or Steering Committee member to report concerns. All reports will be handled confidentially.
- **Enforcement Process:** Upon receiving a report, the Program Managers (and if needed, the Steering Committee) will review the situation. We follow the process outlined in the Code of Conduct document, which typically involves reaching out to the person reported, understanding the facts, and deciding on appropriate action. For minor issues, a friendly reminder or warning might be sufficient. For serious misconduct, actions can range from temporary suspension from project participation to a permanent ban from the community.
- **Resolution and Follow-up:** We commit to resolving Code of Conduct issues promptly and fairly. Once a decision is made, the affected parties will be informed. We won’t publicly shame anyone; however, if someone is removed from the community, other members may be informed that the person will no longer be participating (without divulging private details). Our goal is always to restore a healthy environment. In some cases, that may involve mediation or setting specific expectations for future behavior if the person remains in the community.

The Steering Committee is empowered to enforce the Code of Conduct, and NI Open Source Program Managers back them up with institutional support. This might include consulting NI’s HR or legal teams if an incident is extreme (especially if it involves an NI employee), but generally, the community leaders will handle it internally.

We also emphasize education and improvement. If someone makes a mistake and is willing to learn and apologize, we welcome that. We’re all human, and we’d rather help someone align with our values than simply punish. However, we have zero tolerance for repeated or severe violations that jeopardize community safety.

By referencing the Code of Conduct throughout these bylaws, we ensure that **respect and kindness** remain core to how we operate. It’s not just about handling violations after the fact, but about fostering a culture where problems are less likely to occur. Thank you to everyone for contributing to this positive environment.

## Amending These Bylaws

These bylaws are meant to be a living document. As our community grows and learns, we may find that parts of this governance model need to evolve. Changes to this document can be proposed by anyone, but will be enacted through a lightweight, collaborative process:

- **Proposal for Change:** If you think an update or addition to the bylaws is needed, start by opening an issue or discussion suggesting the change. Clearly describe what you want to change and why. For example, maybe you think we should clarify the role of a “Lead Maintainer” or add a section about handling security vulnerabilities. Any community member (NI or external) can make a suggestion.
- **Discussion and Review:** The suggestion will be discussed openly. NI Program Managers and the Steering Committee will definitely weigh in, since they have a broad view of how the governance works across projects. Maintainers and contributors are encouraged to give feedback too – after all, the bylaws affect everyone. We’ll consider whether the change makes our processes better, more clear, and more inclusive.
- **Drafting the Revision:** If there’s general agreement to proceed, a draft of the updated text will be prepared (this could be a pull request editing this Markdown file). We prefer to get consensus on the concept first, then fine-tune the wording. The draft can be iterated with feedback in the PR comments.
- **Approval:** To officially adopt the change, we’ll need approval from the Steering Committee and at least one NI Open Source Program Manager. In practice this could mean a PR is approved by those folks. If it’s a significant change, they might also announce it on the mailing list or Discussions for broader awareness before finalizing. Minor edits (like fixing typos or updating examples) can be approved with a lighter review (e.g., just a maintainer).
- **Transparency:** Once merged, the updated bylaws should be communicated. This could be as simple as a changelog entry in the commit message or a note in an upcoming community meeting. We might tag a new release of documentation if that’s relevant. The point is to ensure people know the rules have changed. In the document’s header (like at the top of this file), we’ll update the “Last Updated” date so it’s clear when the last change occurred.

We want the amendment process itself to embody the openness we aim for. Nothing here is set in stone forever, and good ideas to improve our governance are welcome. However, changes shouldn’t be made lightly – our bylaws work well when they’re consistent and understood by all. So, we balance adaptability with stability.

By following a collaborative change process, we ensure that the bylaws continue to serve the community’s needs and that everyone has a voice in shaping our project governance. In essence, **these bylaws belong to the community**: let’s keep them useful, clear, and in tune with how we actually work together.

---
*© 2025 National Instruments Corporation. This document is open source (feel free to reuse/adapt it for your own communities). It is provided as guidance for collaborative development and does not constitute legal advice.* 
