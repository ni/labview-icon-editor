# Legacy Validator Tools

This directory contains scripts that previously supported external validator
workflows (packaging, schema sync, shims, knowledge validation, and CI helpers).
They are archived for historical reference only and are not exercised by the
current x-cli pipeline.

Key items:
- `legacy_validator_pack.ps1` — zipped documentation bundle with manifest.
- `legacy_validator_shim.(ps1|sh)` — legacy wrapper scripts for invoking the
  external validator in CI.
- `legacy_validator_schema_sync.sh` — archived schema sync helper.
- `legacy_validator_kv_local.ps1`, `legacy_validator_cp8_exec.ps1` — legacy CI
  entry points.
- `legacy_knowledge_validator.py` — archived validator used by those scripts.

Because these scripts still contain legacy environment variables and output
markers (e.g., `JARVIS_*`), keep them under archive/ unless reintroducing the
external validator with new tooling and tests.
