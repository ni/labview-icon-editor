# Runner CLI Linux Docker

This image is intended for **runner-cli/pylavi/tooling** checks on Linux. It does **not** include LabVIEW or g-cli.

## Build
```bash
docker build -t lvie-runner-cli:ci -f Tooling/docker/runner-cli/Dockerfile Tooling/docker/runner-cli
```

## Run (example)
```bash
docker run --rm -v "$PWD:/repo" -w /repo lvie-runner-cli:ci bash -lc "
  dotnet test Tooling/runner-cli/RunnerCli.Tests/RunnerCli.Tests.csproj -c Release &&
  dotnet run --project Tooling/runner-cli/RunnerCli/RunnerCli.csproj --configuration Release -- version-gate --repo-root /repo --json &&
  dotnet run --project Tooling/runner-cli/RunnerCli/RunnerCli.csproj --configuration Release -- pylavi scan --repo-root /repo --config Tooling/pylavi/vi-validate.yml --report-only --offenders-path /tmp/pylavi-offenders.json --log-path /tmp/vi_validate.log &&
  dotnet run --project Tooling/runner-cli/RunnerCli/RunnerCli.csproj --configuration Release -- pylavi summarize --path /tmp/pylavi-offenders.json --json --output-path /tmp/pylavi-summary.json
"
```
