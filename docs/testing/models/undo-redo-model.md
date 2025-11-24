# Undo/Redo Core Test Model (§8.2)

- UID: `TM-UNDO-001`
- Objective: Model the undo/redo stack invariants, redo-flush rules, and overflow trimming so functional and non-functional tests probe the intended history behaviour.
- Priority: High (UT-001) with Medium non-functional guardrail (NF-001).
- Strategy extract: Levels and types: LabVIEW unit tests under `Test/` plus targeted workflow/automation checks with non-functional sanity triggered by risk/priority (`docs/testing/strategy.md`, Approach).

## Model

### State diagram
```
[Idle]                # no history
  | Record(action)
  v
[UndoAvailable]       # undo stack populated, redo cleared
  | Undo                            | Record(new action)
  v                                 v
[RedoAvailable] <----- Redo ------ [UndoAvailable]
  | Clear/Reset -> [Idle]

Depth limit guard:
[UndoAvailable] --(push beyond max depth)--> [OverflowTrimmed]
[OverflowTrimmed] --Undo--> [RedoAvailable] (trimmed oldest entry stays dropped)
```
- Invariants: redo stack clears on any new action; undo/redo counts never drop below zero; overflow only removes the oldest undo entry and never reorders remaining history.

### Input/Output partitions
- P1: Empty history – undo/redo are no-ops and leave stacks empty.
- P2: Single action – one undo returns to baseline; one redo reapplies the change.
- P3: Multiple actions – successive undo traverses the stack LIFO; redo restores in original order.
- P4: Branch after undo – recording a new action after an undo clears redo history and starts a new stack branch.
- P5: Depth limit boundary – pushes at max_depth-1, max_depth, and max_depth+1 trim only the oldest item while preserving newer ordering.
- P6: Heavy history load – long sequences (e.g., 100+ actions) maintain consistent counts and avoid overflow errors while sustaining performance expectations.

## Traceability to RTM IDs
- UT-001 (High) relies on the state machine and partitions P1–P5 to assert stack invariants and redo-flush behaviour for each transition.
- NF-001 (Medium) uses partitions P5–P6 to confirm controlled overflow trimming and stable performance under heavy history mutation.
