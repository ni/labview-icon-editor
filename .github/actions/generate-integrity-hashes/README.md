# Generate Integrity Hashes Action

This composite action generates SHA256 checksums for release artifacts in a deterministic, verifiable format.

## Features

- Generates SHA256 checksums for all files in artifact directories
- Supports mapping local directory names to artifact names for path translation
- Produces sorted output for reproducibility
- Compatible with `sha256sum -c` verification

## Usage

```yaml
- name: Generate integrity hashes
  uses: ./.github/actions/generate-integrity-hashes
  with:
    artifacts_path: artifacts
    output_path: artifacts/integrity-hashes
    artifact_mappings: '{"sd": "repo-labview-icon-api", "tooling": "repo-tooling-distribution"}'
```

## Inputs

| Input | Required | Default | Description |
|-------|----------|---------|-------------|
| `artifacts_path` | Yes | - | Root path containing artifacts to checksum |
| `output_path` | No | `integrity-hashes` | Path where the checksum file will be written |
| `output_filename` | No | `artifacts.sha256` | Name of the checksum file |
| `artifact_mappings` | No | `{}` | JSON object mapping local directory names to artifact names |

## Outputs

| Output | Description |
|--------|-------------|
| `checksum_file` | Full path to the generated checksum file |
| `checksum_count` | Number of files checksummed |

## Artifact Mappings

The `artifact_mappings` input allows you to translate local directory names to actual artifact names. This is useful when:

- You download artifacts to local directories with different names
- The verification step expects paths matching the artifact names

Example:
```json
{
  "sd": "my-repo-source-distribution",
  "tooling": "my-repo-tooling-distribution"
}
```

This maps files in `artifacts/sd/file.zip` to checksums with paths `../my-repo-source-distribution/file.zip`.

## Verification

The generated checksum file is compatible with `sha256sum -c`:

```bash
cd artifacts/integrity-hashes
sha256sum -c artifacts.sha256
```
