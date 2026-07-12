# Continuum Interoperability Sprint

## Context

- repo: `EndeavorEverlasting/BlacksmithGuild`
- branch: `feat/continuum-harness-interoperability`
- lane: harness architecture / integration experiment
- owned scope: capability classification, one-way export, schema, validation, and standalone boundaries
- forbidden scope: gameplay changes, Bannerlord runtime claims, implementation migration into Continuum, or cross-repository mutation

## Outcome

BlacksmithGuild now publishes a versioned inventory of harness capabilities that Continuum may consume experimentally.

The packet separates:

- generic cores that may become Continuum capabilities;
- BlacksmithGuild adapters and policies that remain authoritative;
- domain-locked Bannerlord and gameplay behavior that cannot enter Continuum's generic core.

## Operational surfaces

```text
.tbg/workflows/continuum-interoperability.contract.json
.tbg/harness/schemas/continuum-capability-packet.schema.json
scripts/tbg/Export-TbgContinuumCapabilityPacket.ps1
scripts/tbg/Verify-TbgContinuumInteroperability.ps1
docs/architecture/continuum-interoperability.md
```

## Candidate capabilities

- exact-head PR lifecycle
- repository-floor topology
- harness-maturity classification
- implementation closeout
- policy reporting

## Retained BlacksmithGuild authority

- repository policy and workflow names
- proof-level vocabulary
- artifact and local-path conventions
- Bannerlord process and launcher behavior
- saves, campaign state, route, movement, trade, economy, and smithing
- installed-game and live runtime evidence

## Validation

```powershell
pwsh -NoProfile -File scripts/tbg/Verify-TbgContinuumInteroperability.ps1
pwsh -NoProfile -File scripts/tbg/Export-TbgContinuumCapabilityPacket.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\test-powershell-utf8-bom-contract.ps1
git diff --check
```

`Governor Contracts` runs the verifier and exercises a temporary packet export on Linux. Installed-game Windows or Linux checks remain advisory and are not required for this architecture sprint.

## Next decision

The first consumer-side experiment belongs in Continuum and should import `TbgContinuumCapabilityPacket.v1` read-only. It should select repository-floor topology as the first parity target, reject domain-locked delegation, and return a report without mutating BlacksmithGuild.
