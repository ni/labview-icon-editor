# Text Icon Tokenization Test Model (§8.2) Test Case Specification (§8.3)

- Model ID: `TM-TEXTICON-001`
- Model source: `docs/testing/models/text-icon-tokenize-model.md`
- Related requirements: TB-001 (Medium), NF-003 (Medium)
- Test assets: `Test/Unit Tests/Text-Based VI Icon Tests/Test Split Text into Words.vi`
- Procedures: `docs/testing/procedures/text-icon-tokenize-procedure.md`

## Coverage Items
| ID | Description |
| --- | --- |
| R1 | `Undo Redo` | Single spaces | `["Undo", "Redo"]` |
| R2 | `Undo   Redo   Save` | Multiple spaces collapse; drop empties | `["Undo", "Redo", "Save"]` |
| R3 | `Undo,Redo;Save/Close` | Comma/semicolon/slash act as separators | `["Undo", "Redo", "Save", "Close"]` |
| R4 | `Undo\nRedo\tSave` | Newline and tab treated as word breaks | `["Undo", "Redo", "Save"]` |
| R5 | `Text_ICON-reset` | Hyphen and underscore split tokens; casing preserved | `["Text", "ICON", "reset"]` |
| R6 | `v1.2 Icon!` | Dots and trailing punctuation break tokens | `["v1", "2", "Icon"]` |
| R7 | `A_B C,D\nE-F` repeated across a long string | Alternating separators under load; drop empties, maintain order for throughput checks | `["A", "B", "C", "D", "E", "F", ...]` |

## Test Cases
| Case ID | Requirement | Priority | Test Path | Procedure | Coverage Items |
| --- | --- | --- | --- | --- | --- |
| TB-001-TC1 | TB-001 | Medium | `Test/Unit Tests/Text-Based VI Icon Tests/Test Split Text into Words.vi` | `docs/testing/procedures/text-icon-tokenize-procedure.md` | R1, R2, R3, R4, R5, R6, R7 |
| NF-003-TC1 | NF-003 | Medium | `Test/Unit Tests/Text-Based VI Icon Tests/Test Split Text into Words.vi` | `docs/testing/procedures/text-icon-tokenize-procedure.md` | R1, R2, R3, R4, R5, R6, R7 |