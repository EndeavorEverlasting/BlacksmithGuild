# Launcher-to-Campaign Event Continuity

```text
[TBG | launcher-to-campaign continuity | observer overlap | campaign readiness cascade]
```

## Operator answer

The repository has separate Windows-window and game-runtime observers, but their existence alone does not prove an uninterrupted listener. Continuous coverage requires one shared `runId` and `correlationId`, an overlap interval across the final launcher handoff, a runtime-observer attachment acknowledgement before the window observer retires, and a gap/reconciliation ledger.

The final launcher window is a checkpoint. It must produce a verified Singleplayer-host handoff and a matched runtime-observer attachment. Window disappearance, a sent click, or a launcher terminal state is not campaign readiness.

The campaign map has a readiness release trigger only after the in-game producer establishes all of the following for the same current session:

- `sessionReady:true`;
- `mapReady:true`;
- `campaignReady:true`;
- `canPollFileInbox:true`;
- runtime observer healthy;
- game process alive;
- a complete 60-second stable map-ready interval;
- no unreconciled observer gap or process-loss event.

The resulting `campaign.automation.ready` event routes to the campaign-readiness cascade. That cascade tells registered consumers that the readiness gate passed, but it does not grant movement, trade, save, command-inbox, or other gameplay authority. Each downstream workflow still owns its own authority and proof.

## Canonical chain

```text
observer.window.started
  -> observer.runtime.started
  -> launch.path.selected
  -> launcher surface events
  -> launch.handoff.verified
  -> runtime.observer.attached
  -> observer.window.retired (optional, only after attachment ACK)
  -> game.runtime.lifecycle.observed
  -> campaign.map.transition_observed
  -> campaign.map.ready_observed
  -> campaign.readiness.stable
  -> campaign.command_poll.ready
  -> campaign.automation.ready
  -> campaign.readiness.cascade_published
```

`SetupPhase.MapTransition` is not `MapReady`. `MapReady` without `campaignReady` and `canPollFileInbox` is not automation readiness. Launcher handoff, process presence, window title, command ACK, stale status JSON, or a trigger match cannot substitute for the full gate.

## Tracked authority

- `.tbg/workflows/launcher-to-campaign-event-continuity.contract.json`
- `.tbg/harness/policies/harness-doctrine.policy.json`
- `.tbg/workflows/runtime-event-observation.contract.json`
- `.tbg/harness/fixtures/event-continuity/launcher-to-campaign-continuity.fixture.json`
- `.tbg/harness/triggers.d/launcher-handoff-runtime-attach.trigger.json`
- `.tbg/harness/triggers.d/runtime-observer-attachment.trigger.json`
- `.tbg/harness/triggers.d/campaign-readiness-cascade.trigger.json`
- `scripts/tbg/Test-TbgLauncherToCampaignContinuity.ps1`

## Proof boundary

The doctrine, contracts, fixture, triggers, validator, catalog registration, and CI prove repository/static enforcement only. They do not prove that the current launcher scripts, runtime observer, in-game module, or campaign-map producer already emit the full chain. That requires a separate implementation and authorized live-certification sprint.
