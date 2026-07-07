# Scripts Agent Rules

```text
[TBG | Script Rules | scope: scripts]
```

## Purpose

Scripts are operational surfaces. Treat them as executable contracts, not helper notes.

## Rules

- Resolve repo root safely.
- Prefer explicit parameters over ambient assumptions.
- Emit machine-readable JSON for validators and readiness checks.
- Write artifacts under `artifacts/latest` when producing evidence.
- Keep dangerous runtime operations behind workflow contracts.
- Avoid hiding failures. Return clear verdicts and missing prerequisites.

## PowerShell expectations

Use:

```powershell
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
```

Use guarded path handling and avoid hard-coded user secrets.

## Runtime caution

Scripts that build, install, launch, or touch Bannerlord runtime state must require the proper runtime workflow contract and ForgeStop rule.
