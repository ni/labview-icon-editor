# ADR: 10 Additional Testing Features for Ollama Executor

- **ID**: ADR-2025-020  
- **Status**: Proposed  
- **Date**: 2025-12-03

## Context
With the initial 5 testing features implemented (ADR-2025-019), we have established:
- Mock Ollama server for isolated testing
- Command vetting test suite (found 2 bugs)
- Conversation scenario tests
- Timeout/failure handling tests
- Integration test framework

To achieve comprehensive test coverage and enable advanced testing scenarios, we need 10 additional testing features that address:
- Performance testing and benchmarking
- Coverage analysis and reporting
- Concurrent execution testing
- Security-focused testing
- Test data generation
- Regression testing automation
- CI/CD integration
- Advanced mocking capabilities

## Decision: 10 Additional Testing Features

### Feature #6: Performance Benchmark Suite (High Priority)
**Problem**: No way to measure executor performance or detect regressions  
**Solution**: Automated benchmark suite tracking key metrics

**Implementation**:
- `Test-Performance.ps1` - Runs standardized benchmark scenarios
- Tracks metrics:
  - Conversation turns per second
  - Command execution overhead
  - Mock server response time
  - Memory usage during execution
  - Artifact creation time
- Generates performance report (JSON + markdown)
- Compares against baseline to detect regressions
- Includes stress test (100+ turns, 10+ concurrent commands)

**Value**: Prevent performance regressions, optimize hot paths, capacity planning

---

### Feature #7: Code Coverage Reporter (High Priority)
**Problem**: Unknown test coverage, can't identify untested code paths  
**Solution**: Coverage analysis and reporting

**Implementation**:
- `Generate-CoverageReport.ps1` - Analyzes test execution
- Instruments PowerShell code to track:
  - Function execution counts
  - Branch coverage (if/else paths)
  - Line coverage
- Generates HTML coverage report with heat maps
- Exports coverage data for CI/CD
- Integrates with all test suites

**Value**: Identify gaps in test coverage, guide test development, quality metrics

---

### Feature #8: Concurrent Execution Test Suite (Medium Priority)
**Problem**: Executor might be used concurrently, but this is untested  
**Solution**: Tests for parallel executor instances

**Implementation**:
- `Test-ConcurrentExecution.ps1`
- Spawns multiple executor instances simultaneously
- Tests:
  - File system conflicts (artifact creation)
  - Mock server handling concurrent requests
  - Resource contention
  - Isolation between instances
- Validates no data corruption or race conditions

**Value**: Safe concurrent usage, identify threading issues

---

### Feature #9: Security Fuzzing Test Suite (High Priority)
**Problem**: Command vetting has known bugs, need comprehensive security testing  
**Solution**: Fuzzing-based security tests

