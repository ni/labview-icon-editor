# FGC-REQ-DOC-008 - Publish SRS as HTML site and PDF
Version: 1.0

## Statement(s)
- RQ1. The documentation pipeline shall generate a static HTML site for the SRS with one page per requirement and an index page.
- RQ2. The pipeline shall produce a combined PDF of the SRS content from the aggregated HTML.

## Rationale
Publishes the requirements in formats suitable for review, offline access, and audit evidence.

## Verification
Method(s): Demonstration | Inspection
Acceptance Criteria:
- AC1. A job run produces `site/srs-html/` and `site/srs-html.zip` with per‑page HTML and an `index.html`.
- AC2. The run produces `site/srs.pdf` derived from the aggregated `site/srs.html`.

## Attributes
Priority: Low
Owner: DevEx
Source: Documentation policy
Status: Proposed
Trace: `scripts/render_srs_html.py`, `scripts/render_srs_pdf.py`, `.github/workflows/release.yml`
