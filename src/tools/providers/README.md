# providers

**Path:** `tools/providers`  
**Languages:** JSON  
**Entrypoints:** n/a

## Overview
Set-StrictMode -Version Latest

### Naming Conventions

- **labviewcli** – provider folders that expose the `labviewcli` command surface (PID tracker, CompareVI, etc.). Even if an upstream toggle eventually hops into g-cli, use this spelling when the command you’re wiring up is `labviewcli`.
- **g-cli** – provider folders that expose the `g-cli` command surface (VIPM/NIPM tooling). These flows may launch LabVIEW indirectly, but we keep the hyphenated name to distinguish the entry point.

Tests don’t need to know which layer ultimately starts LabVIEW; they only care which CLI command they’re exercising. This README mirrors the guidance in `docs/tooling-naming.md`.

## Usage
TBD. Document basic usage and examples here.

## Inputs / Outputs
- **Inputs:** TBD
- **Outputs:** TBD

## Dependencies
- None detected

## Contents
- `gcli/Provider.psm1`
- `gcli/gcli.Provider.psd1`
- `labviewcli/Provider.psm1`
- `labviewcli/labviewcli.Provider.psd1`
- `spec/operations.json`
- `spec/providers.json`
- `vipm/Provider.psm1`
- `vipm/vipm.Provider.psd1`
- `vipm-gcli/Provider.psm1`
- `vipm-gcli/vipm-gcli.Provider.psd1`

## Maintenance
- **Owner:** TBD
- **Status:** Active

## License
- Inherit repo license unless overridden here.
