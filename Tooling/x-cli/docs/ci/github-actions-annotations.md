# GitHub Actions — Run Annotations

Use this helper to retrieve “Annotations” for a workflow run. It collects check run annotations for the run’s commit (`head_sha`) so you can triage errors without opening the web UI.

## Quick start

PowerShell (Windows/Linux/macOS via `pwsh`):

```
pwsh -File scripts/ghops/tools/get-run-annotations.ps1 -Repo LabVIEW-Community-CI-CD/x-cli -RunId 18076116588 -Out artifacts/gh-run-annotations.json -Json
```

With log search (captures error lines when annotations are empty; requires `gh`):

```
pwsh -File scripts/ghops/tools/get-run-annotations.ps1 \
  -Repo LabVIEW-Community-CI-CD/x-cli -RunId 18076116588 \
  -Out artifacts/gh-run-annotations.json -SearchLogs \
  -OutLogs artifacts/run-logs.txt -OutLogsNormalized artifacts/run-logs-normalized.txt \
  -MaxLogHits 100 -Json
```

Outputs
- JSON file with fields: `repo`, `run_id`, `workflow_name`, `head_sha`, `status`, `conclusion`, `total_check_runs`, `total_annotations`, `transport`, `token_awareness`, `annotations[]`.
- Each annotation includes: `check_run_id`, `check_run_name`, `path`, `start_line`, `end_line`, `level`, `title`, `message`, `raw_details`.
- When `-SearchLogs` is used (or annotations are 0), JSON also includes: `annotations_by_level`, `job`, `error_patterns`, `max_log_hits`, `out_logs`, `out_logs_normalized`, and `log_hits[]` (first N matching lines from logs).

Requirements
- Either `gh` CLI authenticated (`gh auth login`) or environment token `GH_TOKEN`/`GITHUB_TOKEN` with read access.
- Minimal scopes: `actions:read`, `checks:read`, and `contents:read` for private repos.

How it works
1. Fetch run: `GET /repos/{owner}/{repo}/actions/runs/{run_id}` → `head_sha`.
2. List check runs for `head_sha`: `GET /repos/{owner}/{repo}/commits/{sha}/check-runs`.
3. For each check run with `output.annotations_count > 0`, fetch `output.annotations_url` with pagination.

Troubleshooting
- 404 Not Found: wrong repo/run id, or token lacks repo access.
- 403 Forbidden: token lacks `checks:read` or `actions:read` scopes.
- Missing `gh` CLI: set `-Transport rest` (requires `GH_TOKEN`/`GITHUB_TOKEN`) or install/authenticate `gh`.
- Token preflight failure: provide an org-scoped PAT (scopes: `read:org`, `repo`, `workflow`) via `GH_TOKEN` or authenticate `gh` as prompted.
- Empty annotations: some failures emit only logs; pull job logs via `gh run view <id> --log` and share relevant excerpts.

## Agent Runbook — Review a Run’s Annotations

Goal: Respond to a request like “Review annotations from https://github.com/LabVIEW-Community-CI-CD/x-cli/actions/runs/18076116588”.

Step 1 — Fetch annotations JSON

- Preferred (with `gh` or `GH_TOKEN`/`GITHUB_TOKEN`):
  - `pwsh -File scripts/ghops/tools/get-run-annotations.ps1 -Repo LabVIEW-Community-CI-CD/x-cli -RunId 18076116588 -Out artifacts/gh-run-annotations.json -Json`
- If `-Repo` is omitted, set the environment:
  - `$env:GITHUB_REPOSITORY='LabVIEW-Community-CI-CD/x-cli'`

Step 2 — Interpret result

- If `conclusion` is `success` and `total_annotations` is 0: reply that the run succeeded; no annotations present.
- If `conclusion` is `failure` and `total_annotations` > 0: summarize the first N annotations and counts by `level`.
- If `conclusion` is `failure` and `total_annotations` is 0: proceed to logs (Step 3).
- Token preflight runs automatically; if the helper fails with a message about `GH_TOKEN`/`GITHUB_TOKEN` or org visibility, follow `docs/ci/token-awareness.md` to export an org-scoped PAT before retrying.

Step 3 — Fallback to logs when annotations are empty

- With `gh` CLI (automatic via helper):
  - Use `-SearchLogs` to fetch the run (or a single job via `-Job '<job name>'`) and extract error lines with patterns (`##[error]`, `error`, `yamllint`, `✗`).
  - Save full and normalized logs by passing `-OutLogs` and `-OutLogsNormalized`.
  - Discover job names quickly if you want to scope: `gh run view 18076116588 --repo LabVIEW-Community-CI-CD/x-cli --json jobs -q ".jobs[].name"`
- REST fallback (automatic when `gh` is unavailable, or force with `-Transport rest`):
  - Requires `GH_TOKEN`/`GITHUB_TOKEN` with `actions:read` to download the run/job logs ZIP.
  - Works with `-SearchLogs`, `-Job`, `-OutLogs`, and `-OutLogsNormalized`; the helper unzips logs under the hood.
