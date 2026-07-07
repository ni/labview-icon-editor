# Troubleshooting experimental branches

Welcome to the **Troubleshooting Guide** for experimental branches. This document aims to help you quickly identify common pitfalls and resolve issues that may arise when working with **long-lived experiment branches** in our GitFlow-like model. Below, you will find **10 typical scenarios** grouped into subsections—each with a **symptom**, a **cause**, and a **solution** (including commands where relevant).

---

## Subsection A: Setup and Approval

### 1. Experiment Branch Not Created After Steering Committee Approval

**Symptom**  
You’ve received approval from the Steering Committee, but you don’t see `experiment/<shortName>` in the repository.

**Cause**  
An NI maintainer or admin is responsible for actually creating the experiment branch. They might not have completed this step yet.

**Solution (One Paragraph)**  
Reach out to the maintainer or Open-Source Program Manager to confirm they have time to create `experiment/<shortName>` from `develop`. Provide them the agreed short name (e.g., “experiment/async-rework”). Once the branch is created, refresh your repository page or pull the latest remote branches locally. If it still doesn’t show up, verify you have the correct repository access and that the branch was indeed pushed to origin.

---

### 2. “approve-experiment” Dispatch Missing from Actions

**Symptom**  
You’re trying to enable official artifact distribution for your experiment, but you cannot find the “approve-experiment” workflow in the Actions tab.

**Cause**  
Either the repository’s CI configuration does not include an “approve-experiment” workflow, or it was inadvertently commented out or renamed.

**Solution (One Paragraph)**  
Check the `.github/workflows` folder in the main repo for a workflow file related to experiments approval. It might be named slightly differently (e.g., `approve-experiment.yml`). If missing, ask a maintainer about the intended approval process. Sometimes the workflow exists but requires admin permissions to view or run. Ensure you have maintainer access, and then check under “All workflows” in the Actions tab for any experiment-related manual workflows. Once located, an admin can trigger **“Run workflow”** on your experiment branch to approve artifact publishing.

---

### 3. Code Scanning Warnings Blocking Approval

**Symptom**  
NI maintainers won’t approve artifact distribution for your experiment because the security scan (VI Analyzer or CodeQL) reports warnings or issues.

**Cause**  
Your experiment’s commits include patterns that the scanning tools flag as potential bugs or security risks. Maintainers require these to be resolved (or justified as false positives) before proceeding.

**Solution (One Paragraph)**  
Review the scan results in the GitHub Actions logs for your experiment branch. Identify each warning and address it: fix the code if it’s a legitimate issue, or discuss with a maintainer if you believe it’s a false positive. After pushing fixes, ensure the scans run clean. Once the scans show no critical warnings, notify the Steering Committee or maintainer. With a clean bill of health, they can confidently run the “approve-experiment” workflow to allow VIP artifact publication.

---

### 4. “NoCI” Label Remains Even After Manual Approval

**Symptom**  
Your experiment branch still has a “NoCI” label after an admin ran the “approve-experiment” action, and CI jobs aren’t triggering automatically.

**Cause**
The “approve-experiment” process might not automatically remove the “NoCI” label from the branch, or the label was added manually and not cleared. The `ci-composite` workflow skips all jobs when this label is present.

**Solution (One Paragraph)**
First, verify in the Actions log that the approve step completed successfully. If CI is still skipped due to the “NoCI” label, remove that label from the experiment branch via the GitHub UI (you need maintainer permissions to edit labels). Once the label is cleared, the `issue-status` job will permit subsequent jobs to run. Going forward, ensure that the experiment branch has an “ApprovedCI” indicator (if used) or simply no “NoCI” label. This will allow normal CI workflows (like build/test) to run on pushes to that branch.

---

### 5. Unsure How to Name the Experiment Branch

**Symptom**  
You want to start an experiment but aren’t sure what branch name to use or what format is acceptable.

**Cause**  
There’s no strict enforcement beyond the recommended `experiment/<shortName>` pattern, which might leave some room for confusion.

**Solution (One Paragraph)**  
Use the convention: prefix with `experiment/` followed by a concise, descriptive name (the “shortName”). For example, `experiment/ui-overhaul` or `experiment/refactor-async`. Avoid spaces or special characters to prevent issues in scripts. If in doubt, check past experiment branches in the repo for examples. Consistent naming helps everyone recognize experiment branches at a glance.

---

## Subsection B: Merging and Sub-Branches

### 6. Merge Conflicts When Pulling from `develop` into Experiment

