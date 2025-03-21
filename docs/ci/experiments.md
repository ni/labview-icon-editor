# Experimental branches

> **Note**: This document provides both a **detailed & comprehensive narrative** and a **step-by-step guide** for our **GitFlow-like experimental branches**. Use it when you need **long-lived, multi-collaborator** features (e.g., 6–8 weeks or up to 1–1.5 years) that eventually merge back into the main product code.

## Table of Contents
1. [Overview](#overview)  
2. [Key Concepts](#key-concepts)  
3. [Why NI Wants Experimental Branches in This Repo](#why-ni-wants-experimental-branches-in-this-repo)  
4. [Detailed & Comprehensive Narrative](#detailed--comprehensive-narrative)  
5. [Step-by-Step Workflow](#step-by-step-workflow)  
   - [Step 1: Propose an Experiment](#step-1-propose-an-experiment)  
   - [Step 2: Create `experiment/<shortName>`](#step-2-create-experimentshortname)  
   - [Step 3: Automated Scans & Manual Approval](#step-3-automated-scans--manual-approval)  
   - [Step 4: (Optional) Alpha/Beta/RC Sub-Branches](#step-4-optional-alphabetarc-sub-branches)  
   - [Step 5: Merge Frequency from `develop`](#step-5-merge-frequency-from-develop)  
   - [Step 6: Final Merge to `develop`](#step-6-final-merge-to-develop)  
   - [Step 7: Partial or Abandoned Experiments](#step-7-partial-or-abandoned-experiments)  
6. [Conclusion & Best Practices](#conclusion--best-practices)  
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
- Enforce code scanning and manual approval for distributing `.vip` artifacts (or equivalent), ensuring security.

---

## Key Concepts

1. **experiment/<shortName>**  
   - The main branch for the experiment, created by an NI maintainer post Steering Committee approval.  
2. **Automatic Scanning**  
   - Docker VI Analyzer & CodeQL run on every commit or PR, catching suspicious code before distribution.  
3. **Manual Approval**  
   - By default, `.vip` packaging is disabled. An NI admin must run an “approve-experiment” workflow to enable artifact distribution for the experiment.  
4. **Alpha/Beta/RC**  
   - Optional sub-branches under `experiment/<shortName>` if your team wants mini-stages of development.  
5. **Big-Bang Merge**  
   - Ultimately, `experiment/<shortName>` merges into `develop` with a final Steering Committee review and version label (major/minor/patch).

---

## Why NI Wants Experimental Branches in This Repo

NI’s primary goal is to make **collaboration** on significant, **long-running** features both **safe and productive**:

1. **Centralized Testing & CI**  
   - By hosting these experiment branches directly in NI’s main repository, contributors can leverage **official** CI pipelines, scanning tools, and `.vip` build workflows.  
   - This ensures potential large-scale or risky features still benefit from **consistent** environment checks and automation.

2. **Early Feedback & Transparency**  
   - When experiments happen in **NI’s repo**, stakeholders—including external collaborators and NI R&D—can observe progress in real-time, **test** artifacts promptly, and give feedback early.  
   - This **transparency** supports a faster iteration cycle and a smoother eventual merge into the shipping version of the software.

3. **Coordinated Merges & Oversight**  
   - Hosting experimental branches in the main repo facilitates **oversight** by the Steering Committee, enabling them to guide or course-correct large features.  
   - It also simplifies final merges: everything is already in the same place, so merging an experiment into `develop` doesn’t involve complicated cross-repo synchronization.

4. **Security & Quality**  
   - Experimental branches remain subject to **automatic code scanning** (Docker VI Analyzer + CodeQL).  
   - Manual gating of `.vip` distribution ensures NI’s brand and user base are not exposed to unreviewed or potentially insecure code.

5. **Enhanced Innovation**  
   - NI wants to encourage **bigger** ideas from the community. By offering direct experiment branches under its official repo, contributors see that NI invests in supporting **innovative** or **ambitious** projects beyond the standard short-lived feature approach.

---

## Detailed & Comprehensive Narrative

1. **Proposal & Scope**  
   - A contributor—internal or external—proposes a **significant** feature via a GitHub Issue, detailing high-level goals and a timeline ranging 6–8 weeks to potentially 1–1.5 years.  
   - The Steering Committee weighs strategic impact, checking if the feature aligns with the roadmap and is worth integrating into `develop` eventually.

2. **Steering Committee & Rationale**  
   - If deemed valuable, NI (in coordination with the Steering Committee) will create `experiment/<shortName>` from `develop`.  
   - All code scanning (Docker VI Analyzer, CodeQL) applies automatically, but artifacts remain gated to protect the broader user base from incomplete or unverified changes.

3. **Experiment Branch as a Pseudo-Develop**  
   - The experiment branch acts like a **“mini development”** line. Multiple collaborators can open sub-branches, do alpha/beta testing, or run partial merges—**all within** the experiment.  
   - Merges or updates to `develop` can happen periodically to reduce future conflicts.

4. **Security & Manual Approval**  
   - NI uses a manual “approve-experiment” workflow to **activate** `.vip` distribution for that experiment. This ensures potential large-scale distributions only happen once the scans show no critical issues and the maintainers are confident in its safety.

5. **Alpha/Beta/RC Sub-Branches**  
   - If the feature is especially big or has distinct phases, sub-branches (`alpha`, `beta`, `rc`) can help test certain milestones or gather feedback from a smaller or larger group.

6. **Frequent Synchronization**  
   - Since the experiment might run **months**, merging `develop` changes into it periodically prevents a massive final conflict resolution stage.

7. **Integration Path**  
   - Eventually, the experiment lead or Steering Committee opens a PR from `experiment/<shortName>` to `develop`. The Steering Committee:
     - Chooses a final version bump label (major/minor/patch).  
     - Merges if everything passes final checks.  
   - Unsuccessful or partial features can be archived or broken into smaller merges.

8. **Abandonment or Partial Merges**  
   - Some experiments may fail or lose relevance. NI can archive or delete the branch if so. If only half the experiment is viable, cherry-picking or partial merges are possible.

---

## Step-by-Step Workflow

### Step 1: Propose an Experiment
- **GitHub Issue**: Outline feature scope, timeline, potential collaborators, rationale for why it needs an experimental approach.  
- **Steering Committee**: They either approve or reject, considering if the feature should live in `experiment/<shortName>` on NI’s repo.

### Step 2: Create `experiment/<shortName>`
- **NI Maintainer**: Creates `experiment/<shortName>` from `develop`.  
- **NoCI**: By default, distributing `.vip` or similar artifacts is disabled until manual approval.

### Step 3: Automated Scans & Manual Approval
- **Docker VI Analyzer + CodeQL**: Automatically run on every commit/PR.  
- **Manual “approve-experiment”**: An NI admin triggers a workflow to enable `.vip` or artifact builds for the experiment once scans are deemed acceptable.

### Step 4: (Optional) Alpha/Beta/RC Sub-Branches
- If staged development is beneficial, the experiment lead can create sub-branches:  
  - `experiment/<shortName>/alpha`  
  - `experiment/<shortName>/beta`  
  - `experiment/<shortName>/rc`

### Step 5: Merge Frequency from `develop`
- **Best Practice**: Merge `develop` into `experiment/<shortName>` every couple of weeks or as needed, preventing large-scale conflicts at the end.

### Step 6: Final Merge to `develop`
- **Open a PR**: From `experiment/<shortName>` or `rc` sub-branch to `develop`.  
- **Steering Committee**: Labels “major/minor/patch.”  
- **Merge**: The entire experiment is integrated into `develop`. Branch is removed or archived.

### Step 7: Partial or Abandoned Experiments
- **Partial Merge**: If only some commits are viable, cherry-pick or do a specialized branch to integrate them.  
- **Abandoned**: Archive or delete the experiment branch if it’s no longer relevant.

---

## Conclusion & Best Practices

- **Motivation**: NI hosts experiments in this repo to offer official CI, early feedback, and centralized scanning for large or innovative features.  
- **Communication**: Keep the Steering Committee and collaborators informed through GitHub issues/PRs.  
- **Security & Approval**: Automated code scans plus manual gating for artifact distribution safeguard the community from half-baked or risky releases.  
- **Sub-Branches**: Use alpha/beta/rc to manage internal staging if desired.  
- **Frequent Sync**: Merging from `develop` regularly saves time on final conflict resolution.  
- **Endgame**: Merge the experiment into `develop` in one final PR, or partially if only a subset of commits succeed, or abandon/archiving if it fails.

---

## See Also
- [MAINTAINERS_GUIDE.md](./actions/maintainers-guide.md) — For how admins run the “approve-experiment” workflow, how final merges are labeled.  
- [TROUBLESHOOTING_EXPERIMENTS.md](./actions/troubleshooting-experiments.md) — Ten common pitfalls (e.g., missing `.vip` files, partial merges).  
- [GOVERNANCE.md](./GOVERNANCE.md) — Steering Committee roles, BDFL membership, and how experiments get approved.

---
