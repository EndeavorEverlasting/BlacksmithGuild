# Harness Entrypoint Focus Map

## Purpose

This map exists because route proof cannot depend on the operator keeping Bannerlord foregrounded.

Every runtime entrypoint must declare whether it owns focus, how it selects the Bannerlord PID/window, and whether it is allowed to be used directly for route proof.

## Default rule

```text
Runtime automation should keep Bannerlord focus-owned by default.
The operator should not have to alt-tab back to Bannerlord for automation proof.
```

## PID and window protocol

The canonical runtime detection path is:

```text
Get-BannerlordRootFromRepo
Get-BannerlordProcessDetection
Get-Phase1LogPath
Get-StatusJsonPath
Get-CrashContextJsonPath
```

The focus keeper may use process/window hints only as explicit overrides:

```text
-ProcessIdHint
-WindowHandleHint
```

Fallback window enumeration is allowed only after the canonical process detection path has selected a PID.

## Entrypoint map

| Entrypoint | Role | Focus policy | Route proof status |
|---|---|---|---|
| `ForgeRouteProof.cmd` | Operator route-proof entrypoint | Calls `ForgeReboot.cmd -FocusKeeperMode SyntheticFocusPulse -ActionTimeoutClass long_distance_travel` | Preferred route proof entrypoint |
| `ForgeReboot.cmd` | Operator reboot iteration entrypoint | Delegates to `scripts/run-reboot-iteration.ps1`, whose default `FocusKeeperMode` is `SyntheticFocusPulse` | Allowed for route proof by default |
| `scripts/run-reboot-iteration.ps1` | Reboot coordinator | Routes through `scripts/run-focused-route-proof-session.ps1` whenever `FocusKeeperMode != None` | Allowed for route proof by default |
| `scripts/run-focused-route-proof-session.ps1` | Focus-owned runtime wrapper | Starts `scripts/start-bannerlord-focus-keeper.ps1` beside `scripts/run-autonomous-assist-session.ps1` | Required wrapper for focused route proof |
| `scripts/start-bannerlord-focus-keeper.ps1` | PID/window focus lease | Reuses canonical process detection, then applies `Observe`, `SyntheticFocusPulse`, or `ForegroundLease` | Focus evidence producer |
| `scripts/run-autonomous-assist-session.ps1` | Low-level assist runner | Raw runner with foreground-loss detection; focused proof must wrap it | Not an operator route-proof entrypoint by itself |
| `ForgeStop.cmd` | Stop/cleanup entrypoint | Stop path only; no focus ownership | Required stop path when stopping first |

## Standard feature requirement

`ForgeReboot.cmd` and `ForgeRouteProof.cmd` should not require the operator to keep Bannerlord focused.

The default runtime path is:

```text
ForgeReboot.cmd
  -> scripts/run-reboot-iteration.ps1 -FocusKeeperMode SyntheticFocusPulse
  -> scripts/run-focused-route-proof-session.ps1
  -> scripts/start-bannerlord-focus-keeper.ps1
  -> scripts/run-autonomous-assist-session.ps1
```

The explicit opt-out is:

```text
ForgeReboot.cmd -FocusKeeperMode None
```

Using the opt-out means route proof cannot claim focus ownership from the harness.

## Stop-before-launch rule

When a focused proof should stop the game first, the only accepted path is:

```text
ForgeRouteProof.cmd -StopBeforeLaunch
```

or:

```text
ForgeReboot.cmd -StopBeforeLaunch
```

Both route to:

```text
ForgeStop.cmd soft
```

No focused route proof path should introduce an ad hoc process kill command.

## Direct runner rule

`scripts/run-autonomous-assist-session.ps1` remains a low-level runner so existing harness pieces can compose it.

It is not the operator-facing route-proof entrypoint.

If a future agent wants to use it directly for route proof, it must either:

```text
add native focus-keeper parameters to that runner
```

or:

```text
call it through scripts/run-focused-route-proof-session.ps1
```

## Required verifier

The contract verifier is:

```text
scripts/verify-harness-entrypoint-focus-map.ps1
```

It must fail if:

```text
ForgeReboot stops defaulting to SyntheticFocusPulse
ForgeRouteProof stops routing through ForgeReboot with SyntheticFocusPulse
run-reboot-iteration stops routing focused runs through run-focused-route-proof-session.ps1
run-focused-route-proof-session stops calling start-bannerlord-focus-keeper.ps1
run-focused-route-proof-session stops using ForgeStop.cmd for StopBeforeLaunch
start-bannerlord-focus-keeper stops using Get-BannerlordProcessDetection
```
