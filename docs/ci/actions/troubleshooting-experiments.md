# Troubleshooting experimental branches

Welcome to the **Troubleshooting Guide** for experimental branches. This document aims to help you quickly identify common pitfalls and resolve issues that may arise when working with **long-lived experiment branches** in our GitFlow-like model. Below, you will find **20 typical scenarios** grouped into subsections—each with a **symptom**, a **cause**, and a **solution** (including commands where relevant).  

---

## Subsection A: Setup & Approval

### 1. Experiment Branch Not Created After Steering Committee Approval

**Symptom**  
You’ve received approval from the Steering Committee, but you don’t see `experiment/<shortName>` in the repository.

**Cause**  
NI maintainers or an admin is responsible for actually creating the experiment branch. They might not have completed this step yet.

**Solution (One Paragraph)**  
Reach out to the maintainer or Open Source Program Manager and confirm they have time to create `experiment/<shortName>` from `develop`. You can provide them with your shortName if needed (e.g., “experiment/async-rework”). Once the branch is created, refresh your repository page or pull the latest remote branches locally. If it still doesn’t show, verify you have the correct permissions and that the branch was indeed pushed to origin.

---

### 2. “approve-experiment” Dispatch Missing from Actions

**Symptom**  
You’re attempting to enable official artifact distribution for your experiment, but you cannot find the “approve-experiment” workflow under GitHub Actions.

**Cause**  
Either the repository’s CI config does not include the “approve-experiment” workflow, or it was inadvertently commented out or renamed.

**Solution (One Paragraph)**  
Check the `.github/workflows` folder in the main repo for a file that defines the “approve-experiment” job. If missing, ask a maintainer to add it or confirm the correct name. Sometimes the workflow might be called “Approve Experiment.” If the workflow does exist, verify that the file is not disabled in repository settings and that you have admin or maintainer privileges to see manual workflows. Once confirmed, you should see a **“Run workflow”** button in the Actions tab where you select your experiment branch.

---

### 3. Code Scanning Warnings Blocking Approval

**Symptom**  
You want NI to approve artifact distribution, but they refuse because the scanning tool warns of potential issues in your experiment branch.

**Cause**  
Your commits contain patterns that the scanning tool interprets as security or quality risks. Maintainers want them resolved before enabling distribution.

**Solution (One Paragraph)**  
Review the scanning report in the Action logs. Fix each flagged issue or comment on why it’s a false positive. Then push new commits to your experiment branch. Once scans are clean or acceptable, maintainers should recheck the logs. With the warnings addressed, they can safely run the “approve-experiment” dispatch and allow artifact publication.

---

### 4. “NoCI” Label Remains Even After Manual Approval

**Symptom**  
You see a “NoCI” label on your experiment branch in GitHub, even though an admin triggered the “approve-experiment” event.

**Cause**  
The specialized GitFlow Action might not automatically remove the “NoCI” label, or the admin’s manual event did not successfully update the branch’s labels.

**Solution (One Paragraph)**  
Check the workflow logs to ensure the “approve-experiment” step completed. If the label persists, an admin can manually remove “NoCI” from the branch or PR. Confirm that the environment variable or config toggling “ApprovedCI” is set to `true`. If the action depends on label removal to start builds, you can remove it in the GitHub UI under “Labels.”

---

### 5. Unsure How to Name the Experiment Branch

**Symptom**  
You want to start an experiment but are uncertain which name to use or how long it can be.

**Cause**  
There’s no strict naming enforcement aside from the recommended `experiment/<shortName>` pattern, leading to confusion.

**Solution (One Paragraph)**  
Follow the recommended naming: `experiment/` prefix plus a concise identifier (e.g., `experiment/ui-overhaul`). Avoid spaces or punctuation that might break scripts. If your feature involves something bigger, be sure to keep it short but descriptive—like `experiment/performance-refactor`. Keeping a consistent naming scheme helps everyone quickly identify the branch as an experiment.

---

## Subsection B: Merging & Sub-Branches

### 6. Merge Conflicts When Pulling from `develop` into Experiment

**Symptom**  
Frequent conflicts occur whenever you merge updated `develop` changes into your experiment branch.

**Cause**  
Your experiment has diverged significantly from `develop`; the code scanning or action logs might also indicate repeated merges.

**Solution (One Paragraph)**  
Merge or rebase from `develop` **regularly**, at least once every few weeks, to reduce large conflict sets. If the conflicts are already massive, break them down by merging `develop` in smaller increments or isolate file sets. Also ensure your local environment is fully updated before pulling. Once resolved locally, push the updated experiment branch so your collaboration stays in sync.

---

### 7. alpha → beta → rc Sub-Branches Not Merging Properly

