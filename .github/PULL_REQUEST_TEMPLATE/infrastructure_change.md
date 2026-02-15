# Infrastructure Change

## Summary
- Related issue/discussion:
- Scope (what changed):
- Why this is needed:
- Out of scope:

## Change Type
- [ ] GitHub workflow (`.github/workflows`)
- [ ] Composite action (`.github/actions`)
- [ ] PowerShell/tooling (`Tooling/`)
- [ ] Runner/env contract (paths, vars, locks, dependencies)
- [ ] CI policy/gates/concurrency
- [ ] Other (describe):

## Version Increment Label
- [ ] Exactly one canonical release label is applied (`Version Increment: Major`, `Version Increment: Minor`, or `Version Increment: Patch`)
- [ ] Compatibility aliases are accepted during migration (`major`, `minor`, `patch`) and will be deprecated after two release cycles

## Risk and Impact
- Risk level: [ ] Low [ ] Medium [ ] High
- Primary failure mode(s):
- Blast radius (jobs/branches/runners/users affected):
- [ ] Permission/token scope changed and documented
- [ ] Secret/variable additions or renames documented
- [ ] No auth/secret/permission changes

## Test Evidence
### Automated
- [ ] Relevant workflow run(s) passed (link):
- [ ] Local parity or targeted script run completed (command + result):
- [ ] Failure-path/guardrail behavior validated (if applicable)

### Manual
- [ ] Affected path validated end-to-end
- [ ] Non-affected path smoke-checked
- Logs/artifacts/notes:

## Rollout and Rollback
- Rollout plan (order + scope):
- Post-merge validation (what/where/how long):
- Rollback trigger(s):
- Rollback steps:
- [ ] No migration/stateful changes
- [ ] Migration/stateful changes documented

## Documentation and Ops Notes
- [ ] Docs/runbook updated in-repo (`docs/` or `Tooling/README.md`)
- [ ] No documentation updates required (reason):
- Follow-up tasks (if any):
