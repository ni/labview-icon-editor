# Labels Governance

This repository standardizes a small set of labels used by CI, docs, and
maintainers to coordinate work. Keep label names lowercase and prefer
`area:*`, `type:*`, `status:*`, and purpose‑specific labels.

## Coverage Labels

- `coverage:conservative` — PRs participating in the Python coverage re‑enablement
  with conservative thresholds while scripts/lib tests mature.
- `coverage:raise-iteratively` — PRs that deliberately raise coverage floors and
  add tests to close gaps.

Notes
- Scope per‑file floors to critical `scripts/lib/*` modules to encourage
  incremental adoption.
- See milestone: `docs/issues/milestone-restore-python-coverage.md` for the
  rollout plan and acceptance criteria.

### Suggested Colors & Descriptions

If you keep a central `labels.json`, add entries similar to:

```json
[
  {
    "name": "coverage:conservative",
    "color": "fbca04",
    "description": "Re-enable Python coverage with conservative floors while scripts/lib tests mature"
  },
  {
    "name": "coverage:raise-iteratively",
    "color": "0e8a16",
    "description": "Incrementally raise coverage thresholds alongside added tests for scripts/lib"
  }
]
```

## Adding Labels

If you maintain a central `labels.json` across repos, add these entries under a
Coverage section with colors and descriptions aligned to this document. For this
repo, you can use `scripts/sync_labels.py` (requires a PAT) to create missing
labels consistently.

Example (using a PAT and targeting this repo):

POSIX bash
```
export GITHUB_TOKEN="$GH_ORG_TOKEN"
export GITHUB_REPOSITORY="LabVIEW-Community-CI-CD/x-cli"
python scripts/sync_labels.py --file docs/labels.json
```

PowerShell
```
$Env:GITHUB_TOKEN = $Env:GH_ORG_TOKEN
$Env:GITHUB_REPOSITORY = 'LabVIEW-Community-CI-CD/x-cli'
python scripts/sync_labels.py --file docs/labels.json
```

Where `docs/labels.json` contains the JSON shown above under “Suggested Colors & Descriptions”.

## Process Labels

Operational labels that influence CI behavior.

- `ci:pre-commit` — Triggers the Pre-Commit workflow on pull requests. Without this
  label, the workflow runs only when manually dispatched, keeping CI noise low. Use
  this label when you want a full CI‑side lint pass in addition to local pre‑commit.

Suggested JSON entry:

```json
{
  "name": "ci:pre-commit",
  "color": "1f6feb",
  "description": "Trigger the Pre-Commit workflow on this PR"
}
```
