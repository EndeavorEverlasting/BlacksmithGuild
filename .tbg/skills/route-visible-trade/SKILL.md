---
name: route-visible-trade
description: Own campaign readiness, route start, route-owned time, movement, arrival, buy and sell deltas, legitimate resource use, and visible trade proof.
---

# Skill: route-visible-trade

## Use when

- Starting or resuming an in-game route.
- Verifying visible movement, checkpoints, arrival, town entry, buying, selling, or trade deltas.
- Editing `src/BlacksmithGuild/MapTrade/**`.
- Working on route-owned clocks, pause/focus effects, or legitimate gameplay-resource boundaries.

## Do not use when

- Repairing launcher scripts without changing route behavior.
- Treating campaign readiness, route assignment, command ACK, or a timer as movement.
- Claiming arrival without position or settlement evidence.
- Claiming trade without inventory and gold deltas.
- Bypassing stamina, material, travel, economy, or other legitimate gameplay costs.

## Read first

1. `AGENTS.md`
2. `.tbg/skills/manifest.json`
3. `docs/handoff/recursive-campaign-assist-loop.md`
4. `docs/control/logs/open/autonomous-assist-session-target.md`
5. current `src/BlacksmithGuild/MapTrade/**`
6. the active route workflow, cert, and runtime evidence

## Behavior proof sequence

```text
campaign ready -> command correlated -> route started -> position changed -> checkpoint or arrival -> buy/sell delta -> terminal evidence
```

A checkpoint is progress, not completion. Focus, unpause, clock ownership, and operator contamination must be recorded when they affect autonomous movement.

## Owned scope

- `src/BlacksmithGuild/MapTrade/**`
- route workflow contracts and route cert schemas
- movement, position, checkpoint, arrival, and trade evidence
- route-specific tests and validators
- legitimate gameplay-resource policy for route execution

## Forbidden scope

- launcher-only script refactors
- free gold, free inventory, teleportation, or fake completion
- save mutation outside an explicit workflow
- stale certs used as current proof
- unrelated agent, skill, or repo-floor rewrites

## Validation

Run the current route contract validators, build, exact-head deployment checks, and runtime evidence collection required by the claimed level. Also run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/tbg/Test-TbgSkillRouting.ps1
powershell -File scripts/test-powershell-utf8-bom-contract.ps1
git diff --check
```

## Done gate

- Campaign, command, route-start, movement, arrival, and trade claims remain separate.
- Numeric or visible evidence supports every behavior claim.
- Exact head and loaded implementation identity are known for runtime claims.
- Legitimate gameplay costs remain enforced.
- Manual contamination and pause/focus conditions are reported.
