# ADR: 10 Refinements for Complete Test Coverage

- **ID**: ADR-2025-021  
- **Status**: Proposed  
- **Date**: 2025-12-03

## Context
We have implemented 9 of 15 testing features. To achieve complete test coverage and production-ready quality, we need 10 refinements that address:
- Remaining 6 testing features (from ADR-2025-020)
- Bug fixes discovered during testing
- Test framework improvements
- Documentation and usability enhancements

## Decision: 10 Refinements for Complete Coverage

### Refinement #1: Fix Command Vetting Bugs (Critical Priority)
**Problem**: Security fuzzing and command vetting tests found 2 critical bugs:
1. Parent directory traversal (`../`, `..\`) not blocked
2. Command chaining (`;`) not properly validated

**Solution**: Update `Test-CommandAllowed` in `Drive-Ollama-Executor.ps1`
- Add explicit check for `..` in path
- Add check for `;` character (command separator)
- Add to forbidden tokens list
- Re-run security fuzzing to verify fixes

**Value**: Close critical security vulnerabilities

---

### Refinement #2: Code Coverage Reporter Implementation
**Problem**: No visibility into test coverage

**Solution**: Implement `Generate-CoverageReport.ps1`
- Parse PowerShell scripts to identify functions and branches
- Instrument test execution to track code paths
- Generate coverage percentage per file
- HTML report with line-by-line coverage visualization
- Export coverage data for CI/CD (Cobertura XML format)

**Value**: Identify untested code, quality metrics

---

### Refinement #3: Test Data Generator Implementation
**Problem**: Creating test scenarios manually is time-consuming

**Solution**: Implement `Generate-TestScenarios.ps1`
- Templates for common patterns (successful build, failures, multi-platform)
- Parameterized generation: `-LVVersion 2025 -Bitness 64 -Outcome success`
- Batch generation: create all LV version/bitness combinations
- Realistic stdout/stderr based on actual build outputs
- Auto-save to `test-scenarios/generated/`

**Value**: Rapid test expansion, consistency

---

### Refinement #4: Mock Server Response Library
**Problem**: Repetitive mock response creation

**Solution**: Implement response library
- Create `mock-responses/` directory structure:
  - `builds/successful/` - Various successful build patterns
  - `builds/failures/` - Different failure types
  - `conversations/` - Multi-turn patterns
  - `errors/` - Malformed JSON, timeouts, and other error conditions
- Create `MockResponseLibrary.psm1` module
- Helper functions: `Get-BuildResponse`, `Get-ErrorResponse`
- MockOllamaServer integration

**Value**: Faster test authoring, reusability

---

### Refinement #5: Snapshot Testing Implementation
**Problem**: Output validation is verbose and brittle

**Solution**: Implement `Test-Snapshots.ps1`
- Capture baseline outputs for known scenarios
- Store in `test-snapshots/{scenario-name}/`
- Compare actual vs snapshot on test runs
- Generate diff report highlighting changes
- Update workflow: review diffs, approve/reject changes
- Support for stdout, stderr, artifacts, JSON responses

**Value**: Catch unexpected changes, easier maintenance

---

### Refinement #6: Health Check & Diagnostics Suite
**Problem**: Test failures are hard to diagnose

**Solution**: Implement `Test-Health.ps1` and `Test-Diagnostics.ps1`

**Test-Health.ps1** checks:
- PowerShell version (>= 7.0)
- Required modules
- Docker availability and version
- File system permissions
- Network connectivity
- Port availability (11435-11440)

**Test-Diagnostics.ps1** validates:
- Test fixture integrity
- Scenario file format (JSON validation)
- Simulation mode functionality
- Mock server can start/stop
- Common configuration errors

**Value**: Faster troubleshooting, better DX

---

### Refinement #7: Concurrent Execution Test Suite
**Problem**: Executor concurrency untested

**Solution**: Implement `Test-ConcurrentExecution.ps1`
- Spawn 5 simultaneous executor instances
- Tests:
  - No file system conflicts
  - Mock server handles concurrent requests
  - Resource isolation (temp files, artifacts)
  - No race conditions
  - Exit codes correct for all instances
- Validates thread safety

**Value**: Production readiness for parallel CI jobs

---

### Refinement #8: Enhanced Performance Benchmarks
**Problem**: Current benchmarks are basic

**Solution**: Enhance `Test-Performance.ps1`
- Add stress tests: 100+ turn conversations, 50+ parallel commands
- Memory profiling: track GC pressure, memory leaks
- Latency percentiles: p50, p95, p99
- Throughput measurement: commands/second
- Resource utilization: CPU, memory, disk I/O
- Regression detection: >10% slower = fail
- Historical tracking: store results over time

**Value**: Performance validation, capacity planning

---

### Refinement #9: CI/CD Pipeline Integration
**Problem**: Tests not integrated with GitHub Actions

**Solution**: Create `.github/workflows/ollama-executor-tests.yml`
- Trigger on PR and push
- Matrix testing: Windows, Linux, macOS
- Test modes: fast on PR, full on merge
- Upload test artifacts (reports, coverage)
- Comment PR with test results
- Block merge if critical tests fail
- Cache dependencies for speed

**Value**: Automated quality gate, faster feedback

---

### Refinement #10: Comprehensive Documentation
**Problem**: Test framework lacks user documentation

**Solution**: Create comprehensive docs
- `docs/testing/ollama-executor-testing-guide.md`:
  - Getting started
  - Running tests
  - Writing new tests
  - Debugging failures
  - CI/CD integration
- `docs/testing/test-architecture.md`:
  - Framework design
  - Component relationships
  - Extension points
- Update main README with testing section
- Add inline documentation to all test scripts
- Create troubleshooting guide

**Value**: Easier adoption, maintainability

---

## Implementation Priority

**Phase 1** (Critical - Security & Stability):
1. Refinement #1: Fix Command Vetting Bugs
2. Refinement #6: Health Check & Diagnostics
3. Refinement #9: CI/CD Pipeline Integration

**Phase 2** (High Value - Coverage & Quality):
4. Refinement #2: Code Coverage Reporter
5. Refinement #5: Snapshot Testing
6. Refinement #8: Enhanced Performance Benchmarks

**Phase 3** (Productivity & Maintainability):
7. Refinement #3: Test Data Generator
8. Refinement #4: Mock Server Response Library
9. Refinement #7: Concurrent Execution Tests

**Phase 4** (Documentation):
10. Refinement #10: Comprehensive Documentation

## Success Criteria

- [ ] All 10 refinements implemented
- [ ] Zero critical security vulnerabilities
- [ ] Test coverage ≥80% of executor code
- [ ] CI/CD pipeline green on all platforms
- [ ] Full test suite runs in <5min (fast mode), <30min (full mode)
- [ ] Documentation complete and reviewed
- [ ] All tests passing on Windows, Linux, macOS
- [ ] Performance baselines established

## Consequences

### Positive
- **Complete Coverage**: All testing features implemented
- **Production Ready**: Security hardened, thoroughly tested
- **CI/CD Integrated**: Automated quality enforcement
- **Maintainable**: Well documented, easy to extend
- **High Quality**: Code coverage, performance validated

### Negative
- **Time Investment**: Significant implementation effort
- **Complexity**: More moving parts to maintain
- **Learning Curve**: Contributors should understand framework

### Mitigations
- Incremental delivery - each refinement adds value independently
- Focus on critical refinements first (security, stability)
- Excellent documentation to ease learning curve
- Automated tests to catch regressions in test framework itself

## References
- Previous: ADR-2025-020 (10 Additional Testing Features)
- Previous: ADR-2025-019 (Top 5 Testing Features)
- Related: ADR-2025-018 (Cross-Compilation Simulation Mode)

> Traceability: Complete testing infrastructure for Ollama executor in `scripts/ollama-executor/`.
