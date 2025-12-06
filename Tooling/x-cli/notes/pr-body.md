{ "author": "codex-agent", "mode": "codex", "change_type": "impl", "srs_ids": ["FGC-REQ-SPEC-001"] }

AGENTS.md digest: SHA256 acee2e960458c7a65c2fc003e5f8bc7e0921fae692c1e54119122db9f54cf585

### Agent Checklist
- [ ] **SRS IDs** in this PR match scope (see `docs/srs/core.md §6.5`): `<FGC-REQ-...>`
- [ ] **Citations**: summary references use `F:path†Lstart-Lend`, `<chunk_id>†Lstart-Lend`
- [ ] **CLI**: help/version/unknown preserved or updated in SRS/tests
- [ ] **Simulation**: default success & configurable failure (env/JSON, precedence) covered by tests
- [ ] **Logging**: JSONL keys & stderr routing preserved; file append concurrency‑safe
- [ ] **Safety**: no `System.Net*`; no `Process.Start`; only `Env.cs` touches environment
- [ ] **Performance**: typical run < 2s; no default artificial delay
- [ ] **Distribution/CI**: single‑file artifacts for linux‑x64 & win‑x64; smoke `--help`
- [ ] **Traceability**: tests updated; SRS §6.5 matrix remains accurate

### Summary
- Capture existing AGENTS.md contract in ADR 0001.
- Snapshot current AGENTS.md.
- Add human quickstart at docs/agents-contract.md.
- Next steps:
  - A0: document current contract (this PR).
  - P2: implement digest check in CI.
  - P3: enforce Agent Checklist presence.
  - P4: generate Preventative Measures from codex_rules.
  - P5: lint commit messages for template compliance.
  - P6: surface violations in developer tooling.
  - P7: auto‑populate PR templates with required blocks.
