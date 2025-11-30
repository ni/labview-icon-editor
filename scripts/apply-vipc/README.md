# Apply VIPC (legacy wrapper)

This wrapper is deprecated; prefer the Orchestration CLI:

```
pwsh -NoProfile -File scripts/common/resolve-repo-cli.ps1 -CliName OrchestrationCli -RepoPath <path> -SourceRepoPath <path> | Out-Null
dotnet run --project Tooling/dotnet/OrchestrationCli/OrchestrationCli.csproj -- apply-deps --repo <path> --bitness <both|64|32> --vipc-path runner_dependencies.vipc
```

The script remains as a thin delegate for existing callers.