**Symptom**  
You’ve created `experiment/<shortName>/alpha`, then `beta`, but merges from alpha to beta produce unexpected code changes or partial merges missing.

**Cause**  
Team members are working in multiple sub-branches without a clear merge order, or you’re skipping essential merges between them.

**Solution (One Paragraph)**  
Establish a clear pipeline: alpha → beta → rc. Finish changes in alpha, merge them fully into beta, then into rc. Communicate the merge order to all collaborators so no one merges rc changes backward into alpha. Use a consistent naming approach and confirm each branch merges cleanly before moving to the next. If needed, use PRs for each stage so the specialized Action logs the merges systematically.

---

### 8. Accidental Direct Commits to `rc` Instead of `beta`

**Symptom**  
A collaborator commits code directly onto your `experiment/<shortName>/rc` branch, bypassing the alpha or beta stage.

**Cause**  
Lack of clarity on the sub-branch flow; the collaborator had push access and accidentally targeted the rc branch.

**Solution (One Paragraph)**  
Explain the sub-branch staging approach: alpha is for early changes, beta is for stabilizing, and rc is for near-final. Revert or cherry-pick those commits onto the correct sub-branch if necessary. Update branch protection rules to disallow direct commits to `rc` or require a PR with lead approval.

---

### 9. Attempting Partial Merge from Sub-Branch into `develop`

**Symptom**  
A user tries to bypass the main experiment trunk and do a partial merge from `beta` or `rc` directly into `develop`.

**Cause**  
They only want certain improvements from the experiment to land early in `develop`, or they misunderstand the final big-bang approach.

**Solution (One Paragraph)**  
It’s acceptable to do partial merges if the code is stable, but coordinate with the experiment lead. Typically, you create a new branch from `beta` or `rc` with the relevant commits and open a PR to `develop`. This ensures the experiment’s main line remains consistent while letting you deliver urgent features or fixes earlier.

---

### 10. Steering Committee Forgets to Approve Final Merge

**Symptom**  
The final PR from `experiment/<shortName>` to `develop` is open, but no one merges it because the Steering Committee hasn’t labeled it “major,” “minor,” or “patch.”

**Cause**  
They might have overlooked the PR or expected more clarifications.

**Solution (One Paragraph)**  
Politely ping the Steering Committee members or reference them in a comment: “@SteeringCommittee, can we finalize the labeling for this PR?” Remind them the specialized action needs that label to do the mainline version bump. If it’s time-sensitive, also note that the BDFL override is possible if they need an immediate merge.

---

## Subsection C: Collaboration & Scanning

### 11. Conflicting Scans from Two Contributors

**Symptom**  
Two collaborators push changes that trigger code scanning with contradictory or overlapping warnings. The logs become messy or contradictory.

**Cause**  
Multiple commits in short succession can cause the scanning steps to produce separate sets of warnings.

**Solution (One Paragraph)**  
Coordinate commits so that one contributor merges or rebases after the other’s scanning results are addressed. If both scanning logs are relevant, unify them by merging whichever commit came first. Re-run the scanning steps or push a new commit that addresses all flagged items. Encourage communication to avoid overlapping partial fixes.

---

### 12. Mysterious “No Artifact Generated” for a PR

**Symptom**  
When a collaborator opens a pull request into `experiment/<shortName>`, the build step completes but no final artifact is attached.

**Cause**  
If the push is from a **fork** or a branch that’s not recognized by the specialized action’s conditions, the packaging might be set to skip. Alternatively, the scanning tool might fail before packaging.

**Solution (One Paragraph)**  
Check the logs carefully. If scanning fails, packaging is typically aborted. Also confirm that your GitHub Action includes `pull_request` triggers for experiment branches. If it’s from a fork, the collaborator might need a PR from the fork’s branch into `experiment/<shortName>`, ensuring they have “Allow actions from external PRs” or a manual approval from a maintainer.

---

### 13. Code Scanning Always Times Out

**Symptom**  
Every commit to your experiment takes forever or times out in the scanning stage.

**Cause**  
The code scanning tool might be analyzing a large codebase or unoptimized scanning rules. Possibly a slow or busy runner environment.

**Solution (One Paragraph)**  
Break your commits or code changes into smaller chunks. Revisit the scanning rules to exclude non-critical areas. If your environment is overburdened, ask a maintainer about scheduling scans or using more powerful runners. If partial scanning is acceptable, temporarily disable scanning on minor files until final integration.

---

### 14. Approve-Experiment Workflow Succeeds but “NoCI” Stays in Logs

**Symptom**  
The final step in the “approve-experiment” workflow claims success, but the logs still mention “NoCI” being active on subsequent commits.