- Manual alternative:
  - `gh run view 18076116588 --repo LabVIEW-Community-CI-CD/x-cli --log > artifacts/run-logs.txt`
  - Job-only logs: `gh run view 18076116588 --repo LabVIEW-Community-CI-CD/x-cli --job '<job name>' --log`
- Without `gh` and no token available, request logs from a collaborator, or ask them to run the command above and share `artifacts/run-logs.txt`.
- Tips for triage:
  - Search for errors: PowerShell → `Select-String -Path artifacts/run-logs.txt -Pattern '##\[error\]|\berror\b|yamllint|✗' | Select-Object -First 100`
  - Unix shells → `rg -n "\#\#\[error\]|\berror\b|yamllint|✗" artifacts/run-logs.txt | head -100`
  - YAML lint jobs: look for `Lint YAML (configured)` blocks; yamllint currently writes repo files under `.pytest_tmp/cwdN/`. Strip that prefix to map back (e.g., `docs/knowledge/edition-map.yml`, `docs/templates/RTM-yaml-template.yaml`).
  - Some actions (e.g., YAML lint) do not emit GitHub Check Annotations; failures appear only in logs with `##[error]` lines.

Pagination note

- The helper paginates fully when `gh` CLI is available (`--paginate`).
- Without `gh`, the REST fallback fetches up to 100 annotations (2×50). For larger runs, prefer `gh` to avoid truncation.

Log search flags

- `-SearchLogs`: enable log scraping (uses `gh run view --log`). Triggered automatically when 0 annotations are returned.
- `-Job '<name>'`: limit scraping to a specific job (default: whole run).
- `-ErrorPatterns`: regexes to match error lines (default includes `##[error]`, `\berror\b`, `yamllint`, `✗`).
- `-MaxLogHits N`: cap the number of matched lines captured (default 100).
- `-OutLogs path`: write full logs to a file.
- `-OutLogsNormalized path`: write logs after stripping temp prefixes.
- `-TmpPathRegex`: regex used for normalization (default: `\.pytest_tmp/cwd\d+/`).
- `-Transport auto|gh|rest`: pick transport. `auto` prefers `gh` when available, else REST.
- `-RequireGh`: fail fast if `gh` is missing (even when `-Transport auto`).
- `-Json` implies `-Quiet` unless you explicitly pass `-Quiet:$false`.
- Token preflight flags (default on):
  - `-PreflightToken`: explicit opt-in (default already on).
  - `-NoPreflightToken`: skip token-awareness checks.
  - `-Org <owner>`: override inferred organization for the preflight.

Path normalization (when logs show temp prefixes)

- Some jobs run in temp workdirs (e.g., `./.pytest_tmp/cwd123/…`). To map to repo paths, drop the prefix:
  - PowerShell: `(Get-Content artifacts/run-logs.txt) -replace "\.pytest_tmp/cwd\d+/", "" | Set-Content artifacts/run-logs-normalized.txt`
  - POSIX: `sed -E 's#\.pytest_tmp/cwd[0-9]+/##g' artifacts/run-logs.txt > artifacts/run-logs-normalized.txt`

Step 4 — Deliver a concise summary

- Include: workflow name, run id, `head_sha`, `conclusion`, `total_check_runs`, `total_annotations`.
- If annotations exist: list up to 5 entries as `[{check_run_name}] path:start_line title` and provide counts by level.
- If logs were required: cite the likely failing job(s) and the first error(s) with line references.

## Common Challenges & Remedies

- Zero annotations but run failed
  - Cause: Many linters write `##[error]` to logs without creating Checks annotations.
  - Remedy: Use Step 3 to pull job logs and search for `##[error]` or tool keywords (e.g., `yamllint`).

- Temp path prefixes in log entries
  - Cause: CI harness or test wrappers execute under ephemeral directories (e.g., `.pytest_tmp/cwdN`).
  - Remedy: Normalize paths using the commands above; the remainder after the prefix is the repository-relative path.

- Tool call timeouts in agent environments
  - Symptom: A helper times out but still writes the JSON (e.g., `command timed out …` followed by `Wrote annotations JSON`).
  - Remedy: Read the output file (`artifacts/gh-run-annotations.json`) and continue. If needed, rerun the script with `-Quiet -Json` to reduce console chatter, then inspect the file.

- Private repo access or missing token
  - Symptom: 404/403 from the GitHub API or `gh` CLI.
  - Remedy: Ensure `gh auth login` or export `GITHUB_TOKEN`/`GH_TOKEN` with `actions:read`, `checks:read`, and `contents:read` scopes.

## Known Patterns — YAML Lint

