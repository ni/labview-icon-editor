# FGC-REQ-QA-003 - Reset stateful modules between tests
Version: 1.0

## Description
Tests that touch stateful modules shall use a `reset_modules` fixture to reload affected modules before and after execution.

## Rationale
Reloading ensures a clean import state and prevents cross-test state leakage.

## Verification
Method(s): Test | Demonstration | Inspection
Acceptance Criteria:
- AC1. Tests manipulating stateful modules declare the `reset_modules` fixture.
- AC2. Consecutive tests mutating `codex_rules.memory` show no state leakage across tests.

## Statement(s)
- RQ1. Tests shall reload stateful modules via `reset_modules` before and after execution.

## Attributes
Priority: Medium
Owner: QA
Source: Team policy
Status: Proposed
Trace: tests/conftest.py, tests/test_reset_modules_memory.py
