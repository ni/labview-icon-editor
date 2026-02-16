# Compute Version

This composite action determines the semantic version for the build based on commit history, branch naming conventions, and pull request labels. On `pull_request` events, pull requests should include exactly one canonical release label: `Version Increment: Major`, `Version Increment: Minor`, or `Version Increment: Patch`. During the compatibility window, alias labels `major`, `minor`, and `patch` are also accepted. If no release label is present, the action defaults to `patch`; conflicting normalized release labels still cause the action to fail. When `bump_type_override` is provided, override precedence is applied and label/event bump detection is skipped.

## Inputs
- `github_token`: GitHub token with repository access.
- `bump_type_override` (optional): Overrides label/event bump detection with `major`, `minor`, `patch`, or `none`.

## Outputs
- `VERSION`: Full version string (e.g. `v1.2.3-build4`).
- `MAJOR`, `MINOR`, `PATCH`: Numeric version components.
- `BUILD`: Commit-based build number.
- `IS_PRERELEASE`: `true` when branch naming implies prerelease.

## Release Label Compatibility
- Canonical labels:
  - `Version Increment: Major`
  - `Version Increment: Minor`
  - `Version Increment: Patch`
- Compatibility aliases (deprecated after two release cycles):
  - `major`
  - `minor`
  - `patch`

## Example
```yaml
- id: version
  uses: ./.github/actions/compute-version
  with:
    github_token: ${{ secrets.GITHUB_TOKEN }}
    bump_type_override: patch
- run: echo "Version is ${{ steps.version.outputs.VERSION }}"
```
