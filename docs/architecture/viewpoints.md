# Architecture Viewpoints (ISO/IEC/IEEE 42010)

**Purpose**: Declare the viewpoints framing our architecture views and concerns; reference model kinds and view methods.

## Viewpoint: Operational (Users)
- **Concerns**: Usability, editor behavior, portability.
- **Views**: C4 Context/Container; user flows.
- **Model kinds**: Behavioral/state; data (icon text).

## Viewpoint: Developer/Build (Maintainers)
- **Concerns**: Structure, build, packaging.
- **Views**: C4 Component/Deployment; build/release workflows.
- **Model kinds**: Component & dependency; workflow graphs.

## Viewpoint: QA/Release (Automation QA / Release Manager)
- **Concerns**: Verification, traceability, release evidence.
- **Views**: Test models; RTM and TRW checklists; CI evidence.
- **Model kinds**: Test model (29119 section 8.2), trace matrices, readiness reports.

## Correspondences
- RTM ↔ Code ↔ Tests: `../requirements/rtm.csv`
- TRW ↔ Tag & Release workflow: `../requirements/TRW_Verification_Checklist.md`

## Decisions & Rationale
- See `../adr/` (e.g., ADR-2025-001) for recent decisions guiding these viewpoints.
