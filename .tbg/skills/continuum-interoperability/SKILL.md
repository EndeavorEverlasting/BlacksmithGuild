---
name: continuum-interoperability
description: Export and evaluate reusable BlacksmithGuild harness capabilities for Continuum without creating a build, validation, launch, or runtime dependency.
---

# Skill: continuum-interoperability

## Use when

- Exporting a BlacksmithGuild capability packet to Continuum.
- Classifying generic harness core versus the BlacksmithGuild adapter.
- Evaluating whether implementation may be extracted after parity proof.
- Updating Continuum interoperability contracts, schemas, exporters, or verifiers.

## Do not use when

- Moving route, smithing, economy, trade, save, campaign, launcher, or gameplay authority out of BlacksmithGuild.
- Making Continuum required for build, validation, launch, or runtime.
- Removing duplicated implementation before parity, fallback, and rollback proof exists.
- Claiming runtime proof from packet export.

## Read first

1. `AGENTS.md`
2. `.tbg/skills/manifest.json`
3. `.tbg/workflows/continuum-interoperability.contract.json`
4. `docs/architecture/continuum-interoperability.md`
5. `scripts/tbg/Export-TbgContinuumCapabilityPacket.ps1`
6. `scripts/tbg/Verify-TbgContinuumInteroperability.ps1`

## Authority and proof boundary

BlacksmithGuild remains the product authority. Export metadata before moving implementation. Delegation requires Continuum parity tests, an app-owned adapter, standalone fallback proof, and a separate extraction sprint with rollback instructions.

This skill may prove classification, packet generation, source inventory, and standalone-boundary checks. It may not prove a Continuum importer, delegated execution, launcher behavior, gameplay, or live runtime success.

## Owned scope

- `.tbg/workflows/continuum-interoperability.contract.json`
- Continuum capability schemas
- `scripts/tbg/*Continuum*.ps1`
- `docs/architecture/continuum-interoperability.md`
- export artifacts and parity planning

## Forbidden scope

- product-domain source extraction
- build or runtime dependency on Continuum
- network mutation from the exporter
- route, save, launcher, trade, economy, or smithing behavior
- removal of fallback implementation in this lane

## Validation

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/tbg/Verify-TbgContinuumInteroperability.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/tbg/Test-TbgSkillRouting.ps1
powershell -File scripts/test-powershell-utf8-bom-contract.ps1
git diff --check
```

## Done gate

- Generic core and app adapter are classified separately.
- Exported metadata names source paths, proof, fallback, and extraction status.
- BlacksmithGuild remains standalone.
- Domain-locked authority is unchanged.
- Any extraction remains a separately authorized sprint.
