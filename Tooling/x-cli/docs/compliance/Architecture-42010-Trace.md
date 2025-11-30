# 42010 Architecture Trace

| 42010 Topic | Where Addressed | Notes |
|---|---|---|
| Stakeholders & Concerns | `docs/architecture/Stakeholders-Concerns.md` | Roles, concerns, measurable fit criteria |
| Viewpoints | `docs/architecture/Viewpoints.md` | Context / Container / Component / Deployment |
| Views | Context → `docs/architecture/Context.md` • Container → `docs/architecture/Container.md` • Component → `docs/architecture/Component.md` (legacy: `docs/Component.md`) • Deployment → `docs/architecture/Deployment.md` | C4-style minimal packet |
| Correspondences | `docs/architecture/Correspondences.md` | Rules & instances linking views and decisions |
| Decisions (ADRs) | `docs/adr/README.md` | Index of numbered ADRs with status/date |
| Traceability | `docs/Design.md` (Architecture section) • `docs/VCRM.csv` (if used) | Requirements ↔ Tests ↔ Code hooks; see ADRs 0011–0014 |

## Review Checklist
- [ ] All links in Design.md “Architecture Packet” resolve to the current files.
- [ ] ADR Index lists the latest decisions with correct status; supersessions reflected.
- [ ] Correspondence rules hold (Context↔Deployment; Container↔Component; Design↔ADRs).
