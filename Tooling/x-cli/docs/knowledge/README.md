# Knowledge Pack (Scaffolding)

Purpose: Host your policy/process references, crosswalks, templates, and glossaries.
This pack avoids quoting standards; you fill clause IDs in `edition-map.yml`.

## What to drop in (you)

-   **Policy & Process manuals** with clause citations (your licensed content).
-   **Edition clause numbers** in `edition-map.yml` (per standard + edition).
-   Any org glossaries, style guides, and checklists.

## What’s included (open content)

-   Crosswalk (`crosswalk-open.csv`) mapping 12207 ⇄ 29148 ⇄ 15289 ⇄ 828/10007/EIA‑649C (labels; no quotes).
-   Templates (`../templates/*`) for SRS, SCMP (CM Plan), Test Plan/Strategy; placeholders reference standards.
-   Glossary (`../glossary/terms.md`) with synonym hints (e.g., SCMP ≈ CM Plan).
-   Clause resolver map (`edition-map.yml`) you complete with actual clause numbers.

## How to cite

- Cite **Standard + clause ID** using `edition-map.yml` (no long quotes). Example:
  - “ISO/IEC/IEEE 12207 — Verification (see edition map: `12207.Verification`)”
- If a clause ID is missing, cite section name only + “(edition map pending)”.

## Maintenance

-   Update `edition-map.yml` when editions change.
-   Keep templates minimal; link to policies instead of duplicating them.
