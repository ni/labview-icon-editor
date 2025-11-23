# Text Icon Tokenization Test Model (§8.2)

- UID: `TM-TEXTICON-001`
- Objective: Model token split decisions for text-based VI icon generation so tests cover delimiter handling, normalization, and mixed-separator throughput.
- Priority: Medium (TB-001, NF-003).
- Strategy extract: Design inputs come from `docs/requirements/rtm.csv` with RTM priorities driving functional and non-functional coverage (`docs/testing/strategy.md`, Approach).

## Model

### Decision table (token splits)
| Rule | Input example | Conditions exercised | Expected tokens |
| --- | --- | --- | --- |
| R1 Basic whitespace | `Undo Redo` | Single spaces | `["Undo", "Redo"]` |
| R2 Collapsed whitespace | `Undo   Redo   Save` | Multiple spaces collapse; drop empties | `["Undo", "Redo", "Save"]` |
| R3 Punctuation delimiters | `Undo,Redo;Save/Close` | Comma/semicolon/slash act as separators | `["Undo", "Redo", "Save", "Close"]` |
| R4 Newline/tab separators | `Undo\nRedo\tSave` | Newline and tab treated as word breaks | `["Undo", "Redo", "Save"]` |
| R5 Hyphen/underscore bridges | `Text_ICON-reset` | Hyphen and underscore split tokens; casing preserved | `["Text", "ICON", "reset"]` |
| R6 Trailing punctuation/decimal | `v1.2 Icon!` | Dots and trailing punctuation break tokens | `["v1", "2", "Icon"]` |
| R7 Mixed separators at load | `A_B C,D\nE-F` repeated across a long string | Alternating separators under load; drop empties, maintain order for throughput checks | `["A", "B", "C", "D", "E", "F", ...]` |

Normalization rules: trim leading/trailing whitespace, drop zero-length tokens, and preserve character casing within tokens for subsequent formatting.

## Traceability to RTM IDs
- TB-001 (Medium) maps to rules R1–R6 to confirm functional token splits for words used in text-based icon rendering.
- NF-003 (Medium) maps to rule R7 to ensure mixed-separator inputs still split correctly without throughput regressions.
