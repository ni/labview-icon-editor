Reviewer note — Markdown Templates analytics

- New artifacts (Preview): md-templates-suggestions-rolling-preview (rolling suggestions), md-templates-suggestions-preview (per-run)
- New artifacts (Sessions): md-templates-suggestions-rolling, md-templates-suggestions
- Job Summary sections to look for:
  - “- Rolling window entries: X” (history window size actually used)
  - “Rolling Suggestions (last N cycles)” (top placeholders not in defaults)
- History (gh-pages):
  - blob: https://github.com/LabVIEW-Community-CI-CD/x-cli/blob/gh-pages/telemetry/templates/suggestions.jsonl
  - raw:  https://raw.githubusercontent.com/LabVIEW-Community-CI-CD/x-cli/gh-pages/telemetry/templates/suggestions.jsonl
- Tuning (repo variables):
  - MD_TEMPLATES_CYCLE_WINDOW (default 8), MD_TEMPLATES_SUGGEST_MINCOUNT (default 2)
  - MD_TEMPLATES_INCLUDE_SNIPPETS=1 to include snippets group in counts (default excluded)
  - MD_TEMPLATES_HISTORY_PUBLISH=1 enables gh-pages append

Tip: Open the latest “Markdown Templates Preview” run and download the rolling artifact; the Job Summary also shows a quick list inline when suggestions exist.
