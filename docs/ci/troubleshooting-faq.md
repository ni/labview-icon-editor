# Troubleshooting & FAQ

This document provides a collection of common **troubleshooting** scenarios (with solutions) and a **FAQ** (Frequently Asked Questions) for the LabVIEW Icon Editor GitHub Actions workflows. Refer back to the main CI guide if you need overall setup instructions or deeper references.

---

## Table of Contents

1. [Troubleshooting](#troubleshooting)
   1. [No. 1: LabVIEW Not Found on Runner](#no-1-labview-not-found-on-runner)
   2. [No. 2: GPG Key Missing or Invalid](#no-2-gpg-key-missing-or-invalid)
   3. [No. 3: No `.vip` Artifact Found](#no-3-no-vip-artifact-found)
   4. [No. 4: Version Label Not Recognized](#no-4-version-label-not-recognized)
   5. [No. 5: Build Number Not Updating](#no-5-build-number-not-updating)
   6. [No. 6: Dev Mode Still Enabled After Build](#no-6-dev-mode-still-enabled-after-build)
   7. [No. 7: Release Not Created or Drafted](#no-7-release-not-created-or-drafted)
   8. [No. 8: Branch Protection Blocks Merge](#no-8-branch-protection-blocks-merge)
   9. [No. 9: Incorrect Pre-Release Suffix (Alpha/Beta/RC)](#no-9-incorrect-pre-release-suffix-alphabetarc)
   10. [No. 10: Hotfix Not Tagged as Expected](#no-10-hotfix-not-tagged-as-expected)

2. [FAQ](#faq)
   1. [Q1: Can I Override the Build Number?](#q1-can-i-override-the-build-number)
   2. [Q2: How Do I Skip Creating a Release?](#q2-how-do-i-skip-creating-a-release)
   3. [Q3: Can I Have More Than Alpha/Beta/RC Channels?](#q3-can-i-have-more-than-alphabeta-rc-channels)
   4. [Q4: Do I Need a GPG Key to Build on a Fork?](#q4-do-i-need-a-gpg-key-to-build-on-a-fork)
   5. [Q5: How Can I Attach Multiple `.vip` Files to a Release?](#q5-how-can-i-attach-multiple-vip-files-to-a-release)
   6. [Q6: Do I Need To Merge Hotfixes Into `develop`?](#q6-do-i-need-to-merge-hotfixes-into-develop)
   7. [Q7: What If I Don’t Want a Draft Release?](#q7-what-if-i-dont-want-a-draft-release)
   8. [Q8: Can I Use This Workflow Without Gitflow?](#q8-can-i-use-this-workflow-without-gitflow)
   9. [Q9: Why Is My Dev Mode Toggle Not Working Locally?](#q9-why-is-my-dev-mode-toggle-not-working-locally)
   10. [Q10: Can I Use a Different LabVIEW Version (e.g., 2023)?](#q10-can-i-use-a-different-labview-version-eg-2023)

---

## Troubleshooting

Below are 10 common issues you might encounter, along with suggested steps to resolve them.

### No. 1: LabVIEW Not Found on Runner

**Symptoms**:
- The workflow fails with an error like “LabVIEW executable not found” or “Command not recognized.”

**Possible Causes**:
- LabVIEW isn’t installed on the self-hosted runner.
- The environment variable or path to LabVIEW isn’t set correctly.

**Solution**:
1. Ensure you’ve actually installed LabVIEW on the machine (e.g., LabVIEW 2021 SP1).
2. Double-check your PATH or environment variables.  
3. See `runner-setup-guide.md` for details on configuring the runner to locate LabVIEW.

---

### No. 2: GPG Key Missing or Invalid

**Symptoms**:
- The workflow tries to sign a tag or release, then fails with “gpg: signing failed: No secret key” or a passphrase prompt.

**Possible Causes**:
- You’re on the main repository but haven’t set up the required GPG key.
- On a fork, GPG is disabled, but the script is still attempting to sign.

**Solution**:
1. If you’re running on a fork, set `DISABLE_GPG_ON_FORKS=true`.  
2. If you’re on the main repo, ensure the GPG key is installed, and the passphrase (if any) is available to the workflow.  
3. Confirm your GitHub Actions secrets are correctly set for GPG usage (e.g., `GPG_PRIVATE_KEY`, `PASSPHRASE`).

---

### No. 3: No `.vip` Artifact Found

**Symptoms**:
- The build succeeds, but the “Upload artifact” step fails with “File not found” or empty artifact.

**Possible Causes**:
- The `Build.ps1` script didn’t actually produce a `.vip` file in the expected folder.
- The workflow’s “paths” setting doesn’t match the output directory.

**Solution**:
1. Check your “Build VI Package” job logs to confirm the `.vip` file was created.  
2. If it’s created in `builds/VI Package/`, ensure the upload step references that folder.  
3. Verify the version of VI Package Manager or the build scripts aren’t failing silently.

---

### No. 4: Version Label Not Recognized

**Symptoms**:
- You labeled your Pull Request “minor” or “patch,” but the version doesn’t increment that segment.

**Possible Causes**:
- The workflow only checks for certain labels (`major`, `minor`, `patch`). Typos or different capitalization might be ignored.
- You’re pushing directly to a branch instead of creating a PR (so no label is read).

**Solution**:
1. Make sure the label is exactly `major`, `minor`, or `patch` in lowercase (unless your workflow script also checks for capitalized labels).  
2. Confirm you’re actually using a Pull Request event (not a direct push).  
3. Check logs for “Determining Bump Type” in the Build VI Package workflow.

---

### No. 5: Build Number Not Updating

**Symptoms**:
- Every build produces the same “-buildN” suffix, or the commit count doesn’t match reality.

**Possible Causes**:
- `fetch-depth` in `actions/checkout` might be set to `1`, causing an incomplete commit history.
- The script uses `git rev-list --count HEAD`, but partial history returns a smaller number.

**Solution**:
1. In your workflow’s checkout step, set `fetch-depth: 0` (full history).  
2. Verify you haven’t overridden the default `git rev-list --count` command.  
3. Check that your repository is fully cloned on the runner.

---

### No. 6: Dev Mode Still Enabled After Build

**Symptoms**:
- You run a build, but the environment remains in “development mode,” causing odd behavior when installing `.vip`.

**Possible Causes**:
- You forgot to run the “disable” step of the Development Mode Toggle.  
- Another step re-applied the `Set_Development_Mode.ps1` script.

**Solution**:
1. Manually run the “Development Mode Toggle” workflow with `mode=disable`.  
2. Confirm your pipeline sequence: typically, dev mode is enabled for debugging only, then disabled prior to final builds.

---

### No. 7: Release Not Created or Drafted

**Symptoms**:
- The workflow completes, but you see no new release in GitHub’s “Releases” section.

**Possible Causes**:
- `DRAFT_RELEASE` is set to `true` (so it’s in draft state), or the “Create Release” step was skipped.
- The build was triggered by a Pull Request, and your workflow logic only creates releases on “push” or merges to main.

**Solution**:
1. Check your workflow triggers: releases are often created only on direct pushes to specific branches.  
2. If `DRAFT_RELEASE == true`, look in “Releases → Drafts” to publish it manually.  
3. Confirm you have “Read and write” permissions for Actions in your repo settings.

---

### No. 8: Branch Protection Blocks Merge

**Symptoms**:
- You can’t merge into `main` or `release-alpha/*`; GitHub says “Branch is protected.”

**Possible Causes**:
- Strict branch protection rules require approvals or passing checks before merging.  
- You’re lacking the required PR reviews or status checks.

**Solution**:
1. Have the required reviewers approve your Pull Request.  
2. Ensure the “Build VI Package” and “Run Unit Tests” checks pass.  
3. Update your `CONTRIBUTING.md` to specify the merging rules so contributors know what’s needed.

---

### No. 9: Incorrect Pre-Release Suffix (Alpha/Beta/RC)

**Symptoms**:
- You expected a `-beta.<N>` suffix, but got `-alpha.<N>` or no suffix at all.

**Possible Causes**:
- Your branch name doesn’t match the required pattern: `release-beta/*`.  
- The script that checks for alpha/beta/rc might not be updated for your custom naming.

**Solution**:
1. Rename your branch to the correct pattern: `release-beta/2.0`, `release-rc/2.0`, etc.  
2. If you changed naming conventions, update your workflow logic to detect them (e.g., a RegEx match).

---

### No. 10: Hotfix Not Tagged as Expected

**Symptoms**:
- Your hotfix branch merges produce a release, but the tag isn’t correct (e.g., it’s missing or still in RC mode).

**Possible Causes**:
- The workflow might treat `hotfix/*` like another pre-release branch if not configured properly.  
- The branch name might not match exactly `hotfix/` (e.g., `hotfix-2.0` without a slash).

**Solution**:
1. Ensure your code checks for `hotfix/` prefix, not `hotfix-`.  
2. Confirm you’re merging into main or the correct base.  
3. Verify the build logs to see how the workflow computed the version and tag.

---

## FAQ

Below are 10 frequently asked questions about the CI workflow and Gitflow process.

### Q1: Can I Override the Build Number?

**Answer**:  
By default, the workflow calculates the build number with `git rev-list --count HEAD`. This ensures sequential builds. If you want a custom offset or manual override, you’d need to modify the build script. However, that breaks the linear progression and isn’t recommended.

---

### Q2: How Do I Skip Creating a Release?

**Answer**:  
You can set an environment variable like `CREATE_RELEASE=false` (if your workflow supports it) or remove the “Create Release” step for certain branches. Another option is to let it create a draft release and simply never publish it.

---

### Q3: Can I Have More Than Alpha/Beta/RC Channels?

**Answer**:  
Yes, you can add logic for `release-gamma/*` or any naming scheme. Just update the portion of your workflow that checks branch names and appends the appropriate suffix.

---

### Q4: Do I Need a GPG Key to Build on a Fork?

**Answer**:  
No. If `DISABLE_GPG_ON_FORKS=true`, the signing process is disabled on forks to prevent missing key issues. You can still produce builds without GPG signatures.

---

### Q5: How Can I Attach Multiple `.vip` Files to a Release?

**Answer**:  
Modify the artifact collection or upload steps to match multiple `.vip` patterns (e.g., `*.vip`). Then, in the “Attach Artifacts” step, loop over all matches and upload each.

---

### Q6: Do I Need To Merge Hotfixes Into `develop`?

**Answer**:  
Yes. In standard Gitflow, after merging a `hotfix/*` into `main`, you also merge it back into `develop` so that your fix is reflected in ongoing development. Otherwise, you risk reintroducing the bug in future releases.

---

### Q7: What If I Don’t Want a Draft Release?

**Answer**:  
Simply set `DRAFT_RELEASE=false`. The release will be published immediately after the workflow completes. Alternatively, you can remove or tweak that setting in your `.yml` file.

---

### Q8: Can I Use This Workflow Without Gitflow?

**Answer**:  
Technically yes, if you don’t rely on alpha/beta/rc branch naming. But the workflow is designed with Gitflow in mind, so some features (like pre-release suffix detection) might not apply if you only have `main`.

---

### Q9: Why Is My Dev Mode Toggle Not Working Locally?

**Answer**:  
The Dev Mode Toggle scripts rely on a self-hosted runner context. If you’re trying to run them directly on your machine outside GitHub Actions, you might need to adapt the PowerShell scripts or replicate the environment variables. Check logs to see if your system path matches what the scripts expect.

---

### Q10: Can I Use a Different LabVIEW Version (e.g., 2023)?

**Answer**:  
Yes, if your machine and project support it. You’ll need to install that version on your self-hosted runner, and potentially update environment variables or references in the build scripts (e.g., specifying the correct LabVIEW EXE path). Just ensure everything in the project is compatible.

---
