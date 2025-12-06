# Requirements Source-of-Truth Migration (CSV -> Structured SrsAPI)

## Decisions (Phase 0)

- Source of truth will be `requirements.yaml` (YAML; JSON allowed), co-located under `docs/requirements/`.
- CSV remains generated for spreadsheet users; it is not edited by hand once YAML lands.
- One schema governs the data: IDs, section, text, type, priority, verification (methods/primary/detail/level), acceptance, trace (up/down), evidence, owner, phase, status, risk, constraints, notes/rationale, version/change notes.
- Validation stack: JSON Schema + SrsAPI lint (ID pattern, normalization, duplicate IDs, required fields, 29148 hygiene where applicable).
- Tooling surface in x-cli: `srs validate`, `srs import-csv`, `srs export-csv`, `srs export-rtm` (optional), `srs export-reqif` (optional, Phase 6).
- CI: dedicated `requirements-validate` job regenerates CSV/RTM, fails on drift or lint errors.
- Governance: YAML is reviewed/owned; generated CSV/RTM are read-only outputs in PRs.

## Phased plan

- **Phase 1**: Add schema (`requirements.schema.json`) and pilot `requirements.yaml` slice (10 entries). Round-trip to CSV.
- **Phase 2**: Implement x-cli commands: validate, import-csv, export-csv, export-rtm (optional).
- **Phase 3**: Add CI job to validate and regenerate CSV/RTM, fail on drift.
- **Phase 4**: Convert full CSV -> YAML; declare YAML canonical; CSV generated.
- **Phase 5**: Retire CSV-only linters; point RequirementsSummarizer to SrsAPI-normalized data.
- **Phase 6 (optional)**: Add ReqIF export for RM tool interoperability.
