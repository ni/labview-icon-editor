# Stream output helpers

To avoid buffered console logs during CI runs, the project provides
scripts for line‑buffered streaming of both stdout and stderr.

- **Bash:** `scripts/stream-output.sh`
- **PowerShell:** `scripts/stream-output.ps1`

## PowerShell usage

On Windows, wrap long‑running commands with the PowerShell helper so
output appears in real time:

```
pwsh -File .\scripts\stream-output.ps1 -Command dotnet -Args @('build', 'XCli.sln', '-c', 'Release')
```

Build and QA scripts already use this helper. New automation shall use the
helper to keep CI logs responsive.

The PowerShell implementation uses `ProcessStartInfo.ArgumentList`, so
paths with spaces and complex arguments are forwarded without quoting
issues. This requires PowerShell 7 or later.

The helper disposes the underlying process once execution finishes,
preventing resource leaks.

Windows PowerShell 5.1 lacks `ArgumentList`; use `pwsh` on modern
systems.

