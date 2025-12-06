# Codex Verified Human Mirror

This document outlines how a trusted human contributor can mirror a
codex-generated change and pass the repository's guard checks.

## Overview
1. A codex agent opens a pull request on a fork or separate
   repository.
2. A trusted human mirrors the branch and submits a new pull request
   to this repository.
3. The mirror must prove authenticity by signing the head commit SHA
   with a shared secret.

## Generating a Signature (Maintainers)
Only repository maintainers with access to secrets can produce a valid
token:

1. Open the repository on GitHub and navigate to the **Actions** tab.
2. Choose **Generate Codex Mirror Signature** from the workflow list.
3. Click **Run workflow**.
4. Enter the branch name or commit SHA to sign and run the job.
5. When the job completes, open the logs and copy the line:
   `Codex-Mirror-Signature: <hex>`.
6. Paste that line into the pull request body alongside the reported
   `SHA: <commit>`.

## Human Checklist
- [ ] Run the **Generate Codex Mirror Signature** workflow and copy the
      `Codex-Mirror-Signature: <hex>` output.
- [ ] Add the signature line as a separate entry in the pull request
      body.
- [ ] Ensure the PR body still contains the codex metadata JSON and
      `Codex Mode: codex` marker.
- [ ] Label the pull request with `codex`.
- [ ] Run repository QA checks and include relevant citations.

## Troubleshooting

- **Signature mismatch**: verify the commit SHA in the PR matches the
  one used during signing. If the diff changed or commits were amended,
  re-run the signer workflow and update the line. Commit amendments are
  expected only from the human mirror; codex agents shall keep commit
  history immutable.
- **Guard failure**: ensure the PR body includes the line exactly
  `Codex-Mirror-Signature: <hex>` with no extra whitespace.
