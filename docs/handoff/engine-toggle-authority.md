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

Automation mode is for disposable-save testing only. It is not proof of runtime PASS by itself.

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

## Current boundary

This first slice adds the authority and the user hotkey. Existing engine services still use some low-level `DevToolsConfig` booleans, but those booleans are now mutated by the authority when the global mode changes.

The next implementation sprint should migrate direct readers to authority calls, especially:

```text
CampaignRuntimeGovernor.OnCampaignTick -> EngineToggleAuthority.IsAutomationEnabled(Governor)
CampaignRuntimeGovernor.AttachProposedActivity -> EngineToggleAuthority.IsBoundedExecutionAllowed(Governor)
MapTradeAutonomousService.StartRouteNow -> EngineToggleAuthority.IsEngineEnabled(MapTrade)
AutonomousGuildLoopService.StartNow -> EngineToggleAuthority.IsEngineEnabled(GuildLoop)
```

## Verification

The documentation/contract verifier is:

```text
scripts/verify-engine-toggle-authority-contract.ps1
```

It checks that the authority exists, the modes exist, the hotkey exists, and the doctrine stays visible.

## Safety boundary

Engine mode is not the same thing as runtime PASS.

```text
Build PASS: code compiled.
Verifier PASS: contract text and surface are present.
Runtime PASS: live disposable-save proof.
Visible mechanics PASS: command ack + route set + clock running + positive movement evidence.
```

Do not claim a mechanism has passed merely because the mode was toggled to Automation.

## Next sprint

After travel gaps are fixed and visible movement proof is stable, migrate remaining raw config readers to the authority and add file-inbox commands for direct `SetEngineToggleManual`, `SetEngineToggleHybrid`, `SetEngineToggleAutomation`, and `ShowEngineToggleState` once `DevCommandBus` is updated to execute them.
