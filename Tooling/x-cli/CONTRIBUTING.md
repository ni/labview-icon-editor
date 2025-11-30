# Contributing to **x-cli**

[![Docs Gate](https://github.com/LabVIEW-Community-CI-CD/x-cli/actions/workflows/docs-gate.yml/badge.svg)](./.github/workflows/docs-gate.yml)
[![SRS Gate](https://github.com/LabVIEW-Community-CI-CD/x-cli/actions/workflows/srs-gate.yml/badge.svg)](./.github/workflows/srs-gate.yml)
[![YAML Lint](https://github.com/LabVIEW-Community-CI-CD/x-cli/actions/workflows/yaml-lint.yml/badge.svg)](./.github/workflows/yaml-lint.yml)
[![PR Coverage Gate](https://github.com/LabVIEW-Community-CI-CD/x-cli/actions/workflows/coverage-gate.yml/badge.svg)](./.github/workflows/coverage-gate.yml)
[![Tests Gate](https://github.com/LabVIEW-Community-CI-CD/x-cli/actions/workflows/tests-gate.yml/badge.svg)](./.github/workflows/tests-gate.yml)
[![Stage 1 Telemetry](https://github.com/LabVIEW-Community-CI-CD/x-cli/actions/workflows/stage1-telemetry.yml/badge.svg)](./.github/workflows/stage1-telemetry.yml)
[![Stage 3](https://github.com/LabVIEW-Community-CI-CD/x-cli/actions/workflows/stage3.yml/badge.svg)](./.github/workflows/stage3.yml)
[![Telemetry Aggregate](https://github.com/LabVIEW-Community-CI-CD/x-cli/actions/workflows/telemetry-aggregate.yml/badge.svg)](./.github/workflows/telemetry-aggregate.yml)

Tip: run `make first-run` to quickly set up a local GitHub token, authenticate gh, and persist `.tools/bin` on PATH.

> **Contractual context**
> This repository is governed by the **SRS** (index at [docs/SRS.md](docs/SRS.md))
> with a registry‑backed, multi‑file layout under `docs/srs/FGC-REQ-*.md`.
> New spec files **must** be registered with the SRS API so hooks can validate IDs.
> **Every change MUST maintain SRS alignment**: update tests, docs, and CI accordingly.

---

### Design Contract
Changes to public behavior (CLI usage, exit codes, config precedence, log schema)
**must** update `/docs/Design.md` and tests. PRs that alter these without doc/test updates
will be requested to add them before merge.

### Architecture Decision Records
ADR templates include a **Traceability** section. When drafting an ADR, list affected SRS IDs and related tests, and register new requirements via `src/SrsApi`.

---

## 0) Quick start

First time here? Run `make first-run` to set up a local GitHub token, authenticate gh, and persist `.tools/bin` on PATH; then open a new terminal.

**Prereqs**  
- .NET SDK **8.0.x**  
- Windows 10/11 or Ubuntu 22.04+ (same as CI runners)  

**Build & test locally**
```bash
dotnet build XCli.sln -c Release
dotnet test  XCli.sln -c Release
```

**GitHub token + gh CLI setup (one-time)**
- Create `.secrets/github_token.txt` and paste your PAT (single line).
- Load and authenticate with helper (adds `.tools/bin` to PATH for this shell):
  - Windows: `pwsh -File scripts/ghops/tools/use-local-github-token.ps1 -Login -Validate [-EnsureGh]`
  - Linux/macOS: `bash scripts/ghops/tools/use-local-github-token.sh --login --validate`
  - After login: `gh auth status` should show your account. If `gh` is missing, place a portable binary under `.tools/bin/` or install from https://cli.github.com/.

**Persist PATH (optional, one-liner)**
- Windows (PowerShell): `pwsh -File scripts/ghops/tools/bootstrap-path.ps1 -AllHosts -WindowsPowerShell [-EchoOnce]`
- Linux/macOS: `bash scripts/ghops/tools/bootstrap-path.sh [--echo-once]`
  - Opens a new terminal for changes to take effect.

**Publish single-file (reference)**
```bash
dotnet publish src/XCli/XCli.csproj -c Release -r linux-x64 -p:PublishSingleFile=true -p:SelfContained=true -o dist/linux
dotnet publish src/XCli/XCli.csproj -c Release -r win-x64   -p:PublishSingleFile=true -p:SelfContained=true -o dist/win
```

---

## 1) Source of truth

- **SRS:** [docs/SRS.md](docs/SRS.md) (IEEE Computer Society, *IEEE Recommended Practice for Software Requirements Specifications*, IEEE Std 830‑1998, <https://standards.ieee.org/standard/830-1998.html>) plus requirement files in `docs/srs/`. A registry maps each `FGC-REQ-...` to its file.
- **Register spec files:** add new `docs/srs/FGC-REQ-*.md` files to the SRS API (`src/SrsApi`) so commit hooks can discover them.
- **Issues:** <https://github.com/LabVIEW-Community-CI-CD/x-cli/issues> (Codex agents create or link issues automatically).
- **Traceability:** `docs/srs/core.md §6.5` maps **Requirement → Files → Tests → CI**.
- **Tests:** Everything under `tests/XCli.Tests` is **spec compliance**; tests are named and structured to assert SRS clauses.
- **Placeholder IDs:** Tests may reference `TEST-REQ-*` identifiers to exercise validation logic.
  These placeholders have no corresponding spec files and are ignored by traceability tooling. Commit messages and PR metadata MUST NOT use `TEST-REQ-*` identifiers; use real `FGC-REQ-*` IDs instead.

> **Policy:** If code changes alter any externally visible behavior (messages, flags, JSON shape, exit codes, timing guarantees), **update SRS and tests in the same PR**.

---

## 2) Repository layout

```
src/
  XCli/
    Program.cs             // Entry (no side-effects; wiring, top-level errors)
    Cli.cs                 // Parse: global opts, subcommand, pass-through ‘--’
    VersionInfo.cs         // Banner/version behavior
    Simulation/            // SimulationPlan + Simulator (default success / configured failure)
    Logging/               // InvocationLogger (stderr JSONL + optional file, concurrency-safe)
    Security/              // IsolationGuard (no network/process spawn)
    Util/Env.cs            // Null-safe env access (ONLY place touching Environment)
    Properties/InternalsVisibleTo.cs
  tests/
    XCli.Tests/
      TestInfra/ProcessRunner.cs       // subprocess runner capturing stdout/stderr, log JSON, and env snapshot
      SpecCompliance/
        FailureSimulationTests.cs       // SRS §3.2 (env/JSON precedence, message, exit code)
        LoggingShapeTests.cs            // SRS §3.3 (JSON keys, stderr-only)
        PassThroughFidelityTests.cs     // SRS §3.1 (exact args[] after ‘--’)
      Unit/EnvTests.cs                  // Env helper behavior
      Analyzers/NoDirectEnvironmentAccessTests.cs // Forbids direct Environment access
.github/workflows/build.yml           // Matrix CI, publish single-file, smoke tests
[docs/SRS.md](docs/SRS.md)                         // SRS index (contract)
```

---

## 3) Contribution workflow

1. **Codex agents automatically create or link GitHub issues as needed.**
2. **Branch**:
   - **Codex branches:** `codex/<issue-number>-<slug-of-title>-<runId>`
   - **Human branches (optional):** `feature/<short-desc>` or `fix/<short-desc>`
3. **Code** + **tests** (update/extend).
4. **Docs**: update `docs/srs/core.md` and any relevant `docs/srs/FGC-REQ-*.md` files.
   - Register new spec files with the SRS API so the registry knows about them.
5. **CI**: ensure `.github/workflows/build.yml` still passes on Windows + Linux.
6. **PR**: title must follow `codex: <change_type> | <short-description>`.
   List SRS IDs in commit metadata and the PR body, not the title.
   - *Example*: `codex: impl | Update logging docs`

**Commit message template**
```
<summary (<=50 chars)>

codex: (spec|impl|both) | SRS: FGC-REQ-<AREA>-<NNN>[@<SPEC-VERSION>][, FGC-REQ-<AREA>-<NNN>[@<SPEC-VERSION>]...][ | issue: #<ISSUE-NUMBER>]
```

Append `@<SPEC-VERSION>` to disambiguate SRS IDs that appear in multiple versions.
Include `| issue: #<ISSUE-NUMBER>` when linking to a GitHub issue; omit this segment when no issue applies.

*Example*:
```
Update logging docs

codex: impl | SRS: FGC-REQ-CLI-001, FGC-REQ-LOG-002 | issue: #123
```

**Install Git hooks**

Run once after cloning to install the commit message hook and configure the
commit template:

```bash
make bootstrap
```
This runs `pre-commit install --hook-type commit-msg` via the
[`pre-commit`](https://pre-commit.com) framework and sets the commit template to
`scripts/commit-template.txt`. Two hooks are installed:

- `scripts/prepare-commit-msg.py` populates the commit message from
  `.codex/metadata.json` (fields: `summary`, `change_type`, `srs_ids`, optional
  `issue`).
  - `scripts/commit-msg` invokes `scripts/check-commit-msg.py` to enforce the
    template defined in [AGENTS.md](AGENTS.md).

If `pre-commit` is unavailable:

- POSIX: run `make hooks` (calls `scripts/hooks-install.sh`) or use `scripts/setup-git-hooks.sh` directly.
- Windows: run `scripts/setup-git-hooks.ps1` to install Windows-friendly `.bat` hook wrappers into `.git/hooks`.

Hooks can also be invoked directly:

```bash
scripts/commit-msg <path-to-commit-message>
```

**Commit hygiene**

Before requesting review, fix up commits locally and push safely:

```bash
git commit --amend   # or: git rebase -i
git push --force-with-lease
```

*Note:* The amend/rebase advice above is intended for human contributors. Codex agents must not rewrite commit history.

#### For Codex Agents
Commit history is immutable—never amend or rebase existing commits. Create new commits instead.

---

## CI Preview: Markdown Templates

- PRs run a non-blocking job: "Markdown Templates Preview".
  - It renders all templates under `docs/templates/markdown/**/*.tpl.md` and uploads:
    - Rendered examples as artifact `md-templates` (`*.example.md`).
    - Combined manifest as artifact `md-templates-sessions-preview` (`sessions-manifest.json`).
  - The job summary shows totals and a Top placeholders table.
  
  Badges:
  
  [![Markdown Templates Preview](https://github.com/LabVIEW-Community-CI-CD/x-cli/actions/workflows/md-templates.yml/badge.svg)](./.github/workflows/md-templates.yml)
  [![Markdown Templates Sessions](https://github.com/LabVIEW-Community-CI-CD/x-cli/actions/workflows/md-templates-sessions.yml/badge.svg)](./.github/workflows/md-templates-sessions.yml)

  Note: Job Summaries display “Effective thresholds: TopN, MinCount,” sourced from repo variables `MD_TEMPLATES_TOPN` (default 10) and `MD_TEMPLATES_MINCOUNT` (default 1). Configure these under Settings → Secrets and variables → Actions → Variables.
- Scheduled runs ("Markdown Templates Sessions") render with domain contexts (default, ci, telemetry, docs) and produce a combined `sessions-manifest.json` with optional schema validation.
- Configure summary depth using repo variable `MD_TEMPLATES_TOPN` (default: 10). Set in Settings → Secrets and variables → Actions → Variables.
- Optionally filter noise with `MD_TEMPLATES_MINCOUNT` to omit placeholders seen fewer than N times (default: 1 = no filtering).
 - See the PR template’s collapsed “Reviewer Guide — Markdown Templates” block for quick review pointers.

---

## 4) Making changes without drifting from the SRS

### 4.1 Adding or changing a **subcommand**
**You MUST:**
1) Update `Cli.cs` to include the new identifier in the recognized set.  
2) Update **help text** and unknown-command error if wording changes.  
3) Update **SRS**: §3.1 (CLI Surface) and §6.2 Log Schema enum (`subcommand`).  
4) Add/adjust tests:  
   - `PassThroughFidelityTests` (args[] preserved after `--`)  
   - `SimulationTests` (default success line + exit 0)  
   - `LoggingShapeTests` (log shows the new subcommand)  
5) Re-run perf tests (`PerfTests`) to ensure **< 2s** (SRS §3.6).
   Tests warn after 4000 ms and fail after 8000 ms by default; override with
   `XCLI_PERF_WARN_MS`/`XCLI_PERF_FAIL_MS`.

### 4.2 Changing **messages** or **output shape**
Messages are **normative** (SRS §4.1.3). If you alter wording, **update SRS** and adjust tests:
- Success stdout: `[x-cli] <subcommand>: success (simulated)`
- Failure stderr: `[x-cli] <subcommand>: failure (simulated) - <message>`
- Unknown stderr: `[x-cli] error: unknown subcommand '<name>'. See --help.`

### 4.3 Environment variables (configuration)
All env reads MUST go through **`Util/Env.cs`**.  
If you add a variable (e.g., `XCLI_NEWFLAG`):
1) Implement retrieval in `Env.cs`.  
2) Update **SRS §3.2** (env list + precedence, if affected).  
3) Add/extend **`EnvTests`**.  
4) Extend **`FailureSimulationTests`** if behavior changes.  
5) Ensure **`NoDirectEnvironmentAccessTests`** still passes.

### 4.4 Logging schema
The JSON log (SRS §3.3 & §6.2.1) is **contractual**.  
If you add a property:  
1) Update `Logging/InvocationLogger.cs`.  
2) Update **SRS** schema (§6.2.1) and **`LoggingShapeTests`**.  
3) Ensure **stderr-only** remains true and file append stays **concurrency-safe**.

### 4.5 Safety constraints
**Never** use `System.Net*` or `Process.Start` in production code.  
Violations will fail **`SecurityTests`** or **`NoDirectEnvironmentAccessTests`**.

---

## Troubleshooting References

- External docs (preferred):
  - PR comments (label-gated): https://github.com/LabVIEW-Community-CI-CD/gha-post-pr-comment
  - Artifacts metadata loader: https://github.com/LabVIEW-Community-CI-CD/gha-artifacts-metadata
- Local fallback (when developing in-repo):
  - `.github/actions/post-comment-or-artifact/README.md`
  - `.github/actions/load-artifacts-meta/README.md`

## Maintainer Guide — Repo Variables

Use repository variables to tune CI summaries and enable Marketplace auto-badges:

- LINT_TOPN (default 10): depth of top-N rule lists shown in comments and summaries.
- LINT_TOPN_SUMMARY_MAX (default 5): show inline "Top rules" in Job Summary only when the unique rule count ≤ this value.

Set via GitHub UI:
- Settings → Secrets and variables → Actions → Variables → New repository variable

Set via GitHub CLI:
```bash
gh variable set LINT_TOPN --body "10"
gh variable set LINT_TOPN_SUMMARY_MAX --body "5"
```

External action repos (post/artifacts) — Marketplace:
- MARKETPLACE_POST_SLUG / MARKETPLACE_ARTIFACTS_SLUG: set these to activate the post‑release README updater (adds Marketplace badges/links with retry/backoff).
```bash
gh variable set MARKETPLACE_POST_SLUG --repo LabVIEW-Community-CI-CD/gha-post-pr-comment --body "<post-slug>"
gh variable set MARKETPLACE_ARTIFACTS_SLUG --repo LabVIEW-Community-CI-CD/gha-artifacts-metadata --body "<artifacts-slug>"
```

## 5) Performance & UX budgets

- **Latency:** Each supported subcommand finishes **< 2000 ms** by default (SRS §3.6).  
- **Default delay:** `XCLI_DELAY_MS` **must** default to `0`.  
- **Output clarity:** Stdout contains only the user-facing message; JSON log lines go to **stderr** (SRS §3.3).

---

## 6) CI rules (must pass before merge)

Matrix job on **ubuntu-latest** and **windows-latest**:
1) `dotnet restore XCli.sln && dotnet build XCli.sln -c Release`
2) `dotnet test XCli.sln -c Release` (OS-specific shells; see workflow)
3) Publish single-file artifacts for linux-x64 & win-x64
4) Smoke test each artifact with `--help`

**Windows test step uses PowerShell**, Linux uses Bash (no cross-shell constructs). For Node-based CI tools (e.g., TypeScript utilities), use the reproducible patterns in [docs/ci/node-patterns.md](docs/ci/node-patterns.md): pin Node 20.x, commit lockfiles, install with `npm ci`, and validate JSON with PowerShell `Test-Json`.

---

## 7) PR checklist (copy into your PR)

- [ ] SRS sections updated (reference IDs here): `FGC-REQ-_____`
- [ ] New spec files registered with the SRS API (`src/SrsApi`)
- [ ] CLI messages unchanged **or** updated in SRS + tests
- [ ] Env variables documented in SRS (§3.2) and handled via `Env.cs`  
- [ ] Logging JSON keys preserved/extended and tests updated
- [ ] No `System.Net*` or `Process.Start` in production code (analyzer tests pass)
- [ ] For notification changes, add/extend checks in `scripts/validate_notifications.sh` and ensure JSONL emits for each check
- [ ] All tests green on Windows and Linux
- [ ] Perf: typical invocation < 2s (no artificial delay by default)
- [ ] Artifacts publish & smoke-test `--help`

---

## 8) Coding guidelines

- C# 12 / .NET 8, **nullable enabled**.  
- Keep modules small and single-purpose; prefer pure functions.  
- Use **`Env` helpers**; do not read environment variables directly elsewhere.  
- Keep CLI parsing straightforward; do not re-tokenize payload args.  
- Log a single JSON object per invocation (compact; no pretty-printing).  

---

## 9) Versioning & release

- Semantic versioning. `--version` prints the informational version (identical regardless of executable name).  
- Releases are produced by the CI workflow (`workflow_dispatch`) and distributed as artifacts.

---

## 10) Security & privacy

- **No network** and **no process spawn**.  
- Do **not** log secrets; logged env variables are restricted to the `XCLI_*` prefix.  
- All writes are optional and limited to the configured log file path.

---

## Pre-commit hooks

- Install hooks: `pre-commit install && pre-commit install --hook-type commit-msg`
- Run all: `pre-commit run --all-files`
- SRS ASCII H1 lint runs on commit to prevent Unicode in SRS titles.
- Auto-fix titles when needed:
  - `pre-commit run srs-title-ascii-fix --all-files`
  - or `python scripts/check_srs_title_ascii.py --fix docs/srs/FGC-REQ-AREA-001.md`

- Docs link check (lychee):
  - Run hook: `pre-commit run docs-link-check --all-files`
  - Direct (cross-platform): `python scripts/docs_link_check.py`
  - Wrappers: `./scripts/docs-link-check.sh` (POSIX) or `pwsh ./scripts/docs-link-check.ps1` (Windows)
  - Note: runs offline with anchors enabled per `.lychee.toml`.

Source of truth for hook documentation links lives in `scripts/precommit_hook_links.json`.
When adding or editing hooks in `.pre-commit-config.yaml`, also add an entry there so
PR comments can hyperlink failing hooks to the right documentation. A guard
(`scripts/check_precommit_hook_links.py`) runs in pre-commit and CI to enforce this.

---
## 11) Questions

Open an issue at <https://github.com/LabVIEW-Community-CI-CD/x-cli/issues> with the SRS ID(s) you’re targeting (e.g., `FGC‑REQ‑SIM‑002`) and the proposed change.

Thanks for contributing! 🎉

## Telemetry (Built-in CLI)

Use the built-in C# telemetry subcommands for QA JSONL and gates:

- Summarize: `dotnet run -- telemetry summarize --in artifacts/qa-telemetry.jsonl --out telemetry/summary.json [--history telemetry/qa-summary-history.jsonl]`
- Write: `dotnet run -- telemetry write --out artifacts/qa-telemetry.jsonl --step <name> --status pass|fail [--duration-ms N] [--meta k=v]`
- Gate: `dotnet run -- telemetry check --summary telemetry/summary.json --max-failures <N>`

Notes:
- `scripts/qa.ps1` already runs summarize and supports an optional MAX_QA_FAILURES gate.
- The Telemetry CLI is self-contained (no Python/Node required for core operations).
- Full docs: `docs/cli/telemetry.md`.

### Telemetry Tests (xUnit)
- Run only telemetry tests:
  - Filter: `dotnet test XCli.sln -c Release --filter "FullyQualifiedName~TelemetryCliTests|FullyQualifiedName~TelemetryValidateTests"`
  - Or use runsettings: `dotnet test XCli.sln -c Release --settings tests/Telemetry.runsettings`

