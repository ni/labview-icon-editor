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
- `changes` / `apply-deps` — detect/apply VIPC when needed (via Orchestration CLI)
- `version` — compute version components
- `missing-in-project-check` — validate project membership
- `test` — run unit tests (LabVIEW 2021 32/64)
- `build-ppl` — build packed libraries (32/64 matrix)
- `build-vip` — package VIP (64-bit default)

Artifacts

- VIP artifacts available from the run
- Release notes: `Tooling/deployment/release_notes.md`

Related workflows

- Dev mode toggle: `scripts/set-development-mode/run-dev-mode.ps1` and `revert-development-mode/run-dev-mode.ps1`
- Draft release (manual): `.github/workflows/draft-release.yml` (invoke via **Run workflow** in GitHub and supply the CI run ID)
- Source distribution smoke: `.github/workflows/source-dist-smoke.yml` (nightly/dispatch) runs the mock g-cli build + artifact existence check via `scripts/smoke/Run-SourceDistSmoke.ps1`.

## Release assets: high-effort TODOs

Low-effort release evidence is already planned (requirements snapshot, version report, SD/Tooling manifests and commit-indexes, CI logs, VS Code task manifest, integrity hashes, repro recipe). Higher-effort items to stage as follow-ups:

- SBOMs (CycloneDX/SPDX) for SD and Tooling payloads
- Diff packs between releases (add/remove/change and hash deltas)
- Coverage and test evidence bundles aligned to the tag
- Security scan outputs (SCA/SAST) with policy status
- Provenance attestation (in-toto/SLSA) chaining commit -> build -> artifacts

## VIPM Docker helper (Linux)

- Location: `Tooling/docker/vipm/README.md` (builds a LabVIEW 2025 Linux image with VIPM CLI and mounts the repo at `/workspace`).
- Use cases: quick VIPM CLI checks (`vipm install /workspace/icon-editor-developer.vipc`, `vipm list --installed`) or previewing VIPM behavior without installing on the host.
- Limitations: not the release path; our official packaging stays on Windows/LabVIEW 2021. VIPM build on Linux is experimental.

