# Native Windows rebuild scenarios

Stage 2 cross-publishes the CLI for `win-x64` and attempts a Wine smoke test. If this
`win_x64_smoke` check fails, Stage 3 shall rebuild the binary natively on Windows.

Native rebuilds are typically required when:

- The Wine smoke test fails (`win_x64_smoke` = `failure`).
- Changes rely on Windows-only APIs such as the registry or file system semantics
  that Wine cannot emulate accurately.
- Platform-specific dependencies or P/Invoke components need verification against
  real Windows libraries.
- Diagnosing behavior that only reproduces on Windows environments.

Recording the smoke result in `telemetry/summary.json` helps Stage 3 decide when a
native rebuild is necessary.
