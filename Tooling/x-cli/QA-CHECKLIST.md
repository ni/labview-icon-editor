# QA Checklist

Use `scripts/qa.sh` (or `scripts/qa.ps1` on Windows) to run all steps automatically.
Each step logs start/end times with millisecond precision and emits a summary table.
Command output streams live to the console and is also written to
`artifacts/logs/<step>.log` for later inspection. Review these timings to detect
regressions or unusually slow commands; large changes may indicate performance
issues or misconfiguration. Pass a file path to `qa.sh` to also write the table to
disk.

For tests that manipulate shared files, pass `--no-parallel` to run sequentially.
The script also writes a minimal `.codex/telemetry.json` when none exists so
telemetry checks can validate the required `agent_feedback` block during local
runs.

## Normative steps
These steps are required for every change. Running `pre-commit run` automatically executes the telemetry agent-feedback check.

- [ ] `git status --short` (verify no unstaged changes)
- [ ] `./scripts/setup-venv.sh` (create virtual environment and install Python dependencies)
- [ ] `./scripts/install-dotnet.sh` (installs .NET SDK if missing)
- [ ] `python scripts/check_agent_feedback_block.py PR_DESCRIPTION.md`
- [ ] Agent Checklist included
- [ ] AGENTS digest lines present & valid
- [ ] `python scripts/check-commit-msg.py .git/COMMIT_EDITMSG`
- [ ] `pre-commit run --files <changed-files>`
- [ ] `python scripts/generate-traceability.py`
- [ ] `python scripts/scan_srs_refs.py`
- [ ] `python scripts/update-agents.py` (only when the commit template or AGENTS snippets change)
- [ ] `dotnet build XCli.sln -c Release`
- [ ] `python -m pytest tests -vv --timeout=300 --durations=20 --maxfail=1`
- [ ] `dotnet test XCli.sln -c Release --blame-hang --blame-hang-timeout 5m`
- [ ] `./scripts/build.sh`
- [ ] Smoke run `--help`

Stage 1 requires a clean worktree before opening a PR. `scripts/qa.sh` does not run
`git status --short`; execute this command manually and ensure the output is empty.

## Advisory steps (optional extras)
These checks are recommended but not required.

- [ ] `dotnet build XCli.sln -c Debug`
- [ ] FGC-REQ-SIM-004: duration reflects configured delay
