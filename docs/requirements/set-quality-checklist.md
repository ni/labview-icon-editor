# Set Quality Checklist (ISO/IEC/IEEE 29148 §5.2.6)

Use this before merge/baseline:

- **Complete** — No missing sections or TBD/TBR items; coverage across lifecycle (trigger → build → release → CLA → tooling → dev-mode).
- **Consistent** — No conflicting rules (e.g., tag suffix vs no-suffix), no duplicate IDs; interfaces align with design constraints.
- **Feasible/Affordable** — Requirements can be implemented and verified with available runners, licenses, and schedule.
- **Comprehensible** — Clear modality (“shall/should/may”), glossary terms defined; no ambiguous words (and/or, as appropriate, etc.).
- **Singular** — One atomic behavior per requirement; multi-verb statements split (e.g., create vs attach vs publish).
- **Verifiable** — Acceptance Criteria measurable (regex/count/timing/hash), method and evidence specified.
- **Traceable** — Upstream/Downstream traces present (SRS/ADR/tests/code), version/change notes updated on edits.

## DevMode Task Evidence

- When running VS Code tasks 06b/06c (unbind and clear-all), keep the transcript logs produced by `scripts/run-devmode-unbind-task.ps1` and `scripts/run-devmode-clear-all-task.ps1` as evidence and reference them in the checklist. Current transcripts:  
  - `reports/logs/devmode-unbind-task-20251128171114.log`  
  - `reports/logs/devmode-clear-all-task-20251128171125.log`
  - The transcripts now highlight the cross-bitness and cross-LabVIEW guard output so reviewers can confirm other LocalHost.LibraryPaths entries stayed untouched.
