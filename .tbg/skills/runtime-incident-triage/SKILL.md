---
name: runtime-incident-triage
description: Reconstruct bounded runtime incidents from completed observer runs and select the next safe diagnostic test without acting on Bannerlord.
---

# Skill: runtime-incident-triage

## Use when

- A completed observer run reports process loss, crash, hang, WER, TaleWorlds evidence, an open span, heartbeat stall, or observer gap.
- Running `ForgeRuntimeIncident.cmd`, `Resolve-TbgRuntimeIncident.ps1`, or the incident assembler validator.
- Selecting the next read-only diagnostic from a bounded incident timeline.

## Do not use when

- Starting, stopping, restarting, clicking, focusing, or otherwise controlling Bannerlord or its launcher.
- Treating window disappearance, stale logs, process presence, an open span, or observer absence as a confirmed crash or cleanup authority.
- Claiming a root cause, live certification, or proof level above the completed evidence.

## Read first

1. `AGENTS.md`
2. `.tbg/skills/manifest.json`
3. `.tbg/workflows/runtime-event-observation.contract.json`
4. `.tbg/workflows/runtime-context-continuity.contract.json`
5. `docs/architecture/runtime-incident-assembly.md`
6. `docs/handoff/runtime-incident-operator-guide.md`
7. `scripts/tbg/Resolve-TbgRuntimeIncident.ps1` (consume only)

## Operating boundary

The assembler is a read-only reconstruction entrypoint for a completed local observer run. It preserves observations, bounded inferences, hypotheses, and unknowns separately. `native_crash_confirmed` requires correlated process loss and external terminal evidence; an open span is only an unresolved boundary. An `incident_ready` trigger routes this skill but cannot certify a live runtime result.

## Owned scope

- `.tbg/skills/runtime-incident-triage/**`
- incident capability and trigger routing
- incident reconstruction guidance and static validation
- read-only incident result and timeline interpretation

## Forbidden scope

- observer, assembler, C#, schema, launcher, process, window, command-inbox, save, or gameplay implementation
- automatic restart, stop, kill, click, focus, or save mutation
- proof promotion or root-cause claims beyond correlated evidence

## Validation

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/tbg/Test-TbgRuntimeIncidentAssembler.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/tbg/Test-TbgSkillRouting.ps1
git diff --check
```

## Done gate

- The selected incident capability is read-only and names its completed-run input.
- Incident classifications remain bounded by the assembler contract.
- A trigger selects triage without granting actuation, cleanup, or live certification.
- Static validation does not claim live runtime proof.
