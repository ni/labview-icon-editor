# R1 — What changed (ISO/IEC/IEEE 29148 alignment)

- Migrated SRS pages to the 29148 template: **Statement(s)** with atomic **shall** and numbered **RQn**, **Verification** with numbered **ACn**, and **Attributes** (Priority/Owner/Source/Status/Trace [+ optional risk]).
- Added strict linter (language hygiene, atomicity, section presence, attribute enums).
- Added set‑level checks (index, consistency), VCRM generator, and **Verified→Evidence** guard.
- Introduced **R1 baseline snapshot** (`docs/baselines/R1`) with SHA‑256 manifest.
- Kept release gate to publish a “29148 Compliant Release” automatically when **100%** compliance is achieved.

