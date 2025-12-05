# OrchestrationCompatCli Parity Matrix (ORCH-030)

Record of compatibility tests between `OrchestrationCompatCli` (shim) and `OrchestrationCli`. Mark each row as you execute the smoke test; capture log paths for evidence.

| Subcommand              | CompatCli exit | OrchestrationCli exit | Log/Evidence                                                | Status   |
|-------------------------|----------------|-----------------------|-------------------------------------------------------------|----------|
| devmode-bind            |                |                       |                                                             | Not run |
| devmode-unbind          |                |                       |                                                             | Not run |
| labview-close           |                |                       |                                                             | Not run |
| apply-deps              |                |                       |                                                             | Not run |
| restore-sources         |                |                       |                                                             | Not run |
| vi-analyzer             |                |                       |                                                             | Not run |
| vi-compare              |                |                       |                                                             | Not run |
| vi-compare-preflight    |                |                       |                                                             | Not run |
| missing-check           |                |                       |                                                             | Not run |
| unit-tests              |                |                       |                                                             | Not run |
| vipm-verify             |                |                       |                                                             | Not run |
| vipm-install            |                |                       |                                                             | Not run |
| package-build           |                |                       |                                                             | Not run |
| local-sd                |                |                       |                                                             | Not run |
| sd-ppl-lvcli            |                |                       |                                                             | Not run |
| source-dist-verify      |                |                       |                                                             | Not run |
| ollama                  |                |                       |                                                             | Not run |

Usage (example):
- Compat: `pwsh -NoProfile -Command "& { ./scripts/common/invoke-repo-cli.ps1 -CliName OrchestrationCompatCli -RepoRoot . -Args @('<subcommand>', ... ) }"`
- Reference: `pwsh -NoProfile -Command "& { ./scripts/common/invoke-repo-cli.ps1 -CliName OrchestrationCli -RepoRoot . -Args @('<subcommand>', ... ) }"`

Evidence: attach log paths (e.g., `reports/logs/...`), exit codes, and note any discrepancies.
