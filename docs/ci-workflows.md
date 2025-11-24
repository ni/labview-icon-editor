# CI Workflows (summary)

Main pipeline: `.github/workflows/ci.yml`

Triggers
- Push/PR to: `main`, `develop`, `release-alpha/*`, `release-beta/*`, `release-rc/*`, `feature/*`, `hotfix/*`, `issue-*`
- `workflow_dispatch` for manual runs
- Gate: `issue-status` enforces branch pattern `issue-<number>` and linked issue Status = In Progress; `NoCI` label skips

Versioning & metadata
- SemVer: MAJOR/MINOR/PATCH from latest tag; BUILD = commit count; commit hash embedded
- Branding: Company = `github.repository_owner`; Author = `git config user.name` fallback to owner
- VIPB auto-discovered (first `*.vipb`); artifacts branded accordingly

Key jobs
- `issue-status` — branch/issue gate
- `changes` / `apply-deps` — detect/apply VIPC when needed
- `version` — compute version components
- `missing-in-project-check` — validate project membership
- `test` — run unit tests (LabVIEW 2021 32/64)
- `build-ppl` — build packed libraries (32/64 matrix)
- `build-vip` — package VIP (64-bit default)

Artifacts
- VIP artifacts available from the run
- Release notes: `Tooling/deployment/release_notes.md`

Related workflows
- Dev mode toggle: `.github/actions/set-development-mode/run-dev-mode.ps1` and `revert-development-mode/run-dev-mode.ps1`
- Draft release (manual): `.github/workflows/draft-release.yml` (use VS Code task “Draft GitHub Release” with CI run ID)
