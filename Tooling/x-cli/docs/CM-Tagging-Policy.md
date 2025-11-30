# CM Tagging Policy (Semver + Coverage Gate)
- **Baseline**: `vX.Y.Z` tag is the configuration baseline for each release.
- **PR policy**: PRs must pass **`coverage`** required check (merged Cobertura + thresholds).
- **Release gate**: Tag push triggers coverage re-run; **release aborts on breach**.
- **Status accounting**: GitHub Release attaches binaries + coverage-html.zip + coverage.xml and references CI run ID.
