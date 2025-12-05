# ADR: Top 5 Testing Features for Ollama Executor

- **ID**: ADR-2025-019  
- **Status**: Proposed  
- **Date**: 2025-12-03

## Context
The Ollama executor (`Drive-Ollama-Executor.ps1`) is a critical component that enables LLM-driven build automation. Currently, testing is limited to:
- Basic simulation mode (ADR-2025-018) for cross-compilation scenarios
- Manual execution with real Ollama models
- No automated test suite for executor logic

To improve reliability, maintainability, and development velocity, we need comprehensive testing capabilities that cover:
- Command allowlist/vetoing logic
- Ollama API interaction and response parsing
- Timeout handling
- Turn limiting
- Error scenarios

## Investigation: Testing Gaps

After analyzing the executor code and existing tests, the key testing gaps are:

1. **No unit tests for command vetting** - The `Test-CommandAllowed` function has complex logic (allowlist, pattern matching, forbidden tokens) but no automated tests
2. **No mock Ollama server** - Testing requires a real Ollama instance, making it slow and environment-dependent
3. **No timeout testing** - CommandTimeoutSec behavior is untested
4. **No turn limit testing** - MaxTurns behavior and conversation state management is untested
5. **No error injection testing** - Error scenarios (invalid JSON, network failures, command failures) are not systematically tested
6. **No integration test framework** - End-to-end scenarios require manual setup
7. **No performance benchmarking** - No way to measure executor overhead or detect regressions

## Decision: Top 5 Testing Features

Based on impact, feasibility, and coverage improvement, implement these five testing features:

### 1. Mock Ollama Server (Highest Priority)
**Problem**: Testing requires real Ollama instance  
**Solution**: Create a lightweight mock HTTP server that simulates Ollama API responses  
**Benefits**:
- Fast, deterministic tests
- No external dependencies
- Enables CI/CD testing
- Supports error injection scenarios

**Implementation**:
- `scripts/ollama-executor/MockOllamaServer.ps1` - Simple HTTP listener
- Configurable via JSON files for different conversation scenarios
- Supports `/api/chat` and `/api/tags` endpoints
- Can simulate delays, errors, and specific response patterns

### 2. Command Vetting Test Suite (High Priority)
**Problem**: Complex allowlist/vetting logic is untested  
**Solution**: Comprehensive test suite for `Test-CommandAllowed` function  
**Benefits**:
- Catch regressions in security-critical code
- Document expected behavior
- Enable safe refactoring

**Implementation**:
- `scripts/ollama-executor/Test-CommandVetting.ps1`
- Tests for: allowlist matching, pattern validation, forbidden tokens, edge cases
- Uses Pester-style assertions or custom test harness
- Validates both acceptance and rejection cases

### 3. Conversation Scenario Tests (High Priority)
**Problem**: Multi-turn conversations and state management untested  
**Solution**: Scenario-based tests using predefined conversation flows  
**Benefits**:
- Test realistic LLM interaction patterns
- Verify turn limiting and early termination
- Test JSON parsing and error recovery

**Implementation**:
- `scripts/ollama-executor/Test-ConversationScenarios.ps1`
- Scenario files in `scripts/ollama-executor/test-scenarios/*.json`
- Each scenario defines: goal, expected turns, Ollama responses, expected outcomes
- Uses mock Ollama server to replay scenarios

### 4. Timeout and Failure Handling Tests (Medium Priority)
**Problem**: Timeout and error paths are untested  
**Solution**: Dedicated tests for failure modes  
**Benefits**:
- Verify executor resilience
- Test timeout enforcement
- Validate error reporting

**Implementation**:
- `scripts/ollama-executor/Test-TimeoutAndFailures.ps1`
- Tests for: command timeout, network failures, malformed responses, command failures
- Uses simulation mode and mock server
- Validates exit codes and error messages

### 5. Integration Test Framework (Medium Priority)
**Problem**: No end-to-end test automation  
**Solution**: Framework for running complete executor workflows  
**Benefits**:
- Test full executor flow
- Validate real-world scenarios
- Support regression testing

**Implementation**:
- `scripts/ollama-executor/Test-Integration.ps1`
- Combines mock server, simulation mode, and scenario files
- Tests complete flows: successful build, build failure, timeout, max turns
- Validates artifacts, logs, and exit codes
- Can run in CI/CD with no external dependencies

## Implementation Priority

1. **Phase 1** (Immediate): Mock Ollama Server + Command Vetting Tests
   - Provides foundation for other tests
   - Addresses highest-risk areas (security, external dependency)

2. **Phase 2** (Short-term): Conversation Scenario Tests
   - Builds on mock server
   - Tests core executor logic

3. **Phase 3** (Medium-term): Timeout/Failure Tests + Integration Framework
   - Completes test coverage
   - Enables CI/CD integration

## Alternatives Considered

### A: Use Existing Test Frameworks (Pester, NUnit)
- **Pros**: Standard tools, good IDE support
- **Cons**: Additional dependencies, learning curve, may not fit PowerShell scripting patterns
- **Decision**: Start with custom test scripts (PowerShell native), migrate to Pester if beneficial

### B: Test Against Real Ollama Only
- **Pros**: No mocking complexity, tests real integration
- **Cons**: Slow, flaky, environment-dependent, can't test error scenarios reliably
- **Decision**: Rejected - use mock for unit tests, real Ollama for manual validation

### C: Record/Replay Ollama Responses
- **Pros**: Uses real responses, easier initial setup
- **Cons**: Brittle (model changes break tests), hard to create targeted scenarios
- **Decision**: Rejected - use mock with configurable scenarios instead

## Consequences

### Positive
- **Faster Development**: Quick feedback from automated tests
- **Higher Quality**: Catch bugs before they reach production
- **Better Documentation**: Tests serve as executable specifications
- **Easier Refactoring**: Confidence to improve code without breaking functionality
- **CI/CD Ready**: No external dependencies for testing

### Negative
- **Maintenance**: Test code should be kept in sync with executor changes
- **Initial Effort**: Time required to implement all five features
- **Mock Limitations**: Mock server may not catch Ollama-specific issues

### Mitigations
- Start with highest-value tests (mock server, command vetting)
- Keep tests focused and simple
- Document test scenarios clearly
- Supplement automated tests with occasional real Ollama validation

## Success Criteria

- [ ] Mock Ollama server handles all required API endpoints
- [ ] Command vetting test suite covers ≥90% of vetting logic paths
- [ ] Conversation scenario tests cover at least 5 common patterns
- [ ] Timeout/failure tests cover at least 10 error scenarios
- [ ] Integration tests can run in <30 seconds without external dependencies
- [ ] All tests pass in CI/CD environment
- [ ] Test documentation explains how to add new scenarios

## Follow-ups
- [ ] Add test coverage reporting
- [ ] Create VS Code task for running all executor tests
- [ ] Document testing best practices for contributors
- [ ] Consider migrating to Pester if test suite grows significantly

> Traceability: Ollama executor scripts under `scripts/ollama-executor/`; follows testing patterns from XCLI tests.
