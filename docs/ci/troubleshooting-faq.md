# Troubleshooting and FAQ

This document provides a collection of common **troubleshooting** scenarios (with solutions) and a **FAQ** (Frequently Asked Questions) for the LabVIEW Icon Editor GitHub Actions workflows. Refer back to the main CI guide if you need overall setup instructions or deeper references.

---

## Table of Contents

1. [Troubleshooting](#troubleshooting)
   1. [No. 1: LabVIEW Not Found on Runner](#no-1-labview-not-found-on-runner)
   2. [No. 2: No `.vip` Artifact Found](#no-2-no-vip-artifact-found)
   3. [No. 3: Version Label Not Recognized](#no-3-version-label-not-recognized)
   4. [No. 4: Build Number Not Updating](#no-4-build-number-not-updating)
   5. [No. 5: Dev Mode Still Enabled After Build](#no-5-dev-mode-still-enabled-after-build)
   6. [No. 6: Release Not Created](#no-6-release-not-created)
   7. [No. 7: Branch Protection Blocks Merge](#no-7-branch-protection-blocks-merge)
   8. [No. 8: Incorrect Pre-Release Suffix (Alpha/Beta/RC)](#no-8-incorrect-pre-release-suffix-alphabetarc)
   9. [No. 9: Hotfix Not Tagged as Expected](#no-9-hotfix-not-tagged-as-expected)
   10. [No. 10: Double-Dash Parameters Not Recognized](#no-10-double-dash-parameters-not-recognized)
   11. [No. 11: Company/Author Fields Not Populating](#no-11-companyauthor-fields-not-populating)
   12. [No. 12: JSON Fields Overwritten Incorrectly](#no-12-json-fields-overwritten-incorrectly)
   13. [No. 13: Repository Forks Not Displaying Correct Metadata](#no-13-repository-forks-not-displaying-correct-metadata)


2. [FAQ](#faq)
   1. [Q1: Can I Override the Build Number?](#q1-can-i-override-the-build-number)
   2. [Q2: How Do I Create a Release?](#q2-how-do-i-create-a-release)
   3. [Q3: Can I Have More Than Alpha, Beta, or RC Channels?](#q3-can-i-have-more-than-alpha-beta-or-rc-channels)
   4. [Q4: How Can I Attach Multiple `.vip` Files to a Release?](#q4-how-can-i-attach-multiple-vip-files-to-a-release)
   5. [Q5: Do I Need To Merge Hotfixes Into `develop`?](#q5-do-i-need-to-merge-hotfixes-into-develop)
   6. [Q6: What About Draft Releases?](#q6-what-about-draft-releases)
   7. [Q7: Can I Use This Workflow Without Gitflow?](#q7-can-i-use-this-workflow-without-gitflow)
   8. [Q8: Why Is My Dev Mode Toggle Not Working Locally?](#q8-why-is-my-dev-mode-toggle-not-working-locally)
   9. [Q9: Can I Use a Different LabVIEW Version (e.g., 2023)?](#q9-can-i-use-a-different-labview-version-eg-2023)
   10. [Q10: How Do I Pass Repository Name and Organization?](#q10-how-do-i-pass-repository-name-and-organization)
   11. [Q11: Can I Omit the Company/Author Fields in My JSON?](#q11-can-i-omit-the-companyauthor-fields-in-my-json)
   12. [Q12: Why Must I Use Single-Dash Instead of Double-Dash?](#q12-why-must-i-use-single-dash-instead-of-double-dash)
   13. [Q13: Can I Add More Fields to the VIPB Display Information?](#q13-can-i-add-more-fields-to-the-vipb-display-information)


---

## Troubleshooting

Below are 13 possible issues you might encounter, along with suggested steps to resolve them.

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

### No. 2: No `.vip` Artifact Found

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

### No. 3: Version Label Not Recognized

**Symptoms**:
- You labeled your Pull Request “minor” or “patch,” but the version doesn’t increment that segment.

**Possible Causes**:
- The workflow only checks for certain labels (`major`, `minor`, `patch`). Typos or different capitalization might be ignored.
- You’re pushing directly to a branch instead of creating a PR. Version bumps require a labeled pull request.

**Solution**:
1. Make sure the label is exactly `major`, `minor`, or `patch` in lowercase (unless your workflow script also checks for capitalized labels).  
2. Confirm you’re actually using a Pull Request event (not a direct push).  
3. Check the CI Pipeline (Composite) logs for the **version** job’s “Determine bump type” step (from `.github/actions/compute-version`).

---

### No. 4: Build Number Not Updating

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

### No. 5: Dev Mode Still Enabled After Build

**Symptoms**:
- You run a build, but the environment remains in “development mode,” causing odd behavior when installing `.vip`.

**Possible Causes**:
- You forgot to run the “disable” step of the Development Mode Toggle.  
- Another step re-applied the `Set_Development_Mode.ps1` script.

**Solution**:
1. Manually run the “Development Mode Toggle” workflow with `mode=disable`.  
2. Confirm your pipeline sequence: typically, dev mode is enabled for debugging only, then disabled prior to final builds.

---

### No. 6: Release Not Created

**Symptoms**:
- The workflow completes, but you see no new release in GitHub’s “Releases” section.

**Possible Causes**:
- The composite pipeline only uploads artifacts and does not create releases automatically.
- The build was triggered by a Pull Request, and your workflow logic only creates releases on “push” or merges to main.

**Solution**:
1. Create releases manually through GitHub’s interface or configure a separate workflow to publish them.
2. Check your workflow triggers if you expect another workflow to handle releases on certain branches.
3. Confirm you have “Read and write” permissions for Actions in your repo settings.

---

### No. 7: Branch Protection Blocks Merge

**Symptoms**:
- You can’t merge into `main` or `release-alpha/*`; GitHub says “Branch is protected.”

**Possible Causes**:
- Strict branch protection rules require approvals or passing checks before merging.
- The [`issue-status`](../../.github/workflows/ci.yml#issue-status) job determined the branch name or issue status was invalid, so downstream checks were skipped.
- You’re lacking the required PR reviews or status checks.

**Solution**:
1. Have the required reviewers approve your Pull Request.
2. Ensure all required status checks pass:
   - [`issue-status`](../../.github/workflows/ci.yml#issue-status) – verifies branch naming and issue status. If it fails or is skipped, downstream jobs won’t run.
   - [`changes`](../../.github/workflows/ci.yml#changes) – detects `.vipc` file changes.
   - [`apply-deps`](../../.github/workflows/ci.yml#apply-deps) – applies VIPC dependencies when needed.
   - [`missing-in-project-check`](../../.github/workflows/ci.yml#missing-in-project-check) – validates project file membership.
   - [`Run Unit Tests`](../../.github/workflows/ci.yml#test) – executes unit tests.
   - [`Build VI Package`](../../.github/workflows/ci.yml#build-vip) – produces the `.vip` artifact.
3. Update your `CONTRIBUTING.md` to specify the merging rules so contributors know what’s needed.

---

### No. 8: Incorrect Pre-Release Suffix (Alpha/Beta/RC)

**Symptoms**:
- You expected a `-beta.<N>` suffix, but got `-alpha.<N>` or no suffix at all.

**Possible Causes**:
- Your branch name doesn’t match the required pattern: `release-beta/*`.  
- The script that checks for alpha/beta/rc might not be updated for your custom naming.

**Solution**:
1. Rename your branch to the correct pattern: `release-beta/2.0`, `release-rc/2.0`, etc.  
2. If you changed naming conventions, update your workflow logic to detect them (e.g., a RegEx match).

---

### No. 9: Hotfix Not Tagged as Expected

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

### No. 10: Double-Dash Parameters Not Recognized

**Symptoms**:
- You see an error like:  
  *“A positional parameter cannot be found that accepts argument '--lv-ver'”*

**Possible Causes**:
- PowerShell scripts typically declare parameters with single dashes (e.g. `-SupportedBitness 64`).  
- The script has no parameter named `lv-ver` or `arch`, so passing `--lv-ver` or `--arch` triggers a parsing error.

**Solution**:
1. Remove or replace `--lv-ver` and `--arch` with valid single-dash parameters your script actually declares, such as `-Package_LabVIEW_Version 2021` and `-SupportedBitness 64`.  
2. If you really want `--lv-ver`, you must update the script’s `param()` block to accept that alias.

---

### No. 11: Company/Author Fields Not Populating

**Symptoms**:
- The final `.vip` file’s metadata for “Company Name” or “Author Name (Person or Company)” remains empty.

**Possible Causes**:
- You didn’t pass `-CompanyName` or `-AuthorName` to the `Build.ps1` script.  
- The JSON creation step is missing or incorrectly references the parameters.

**Solution**:
1. In your GitHub Actions or local call, ensure you specify both `-CompanyName "XYZ Corp"` and `-AuthorName "my-org/repo"`.  
2. Check that the script’s code block generating `$DisplayInformationJSON` includes these fields.  
3. Confirm no conflicting code overwrote your JSON after you set it.

---

### No. 12: JSON Fields Overwritten Incorrectly

**Symptoms**:
- You see “Add-Member … already exists” errors, or your `Package Version` keys get overwritten unexpectedly.

**Possible Causes**:
- The script is re-adding or re-initializing the same JSON fields multiple times without using `-Force`.  
- Another function in the pipeline modifies the same subobject.

**Solution**:
1. Update your script to **conditionally** add fields only if they’re missing, or directly assign the property if it already exists.  
2. If needed, specify `Add-Member -Force` (though recommended approach is to check existence first).  
3. Ensure you only do the “Package Version” injection once in your pipeline.

---

### No. 13: Repository Forks Not Displaying Correct Metadata

**Symptoms**:
- A user forks the repository, but the `.vip` file still shows the **original** repo or organization name.

**Possible Causes**:
- The fork’s GitHub Actions workflow wasn’t updated to pass the new org name.  
- The fork’s build scripts are still using default or stale values for `-CompanyName` / `-AuthorName`.

**Solution**:
1. In the new fork, update the workflow to pass `-CompanyName "${{ github.repository_owner }}"` and `-AuthorName "${{ github.repository }}"`.  
2. Check that the script logic references those parameters for the final JSON.  
3. Review environment variables in GitHub Actions for the fork to ensure they’re set correctly.

---

## FAQ

Below are 14 frequently asked questions about the CI workflow and Gitflow process.

### Q1: Can I Override the Build Number?

**Answer**:  
By default, the workflow calculates the build number with `git rev-list --count HEAD`. This ensures sequential builds. If you want a custom offset or manual override, you’d need to modify the build script. However, that breaks the linear progression and isn’t recommended.

---

### Q2: How Do I Create a Release?

**Answer**:
The composite pipeline only uploads artifacts and does not create GitHub releases automatically. Create releases manually through the GitHub interface or set up a separate workflow dedicated to publishing them.

---

### Q3: Can I Have More Than Alpha, Beta, or RC Channels?

**Answer**:  
Yes, you can add logic for `release-gamma/*` or any naming scheme. Just update the portion of your workflow that checks branch names and appends the appropriate suffix.

---

### Q4: How Can I Attach Multiple `.vip` Files to a Release?

**Answer**:  
Modify the artifact collection or upload steps to match multiple `.vip` patterns (e.g., `*.vip`). Then, in the “Attach Artifacts” step, loop over all matches and upload each.

---

### Q5: Do I Need To Merge Hotfixes Into `develop`?

**Answer**:  
Yes. In standard Gitflow, after merging a `hotfix/*` into `main`, you also merge it back into `develop` so that your fix is reflected in ongoing development. Otherwise, you risk reintroducing the bug in future releases.

---

### Q6: What About Draft Releases?

**Answer**:
The composite pipeline doesn’t create releases, so draft releases are not generated. If you require a draft or published release, create it manually or configure a separate workflow to handle release creation.

---

### Q7: Can I Use This Workflow Without Gitflow?

**Answer**:  
Technically yes, if you don’t rely on alpha/beta/rc branch naming. But the workflow is designed with Gitflow in mind, so some features (like pre-release suffix detection) might not apply if you only have `main`.

---

### Q8: Why Is My Dev Mode Toggle Not Working Locally?

**Answer**:  
The Dev Mode Toggle scripts rely on a self-hosted runner context. If you’re trying to run them directly on your machine outside GitHub Actions, you might need to adapt the PowerShell scripts or replicate the environment variables. Check logs to see if your system path matches what the scripts expect.

---

### Q9: Can I Use a Different LabVIEW Version (e.g., 2023)?

**Answer**:  
Yes, if your machine and project support it. You’ll need to install that version on your self-hosted runner, and potentially update environment variables or references in the build scripts (e.g., specifying the correct LabVIEW EXE path). Just ensure everything in the project is compatible.

---

### Q10: How Do I Pass Repository Name and Organization?

**Answer**:
Inside **GitHub Actions**, you can reference environment variables such as `${{ github.repository_owner }}` and `${{ github.event.repository.name }}`. Set them first in your workflow step and then pass them to your script:

```yaml
env:
  REPO_OWNER: ${{ github.repository_owner }}
  REPO_NAME: ${{ github.event.repository.name }}
run: |
  .\build_vip.ps1 -CompanyName "$env:REPO_OWNER" -AuthorName "$env:REPO_NAME"
```

`${{ github.repository }}` returns `owner/repo`, so it isn’t suitable for the author field. Using the separate owner and repository values ensures your build is branded correctly when `DisplayInformationJSON` is injected by `build_vip.ps1`.

---

### Q11: Can I Omit the Company/Author Fields in My JSON?

**Answer**:  
Yes. If you don’t want to display them, pass empty strings (`-CompanyName "" -AuthorName ""`) or remove those fields from your script’s JSON object. The final `.vip` file will simply show blank lines or omit those entries.

---

### Q12: Why Must I Use Single-Dash Instead of Double-Dash?

**Answer**:  
PowerShell **named parameters** typically start with a single dash (`-Parameter`). Double-dash syntax (`--param`) is common in Linux CLI tools but is not standard in a typical PowerShell `param()` declaration. If you try to pass `--arch` or `--lv-ver`, you’ll get an error about an unrecognized parameter.

---

### Q13: Can I Add More Fields to the VIPB Display Information?

**Answer**:  
Absolutely. You can modify `$jsonObject` in your script to include new keys, such as `"Product Description"` or `"Special Internal ID"`. Just be sure that the VI that updates the `.vipb` file (`Modify_VIPB_Display_Information.vi`) knows how to handle those additional fields, or they might be ignored.
