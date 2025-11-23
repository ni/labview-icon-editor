---
adr:
  id: "ADR-{YYYY}-{NNN}"
  title: "<short decision name>"
  status: "Proposed"   # Proposed | Accepted | Rejected | Deprecated | Superseded
  date: "2025-11-20"
  owner: "<person or team>"
  reviewers: ["<name1>", "<name2>"]
  tags: ["architecture"]
  supersedes: []        # e.g., ["ADR-2023-002"]
  superseded_by: null   # e.g., "ADR-2025-014"
  links:
    related_work_items: []      # e.g., Jira, GitHub issues
    related_requirements: []    # requirement IDs for traceability
    related_docs: []            # URLs/docs that informed the decision
---

# <short decision name>

## 1. Context
- **Problem statement**: <why is a decision needed?>  
- **Background & constraints**: <business/technical/regulatory>  
- **Decision drivers / quality attributes** (ranked): <e.g., Reliability, Security, Performance, Maintainability, Cost>  
- **In-scope / out-of-scope**: <boundaries so the decision is testable>

## 2. Options considered
1. **Option A** — <one-line summary>  
   - **Description**: <what it is / how it works>  
   - **Evidence / references**: <benchmarks, spikes, case studies>  
   - **Pros**: <bulleted>  
   - **Cons**: <bulleted>  
   - **Risks / unknowns**: <bulleted>  
2. **Option B** — …
3. **Option C** — …

## 3. Decision
- **Chosen option**: <Option X>  
- **Rationale**: <why this beats the alternatives against the drivers>  
- **Scope of applicability**: <systems, teams, boundaries>  
- **Assumptions**: <facts we rely on>  
- **Dependencies**: <things that must be true or delivered>

## 4. Consequences
- **Positive**: <benefits and opportunities>  
- **Negative / trade‑offs**: <costs, constraints, debt created>  
- **Follow‑up actions**: <what needs doing to realize the decision>

## 5. Implementation plan
- **Milestones & owners**: <who does what, when>  
- **Affected components**: <services, repos, data>  
- **Compatibility & migration**: <data, API, contract>  
- **Rollback strategy**: <how we back out safely>

## 6. Verification & validation
- **Success criteria / measures of performance**: <quantitative where possible>  
- **Verification method**: <inspection | analysis/simulation | demonstration | test>  
- **Validation with stakeholders**: <how we’ll confirm we built the right thing>

## 7. Security, privacy & compliance
- **Threats & mitigations**: <STRIDE or equivalent>  
- **Data protection**: <classification, retention, encryption>  
- **Regulatory impact**: <standards, laws, audits>

## 8. Traceability
- **Upstream** (business/stakeholder needs): <IDs>  
- **System/software requirements**: <IDs>  
- **Downstream** (tests / VCRM entry / monitoring): <IDs or links>

## 9. Open issues / TBD / TBR
- <ID> — <issue> — <owner> — <due>

## 10. Change log
- 2025-11-20 — <author> — Created
