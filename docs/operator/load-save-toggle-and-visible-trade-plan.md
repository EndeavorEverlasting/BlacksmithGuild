# Load, Toggle, Travel, and Visible-Trade Operator Plan

```text
[TBG | Operator Load/Toggle/Visible Trade | implementation plan | branch: agent/route-automation-operator-plan]
```

## Context

- Repository: `EndeavorEverlasting/BlacksmithGuild`
- Sprint: post-PR #37/#41/#42 cleanup and operator control truth
- Scope: safe repository consolidation, route-start correctness, exact launch/hotkey instructions, worker-engine handoffs, and the implementation order for a visible trade cycle
- Forbidden claims: exact named-save load without identity evidence; route start presented as arrival; command ACK presented as completion; API buy presented as a visible marketplace UI; fake gold, items, movement, stamina, or XP
- Canonical machine catalog: `.tbg/operator/control-surface.json`
- Workflow contract: `.tbg/workflows/continue-visible-trade-cycle.contract.json`

This plan distinguishes what a user can test now from the complete product target. It uses Bannerlord's mechanisms. It does not grant free outcomes or substitute evidence for gameplay.

## Repository hygiene gate

Do not begin a user runtime test until all of these are true:

1. The test branch is based on current `origin/main`.
2. `git status --short` is empty.
3. `git diff --check` passes.
4. The route, engine-authority, operator-control, and Governor contract verifiers pass.
5. The Windows build passes with Bannerlord closed.
6. No merge, rebase, or cherry-pick is in progress.
7. Runtime evidence from an older branch is not being reused as a new PASS.

PRs #37, #41, and #42 were consolidated before this plan branch was created. The stale local composite previously being merged into `feat/route-owned-clock-resume` was rejected; only the seven unique route-owned-clock commits were replayed on current main.

## Before launching

1. Use a disposable or backed-up single-player SandBox save for automation validation.
2. Save and exit Bannerlord normally before a build/install.
3. If a Forge or assist runner is still active, stop the automation shell:

```powershell
.\ForgeStop.cmd soft
```

4. Use `force` only as an emergency. It kills Bannerlord and can lose unsaved progress:

```powershell
.\ForgeStop.cmd force
```

## Load an existing game

From the repository root:

```powershell
.\ForgeContinue.cmd
```

What this does:

- builds/installs through the repository launch path;
- selects Bannerlord's native **Continue** option;
- waits for game/runtime attach.

What this does **not** prove:

- it does not select a save by file name;
- it does not prove that `BlacksmithGuild_DevStart.sav` or any other named save was loaded;
- the existence of a dev save is not loaded-save identity.

After the campaign appears:

1. Confirm the expected character, clan, and location in the game UI.
2. Return to the open campaign map and close panels that can swallow hotkeys.
3. Press **F7**.
4. Confirm `campaignReady: true`.
5. Treat an unexpected character/save as a hard stop. Do not enable Automation.

The final visible-trade CMD must add `requestedSaveId`, `loadedSaveId`, and `identityVerified` before it may claim `save_loaded`.

## Automation hotkeys

### Global mode: Ctrl+Alt+T

On a campaign hotkey surface, press **Ctrl+Alt+T** to cycle:

```text
Manual -> Hybrid -> Automation -> Manual
```

Read the lower-left notice:

```text
Engines: Manual
Engines: Hybrid
Engines: Automation
```

Do not assume the starting mode. Cycle until the notice shows the mode you want.

- **Manual**: autonomous takeover is off; entering Manual requests hold/abort for active MapTrade and GuildLoop routes.
- **Hybrid**: explicit user/CMD actions are allowed, but autonomous MapTrade tick startup is off.
- **Automation**: higher-order autonomous startup is permitted. This is permission, not proof that any action succeeded.

The route tick now checks `IsAutomationEnabled(MapTrade)`. A successful automatic start returns immediately, so a cached pre-start town-menu state cannot cancel the new move order in the same tick.

### Immediate movement abort: Ctrl+Alt+B

Press **Ctrl+Alt+B** on a safe campaign surface to abort active TBG movement automation:

- autonomous guild loop;
- cohesion move;
- MapTrade route;
- auto-travel.

This is an in-game movement abort. It does not terminate a separate PowerShell runner.

### External runner stop

For `Run-AutonomousAssistSession.cmd` or another Forge runner, use:

```powershell
.\ForgeStop.cmd soft
```

The in-game **Ctrl+Alt+T** and **Ctrl+Alt+B** controls do not by themselves prove that an external runner finalized its evidence.

## Current runnable mechanism test

This is the strongest honest user test available now. It is not yet the final visible marketplace cycle.

1. Load the expected existing save with `ForgeContinue.cmd`.
2. Confirm the character and press **F7** on the campaign map.
3. Press **Ctrl+Alt+T** until the notice says `Engines: Automation`.
4. Start one bounded guild-loop cycle:

```powershell
.\Run-AutonomousGuildLoop.cmd
```

