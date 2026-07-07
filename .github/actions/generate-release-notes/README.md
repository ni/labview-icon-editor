# Generate Release Notes

This composite action creates a Markdown file summarizing commits since the last tag.
The resulting file can be injected into the VI Package build process.

## Inputs

- `output_path` (optional): Path for the generated release notes file relative to the repository root. Defaults to `Tooling/deployment/release_notes.md`.

## Example Usage

```yaml
- name: Generate release notes
  uses: ./.github/actions/generate-release-notes
  with:
    output_path: Tooling/deployment/release_notes.md
```
