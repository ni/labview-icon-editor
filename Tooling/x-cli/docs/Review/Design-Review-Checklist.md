# Design Review Checklist — x-cli

## Readiness
- [ ] Design goals & non‑goals clearly stated
- [ ] Public CLI contract defined (usage, `--`, exit codes)
- [ ] Config model complete (env + JSON + precedence)
- [ ] Logging schema stable and testable
- [ ] Security constraints explicit (no network/process)
- [ ] Performance budget stated

## Architecture
- [ ] Component responsibilities separated (Parser, Router, Config, Policy, Engine, Logger, Guard)
- [ ] Diagram(s) included and readable
- [ ] Extensibility points documented

## Verification
- [ ] Requirements → Code → Tests mapped (traceability)
- [ ] JSON schema test exists
- [ ] IsolationGuard test(s) exist
- [ ] Perf test(s) exist (informational)

## Documentation
- [ ] Help text instructive (lists env vars & JSON)
- [ ] Example config included
- [ ] Release notes expectations clear (breaking changes policy)

## Sign‑off
- [ ] Maintainer
- [ ] CI owner
- [ ] QA/test owner
- [ ] Security/champ (can be maintainer on small projects)
