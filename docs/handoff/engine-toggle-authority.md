# Engine Toggle Authority

This document is the authoritative plan and current implementation note for shared engine toggles.

The problem is that engine state was historically split across raw booleans, command handlers, hotkeys, and higher-order systems:

```text
DevToolsConfig.MapTradeAutonomousMode
DevToolsConfig.GuildLoopAutonomousMode
DevToolsConfig.CampaignRuntimeGovernorAutonomousMode
DevToolsConfig.CampaignRuntimeGovernorAllowBoundedExecution
DevHotkeyHandler direct commands
DevCommandBus file-inbox commands
Governor / Route Council / Regent decisions
```

The desired model is one repeatable authority that can be used by users, hotkeys, scripts, and higher-order engines.

## Core doctrine

```text
Engine toggling is a shared runtime function, not a scattered config edit.

Manual mode means user-driven and read-only surfaces are preferred.
Hybrid mode means explicit user/file-inbox commands may run visible mechanisms, but higher-order autonomous takeover remains off.
Automation mode means higher-order engines may drive enabled engines and bounded execution can be turned on through the same authority.

Higher-order engines may request a target engine mode, but they should do so through EngineToggleAuthority.
Users may cycle global mode through hotkeys.
Raw DevToolsConfig booleans are low-level switches, not the policy authority.
```

## Current implementation

The first implementation lives in:

```text
src/BlacksmithGuild/DevTools/EngineToggleAuthority.cs
```

It defines:

```text
EngineToggleMode:
  Manual
  Hybrid
  Automation

EngineToggleKey:
  Governor
  MapTrade
  GuildLoop
  Cohesion
  HorseMarket
  Smithing
  Companion
  Assistive
```

The global hotkey is:

```text
Ctrl+Alt+T
```

It cycles:

```text
Manual -> Hybrid -> Automation -> Manual
```

Operator instructions and current capability limits:
[load-save-toggle-and-visible-trade-plan.md](../operator/load-save-toggle-and-visible-trade-plan.md).

## Current mode behavior

### Manual

```text
Governor autonomous tick: off
Governor bounded execution: off
MapTrade autonomous route command: off
GuildLoop autonomous route command: off
Assistive mode: off
Read-only/intel commands: still expected to remain available where command surfaces allow them
```

### Hybrid

```text
Governor autonomous tick: off
Governor bounded execution: off
MapTrade explicit route command: allowed
GuildLoop explicit route command: allowed
Assistive mode: on
```

Hybrid is the normal human-in-the-loop test mode. It allows visible mechanisms to be triggered intentionally without giving the Governor full autonomous takeover.

### Automation

```text
Governor autonomous tick: on
Governor bounded execution: on
MapTrade explicit route command: allowed
GuildLoop explicit route command: allowed
Assistive mode: on
```

Automation mode allows higher-order engines to drive enabled runtime engines and allows governor-scoped bounded execution when separately enabled by authority. It is appropriate only when the operator has accepted the risk profile for the current save or session. It is not proof of runtime PASS by itself.

## Runtime control semantics

Mode changes are runtime control decisions, not cosmetic labels.

### Manual is an active stop/hold request

Manual mode must request hold or abort for already-active autonomous routes.

```text
Manual mode:
- disables future autonomous startup
- disables bounded execution
- disables assistive command acceptance for movement/action commands
- requests hold/abort for already-active autonomous routes
- preserves read-only/intel surfaces where safe
```

Manual is not merely a config preference. Manual is an operator control state.

### Hybrid is explicit-command mode

```text
Hybrid mode:
- read-only and intel commands are allowed
- explicit user/file-inbox visible-mechanism commands may run
- autonomous governor takeover remains off
- bounded execution remains off
- active autonomous loops must not continue unless explicitly commanded
```

Hybrid is not partial Automation. Hybrid is explicit-command mode.

### Automation is permission, not proof

```text
Automation mode:
- allows higher-order engines to drive enabled runtime engines
- allows governor-scoped bounded execution when separately enabled by authority
- may use route, trade, guild-loop, and assistive surfaces that have been enabled through authority
- does not prove that any live runtime mechanism succeeded
```

Automation is not runtime proof. Automation is permission for higher-order engines under bounded doctrine.

### Aggregate mode inference

Aggregate mode inference must obey this rule:

```text
Manual only when every known engine is Manual
Automation only when every known engine is Automation
Hybrid for every mixed state
```

Any per-engine mode change must recompute the aggregate global mode before BuildSummary, hotkey cycling, or operator display.

Mixed engine state is Hybrid.

### Bounded execution scope

Bounded execution is a Governor capability, not a general Automation capability.

```text
IsBoundedExecutionAllowed(engine) may return true only when:
- engine == Governor
- Governor mode == Automation
- CampaignRuntimeGovernorAllowBoundedExecution is true
```

Bounded execution belongs to Governor only.

### Assistive readiness

Assistive readiness must read EngineToggleAuthority.

```text
Assistive readiness doctrine:
- Manual mode must reject assistive movement/action commands.
- Hybrid and Automation may accept assistive commands only when the Assistive engine is enabled.
- Assistive readiness must read EngineToggleAuthority or an authority-owned config path.
- DevToolsConfig.AssistiveMode is not enough unless the command readiness path consumes it.
```

