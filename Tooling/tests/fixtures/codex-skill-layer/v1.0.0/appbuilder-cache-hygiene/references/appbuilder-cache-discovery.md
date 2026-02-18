# AppBuilder Cache Discovery Contract

Use deterministic discovery rules before deleting anything:

## Preferred inputs
1. Explicit `-CachePath` values from workflow/job config.
2. LabVIEW version hint (`major.minor` or year) and bitness hint (`32` or `64`).

## Default discovery roots
- `%USERPROFILE%\Documents\LabVIEW Data`
- `%LOCALAPPDATA%\National Instruments`
- `%PROGRAMDATA%\National Instruments`

## Candidate path rule
- Directory path contains `appbuilder` and `cache` tokens (case-insensitive).
- Optional filter by year token (for example `2020`, `2026`) when provided.
- Optional filter by bitness token (`32`, `64`) when path naming includes it.

## Safety
- Only delete directories, never individual system files.
- Log all candidates, removed paths, and failures to JSON.
