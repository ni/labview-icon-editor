# R1 Readiness Audit — vX.Y.Z

**As‑of (UTC):** <YYYY‑MM‑DD HH:MM>  
**Repo:** <org/repo> · **Commit:** <sha7> · **Tag:** vX.Y.Z  
**Scope:** Release‑Readiness Gate (coverage PR gate + semver release) per 12207/29119/10007/15289.

## A) Verdict
Overall: ☐ PASS ☐ FAIL

| Gate | Status | Evidence | Standards |
|---|---|---|---|
| PR coverage gate required | ☐ PASS ☐ FAIL | PR run link; `coverage.xml`, `coverage-html.zip` | 29119‑2/‑3 |
| Release coverage & artifacts | ☐ PASS ☐ FAIL | Tag run link; Release assets include binaries + `coverage-html.zip` + `coverage.xml` | 12207, 10007 |
| Docs present (Strategy/Report/CM) | ☐ PASS ☐ FAIL | paths under `docs/compliance/*` | 15289 |

## B) Evidence links/paths
- PR run: <url> (artifact names: `coverage-xml-and-html`)
- Tag run: <url> (artifact names: `release-contents`)
- Release page: <url>
- Thresholds config: `docs/compliance/coverage-thresholds.json`

## C) Notes & follow-ups
- <list any exceptions or next steps>
