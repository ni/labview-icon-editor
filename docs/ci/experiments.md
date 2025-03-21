# EXPERIMENTS.md

> **Note**: This document provides a **high-level narrative** and a **step-by-step guide** for our **GitFlow-like experimental branches**. Use it when you need long-lived, multi-collaborator features (e.g., 6–8 weeks or up to 1–1.5 years) that eventually merge back into the main product code.

## Table of Contents
1. [Overview](#overview)
2. [Key Concepts](#key-concepts)
3. [High-Level Narrative](#high-level-narrative)
4. [Step-by-Step Workflow](#step-by-step-workflow)
   - [Step 1: Propose an Experiment](#step-1-propose-an-experiment)
   - [Step 2: Create `experiment/<shortName>`](#step-2-create-experimentshortname)
   - [Step 3: Automated Scans & Manual Approval](#step-3-automated-scans--manual-approval)
   - [Step 4: (Optional) Alpha/Beta/RC Sub-Branches](#step-4-optional-alphabetarc-sub-branches)
   - [Step 5: Merge Frequency from `develop`](#step-5-merge-frequency-from-develop)
   - [Step 6: Final Merge to `develop`](#step-6-final-merge-to-develop)
   - [Step 7: Partial or Abandoned Experiments](#step-7-partial-or-abandoned-experiments)
5. [Conclusion & Best Practices](#conclusion--best-practices)
6. [See Also](#see-also)

---

## Overview
Long-lived **experimental branches** (`experiment/<shortName>`) allow you to develop complex features in an isolated environment.  
- **Multi-collaborator**: Multiple contributors can push or PR into the experiment.  
- **Length**: Typically 6–8 weeks or up to 1–1.5 years.  
- **Goal**: Eventually merge these experiments into `develop` if deemed successful.

**Why This Model?**  
- Reduce disruption to day-to-day merges in `develop`.  
- Provide a “pseudo-develop” for features that need alpha/beta/rc staging.  
- Enforce code scanning and manual approval for distributing `.vip` artifacts (or equivalent), ensuring security.

---

## Key Concepts

1. **experiment/<shortName>**  
   - The main branch for the experiment. Created by an NI maintainer after Steering Committee approval.
2. **Automatic Scanning**  
   - Docker VI Analyzer & CodeQL run on every commit or PR, catching suspicious code before distribution.
3. **Manual Approval**  
   - By default, `.vip` packaging is disabled. An NI admin must run an “approve-experiment” workflow to enable artifact distribution for the experiment.
4. **Alpha/Beta/RC**  
   - Optional sub-branches under `experiment/<shortName>/alpha`, etc., if your team wants mini-stages of development.
5. **Big-Bang Merge**  
   - Ultimately, `experiment/<shortName>` merges into `develop` with a final Steering Committee review and version label (major/minor/patch).

---

## High-Level Narrative

1. **Proposal**: A contributor or external collaborator has a **big idea** requiring weeks/months. They open an Issue describing the scope.  
2. **Approval**: The Steering Committee and NI confirm the idea is viable, sets up `experiment/<shortName>` with scanning but no auto-release.  
3. **Development**: The experiment evolves in a **pseudo-develop** style. Sub-branches like alpha/beta/rc help refine the work. Code scanning always runs automatically.  
4. **Manual “approve-experiment”**: Once the lead is comfortable, an NI admin runs the manual dispatch so the experiment’s commits can produce `.vip` artifacts for testers.  
5. **Final Integration**: After alpha/beta/rc cycles, the experiment merges into `develop`. Partial merges or abandoned branches are also possible if only part of the feature is worth integrating.

---

## Step-by-Step Workflow

### Step 1: Propose an Experiment
- **Open GitHub Issue**: Provide a concise pitch (goals, timeline, expected collaborators).  
- **Steering Committee Review**: They confirm the experiment’s **relevance** to eventually merge into the main code.

### Step 2: Create `experiment/<shortName>`
1. **NI Maintainer**: Once the committee says “yes,” an NI maintainer creates `experiment/<shortName>` from `develop`.  
2. **NoCI by Default**: Official `.vip` distribution is blocked until scanning is verified safe and an NI admin manually enables it.

### Step 3: Automated Scans & Manual Approval
- **Auto-Scan**: Every commit triggers Docker VI Analyzer & CodeQL, which helps flag potential security or code issues.  
- **Manual Approval**:  
  1. NI admin runs a manual “approve-experiment” dispatch event (or toggles from “NoCI” → “ApprovedCI”).  
  2. The experiment then automatically publishes `.vip` artifacts on each subsequent commit, making it easier for multiple collaborators or testers to install and test.

### Step 4: (Optional) Alpha/Beta/RC Sub-Branches
- If your experiment is large or has staged rollouts, you can create sub-branches:  
  - `experiment/<shortName>/alpha`  
  - `experiment/<shortName>/beta`  
  - `experiment/<shortName>/rc`  
- **Flow**: alpha → beta → rc → merge back into the main experiment branch. These are purely optional but can help **structure** major changes.

### Step 5: Merge Frequency from `develop`
- **Best Practice**: Merge `develop` into your experiment branch regularly (e.g., weekly or bi-weekly) to avoid huge conflicts later.  
- Some experiments remain isolated until the end, but expect more complex merges if you skip frequent syncs.

### Step 6: Final Merge to `develop`
1. **Open a PR** from `experiment/<shortName>` (or its `rc` sub-branch) to `develop`.  
2. **Steering Committee** sets the final label (“major,” “minor,” or “patch”) in the main CI system.  
3. **Big Bang**: The entire experiment merges, including all alpha/beta changes. Once merged, you can delete or archive `experiment/<shortName>`.

### Step 7: Partial or Abandoned Experiments
- **Partial Merge**: If only part of the experiment is good, create a new branch with cherry-picked commits and PR it to `develop`.  
- **Abandon**: If the experiment fails or is no longer relevant, the experiment lead or NI maintainer can archive or delete the branch. No final merge needed.

---

## Conclusion & Best Practices
- **Communicate**: Use GitHub Issues or sub-PRs to keep all collaborators informed of progress.  
- **Scan Early, Scan Often**: Rely on Docker VI Analyzer & CodeQL to maintain quality.  
- **Approve**: Remember, an NI admin must run “approve-experiment” before official `.vip` files are produced.  
- **Frequent Merges**: Pull from `develop` regularly to reduce conflict overhead.  
- **Be Prepared**: The final big-bang merge will require Steering Committee sign-off with a version label.

---

## See Also
- [MAINTAINERS_GUIDE.md](./MAINTAINERS_GUIDE.md) — Admin tasks, how to perform the “approve-experiment” dispatch.  
- [TROUBLESHOOTING_EXPERIMENTS.md](./TROUBLESHOOTING_EXPERIMENTS.md) — Ten common issues and their fixes.  
- [GOVERNANCE.md](./GOVERNANCE.md) — Steering Committee roles, BDFL model, appointment/lifetime membership.  