### Runtime surface obedience matrix

| Surface | Manual | Hybrid | Automation |
|---|---|---|---|
| Governor autonomous tick | off | off | on |
| Governor bounded execution | off | off | governor-only |
| MapTrade autonomous route | hold/abort active, no new autonomous start | explicit only | allowed if enabled |
| GuildLoop autonomous route | hold/abort active, no new autonomous start | explicit only | allowed if enabled |
| Assistive movement/action commands | reject | allow if Assistive enabled | allow if Assistive enabled |
| Read-only/intel commands | allow | allow | allow |

## Public API

Future code should prefer these calls:

```csharp
EngineToggleAuthority.SetGlobalMode(EngineToggleMode.Hybrid, "source")
EngineToggleAuthority.SetEngineMode(EngineToggleKey.MapTrade, EngineToggleMode.Automation, "Governor", "route council selected trade")
EngineToggleAuthority.IsEngineEnabled(EngineToggleKey.MapTrade)
EngineToggleAuthority.IsAutomationEnabled(EngineToggleKey.Governor)
EngineToggleAuthority.IsBoundedExecutionAllowed(EngineToggleKey.Governor)
EngineToggleAuthority.BuildSummary("source")
```

## Higher-order engine rule

Higher-order engines must not flip raw booleans directly.

Good:

```csharp
EngineToggleAuthority.SetEngineMode(EngineToggleKey.MapTrade, EngineToggleMode.Automation, "RouteCouncil", "trade vote won")
```

Bad:

```csharp
DevToolsConfig.MapTradeAutonomousMode = true;
```

## Test duration doctrine

PR #26 owns the repo-wide bounded test-duration doctrine. This PR must not carry a competing timeout doctrine.

The authority and its verifiers follow:

```text
docs/operator/test-duration-doctrine.md
docs/handoff/test-duration-policy.manifest.json
docs/handoff/test-duration-policy-agent-note.md
docs/handoff/test-duration-policy.refactor-plan.md
```

The default test posture is fast, bounded, and interruptible. Thirty seconds is the default budget for static verifiers, smoke tests, CMD wrapper tests, launcher/UI observations, runtime evidence probes, and bounded harnesses unless a named live-cert or explicit long-run profile is selected.

Future agents should keep offline verifiers and contract tests centered around 30 seconds. Longer waits are allowed only for live runtime proof such as launcher startup, disposable save bootstrap, or visible mechanics proof, and they must emit named classifications instead of hanging silently.

## Current boundary

This first slice adds the authority and the user hotkey. Existing engine services still use some low-level `DevToolsConfig` booleans, but those booleans are now mutated by the authority when the global mode changes.

The next implementation sprint should migrate direct readers to authority calls.

The next implementation sprint should migrate remaining direct readers to authority calls, especially:

```text
CampaignRuntimeGovernor.OnCampaignTick -> EngineToggleAuthority.IsAutomationEnabled(Governor)
CampaignRuntimeGovernor.AttachProposedActivity -> EngineToggleAuthority.IsBoundedExecutionAllowed(Governor)
future file-inbox commands once DevCommandBus is updated
```

Already migrated in this PR:

```text
MapTradeAutonomousService.StartRouteNow -> EngineToggleAuthority.IsEngineEnabled(MapTrade)
MapTradeAutonomousService.OnCampaignTick automatic branch start -> EngineToggleAuthority.IsAutomationEnabled(MapTrade)
AutonomousGuildLoopService.StartNow -> EngineToggleAuthority.IsEngineEnabled(GuildLoop)
AssistReadinessEvaluator.CanAcceptAssistiveCommand -> EngineToggleAuthority.IsEngineEnabled(Assistive)
```

Current incomplete mode gates:

```text
Cohesion
HorseMarket
Smithing
Companion
```

Those names are present in the authority and mode summary, but their service-level
execution paths are not yet comprehensively gated by the corresponding mode. A
mode label must not be presented as a completed worker integration.

## Verification

The documentation/contract verifiers are:

```text
scripts/verify-engine-toggle-authority-contract.ps1
```

They check that the authority exists, the modes exist, the hotkey exists, the PR #26 duration doctrine is referenced, and the runtime-control boundaries stay visible.

## Safety boundary

Engine mode is not the same thing as runtime PASS.

```text
Build PASS: code compiled.
Verifier PASS: contract text and surface are present.
Runtime PASS: live disposable-save proof.
Visible mechanics PASS: command ack + route set + clock running + positive movement evidence.
```

Do not claim a mechanism has passed merely because the mode was toggled to Automation.

## Agent and script control

The file inbox now dispatches `ShowEngineToggleState`, the three global set commands, and the three targeted MapTrade commands: `SetMapTradeManual`, `SetMapTradeHybrid`, and `SetMapTradeAutomation`.

Unattended MapTrade validation must use the targeted commands. `SetMapTradeAutomation` changes only MapTrade, so a route proof does not silently enable Governor, Smithing, Companion, or another worker. `SetMapTradeManual` requests the same active route hold/abort as the in-game authority and is the required terminal cleanup command for an agent-run proof.

The next implementation sprint should migrate remaining direct readers to authority calls. The targeted command seam does not turn the incomplete Cohesion, HorseMarket, Smithing, or Companion mode gates into runtime PASS.
