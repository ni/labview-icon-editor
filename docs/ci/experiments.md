# Experimental branches

> **Note:** This document provides a **step-by-step guide** for our **GitFlow-like experimental branches** for **long-lived, multi-collaborator** features (e.g., 6–8 weeks up to 1–1.5 years) that eventually merge back into the main product code.

## Table of Contents
1. [Overview](#overview)  
2. [Key Concepts](#key-concepts)  
3. [Why NI Wants Experimental Branches in This Repo](#why-ni-wants-experimental-branches-in-this-repo)  
4. [Detailed and Comprehensive Narrative](#detailed-and-comprehensive-narrative)  
5. [Step-by-Step Workflow](#step-by-step-workflow)  
   - [Step 1: Propose an Experiment](#step-1-propose-an-experiment)  
   - [Step 2: Create `experiment/<shortName>`](#step-2-create-experimentshortname)  
   - [Step 3: Automated Scans and Manual Approval](#step-3-automated-scans-and-manual-approval)  
   - [Step 4: (Optional) Alpha/Beta/RC Sub-Branches](#step-4-optional-alphabetarc-sub-branches)  
   - [Step 5: Merge Frequency from `develop`](#step-5-merge-frequency-from-develop)  
   - [Step 6: Final Merge to `develop`](#step-6-final-merge-to-develop)  
   - [Step 7: Partial or Abandoned Experiments](#step-7-partial-or-abandoned-experiments)  
6. [Conclusion and Best Practices](#conclusion-and-best-practices)  
7. [See Also](#see-also)

---

## Overview
Long-lived **experimental branches** (`experiment/<shortName>`) allow you to develop complex features in an isolated environment.

- **Multi-collaborator**: Multiple contributors can push or PR into the experiment.  
- **Length**: Typically 6–8 weeks or up to 1–1.5 years.  
- **Goal**: Eventually merge these experiments into `develop` if deemed successful.

**Why This Model?**  
- Reduce disruption to day-to-day merges in `develop`.  
- Provide a “pseudo-develop” for features needing alpha/beta/rc staging.  
- Enforce code scanning and manual approval for distributing `.vip` artifacts, ensuring security.

---

## Key Concepts

1. **experiment/<shortName>**  
   - The main branch for the experiment, created by an NI maintainer after Steering Committee approval.  
2. **Automatic Scanning**  
   - Docker VI Analyzer and CodeQL run on every commit or PR, catching suspicious code before distribution.  
3. **Manual Approval**  
   - By default, `.vip` packaging is disabled. An NI admin must run an “approve-experiment” workflow to enable artifact distribution for the experiment.  
4. **Alpha/Beta/RC**  
   - Optional sub-branches under `experiment/<shortName>` if the team wants mini-stages of development.  
5. **Big-Bang Merge**  
   - Ultimately, `experiment/<shortName>` merges into `develop` with a final Steering Committee review and version label (major/minor/patch).

---

## Why NI Wants Experimental Branches in This Repo

NI’s primary goal is to make **collaboration** on significant, **long-running** features both **safe and productive**:

1. **Centralized Testing and CI**  
   - By hosting experiment branches directly in NI’s main repository, contributors can leverage **official** CI pipelines, scanning tools, and `.vip` build workflows.  
   - This ensures potentially large or risky features still benefit from **consistent** environment checks and automation.

2. **Early Feedback and Transparency**  
   - When experiments happen in **NI’s repo**, stakeholders—including external collaborators and NI R&D—can observe progress in real-time, **test** artifacts promptly, and give feedback early.  
   - This **transparency** supports a faster iteration cycle and a smoother eventual merge into the shipping version of the software.

3. **Coordinated Merges and Oversight**  
   - Hosting experimental branches in the main repo facilitates **oversight** by the Steering Committee, enabling them to guide or course-correct large features.  
   - It also simplifies final merges: everything is already in one place, so merging an experiment into `develop` doesn’t involve cross-repo synchronization.

4. **Security and Quality**  
   - Experiment branches remain subject to **automatic code scanning** (Docker VI Analyzer + CodeQL).  
   - Manual gating of `.vip` distribution ensures NI’s brand and user base are not exposed to unreviewed or potentially insecure code.

5. **Enhanced Innovation**  
   - NI wants to encourage **bigger** ideas from the community. By offering direct experiment branches under its official repo, contributors see that NI invests in supporting **innovative** or **ambitious** projects beyond the standard short-lived feature approach.

---

## Detailed and Comprehensive Narrative

1. **Proposal and Scope**  
   - A contributor—internal or external—proposes a **significant** feature via a GitHub Issue, detailing high-level goals and an expected timeline (ranging from ~6–8 weeks up to 1+ year).  
   - The Steering Committee weighs strategic impact, checking if the feature aligns with the roadmap and is worth integrating into `develop` eventually.

2. **Steering Committee Decision**  
   - If deemed valuable, NI (with the Steering Committee) will create `experiment/<shortName>` from `develop`.  
   - All code scanning (Docker VI Analyzer, CodeQL) applies automatically, but artifact publishing remains gated to protect the broader user base from incomplete or unverified changes.

3. **Experiment Branch as a Pseudo-Develop**  
   - The experiment branch acts like a **“mini development”** line. Multiple collaborators can open sub-branches, do alpha/beta testing, or run partial merges—**all within** the experiment.  
   - Merges or updates from `develop` can happen periodically to reduce future conflicts.

4. **Security and Manual Approval**  
   - NI uses a manual “approve-experiment” workflow to **activate** `.vip` distribution for that experiment. This ensures large-scale distributions only happen once scans show no critical issues and maintainers are confident in its safety.

5. **Alpha/Beta/RC Sub-Branches**  
   - If the feature is especially big or has distinct phases, sub-branches (`alpha`, `beta`, `rc`) can help test certain milestones or gather feedback from a smaller or broader group.

6. **Frequent Synchronization**  
   - Since the experiment might run **months**, merging `develop` changes into it periodically prevents a massive final conflict resolution stage.

7. **Integration Path**  
   - Eventually, the experiment lead or Steering Committee opens a PR from `experiment/<shortName>` to `develop`. The Steering Committee:  
     - Chooses a final version bump label (major/minor/patch).  
     - Merges if everything passes final checks.  
   - Unsuccessful or partial features can be archived, or selectively merged in smaller pieces if only part of the work is viable.

8. **Abandonment or Partial Merges**  
   - Some experiments may fail or lose relevance. NI can archive or delete the branch if so. If only part of the experiment is useful, cherry-picking or partial merges into `develop` are possible.

---

## Step-by-Step Workflow

### Step 1: Propose an Experiment
- **GitHub Issue**: Outline the feature scope, timeline, potential collaborators, and why it needs an experimental approach.  
- **Steering Committee**: The committee reviews and either approves or rejects the idea, considering if the feature should live in an `experiment/<shortName>` branch on NI’s repo.

### Step 2: Create `experiment/<shortName>`
- **Branch Creation**: An NI maintainer (or admin) creates the new experiment branch from `develop` once the Steering Committee gives approval.  
- **Notification**: The contributor is notified when the branch is ready. Permissions are set so collaborators can push to this branch.

### Step 3: Automated Scans and Manual Approval
- **CI on Every Commit**: Standard CI checks (VI Analyzer, CodeQL) run for all pushes or PRs to the experiment branch, preventing obvious issues.  
- **No Artifact Publishing**: By default, CI will not publish `.vip` packages for experiment branches. An NI Open-Source Program Manager or maintainer must manually trigger an “approve-experiment” event to allow publishing. Until then, artifacts (if built) are kept internal.

### Step 4: (Optional) Alpha/Beta/RC Sub-Branches
- **Sub-Branch Strategy**: For very large efforts, the team can create sub-branches like `experiment/<shortName>/alpha` (then beta, then rc) to stage progressive testing.  
- **Merge Progression**: Work is merged upward (alpha → beta → rc → main experiment branch) to ensure each stage is cumulative and nothing is missed. This is only needed if the team explicitly wants phased releases.

### Step 5: Merge Frequency from `develop`
- **Stay Up to Date**: The experiment owner periodically merges changes from `develop` into the experiment branch (or rebases) to minimize divergence.  
- **Conflict Resolution**: Regular syncs reduce the risk of merge conflicts when the experiment reintegrates into `develop`.

### Step 6: Final Merge to `develop`
- **Review and Label**: When the experiment is complete, a final PR to merge `experiment/<shortName>` back into `develop` is opened. The Steering Committee reviews the full changeset. They assign a release label (major/minor/patch) reflecting the impact of the feature.  
- **Approval**: Once tests pass and any final feedback is addressed, the Steering Committee (and NI’s Open-Source Program Manager, if required) approve and merge the experiment into `develop`. This effectively promotes the feature to be part of the next official release cycle.

### Step 7: Partial or Abandoned Experiments
- **Partial Merge**: If only some parts of the experiment are ready or valuable, maintainers might choose to merge those selectively (e.g., via cherry-pick or separate PRs) instead of the entire branch.  
- **Abandonment**: If an experiment is deemed not successful or obsolete, the branch can be closed without merging. The history is kept for reference, but it won’t be integrated. Lessons learned can be documented for future efforts.

---

## Conclusion and Best Practices

- **Motivation** – NI hosts experiments in this repo to offer official CI, early feedback, and centralized scanning for large or innovative features.  
- **Communication** – Keep the Steering Committee and collaborators informed through GitHub issues and PR updates.  
- **Security and Approval** – Automated code scans, plus manual gating for artifact distribution, safeguard the community from half-baked or risky releases.  
- **Sub-Branches** – Use alpha/beta/rc sub-branches to manage internal staging if needed, but keep merges flowing in one direction (up toward the main experiment branch).  
- **Frequent Sync** – Merging from `develop` regularly saves time on final conflict resolution.  
- **Endgame** – Merge the experiment into `develop` in one final PR when ready. If only part of the work is successful, merge that portion and document or archive the rest.

---

## See Also
- [**`maintainers-guide.md`**](./actions/maintainers-guide.md) — How admins run the “approve-experiment” workflow and perform final merges.
- [**`troubleshooting-experiments.md`**](./actions/troubleshooting-experiments.md) — Ten common pitfalls (e.g., missing `.vip` artifacts, merge strategies for sub-branches).
- [**`GOVERNANCE.md`**](../../GOVERNANCE.md) — Steering Committee roles, BDFL membership, and how experiments get approved.
