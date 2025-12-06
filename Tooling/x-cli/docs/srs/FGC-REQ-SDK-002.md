# FGC-REQ-SDK-002 - x-sdk leverages GitKraken GK-CLI
Version: 1.0

## Description
The `x-sdk` repository shall leverage GitKraken's GK-CLI (pinned to v3.1.37) to streamline local developer workflows for multi-repo work items, commits, and pull requests.

## Rationale
Using a mature CLI for git and work item flows reduces bespoke tooling in x-sdk and provides a consistent UX across platforms.

## Verification
Method(s): Inspection | Demonstration
Acceptance Criteria:
- AC1. Integration docs reference GK-CLI v3.1.37 and provide install/usage guidance across OSes.
- AC2. Sample commands include authentication and basic work item flow (`gk auth login`, `gk work create`, `gk work commit --ai`, `gk work push`, `gk work pr create --ai`).

## Statement(s)
- RQ1. The SDK documentation SHALL reference GK-CLI v3.1.37 and provide version-pinned installation instructions.
- RQ2. The SDK documentation SHALL include example commands covering authentication, work item creation, commit, push, and PR creation.

## Attributes
Priority: Low
Owner: DevRel
Source: ADR-0022
Status: Accepted
Trace: docs/srs/FGC-REQ-SDK-002.md