**Implementation**:
- `Test-SecurityFuzzing.ps1`
- Generates 1000+ malicious command variations:
  - Path traversal attempts (`../`, `..\`, encoded variants)
  - Command injection (`;`, `|`, `&`, `$(...)`)
  - Script injection (`<script>`, PowerShell operators)
  - Unicode/encoding attacks
  - Buffer overflow attempts (very long commands)
  - NULL byte injection
- All should be rejected by vetting logic
- Reports any that pass through

**Value**: Harden security, prevent command injection attacks

---

### Feature #10: Test Data Generator (Medium Priority)
**Problem**: Creating test scenarios manually is time-consuming  
**Solution**: Automated test data generation

**Implementation**:
- `Generate-TestScenarios.ps1`
- Templates for common scenarios:
  - Successful builds (all LV versions/bitness)
  - Build failures (compilation errors, missing files)
  - Multi-platform workflows
  - Long conversations (20+ turns)
  - Error recovery patterns
- Parameterized generation (LV version, bitness, error types)
- Exports to JSON scenario files
- Includes realistic stdout/stderr samples

**Value**: Rapid test scenario creation, consistency, regression test generation

---

### Feature #11: Regression Test Automation (High Priority)
**Problem**: No automated way to track fixed bugs or prevent regressions  
**Solution**: Regression test framework

**Implementation**:
- `Test-Regressions.ps1`
- Maintains regression test database (JSON)
- Each regression test includes:
  - Bug ID/description
  - Reproduction scenario
  - Expected vs actual behavior
  - Fix verification test
- Auto-runs all regression tests
- Fails if any previously-fixed bug resurfaces
- Easy to add new regression tests when bugs are fixed

**Value**: Prevent bug reintroduction, quality tracking over time

---

### Feature #12: CI/CD Test Orchestrator (High Priority)
**Problem**: Running all tests manually is tedious, need CI/CD integration  
**Solution**: Unified test orchestration script

**Implementation**:
- `Run-AllTests.ps1` - Master test runner
- Executes all test suites in correct order:
  1. Unit tests (vetting)
  2. Mock server health check
  3. Scenario tests
  4. Timeout/failure tests
  5. Integration tests
  6. Performance benchmarks
  7. Security fuzzing
  8. Regression tests
- Parallel execution where safe
- Generates unified test report (JUnit XML, HTML)
- Exit code indicates pass/fail for CI/CD
- Configurable test selection (--fast, --full, --security-only)

**Value**: One-command testing, CI/CD integration, faster feedback

---

### Feature #13: Mock Server Response Library (Medium Priority)
**Problem**: Creating mock responses for every scenario is repetitive  
**Solution**: Reusable response library

**Implementation**:
- `mock-responses/` directory with categorized responses:
  - `successful-builds/*.json` - Various successful build responses
  - `errors/*.json` - Error responses (timeouts, failures, invalid JSON)
  - `conversations/*.json` - Multi-turn conversation patterns
  - `edge-cases/*.json` - Unusual but valid responses
- `MockResponseLibrary.psm1` - Helper functions:
  - `Get-SuccessBuildResponse -LVVersion 2025 -Bitness 64`
  - `Get-ErrorResponse -Type Timeout`
  - `Get-ConversationPattern -Pattern InvalidJsonRecovery`
- MockOllamaServer can load from library

**Value**: Test reusability, faster test authoring, consistency

---

### Feature #14: Snapshot Testing for Outputs (Medium Priority)
**Problem**: Validating executor output is verbose and brittle  
**Solution**: Snapshot-based testing

**Implementation**:
- `Test-Snapshots.ps1`
- Captures "golden" outputs for known scenarios
- Stores snapshots in `test-snapshots/`
- On subsequent runs, compares actual vs snapshot
- Highlights diffs for review
- Easy snapshot update workflow
- Supports:
  - Stdout/stderr content
  - Artifact structure
  - Log file formats
  - JSON responses

**Value**: Catch unexpected output changes, easier test maintenance

---

### Feature #15: Health Check & Diagnostics Suite (Medium Priority)
**Problem**: When tests fail, hard to diagnose why  
**Solution**: Diagnostic test suite

**Implementation**:
- `Test-Health.ps1` - Environment health checks:
  - PowerShell version compatibility
  - Required modules available
  - Docker accessibility (for real Ollama tests)
  - File system permissions
  - Network connectivity
  - Mock server can bind to ports
- `Test-Diagnostics.ps1` - Troubleshooting tests:
  - Validates test fixtures exist
  - Checks scenario file format
  - Verifies simulation mode works
  - Tests mock server in isolation
- Detailed error messages with remediation steps

**Value**: Faster troubleshooting, better developer experience, reduced setup issues

---

## Implementation Priority

**Phase 1** (Immediate - High ROI):
1. Feature #6: Performance Benchmark Suite
2. Feature #9: Security Fuzzing Test Suite
3. Feature #12: CI/CD Test Orchestrator

**Phase 2** (Short-term - Quality):
4. Feature #7: Code Coverage Reporter
5. Feature #11: Regression Test Automation

**Phase 3** (Medium-term - Productivity):
6. Feature #10: Test Data Generator
7. Feature #13: Mock Server Response Library
8. Feature #14: Snapshot Testing

**Phase 4** (Long-term - Advanced):
9. Feature #8: Concurrent Execution Tests
10. Feature #15: Health Check & Diagnostics

## Success Criteria

- [ ] All 10 features implemented and documented
- [ ] CI/CD orchestrator runs in <5 minutes for fast mode, <30 minutes for full
- [ ] Security fuzzing finds and validates fixes for known bugs
- [ ] Performance benchmarks establish baselines for all scenarios
- [ ] Code coverage reaches ≥80% for executor scripts
- [ ] Regression test count grows with each bug fix
- [ ] Snapshot tests cover all major output formats
- [ ] Health checks catch 90%+ of common setup issues

## Consequences

### Positive
- **Comprehensive Testing**: 15 total features cover unit, integration, performance, security
- **CI/CD Ready**: Automated test suite suitable for continuous integration
- **Security Hardening**: Fuzzing finds edge cases human testers miss
- **Quality Metrics**: Coverage and benchmarks provide measurable quality goals
- **Developer Velocity**: Test generators and libraries accelerate test authoring
- **Maintainability**: Regression suite prevents backsliding

### Negative
- **Maintenance Burden**: More test code to maintain
- **Execution Time**: Full test suite may take 30+ minutes
- **Learning Curve**: Developers should understand test framework
- **Infrastructure**: Some features require CI/CD environment

### Mitigations
- Provide clear documentation for each feature
- Fast test mode for rapid feedback (<5 min)
- Modular design - features can be used independently
- Progressive implementation - deliver value incrementally

## References
- Previous: ADR-2025-019 (Top 5 Testing Features)
- Related: ADR-2025-018 (Cross-Compilation Simulation Mode)

> Traceability: Ollama executor testing scripts under `scripts/ollama-executor/`.
