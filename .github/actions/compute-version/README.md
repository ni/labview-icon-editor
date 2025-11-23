# Compute Version

This composite action determines the semantic version for the build based on commit history, branch naming conventions and pull request labels. Pull requests should include exactly one of the labels `major`, `minor`, or `patch`. If no label is present, the action defaults to `patch`; conflicting labels still cause the action to fail.

The action requires at least one existing semantic version tag (`vMAJOR.MINOR.PATCH`) in the repository. If none are found, it stops and asks you to create the initial tag so it can derive `MAJOR`, `MINOR`, and `PATCH`.

## Inputs
- `github_token`: GitHub token with repository access.

## Outputs
- `VERSION`: Full version string (e.g. `v1.2.3-build4`).
- `MAJOR`, `MINOR`, `PATCH`: Numeric version components.
- `BUILD`: Commit-based build number (total commits from repo root).
- `IS_PRERELEASE`: `true` when branch naming implies prerelease.
- `Commit`: Git commit hash is resolved by callers (e.g., build scripts) automatically; no user prompt required.

## Example
```yaml
- id: version
  uses: ./.github/actions/compute-version
  with:
    github_token: ${{ secrets.GITHUB_TOKEN }}
- run: echo "Version is ${{ steps.version.outputs.VERSION }}"
```