- Symptoms in logs
  - Group header shows a temp-prefixed repo path, for example:
    - `##[group]./.pytest_tmp/cwd6/docs/knowledge/edition-map.yml`
  - Followed by yamllint errors such as:
    - `##[error]2:5 [indentation] wrong indentation: expected 2 but found 4`
  - Similar messages may appear for other files (e.g., `docs/templates/RTM-yaml-template.yaml`).

- Mapping paths
  - Drop the `.pytest_tmp/cwdN/` prefix to get the repository-relative file path.
  - See “Path normalization” above for quick commands to rewrite logs.

- Local reproduction
  - Ensure Python + yamllint are available (e.g., `pipx run yamllint --version`).
  - Run against docs to confirm:
    - `pipx run yamllint -d .yamllint docs/`

  If `pipx` is not installed (common on fresh Windows/macOS machines), use Python’s pip fallback:
  - Install once in the current environment:
    - PowerShell / Windows: `python -m pip install --upgrade pip; python -m pip install yamllint`
    - POSIX shells: `python3 -m pip install --user --upgrade pip; python3 -m pip install --user yamllint`
  - Run with pip fallback:
    - PowerShell / Windows: `python -m yamllint -c .yamllint docs/`
    - POSIX shells: `python3 -m yamllint -c .yamllint docs/`

  Notes:
  - Prefer `pipx` when available to avoid polluting your base interpreter; the `pip` fallback is fine for quick local checks.
  - If your shell cannot decode this file due to special characters (e.g., `→`, `✗`), ensure UTF‑8 encoding when editing or piping content.

- Typical fix
  - Align indentation to match the yamllint configuration (commonly 2 spaces per level).
  - Re-run the linter locally before pushing a fix.

## Agent Tips — Editing Docs in pwsh

- UTF‑8 encoding
  - When scripting edits with Python on Windows, read/write with `encoding='utf-8'` to avoid `UnicodeDecodeError` for characters like `→` or `✗`.

- Quoting/escaping
  - Prefer using small Python scripts for multi-line, regex-like replacements instead of complex PowerShell escaping.
  - When you must use PowerShell, favor here-strings (`@'…'@` / `@"…"@`) and double-up backticks inside code spans.

## Response Templates

Success (annotations found)

```
Run Review
- Workflow "{workflow_name}" (run id {run_id}, SHA {head_sha}) → {conclusion}
- Check runs: {total_check_runs} | Annotations: {total_annotations}
- Sample:
  [{check_run_name}] {path}:{start_line} {title}
  ... (limit 5)
- Levels: {errors} errors, {warnings} warnings, {notes} notes
```

Failure with 0 annotations (suggest logs)

```
Run Review
- Workflow "{workflow_name}" (run id {run_id}, SHA {head_sha}) → failure
- Tooling reports {total_check_runs} check runs but 0 annotations.
- Please share job logs to triage root cause:
  gh run view {run_id} --repo LabVIEW-Community-CI-CD/x-cli --log > artifacts/run-logs.txt
```

No repository access (private repo / missing token)

```
I can’t access the run’s annotations due to repository permissions. Please provide one of:

- Annotations JSON (preferred):
  pwsh -File scripts/ghops/tools/get-run-annotations.ps1 -Repo LabVIEW-Community-CI-CD/x-cli -RunId 18076116588 -Out artifacts/gh-run-annotations.json -Json

- Or job logs:
  gh run view 18076116588 --repo LabVIEW-Community-CI-CD/x-cli --log > artifacts/run-logs.txt

If gh isn’t configured, set a token with read scopes:
  $env:GITHUB_TOKEN='<token-with-actions:read,checks:read>'
```

## Agent message template (no access)

When you can’t access a run (private repo or missing token), use this concise request to get what you need quickly:

```
I can’t access the run’s annotations due to repository permissions. Could you share one of the following so I can triage immediately?

- Annotations JSON (preferred):
  pwsh -File scripts/ghops/tools/get-run-annotations.ps1 -Repo LabVIEW-Community-CI-CD/x-cli -RunId 18076116588 -Out artifacts/gh-run-annotations.json -Json

- Or job logs:
  gh run view 18076116588 --repo LabVIEW-Community-CI-CD/x-cli --log > artifacts/run-logs.txt

If you don’t have gh configured, set a token with read scopes:
  $env:GITHUB_TOKEN='<token-with-actions:read,checks:read>'

Then rerun the annotations command above and attach the JSON/logs here.

## Automatic Artifact Per Run (optional)

To attach `gh-run-annotations.json` as an artifact automatically for each workflow run:

- Enable with a repository variable:
  - Settings → Secrets and variables → Actions → Variables → add `UPLOAD_RUN_ANNOTATIONS=1` (or `true`).
- A dedicated workflow (`.github/workflows/run-annotations.yml`) listens for all completed runs and uploads the artifact named `gh-run-annotations-<run_id>`.
- Permissions are scoped to read: `actions`, `checks`, and `contents`.
- The collector workflow skips itself to avoid loops.
```
