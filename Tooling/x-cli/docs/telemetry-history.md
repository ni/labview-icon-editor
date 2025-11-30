# Telemetry History

Telemetry summaries from CI runs are stored on the repository's **GitHub Pages** branch (`gh-pages`).
Each run appends its `telemetry/summary.json` and computed diff files to the `history/` folder on that branch.

## Retention
- Keep history for the most recent **90 days**.
- Older `summary-*.json` and `diff-*.json` files are pruned during upload.

## Access
- Pages content is publicly readable at `<repo-url>/history/`.
- Writes require a `GITHUB_TOKEN` with `contents: write` scope and are performed by CI.
- Only maintainers with branch permissions can modify or remove history.

## Privacy
- Telemetry files contain aggregate build and test statistics; they do not include personal data or secrets.
- Because the history is published via GitHub Pages, anyone can view the data.
- Avoid adding sensitive information to telemetry outputs.