**Cause**  
It could be a caching or environment variable issue. Possibly the specialized Action never wrote the updated “ApprovedCI” state to the correct config.

**Solution (One Paragraph)**  
Open the Approve-Experiment workflow logs. Look for lines saying “Successfully toggled from NoCI to ApprovedCI.” If absent, re-run the event. If the config file or environment variable is in a separate branch, ensure it merges into `experiment/<shortName>`. Once verified, the next push should show logs referencing “ApprovedCI.”

---

### 15. Another Repo’s Changes Not Flowing Down to the Experiment

**Symptom**  
The specialized action or scanning updates made on `main` repo aren’t reflected in your experiment-based repo or a collaborator’s fork.

**Cause**  
The changes in the action or scanning config are not automatically pulled into every existing branch or fork. They require a manual pull or rebase from upstream.

**Solution (One Paragraph)**  
Explain to collaborators that, if they’re on an older version of the specialized Action or scanning config, they must merge from the upstream `main` or `develop` to incorporate those updates. For forks, they can open a PR from upstream. Once merged, the new pipeline changes will appear in their experiment branch or fork.

---

## Subsection D: Final Integration & Advanced Issues

### 16. One-Year Experiment Overwhelms the Final Merge

**Symptom**  
An experiment that lasted ~1 year has massive changes, making the final PR extremely large and difficult to review.

**Cause**  
No incremental merges were done, so develop and the experiment diverged significantly.

**Solution (One Paragraph)**  
Encourage partial merges or chunk-based merges well before the 1-year mark. If you’re already at a big-bang PR, break it into smaller merges if feasible (like a “phase1” sub-branch). Conduct thorough reviews in stages or rely on thorough testing. Also check the scanning logs carefully for each phase to ensure no hidden regressions.

---

### 17. Lost “rc” Branch Before Merging to develop

**Symptom**  
The `experiment/<shortName>/rc` sub-branch was accidentally deleted or overwritten, losing final release candidate changes.

**Cause**  
A mistaken force-push or deletion by a collaborator who misunderstood the branch’s purpose.

**Solution (One Paragraph)**  
Check your Git history or any open pull requests that might reference the `rc` commits. You can restore the branch from the relevant commit hash if found in logs or merges. Communicate the importance of not force-pushing without lead approval. If you cannot restore it, revert to `beta` or older commits and rebuild the rc changes from memory or PR diffs.

---

### 18. Steering Committee Sets Wrong Label (Major/Minor/Patch)

**Symptom**  
They labeled the final PR “minor,” but you suspect it’s actually a “major” release. The specialized Action merges it as “minor.”

**Cause**  
Possibly a committee oversight or misunderstanding of the changes’ scope.

**Solution (One Paragraph)**  
Discuss it in the PR or mention the BDFL for a final call. If the merge already happened, the version is set. You can do an immediate follow-up PR to correct the version label or do a new “major” label if it’s truly that big. Document the reason for re-labeling so future references are consistent.

---

### 19. Conflict Between Two Simultaneous Experiments

**Symptom**  
Two experiment branches overlap in scope, and maintainers are unsure how merges from each experiment eventually unify in `develop`.

**Cause**  
Large or overlapping changes in distinct branches create uncertain interactions. No cross-communication between leads.

**Solution (One Paragraph)**  
Encourage the leads to share progress and possibly do a “sync branch” that merges both experiments. If they remain separate, each experiment merges into `develop` in sequence, with the second lead reconciling conflicts. Steering Committee can help schedule which merges first to minimize chaos. Keep scanning each experiment individually until both finalize.

---

### 20. Approve-Experiment Trigger Overused

**Symptom**  
An admin is re-running “approve-experiment” every few commits for no apparent reason, causing confusion about the actual “NoCI” vs. “ApprovedCI” state.

**Cause**  
A misunderstanding that “approve-experiment” must be repeated after each scanning pass or that the experiment lead wants incremental approvals.

**Solution (One Paragraph)**  
Clarify that typically one approval suffices to switch from “NoCI” → “ApprovedCI,” letting you build artifacts indefinitely. The only time you might re-run is if the scope drastically changed or if you intentionally toggled it off due to scanning issues. Maintain consistent logs to avoid accidental repeated toggling. Document or have a policy limiting how many times “approve-experiment” is run for a single branch.

---

## See Also
- [EXPERIMENTS.md](../EXPERIMENTS.md) – How to propose & manage experimental branches.  
- [MAINTAINERS_GUIDE.md](docs/ci/actions/maintainers-guide.md) – Admin tasks & final merges.  
- [GOVERNANCE.md](./GOVERNANCE.md) – Steering Committee roles, BDFL structure.

---
