This PR adds CI-related files that were present in older PRs but missing in current develop:

- scripts/* tools/* configs (no docs)
- workflows added only if the file did not already exist locally (no overwrites)

Intent: preserve useful CI helpers without reintroducing stale workflow logic. If any additional files should be included/excluded, comment and I will adjust.
---

### Reviewer Guide — Markdown Templates Analytics
- Preview artifacts: `md-templates-suggestions-rolling-preview`, `md-templates-suggestions-preview`
- Sessions artifacts: `md-templates-suggestions-rolling`, `md-templates-suggestions`
- Job Summary: look for “Rolling window entries: X” and “Rolling Suggestions (last N cycles)”
- History (gh-pages): [blob](https://github.com/LabVIEW-Community-CI-CD/x-cli/blob/gh-pages/telemetry/templates/suggestions.jsonl) · [raw](https://raw.githubusercontent.com/LabVIEW-Community-CI-CD/x-cli/gh-pages/telemetry/templates/suggestions.jsonl)
- Tuning: `MD_TEMPLATES_CYCLE_WINDOW` (default 8), `MD_TEMPLATES_SUGGEST_MINCOUNT` (default 2), `MD_TEMPLATES_INCLUDE_SNIPPETS` (0/1), `MD_TEMPLATES_HISTORY_PUBLISH` (1)