5. Return focus to the game and watch:
   - lower-left TBG route notices;
   - the party begin real campaign-map movement;
   - arrival/blocked notices;
   - any bounded buy attempt notice.
6. Stop at any time with **Ctrl+Alt+T** until `Manual`, or use **Ctrl+Alt+B** for an immediate movement abort.
7. Export evidence:

```powershell
.\Run-ExportEvidence.cmd
```

8. Inspect:

```text
docs/evidence/latest/BlacksmithGuild_MapTradeRouteCert.json
docs/evidence/latest/BlacksmithGuild_MapTradeCert.json
docs/evidence/latest/BlacksmithGuild_AutonomousGuildLoop.json
docs/evidence/latest/README.md
```

Important limitations:

- `Run-AutonomousGuildLoop.cmd` waits for command acknowledgement, not terminal loop completion. Keep observing the game/result files after the wrapper returns.
- PR #37's branch-selected route mission is a travel-only safety route. Route-start evidence does not prove arrival or trading.
- The buy driver can perform one bounded Bannerlord API buy and must record real gold and inventory deltas.
- Sell execution remains a stub.
- The automated trading screen is not opened for the user. A lower-left notice plus delta JSON is not the same proof level as visible marketplace UI.

## Worker-bee handoff truth

| Worker | Authority today | Implemented handoff | Honest gap |
|---|---|---|---|
| Governor | Real Automation gate | decision scheduling -> worker proposal | adapters still defer/block most worker execution |
| MapTrade | Real Manual/Hybrid/Automation gate | branch target -> route -> route/trade JSON | fresh town-menu movement proof; sell and trade-UI gaps |
| GuildLoop | Real gate | market -> route/cohesion -> bounded trade/forge -> loop report | root CMD is ACK-based, one cycle only |
| Cohesion | Mode label exists, service gate incomplete | analysis -> explicit move -> evidence | global mode is not a complete Cohesion gate |
| HorseMarket | Mode label exists, service gate incomplete | advisory -> optional MapTrade pack mission | no general horse-acquisition loop |
| Smithing | Mode label exists, service gate incomplete | advisory -> one refine/smelt -> evidence | crafting/rest loop absent; not mode-gated |
| Companion | Mode label exists, service gate incomplete | tavern intel -> explicit recruitment test | not part of autonomous guild loop |
| Assistive | Real gate | runtime readiness -> explicit action/runner -> evidence | external runner lifecycle is a separate control plane |

Every worker handoff in the final cycle must carry one correlation identity with:

```text
schemaVersion
runId
correlationId
branch
headSha
effectivePolicyId
producer
consumer
stage
inputDigest
decisionOrResult
blockers
evidenceLinks
nextAction
terminal
```

PR #41's effective-policy context is the foundation. Legacy PRs #20 and #28-#33 contain useful fragments, but no legacy stack is a complete correlated worker handoff and none should be merged wholesale.

## Proof ladder

The final workflow must advance each level separately:

1. **Save loaded**: requested and loaded save identities match.
2. **Route started**: fresh exact-target route cert and command acceptance.
3. **Movement observed**: positive party distance, clock running, no immediate hold.
4. **Arrival observed**: fresh target-settlement arrival state.
5. **Trade proven**: real gold and inventory deltas with `fakeGameplayDelta=false`.
6. **Trade UI visible**: marketplace/trade surface visibly opened for the user.
7. **Terminal handoff**: linked English and machine result name the outcome, blockers, and next engine.

No lower level may satisfy a higher level.

## Implementation order for the final CMD

The future `Run-TbgVisibleTradeCycle.cmd` must be implemented in this order:

1. Exact save request and loaded-save identity.
2. Pre-launch Manual mode and in-game effective-mode visibility.
3. One terminal-waiting wrapper with a run/correlation ID.
4. Exact-target route start and positive movement proof.
5. Arrival and town-entry proof.
6. One real buy with gold/inventory deltas.
7. Visible marketplace/trade-screen proof.
8. Sell leg.
9. Pack-animal acquisition branch.
10. Bounded smithing refine/smelt handoff.
11. Only then multi-cycle worker orchestration.

Do not create the root CMD as a stub that merely forwards an ACK-producing command.

## Validation

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-route-branch-autostart-contract.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-route-owned-clock-resume-contract.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-route-owned-clock-live-proof-collector-contract.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-engine-toggle-authority-contract.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-operator-control-surface.ps1
dotnet build src\BlacksmithGuild\BlacksmithGuild.csproj --configuration Debug --no-restore
git diff --check
```

## Gaps and risks

- No new live gameplay PASS is claimed by this plan or its static verifiers.
- Native Continue does not prove named-save identity.
- The current route changes require fresh movement evidence from a town-menu attach.
- Engine labels for Cohesion, HorseMarket, Smithing, and Companion are not complete service gates.
- A user can see notices and map movement, but fully visible automated marketplace trading is not implemented.

## Next command

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-operator-control-surface.ps1
```
