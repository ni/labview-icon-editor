# Editor Position Test Model (§8.2)

- UID: `TM-EDITORPOS-001`
- Objective: Model window bound validation and persistence so position tests stress coordinate limits, scaling, and recovery paths.
- Priority: Medium (UT-002, NF-002).
- Strategy extract: Functional / Unit tests use boundary-value combinations for INI states with fixtures and golden comparisons for persisted coordinates (`docs/testing/strategy.md`, Test Levels, Types, and Techniques).

## Model

### Equivalence partitions (bounds and persistence)
| Partition | Representative cases | Expected handling / test focus |
| --- | --- | --- |
| P1 In-bounds | Positive X/Y within current work area; width/height within monitor | Persist and restore exact coordinates. |
| P2 Negative origin | X or Y < 0 | Clamp to minimum visible origin (e.g., 0,0) before saving/restoring. |
| P3 Oversized window | Width/height > monitor bounds | Clamp dimensions to fit available work area; preserve aspect if enforced. |
| P4 Edge proximity | Positions leaving <=1 px on any edge | Snap/clamp fully onto screen without drifting across sessions. |
| P5 Missing/corrupt persisted values | INI section absent, NaN, non-numeric strings | Fall back to default safe position/size and rewrite clean values. |
| P6 Resolution/monitor change | Restore with reduced resolution or monitor count | Recompute safe position inside active work area; avoid off-screen placement. |
| P7 Cross-session durability | Save, close, reopen with unchanged environment | Round-trips without drift; last saved position is respected. |

## Traceability to RTM IDs
- UT-002 (Medium) covers partitions P1–P5 to verify persisted coordinates are validated and restored safely.
- NF-002 (Medium) exercises P6–P7 to ensure usability resilience across environment changes and repeated sessions.
