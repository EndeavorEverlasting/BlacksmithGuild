---
name: route-visible-trade
description: Own campaign readiness acceptance, route start, route-owned time, movement, arrival, buy and sell deltas, legitimate resource use, and visible trade proof after the launcher-to-campaign continuity gate.
---

# Skill: route-visible-trade

## Use when

- Accepting a fresh `campaign.automation.ready` event from the canonical continuity workflow.
- Starting or resuming an in-game route after a task-specific workflow independently grants gameplay authority.
- Verifying visible movement, checkpoints, arrival, town entry, buying, selling, or trade deltas.
- Editing `src/BlacksmithGuild/MapTrade/**`.
- Working on route-owned clocks, pause/focus effects, or legitimate gameplay-resource boundaries.

## Do not use when

- Repairing launcher scripts without changing route behavior.
- Treating launcher handoff, runtime observer attachment, `SetupPhase.MapTransition`, bare `MapReady`, route assignment, command ACK, a timer, or a trigger match as movement or campaign automation readiness.
- Acting on `campaign.automation.ready` when `runId`, `correlationId`, game session, observer health, stability window, or command-poll readiness is stale, missing, mismatched, or blocked.
- Treating the campaign readiness cascade as gameplay authority. It is routing and notification only.
- Claiming arrival without position or settlement evidence.
- Claiming trade without inventory and gold deltas.
- Bypassing stamina, material, travel, economy, or other legitimate gameplay costs.

## Read first

1. `AGENTS.md`
2. `.tbg/skills/manifest.json`
3. `.tbg/workflows/launcher-to-campaign-event-continuity.contract.json`
4. `.tbg/workflows/runtime-event-observation.contract.json`
5. `.tbg/harness/triggers.d/campaign-readiness-cascade.trigger.json`
6. `docs/handoff/launcher-to-campaign-event-continuity.md`
7. `docs/handoff/recursive-campaign-assist-loop.md`
8. `docs/control/logs/open/autonomous-assist-session-target.md`
9. current `src/BlacksmithGuild/MapTrade/**`
10. the active route workflow, cert, and runtime evidence

## Campaign readiness acceptance

The route lane may accept the campaign surface only when the current correlated event lineage contains:

```text
launch.handoff.verified
  -> runtime.observer.attached
  -> game.runtime.lifecycle.observed
  -> campaign.map.transition_observed
  -> campaign.map.ready_observed
  -> campaign.readiness.stable
  -> campaign.command_poll.ready
  -> campaign.automation.ready
  -> campaign.readiness.cascade_published
```

The accepting packet must show the same `runId`, `correlationId`, and game session, plus:

- `sessionReady:true`;
- `mapReady:true`;
- `campaignReady:true`;
- `canPollFileInbox:true`;
- healthy runtime observer;
- live correlated game process;
- no unreconciled observer gap or process loss;
- at least 60 seconds of stable map-ready evidence.

A campaign readiness trigger routes the packet. It grants no movement, command-inbox, save, trade, smithing, or engine-enable authority. The active route workflow must separately grant the requested gameplay mutation and name its proof contract.

## Behavior proof sequence

```text
campaign automation ready
  -> task-specific authority
  -> command correlated
  -> route started
  -> position changed
  -> checkpoint or arrival
  -> buy/sell delta
  -> terminal evidence
```

A checkpoint is progress, not completion. Focus, unpause, clock ownership, observer gaps, and operator contamination must be recorded when they affect autonomous movement.

## Owned scope

- `src/BlacksmithGuild/MapTrade/**`
- route workflow contracts and route cert schemas
- campaign readiness acceptance and lineage validation for route entry
- movement, position, checkpoint, arrival, and trade evidence
- route-specific tests and validators
- legitimate gameplay-resource policy for route execution

## Forbidden scope

- launcher-only script refactors
- changing the launcher-to-campaign continuity contract in a route-only sprint
- free gold, free inventory, teleportation, or fake completion
- save mutation outside an explicit workflow
- stale certs or readiness packets used as current proof
- gameplay mutation from the readiness trigger alone
- unrelated agent, skill, or repo-floor rewrites

## Validation

Run the current route contract validators, build, exact-head deployment checks, and runtime evidence collection required by the claimed level. Also run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/tbg/Test-TbgLauncherToCampaignContinuity.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/tbg/Test-TbgRuntimeEventObservation.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/tbg/Test-TbgTriggerFragments.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/tbg/Test-TbgSkillRouting.ps1
powershell -File scripts/test-powershell-utf8-bom-contract.ps1
git diff --check
```

## Done gate

- Launcher handoff, runtime attachment, map transition, map ready, campaign ready, command-poll ready, route start, movement, arrival, and trade claims remain separate.
- `campaign.automation.ready` is accepted only from the same fresh correlated observer lineage after a complete 60-second stable map-ready interval.
- The campaign readiness cascade grants no gameplay authority; the active route workflow supplies separate authority.
- Numeric or visible evidence supports every behavior claim.
- Exact head and loaded implementation identity are known for runtime claims.
- Legitimate gameplay costs remain enforced.
- Manual contamination, observer gaps, and pause/focus conditions are reported.
