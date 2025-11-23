# Undo/Redo Core Test Model (§8.2) Test Case Specification (§8.3)

- Model ID: `TM-UNDO-001`
- Model source: `docs/testing/models/undo-redo-model.md`
- Related requirements: UT-001 (High), NF-001 (Medium)
- Test assets: `Test/Unit Tests/Undo Redo Core/Test Add and Undo All.vi`, `Test/Unit Tests/Undo Redo Core/Test Overflow.vi`
- Procedures: `docs/testing/procedures/undo-redo-procedure.md`

## Coverage Items
| ID | Description |
| --- | --- |
| P1 | Empty history – undo/redo are no-ops and leave stacks empty. |
| P2 | Single action – one undo returns to baseline; one redo reapplies the change. |
| P3 | Multiple actions – successive undo traverses the stack LIFO; redo restores in original order. |
| P4 | Branch after undo – recording a new action after an undo clears redo history and starts a new stack branch. |
| P5 | Depth limit boundary – pushes at max_depth-1, max_depth, and max_depth+1 trim only the oldest item while preserving newer ordering. |
| P6 | Heavy history load – long sequences (e.g., 100+ actions) maintain consistent counts and avoid overflow errors while sustaining performance expectations. |

## Test Cases
| Case ID | Requirement | Priority | Test Path | Procedure | Coverage Items |
| --- | --- | --- | --- | --- | --- |
| UT-001-TC1 | UT-001 | High | `Test/Unit Tests/Undo Redo Core/Test Add and Undo All.vi` | `docs/testing/procedures/undo-redo-procedure.md` | P1, P2, P3, P4, P5, P6 |
| NF-001-TC1 | NF-001 | Medium | `Test/Unit Tests/Undo Redo Core/Test Overflow.vi` | `docs/testing/procedures/undo-redo-procedure.md` | P1, P2, P3, P4, P5, P6 |