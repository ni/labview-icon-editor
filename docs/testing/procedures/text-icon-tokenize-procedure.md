# Text Icon Tokenization Automated Test Procedure (ISO/IEC/IEEE 29119-3 §8.4)

- Procedure ID: `PRO-AUTO-TEXTICON-001`
- Applicable requirements: TB-001, NF-003
- Test case specification: `docs/testing/specs/text-icon-tokenize-tcs.md`
- Executor: automation (self-hosted LabVIEW runner)

## Start Conditions
- Environment: LabVIEW 2021 on `test-2021-x64` and `test-2021-x86`; repository checked out at target commit.
- Pre-conditions: Unit Test Framework installed; no prior tokenization artifacts cached.
- Data: mixed-separator input strings exercised by the test VI.

## Procedure Steps (ordered)
1) Run `Test/Unit Tests/Text-Based VI Icon Tests/Test Split Text into Words.vi` on x64, then x86.
2) Collect outputs/logs showing token lists and throughput timing (if emitted).
3) Map observed behavior to coverage items R1–R7 in `docs/testing/specs/text-icon-tokenize-tcs.md` (whitespace collapse, punctuation, newline/tab, hyphen/underscore, trailing punctuation/decimals, mixed separators, load/throughput).

## Expected Results
- Tokens split according to decision table; empty tokens removed; ordering preserved; no performance regressions for mixed separators.

## Stop / Wrap-up
- Stop criteria: suite completion or first blocking defect.
- Wrap-up: archive logs and `test-results.json`; update status/completion report; attach artifacts to PR/tag run.
