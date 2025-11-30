# Requirements Traceability Matrix (RTM) — One‑Pager

> Cite via edition map (no quotes): 29148.RTM/Traceability · 29119_2.Test_Monitoring_Control/Exit_Criteria · 15289.Information_Items

**Source of truth**: `docs/traceability.yaml` (used by CI `Traceability Gate`).
This page presents a readable snapshot; keep the YAML updated.

| Req ID           | Source (path#anchor)          | Verification (T/A/I/D) | Tests (glob)          | Code (glob)      | Status |
| ---------------- | ----------------------------- | ---------------------: | --------------------- | ---------------- | :----: |
| FGC-REQ-CLI-001  | docs/srs/core.md#cli-basics   |                      T | tests/XCli.Tests/\*\* | src/XCli/\*\*    |   ⬜   |
| FGC-REQ-GUID-002 | docs/srs/core.md#guidance     |                    T/A | tests/py\_\*/\*\*     | codex_rules/\*\* |   ⬜   |
| FGC-REQ-LOG-003  | docs/srs/core.md#json-logging |                    T/I | tests/\*_/Logging_    | src/\*_/Logging_ |   ⬜   |

**Legend** — Verification: **T**est · **A**nalysis · **I**nspection · **D**emonstration.
**Status**: ⬜ Open · ✅ Verified · ⚠️ Partial · ❌ Failed.

_Minimal use_: keep 1 row per requirement that matters for this release; link anchors where possible.
