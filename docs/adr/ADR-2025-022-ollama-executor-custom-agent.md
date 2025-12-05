# ADR: Ollama Executor Custom Agent Definition

- **ID**: ADR-2025-022  
- **Status**: Accepted  
- **Date**: 2025-12-03

## Context

The Ollama locked executor (ADR-2025-017) provides a secure mechanism for LLM-driven build flows, but there is no standardized way for GitHub Copilot or other AI assistants to discover and use these capabilities. Developers need a machine-readable agent definition that describes the executor's capabilities, security guardrails, and workflow patterns. This agent definition should enable AI assistants to:

1. Drive source distribution builds for specific LabVIEW versions and bitnesses
2. Orchestrate package builds and SD→PPL pipelines
3. Modify VIPB files for different LabVIEW targets using Seed Docker container
4. Run security and smoke tests
5. Respect security guardrails (allowlist, path traversal prevention, timeout enforcement)

**Decision drivers** (ranked):
1. **Discoverability**: AI assistants should find and understand executor capabilities automatically
2. **Security**: Agent SHALL enforce existing guardrails and SHALL not introduce new attack vectors
3. **Portability**: VIPB modification should work cross-platform (Windows/macOS/Linux)
4. **Traceability**: Requirements should be documented for verification

## Options considered

1. **Option A** — Custom agent at `.github/agents/ollama-executor.agent.md`
   - **Description**: Define a custom agent using GitHub's agent configuration format with YAML frontmatter and markdown documentation
   - **Pros**: 
     - Machine-readable format for GitHub Copilot integration
     - Human-readable documentation in same file
     - Follows repository convention (existing `.github/agents/` directory)
   - **Cons**: 
     - Requires maintenance as executor capabilities change
     - Format may evolve as GitHub agent specification matures

2. **Option B** — Inline documentation in executor scripts only
   - **Description**: Rely on script comments and README files for documentation
   - **Pros**: 
     - No new files to maintain
     - Documentation stays close to implementation
   - **Cons**: 
     - Not machine-readable for AI assistants
     - Scattered documentation harder to discover

3. **Option C** — External API specification (OpenAPI/JSON Schema)
   - **Description**: Define executor interface as formal API specification
   - **Pros**: 
     - Rigorous schema validation
     - Generates client bindings
   - **Cons**: 
     - Overkill for script-based executor
     - Additional tooling overhead

## Decision

Choose **Option A**: Create a custom agent definition at `.github/agents/ollama-executor.agent.md` with:

1. **YAML frontmatter** with `name: ollama-executor` and description
2. **Capability documentation** for all build workflows (SD, PPL, package builds)
3. **Seed Docker integration** for cross-platform VIPB modification
4. **Interactive build workflow** with user prompting for LabVIEW version/bitness
5. **Security guardrails reference** (allowlist, path traversal, command chaining prevention)

## Consequences

### Positive

- **+** AI assistants can discover and invoke executor capabilities correctly
- **+** Single source of truth for executor documentation
- **+** Seed Docker integration enables cross-platform VIPB modification
- **+** Interactive workflow guides users through version/bitness selection

### Negative / trade-offs

- **–** Agent file SHALL be updated when executor capabilities change
- **–** Seed Docker dependency for cross-platform VIPB modification

### Follow-up actions

- [ ] Add agent to VS Code task documentation
- [ ] Create smoke test for agent discovery by GitHub Copilot
- [ ] Monitor GitHub agent specification for format changes

## Implementation

### Affected components

- `.github/agents/ollama-executor.agent.md` — Agent definition (created)
- `.github/agents/requirements-injector.agent.md` — Requirements injection agent (created)
- `scripts/ollama-executor/` — Existing executor scripts (unchanged)
- `Tooling/seed/` — Docker container for VIPB modification (referenced)

### Agent capabilities documented

1. Source Distribution Builds (`Run-Locked-SourceDistribution.ps1`)
2. Package Builds (`Run-Locked-PackageBuild.ps1`)
3. Local SD→PPL Pipeline (`Run-Locked-LocalSdPpl.ps1`)
4. Ollama Host Orchestration (`Run-Ollama-Host.ps1`)
5. Smoke Tests (`-SmokeOnly` switch)
6. Interactive Real LabVIEW Build (user prompting + VIPB modification + build)
7. Test Suites (`Test-CommandVetting.ps1`, `Test-SecurityFuzzing.ps1`, and `Test-SimulationMode.ps1`)

### Seed Docker integration

The agent documents using the vendored Seed container (`seed:latest`, built locally from `Tooling/seed/Dockerfile`) for:

- `vipb2json` — Convert VIPB to JSON for editing
- `json2vipb` — Convert JSON back to VIPB format
- Additional tools: `lvproj2json`, `json2lvproj`, `buildspec2json`, `json2buildspec`

## Verification & validation

### Success criteria

- Agent file passes YAML frontmatter validation
- All 35 requirements in CSV have status "Completed"
- Simulation mode tests pass (command vetting, smoke tests)
- Documentation accurately reflects executor capabilities

### Verification method

- **Inspection**: Review agent file and requirements CSV
- **Test**: Run `Test-SimulationMode.ps1` to validate build workflow execution

## Security, privacy & compliance

### Threats & mitigations

- **Command injection**: Mitigated by allowlist-only execution in executor
- **Path traversal**: Mitigated by `../` pattern rejection
- **Privilege escalation**: Mitigated by sudo/runas keyword blocking
- **Data exfiltration**: Mitigated by network tool blocking (wget/curl/nc)

### Agent security model

The agent inherits all security guardrails from the locked executor (ADR-2025-017):

1. Exact allowlist matching for commands
2. Forbidden token detection (rm, del, Remove-Item, Format-*, sudo, runas)
3. Command chaining prevention (`;`, `|`, `&` rejected)
4. Configurable timeout enforcement (`CommandTimeoutSec`)

## Traceability

### Upstream

- ADR-2025-017: Ollama locked executor for scripted builds
- AGENT.md: Repository agent configuration

### Requirements

- OLLAMA-AGENT-001 to OLLAMA-AGENT-035 in `docs/requirements/ollama-executor-agent-requirements.csv`

### Downstream

- VS Code tasks 30–32 in `.vscode/tasks.json`
- Executor scripts under `scripts/ollama-executor/`
- Seed Docker container `Tooling/seed/Dockerfile`

## Change log

- 2025-12-03 — @copilot — Created ADR for ollama-executor custom agent
