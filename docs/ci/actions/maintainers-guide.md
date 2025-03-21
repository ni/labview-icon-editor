## Introduction
This document is written for maintainers of experimental branches and experiment leads in order to guide them througout the lifecycle of the experiment. It covers:

- **How** to create and manage experimental branches,  
- **When** and **how** to manually approve `.vip` artifact distribution,  
- **Working** with the Steering Committee for final merges,  
- **Handling** partial merges, alpha/beta/rc sub-branches, and BDFL overrides.

**Context**: Our project supports a **GitFlow-like model** for core development (`main`, `develop`, `release-*`, `hotfix/*`) plus **long-lived experimental branches** (`experiment/<shortName>`). This doc focuses on the extra tasks maintainers handle for experiments.

> **Note**: For a broader overview of experiment lifecycle, see [EXPERIMENTS.md](./EXPERIMENTS.md). For governance details (Steering Committee roles, BDFL approach), see [GOVERNANCE.md](./GOVERNANCE.md). For common pitfalls in experiments, see [TROUBLESHOOTING_EXPERIMENTS.md](./TROUBLESHOOTING_EXPERIMENTS.md).

---

## Table of Contents
1. [Roles & Responsibilities](#roles--responsibilities)  
2. [Creating an Experiment Branch](#creating-an-experiment-branch)  
3. [Approving Official Artifact Distribution](#approving-official-artifact-distribution)  
4. [Alpha/Beta/RC Management](#alphabeta-and-rc-management)  
5. [Code Scanning & Security Checks](#code-scanning--security-checks)  
6. [BDFL Overrides](#bdfl-overrides)  
7. [Labels & Final Merges](#labels--final-merges)  
8. [Partial Merges](#partial-merges)  
9. [Archiving or Deleting an Experiment](#archiving-or-deleting-an-experiment)  
10. [Best Practices & Tips](#best-practices--tips)  
11. [See Also](#see-also)

---

## 1. Roles & Responsibilities
Maintainers serve as **administrators** and **trusted gatekeepers**. You:

- **Facilitate** the creation of `experiment/<shortName>` branches once the Steering Committee approves a new experiment.
- **Oversee** day-to-day merges in the experiment if you’re also designated as the “experiment lead,” or support the lead if they’re external.
- **Enforce** scanning and manual approval before distributing `.vip` artifacts from experimental branches.
- **Coordinate** final merges into `develop` (and eventually `main`) for big features.

The **Open Source Program Manager** (OSPM) or designated NI staff typically handle BDFL decisions and can override specific steps on a case-by-case basis (see [BDFL Overrides](#bdfl-overrides)).

---

## 2. Creating an Experiment Branch
1. **Steering Committee Approval**  
   - A collaborator or lead opens a GitHub Issue proposing the experiment. The Steering Committee, chaired by the OSPM, decides if it’s viable.
2. **Branch Creation**  
   - You (an NI maintainer) create `experiment/<shortName>` from `develop`.  
   - By default, this branch has “NoCI” for `.vip` distribution to **prevent** automatic artifact sharing until code scanning is done.
3. **Documenting**  
   - Add a short summary on the new branch in the GitHub Issue so watchers know it’s live.  
   - If alpha/beta/rc sub-branches are planned, note that too.

**Pro Tip**: If the experiment lead is external but has repo write access, you can coordinate with them to create the branch. The key is ensuring official distribution remains blocked initially until approval.

---

## 3. Approving Official Artifact Distribution
Until you **manually** approve the experiment, the specialized CI or GitHub Action **won’t** publish `.vip` artifacts. 

### How to Approve
1. **Workflow Dispatch**  
   - Go to the **Actions** tab on GitHub, locate the “approve-experiment” workflow (or similarly named).  
   - Click **“Run workflow”**, specifying the `experiment/<shortName>` branch if needed.  
   - This sets an environment variable or label (e.g., “ApprovedCI”) that flips the build steps from “NoCI” → “ApprovedCI.”
2. **Verification**  
   - Confirm the logs show “ApprovedCI” is now active. Subsequent commits or merges in the experiment will produce `.vip` artifacts for testers.

### When to Approve
- Typically **after** Docker VI Analyzer + CodeQL show no critical warnings.  
- The experiment lead (or Steering Committee) may nudge you once they feel the code is stable enough to share widely.

**Note**: If the experiment changes drastically or code scanning flags new issues, you can revert to “NoCI” or temporarily stop artifact distribution.

---

## 4. Alpha/Beta and RC Management
Some experiments use **sub-branches** to stage progress:

1. **Alpha**  
   - For early prototypes, possibly unstable.  
   - Merges from alpha → main experiment branch once it’s somewhat stable.
2. **Beta**  
   - After alpha is proven, create a `experiment/<shortName>/beta` for broader internal testing.  
   - PR merges from beta → the main experiment branch bring more maturity to the code.
3. **RC (Release Candidate)**  
   - Near-final code. Merging rc → the main experiment branch typically signals readiness for integration into `develop`.

**Maintainer Role**  
- You ensure sub-branches are protected or open for the right collaborators.  
- Provide guidance on labeling merges (“merge alpha → main experiment,” etc.) using the specialized GitHub Action that logs recommended commands.

---

## 5. Code Scanning & Security Checks
**Docker VI Analyzer** and **CodeQL** run automatically:

1. **Check Logs**  
   - Each PR or push will display results. If issues are flagged, ask the experiment lead to address them before approving `.vip` builds.
2. **Failure Cases**  
   - If repeated critical warnings appear, you might keep the experiment in “NoCI” until resolved.  
   - The BDFL or OSPM can override if it’s a priority.

> **Note**: This scanning approach is still being experimented with by LabVIEW R&D, so occasional false positives or integration quirks may occur. See `TROUBLESHOOTING_EXPERIMENTS.md` for more info.

---

## 6. BDFL Overrides
Although we want a consistent approach, the BDFL (via the OSPM or designated NI staff) may **skip** certain steps in **rare** circumstances:

- **Forcing** a `.vip` artifact distribution even if scanning isn’t fully complete.  
- **Ignoring** normal labeling or merging rules in urgent cases (e.g., critical fixes).

We don’t document formal guidelines for these rare actions; they’re done case by case. If you see a forced override, log it in the relevant GitHub Issue or PR for transparency.

---

## 7. Labels & Final Merges
### 7.1. Labels for Major/Minor/Patch
The main CI doc covers how to label PRs. Generally:
- “major” = big changes  
- “minor” = moderate addition  
- “patch” = bug fix

### 7.2. Merging Experiment → `develop`
Once an experiment is ready for prime time:
1. **Open a PR** from `experiment/<shortName>` (or its `rc` branch) to `develop`.  
2. **Steering Committee** decides if it’s major/minor/patch for the next release.  
3. Maintainers just ensure the right label is set, then merge.

*(For partial merges, see below.)*

---

## 8. Partial Merges
If only a portion of the experiment is viable:

1. **Create a Sub-Branch**  
   - For instance, `experiment/<shortName>-partial`, cherry-picking or selecting commits that are stable.  
2. **Open a PR** from that sub-branch into `develop`.  
3. **Continue** other incomplete features in the main experiment branch if it’s still ongoing.

---

## 9. Archiving or Deleting an Experiment
If an experiment is **complete** or **abandoned**:

- **Complete**: Merge to `develop`, then delete or rename the branch to `archived/<shortName>`.  
- **Abandoned**: If scanning fails repeatedly or scope changes drastically, you can delete or archive it.  
- Document the reason in the original GitHub Issue.

---

## 10. Best Practices & Tips
1. **Frequent Merges from `develop`**  
   - Minimizes massive conflicts. At least once every couple of weeks if `develop` is active.
2. **Early “approve-experiment”**  
   - If you trust the scanning results quickly, enabling `.vip` distribution sooner can help gather feedback from collaborators.
3. **Communicate with the Steering Committee**  
   - Keep them informed of major changes, alpha/beta milestones, or partial merges.  
4. **Log BDFL Overrides**  
   - If an override happens, mention it in the PR or Issue to maintain transparency.

---

## See Also
- [EXPERIMENTS.md](../EXPERIMENTS.md)  
- [TROUBLESHOOTING_EXPERIMENTS.md](./TROUBLESHOOTING_EXPERIMENTS.md)  
- [GOVERNANCE.md](./GOVERNANCE.md)

---

If you run into issues, check [TROUBLESHOOTING_EXPERIMENTS.md](./TROUBLESHOOTING_EXPERIMENTS.md).

---