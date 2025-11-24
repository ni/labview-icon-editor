# Editor Position Test Model (§8.2) Test Case Specification (§8.3)

- Model ID: `TM-EDITORPOS-001`
- Model source: `docs/testing/models/editor-position-model.md`
- Related requirements: UT-002 (Medium), NF-002 (Medium)
- Test assets: `Test/Unit Tests/Editor Position/Position Out of Bounds Test.vi`, `Test/Unit Tests/Editor Position/Test Window Position.vi`
- Procedures: `docs/testing/procedures/editor-position-procedure.md`

## Coverage Items
| ID | Description |
| --- | --- |
| P1 | Positive X/Y within current work area; width/height within monitor | Persist and restore exact coordinates. |
| P2 | X or Y < 0 | Clamp to minimum visible origin (e.g., 0,0) before saving/restoring. |
| P3 | Width/height > monitor bounds | Clamp dimensions to fit available work area; preserve aspect if enforced. |
| P4 | Positions leaving <=1 px on any edge | Snap/clamp fully onto screen without drifting across sessions. |
| P5 | INI section absent, NaN, non-numeric strings | Fall back to default safe position/size and rewrite clean values. |
| P6 | Restore with reduced resolution or monitor count | Recompute safe position inside active work area; avoid off-screen placement. |
| P7 | Save, close, reopen with unchanged environment | Round-trips without drift; last saved position is respected. |

## Test Cases
| Case ID | Requirement | Priority | Test Path | Procedure | Coverage Items |
| --- | --- | --- | --- | --- | --- |
| UT-002-TC1 | UT-002 | Medium | `Test/Unit Tests/Editor Position/Test Window Position.vi` | `docs/testing/procedures/editor-position-procedure.md` | P1, P2, P3, P4, P5, P6, P7 |
| NF-002-TC1 | NF-002 | Medium | `Test/Unit Tests/Editor Position/Position Out of Bounds Test.vi` | `docs/testing/procedures/editor-position-procedure.md` | P1, P2, P3, P4, P5, P6, P7 |