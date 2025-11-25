# Ephemeral PowerShell Script Signing (Design)

Enable a single-pass, per-machine/job signing of all repository PowerShell scripts using a throwaway self-signed code-signing certificate. This is meant for developers or CI jobs that explicitly choose to trust the certificate on their own machine; it is not intended to impersonate a real publisher or provide cross-machine trust.

## Intent and scope
- Provide a helper that creates an ephemeral code-signing cert, trusts it for the current user (optional), signs all repo scripts in one pass, emits a manifest, and optionally cleans up the cert.
- Fit both local developer runs and GitHub Actions jobs that require `AllSigned` or want signatures on packaged artifacts.
- Minimize blast radius: default to user cert stores, avoid long-lived secrets, and make cleanup easy.

## Goals and non-goals
- Goals: single certificate per invocation/job; configurable trust (TrustedPublisher optional); default timestamping; JSON manifest of signed files; guardrails for excludes; idempotent signing (skip or re-sign already-signed files based on thumbprint).
- Non-goals: real identity/code-signing PKI, cross-job/machine reuse, or altering execution policy enforcement. `TrustedRoot` import stays opt-in and discouraged.

## Proposed assets
- `scripts/sign-pwsh-scripts.ps1`
  - Creates an ephemeral code-signing cert (`New-SelfSignedCertificate -Type CodeSigningCert -Subject "CN=$($env:USERNAME) Ephemeral Icon Editor" -CertStoreLocation Cert:\CurrentUser\My`).
  - Optionally exports `.cer` to `%TEMP%`, imports to `Cert:\CurrentUser\TrustedPublisher` (and optionally `...Root` if requested).
  - Discovers target files and signs them with one cert and timestamp server.
  - Emits a manifest (default `reports/script-signing.json`) and returns thumbprint and counts.
  - Optional cleanup removes the cert from `My`, `TrustedPublisher`, `Root` (if added), and deletes the exported `.cer`.
- `scripts/sign-pwsh-scripts` (composite)
  - Thin wrapper around the script for CI.
  - Inputs: `repository_path` (default `${{ github.workspace }}`), `trust_publisher` (bool), `trust_root` (bool, default false), `timestamp_server` (default `http://timestamp.digicert.com`), `include`/`exclude` globs, `manifest_path`, `cleanup`, `what_if`.
  - Outputs: `cert_thumbprint`, `manifest_path`, `signed_count`, `cert_subject`.

## Signing flow (single pass)
1) Create cert and export `.cer` to `%TEMP%\ephemeral-pwsh-signing.cer`.  
2) Optional trust: import to `CurrentUser\TrustedPublisher` (default off), `CurrentUser\Root` only when explicitly requested.  
3) Discover files under `repository_path` with includes `*.ps1,*.psm1,*.psd1`; default excludes: `.git/**`, `artifacts/**`, `builds/**`, `builds-isolated/**`, `reports/**`, `Tooling/docker/**`. Excludes are configurable.  
4) Sign each discovered file via `Set-AuthenticodeSignature -Certificate $cert -IncludeChain NotRoot -TimestampServer <server> -HashAlgorithm SHA256`.  
   - If already signed by the same thumbprint, skip; otherwise re-sign by default with a `-SkipResign` switch available.  
5) Emit manifest JSON with: subject, thumbprint, validity, timestamp server, trust flags, counts, and per-file results.  
6) Optional cleanup removes cert(s) and temp files; manifest remains for auditing.

## Usage examples
### Local (developer)
```pwsh
pwsh ./scripts/sign-pwsh-scripts.ps1 `
  -RepositoryPath "$PWD" `
  -TrustPublisher `
  -TimestampServer 'http://timestamp.digicert.com' `
  -ManifestPath 'reports/script-signing.json' `
  -Cleanup
```
- Use `-WhatIf` to dry-run discovery/signing.  
- Omit `-TrustPublisher` if you only care about signed artifacts, not execution under `AllSigned`.  
- Avoid `-TrustRoot` unless you fully understand the risk.

### GitHub Actions (per job that needs it)
```yaml
- name: Ephemeral sign PowerShell scripts
  uses: ./scripts/sign-pwsh-scripts
  with:
    repository_path: ${{ github.workspace }}
    trust_publisher: true        # required if the job enforces AllSigned
    cleanup: true                # remove the cert after signing
    manifest_path: reports/script-signing.json
```
- Each job is isolated; run this early in any Windows job that executes PowerShell with `AllSigned` or needs signed artifacts.  
- Jobs that only build/package can set `trust_publisher: false` and still sign files.

## Security, trust, and observability
- Trust is local to the user profile on that runner; other machines/users will not trust the cert.  
- Default to `TrustedPublisher` only; `TrustedRoot` should stay off unless a job explicitly opts in.  
- Timestamping keeps signatures valid on the same machine after the cert expires but does not confer trust elsewhere.  
- Manifest plus console summary provide traceability (files signed/skipped, thumbprint). Expose `manifest_path` as an artifact if useful for auditing.

## Open items before implementation
- Decide default behavior for already-signed files: skip vs. re-sign (proposal: skip when the thumbprint matches, re-sign otherwise).  
- Confirm exclude list is correct for this repo (e.g., whether to sign under `Tooling/` or `Test/`).  
- Validate the timestamp server to use (current proposal: `http://timestamp.digicert.com`).  
- Choose failure policy: fail fast on any signing error vs. warn and continue; proposal is fail when cert creation/trust fails, warn on individual file failures but surface a non-zero exit if any files fail to sign.

