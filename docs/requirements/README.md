# Requirements Documentation

This directory contains the formal requirements for the labview-icon-editor project.

## Overview

Requirements are managed in CSV format to enable easy processing, filtering, and reporting while maintaining traceability to implementation and tests.

## Files

- **requirements.csv**: Main requirements database with all requirement attributes
- **requirements_29148_flags.csv**: Requirements annotated with ISO 29148 compliance flags
- **requirements_rewritten_29148_flags.csv**: Rewritten requirements for improved ISO 29148 compliance
- **glossary.md**: Definitions of key terms used in requirements
- **set-quality-checklist.md**: Quality checklist for requirements set
- **dotnet-runner.md**: Documentation for .NET tooling used for requirements processing

## Requirements Structure

Each requirement in the CSV includes the following key attributes:

- **ID**: Unique identifier for the requirement
- **Section**: Category or subsystem the requirement belongs to
- **Statement**: The actual requirement text
- **Type**: Type of requirement (Functional, Process, etc.)
- **Priority**: Relative importance (High, Medium, Low)
- **Verification Method**: How the requirement will be verified (Test, Inspection, etc.)
- **Status**: Current state (Planned, Proposed, Implemented, etc.)
- **Owner**: Individual or team responsible
- **Evidence/Implementation**: Links to code, tests, or documentation

## Tools

Requirements are processed using:

- **RequirementsSummarizer**: .NET tool for generating reports from requirements.csv
- **Python validation scripts**: Located in `.github/scripts/` for linting and quality checks

## Workflow

1. Add or update requirements in requirements.csv
2. Run validation scripts to check quality
3. Generate reports using RequirementsSummarizer
4. Review and baseline changes
5. Track implementation and verification status

## Standards Compliance

Requirements follow ISO 29148 guidelines for requirements engineering, emphasizing:

- Clear, unambiguous language
- Testability and verifiability
- Traceability to design and implementation
- Completeness and consistency

## More Information

For detailed information about specific requirements, use the RequirementsSummarizer tool to generate filtered reports or consult the full requirements.csv file.
