# Viewpoints (definitions)

| Viewpoint | Purpose | Primary stakeholders | Concerns addressed | Notation |
|---|---|---|---|---|
| **Context** | System-in-environment scope & interfaces | CI, Users, Security | Boundaries, external interfaces, trust | Mermaid graph (C4-style) |
| **Container** | Major run-time containers/modules | Dev, QA, CI | Tech stack, interop, dependencies | Mermaid graph |
| **Component** | Internal structure of key containers | Dev, QA | Allocation of responsibilities, test seams | Mermaid graph |
| **Deployment** | Where/how it runs | CI, Release/CM, Ops | OS targets, packaging, config | Mermaid graph |

**Conformance notes**
- Each view states assumptions & constraints and references ADRs when decisions apply.
- **Correspondences** (see `Correspondences.md`) must hold across views; drift is flagged in reviews.