**Symptom**  
You encounter frequent merge conflicts whenever you merge updates from `develop` into your experiment branch.

**Cause**  
Your experiment has diverged significantly from `develop`; features on `develop` and your experiment may be touching the same areas of code.

**Solution (One Paragraph)**  
Merge (or rebase) from `develop` into your experiment branch regularly—aim for at least once every couple of weeks. Smaller, more frequent merges are easier to handle than one large merge. If conflicts are complex, break them down: merge `develop` in segments or resolve file-by-file to isolate problem areas. Ensure your local environment is up-to-date with both `develop` and your experiment before merging, and run tests after each sync. Regular integration reduces the pain of a big bang merge at the end.

---

### 7. alpha → beta → rc Sub-Branches Not Merging Properly

**Symptom**  
You’ve set up sub-branches (`alpha`, `beta`, `rc`) under your experiment, but merging changes from alpha to beta (or beta to rc) is causing strange diffs or missing commits.

**Cause**  
Team members might be committing to multiple sub-branches in parallel, or merges aren’t happening in the strict alpha → beta → rc order, causing inconsistencies.

**Solution (One Paragraph)**  
Adopt a strict discipline: treat the `alpha` branch as the source of truth during early development. Merge `alpha` into `beta` only when alpha is stable for a cycle, and similarly merge `beta` into `rc` in order. Instruct collaborators to **not** commit directly to `beta` or `rc` unless absolutely necessary (and if so, ensure those commits also flow back down to alpha). If things get out of sync, you may need to manually cherry-pick missing commits or do a fresh merge from the lower branch. Clear communication among team members about the merge order is key.

---

### 8. Accidental Direct Commits to `rc` Instead of `beta`

**Symptom**  
A contributor accidentally pushed commits directly to the `experiment/<shortName>/rc` branch instead of going through `beta`, bypassing the intended workflow.

**Cause**  
Miscommunication or misunderstanding of the branching strategy; the contributor might not have realized `rc` should only contain changes already vetted in `beta`.

**Solution (One Paragraph)**  
If the commits in `rc` are needed, cherry-pick or merge them back into `beta` (and `alpha` if relevant) to realign the branches. Then reset the `rc` branch to match `beta` or perform a merge from `beta` into `rc` so that `rc` is again ahead of `beta` only by the intended changes. Set branch protection rules to prevent direct pushes to `rc` (and `beta` if desired), requiring PRs instead. Remind the team of the proper flow: work goes into alpha, then beta, then rc, then main.

---

### 9. Attempting Partial Merge from Sub-Branch into `develop`

**Symptom**  
Someone wants to merge only a specific feature from the experiment’s `beta` or `rc` branch into `develop` before the experiment is fully done.

**Cause**  
They might have an urgent need for part of the experiment’s functionality in `develop` sooner (e.g., a subset of changes is stable and valuable independently).

**Solution (One Paragraph)**  
This can be done carefully: create a new branch off `develop`, then manually cherry-pick the desired commits from the experiment sub-branch into it. Open a PR to merge that into `develop` as a standalone feature. Mark the original experiment commits (e.g., via notes or labels) to avoid duplicating work when the full experiment merges later. Coordinate with maintainers to ensure that merging part of the experiment early won’t cause integration problems. This approach should be the exception, not the norm, and used only with Steering Committee awareness.

---

### 10. Steering Committee Forgets to Approve Final Merge

**Symptom**  
The final PR from `experiment/<shortName>` to `develop` is ready to merge, but it’s stalled because no one has applied a version label or formally approved it.

**Cause**  
The Steering Committee may be busy or may have assumed maintainers would handle the merge. Alternatively, the necessary version bump label (“major”, “minor”, or “patch”) wasn’t added, so CI might not allow the merge.

**Solution (One Paragraph)**  
Politely remind the Steering Committee in the PR comments that the experiment is ready to merge. Highlight any last scan results and that all tests pass. Ask for a final review and a decision on the version label for the merge. Maintainers can help by pinging the committee through the appropriate channels (GitHub mentions or a Discord/meeting reminder). Once the Steering Committee adds the label and approves, proceed with the merge into `develop`. If the committee is unavailable, the Open-Source Program Manager can step in to ensure the process concludes.
  
---

## See Also
- [**`maintainers-guide.md`**](maintainers-guide.md) – Admin tasks and final merge processes.
- [**`GOVERNANCE.md`**](../../../GOVERNANCE.md) – Steering Committee roles, BDFL structure.
