# ADR 0001: Adopt ADRs (MADR) and a repository‑root `agent.yaml` as the single source of truth for our AI agent

*Status*: **Accepted**  
*Date*: 2025-11-20  
*Deciders*: Architecture, Product, ML/AI, Security

## Context and Problem Statement
We need a durable, reviewable way to (a) record significant architectural decisions and (b) define the behavior and boundaries of our AI agent in a single place that is easy to audit, test, and version. Prior decisions and configuration have been scattered across docs, code comments, and environment‑specific UIs.

## Decision
1. Use **Architecture Decision Records (ADRs)** stored under `docs/adr/`, named `NNNN-title.md` with zero‑padded sequence numbers (starting at 0001), using a concise MADR‑style structure.
2. Create and maintain a repository‑root `agent.yaml` as the **single source of truth** for agent identity, goals, guardrails, model selection, and capabilities.

## Decision Drivers
- **Traceability and verification**: Requirements and constraints shall be written with clear, testable language (binding provisions use *shall*; preferences use *should*; allowances use *may*; avoid subjective or open‑ended terms). This follows the requirements language guidance and characteristics of good requirements. fileciteturn0file2
- **Version control and reviewability**: Both ADRs and `agent.yaml` live in the repo and are reviewed via pull requests.
- **Operational simplicity**: One config file minimizes drift across environments.

## Considered Options
- **A. ADRs + `agent.yaml` in the repo (chosen)**
- **B. Wiki pages + ad‑hoc config in code comments**
- **C. Proprietary UI for agent configuration**

### Pros and Cons of the Options
**A. ADRs + `agent.yaml` (chosen)**
- Pros: versioned, testable, auditable; supports CI checks; easy to diff and roll back.
- Cons: small upfront effort to define schema and checks.

**B. Wiki + comments**
- Pros: low barrier to start.
- Cons: untestable, tends to drift; poor traceability; no PR gate.

**C. Proprietary UI**
- Pros: visual convenience.
- Cons: hard to version and test; vendor lock‑in; limited automation.

## Requirements (Acceptance Criteria)
The following *shall* statements are binding and verifiable. They use unambiguous “shall/should/may” wording and avoid vague language, per good practice for requirements. fileciteturn0file2

- **R‑001**: The repository **shall** contain `agent.yaml` at the root describing agent identity, goals, model, capabilities, safety guardrails, and revision metadata.
- **R‑002**: `agent.yaml` **shall** include, at minimum:
    - `metadata.name`, `metadata.version`, `metadata.owners[]`, and `description`.
    - `goals[]` with succinct, outcome‑oriented statements.
    - `model.provider`, `model.name`, `model.temperature`, and `model.max_tokens` (or analogous fields).
    - `capabilities[]` (enabled/disabled) and any `tools[]` the agent may call.
    - `safety` guardrails (e.g., PII redaction, external‑network policy) and I/O limits.
    - `revision.last_modified` (ISO‑8601 date) and `revision.authors[]`.
- **R‑003**: All binding statements in ADRs and `agent.yaml` **shall** use *shall*; preferences **should** use *should*; allowances **may** use *may*; vague, subjective terms **shall** be avoided (see lint rules for disallowed phrases). fileciteturn0file2
- **R‑004**: Each ADR **shall** include Status, Date, Context, Decision, Consequences, and be uniquely identified by a zero‑padded sequence number.
- **R‑005**: CI **shall** validate that `agent.yaml` is well‑formed YAML and contains the mandatory keys in R‑002.

## Verification
- **Inspection**: Validate presence of required sections/keys and wording (e.g., that binding items use *shall*). fileciteturn0file2
- **Analysis**: Static checks (e.g., lints/schemas) confirm shape and allowable values. fileciteturn0file2
- **Demonstration/Test**: Run a dry‑run that loads `agent.yaml` and verifies capabilities toggles behave as intended. fileciteturn0file2

## Consequences
- Positive: repeatable configuration; clear history of decisions; easier audits and onboarding.
- Negative: minor upfront overhead to maintain ADRs and schema; mitigated with templates and CI.

## Links
- Initial config: `/agent.yaml`
- Standard referenced for requirement quality and phrasing (internal copy available to the team). fileciteturn0file2
