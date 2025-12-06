# Correspondences & Consistency

**Rules**
1. **Context ↔ Deployment:** External interfaces shown in Context must appear in Deployment endpoints.
2. **Container ↔ Component:** Every container responsibility has at least one realizing component.
3. **Design ↔ ADRs:** Each significant technology/packaging/security choice links to an ADR.
4. **Architecture ↔ Tests:** Key responsibilities have tests (unit/integration); logger JSON schema is verified.
5. **Architecture ↔ SRS/RTM:** Each critical capability maps to requirements with verification hooks.

**Examples (seed)**
- Logging JSON schema ↔ `InvocationLogger` ↔ tests in `tests/XCli.Tests/SpecCompliance/*`.
- IsolationGuard rules ↔ policy tests; absence of process exec/network in tests/CI.
