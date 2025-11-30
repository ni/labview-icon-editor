# Markdown Templates

This folder collects reusable Markdown templates and examples to streamline doc updates across agents.

- Use `scripts/md_emit.py` to render a `.tpl.md` file with a small JSON/YAML context.
- Unknown placeholders are left as-is, so you can iteratively refine templates as needs evolve.

Quick start
- Example render:
  - POSIX: `python3 scripts/md_emit.py --template docs/templates/markdown/examples/repo-guidelines.tpl.md --context docs/templates/markdown/examples/repo-guidelines.context.json --out docs/templates/markdown/examples/repo-guidelines.example.md`
  - Windows: `py scripts\md_emit.py --template docs\templates\markdown\examples\repo-guidelines.tpl.md --context docs\templates\markdown\examples\repo-guidelines.context.json --out docs\templates\markdown\examples\repo-guidelines.example.md`

Conventions
- Template placeholders use `{{PLACEHOLDER}}` syntax.
- Keep templates short and specific. Prefer concrete commands and repo paths.
- Add an example output next to each template to help reviewers visualize the result without running the tool.

Contexts
- Central reusable contexts live under `docs/templates/markdown/contexts/` (e.g., `default.json`).
- Templates may provide a sibling `*.context.json|yaml|yml`; the renderer will prefer sibling contexts first, then fall back to `contexts/default.json`.

CI Preview (non-blocking)
- Workflow `Markdown Templates Preview` renders all `*.tpl.md` on PRs and uploads `*.example.md` as artifacts for quick review.
- Rendering failures do not block merges; fixups can be applied in follow-ups.

Badges
- Preview: [Markdown Templates Preview](../../../.github/workflows/md-templates.yml)
- Sessions: [Markdown Templates Sessions](../../../.github/workflows/md-templates-sessions.yml)
- Tune summary with repo variables:
  - `MD_TEMPLATES_TOPN` (default 10)
  - `MD_TEMPLATES_MINCOUNT` (default 1)
- Job summaries print “Effective thresholds: TopN, MinCount” using these values.

Analytics
- The renderer writes a per-template meta JSON (e.g., `name.meta.json`) containing `placeholdersUsed` and `placeholdersMissing`.
- The sessions workflow aggregates manifests into a single `sessions-manifest.json` and validates it against `docs/schemas/v1/md.templates.sessions.v1.schema.json` (non‑blocking).
- Job Summaries include per-domain counts and, when available, a Top placeholders table to guide codifying common keys into `contexts/default.json`.

Snippets
- Common blocks (non-blocking helpers) live under `docs/templates/markdown/snippets/`.
- Example: `snippets/cross-agent-reflection.tpl.md` — a minimal scaffold for the PR “Cross-Agent Session Reflection” section.

History & Suggestions (optional)
- Set repo variables to enable history and rolling suggestions on gh-pages:
  - `MD_TEMPLATES_HISTORY_PUBLISH=1` to append suggestions to `gh-pages/telemetry/templates/suggestions.jsonl`.
  - `MD_TEMPLATES_CYCLE_WINDOW=8` number of cycles to aggregate for rolling suggestions.
  - `MD_TEMPLATES_SUGGEST_MINCOUNT=2` minimum count to include in suggestions.
  - `MD_TEMPLATES_INCLUDE_SNIPPETS=0|1` whether snippet templates participate in counts.
- Preview artifacts: `md-templates-suggestions-preview`, `md-templates-suggestions-rolling-preview`.
- Sessions artifacts: `md-templates-suggestions`, `md-templates-suggestions-rolling`.
