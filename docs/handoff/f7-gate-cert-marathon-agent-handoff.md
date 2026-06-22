# F7 Gate + Cert Marathon — Agent Handoff

**Last updated:** 2026-06-22  
**Branch:** `fix/f7-gate-stability` (PR → `main`)  
**Sprint outcome:** Build PASS; F7 gate **FAIL (agent shell)**; Continue cert / Track A/B **NOT RUN**

## What this sprint shipped

1. **Refocus hardening** — `launcher-auto-nav.ps1` post-handoff + after PLAY/CONTINUE/Safe Mode; `run-live-assistive-cert.ps1` `Wait-MapReady`
2. **F7 runner** — `Run-F7GateContinue.cmd` + `scripts/run-f7-gate-continue.ps1` (detached launch, 60s stability, checkpoint manifest)
3. **C# load gates** — no help hotkeys / orchestrator during MapTransition half-ready window
4. **Safe Mode trail** — launch log + manifest `launchSignals.priorSessionCrashLikely`

## Safe Mode = prior crash chain (read Launch.tail)

When the launcher shows **Safe Mode** and automation clicks **No**, treat that as first-class evidence:

| Launch.log signal | Meaning |
|-------------------|---------|
| `Game shut down unexpectedly on previous session` | Engine believes the **prior** run hard-exited |
| `clicked Safe Mode No` / `Safe Mode: No selected` | We kept full mod load (not vanilla Safe Mode) |
| `priorSessionCrashLikely: true` in F7 manifest | Parsed by `Run-F7GateContinue.cmd` |

**Interpretation:** Safe Mode No at the start of a Continue F7 run usually means the **last** session died during load (often MapTransition), not that launcher click wiring failed. Do not classify as sell/smelt/clan failure. Hook-mask bisect applies only if map-ready lines appear **after** Safe Mode dismiss in the same run.

Evidence example: `docs/evidence/live-cert/20260622-011418/` — Safe Mode @ 01:14:43, MapTransition death ~01:15:02, no TBG READY.

**USER path repro (2026-06-22 01:24):** `docs/evidence/live-cert/20260622-012354/` — Safe Mode No, died at MapTransition/MapState, `forwardDone=false`.

**USER path repro post-MapTransition-gate (2026-06-22 01:33, @ `80ffa31`):** `docs/evidence/live-cert/20260622-013214/` — **reached `MapTransition -> MapReady` @ 01:33:23**, then died ~2s later. No `[TBG MAPREADY]`, no TBG READY. Hotkey trace only **after** MapReady (gate worked). **Next: hook-mask bisect on USER terminal** — crash is post-MapReady immediate-hook / hotkey-poll race.

**Agent sprint (2026-06-22 01:44, mask `0x0F` + immediate-hooks gate):** `docs/evidence/live-cert/20260622-014437/` — agent shell stuck `MapTransition`, timeout @ 5m; Cursor foreground stole refocus (`launcher window not found`). **Not comparable to USER MapReady crash** — USER terminal required.

**Agent B C# hardening (`fix/f7-post-mapready-csharp-hardening`, stacked on `fix/f7-gate-stability`):** Per-hook `[TBG MAPREADY] begin/ok/failed` logs; orchestrator entry logging; deferred hooks delayed ≥2 campaign ticks; orchestrator runs before `IsMapLoadTransitionWindow` downstream gate; strict SubModule hotkey gate (`IsSettlementInteriorReady || (IsCampaignMapReady && ImmediateHooksCompleted)`). Build PASS. F7 not run (agent shell). USER verify with `Run-F7GateContinue.cmd -HookMask 0x0F`.

## What shipped this sprint (post-`48cd14f`)

1. **`CampaignMapReadyOrchestrator.ImmediateHooksCompleted`** — set after immediate hooks finish
2. **`SubModule` hotkey gate** — `DevHotkeyHandler.Poll` waits for `ImmediateHooksCompleted` or `ForwardLaunchCompletedThisProcess`
3. **F7 manifest** — records `mapReadyHookMask` from `$env:TBG_MAP_READY_HOOK_MASK`

## F7 gate result (post-fix, agent shell)

| Signal | Value |
|--------|-------|
| Verdict | **FAIL (agent shell — load crash chain, not feature regression)** |
| SessionId | `20260622-011418` |
| Safe Mode | **Yes → No** (`priorSessionCrashLikely`) |
| Phase1 last | `MapTransition` @ 01:15:02; MapState seen, no TBG READY |
| `[TBG MAPREADY]` | Absent |
| Status.json | `campaignReady: false`, `canPollFileInbox: false` |
| Launch.log | CONTINUE verified 01:14:57; process gone ~01:15:03 |
| Runner | `Run-F7GateContinue.cmd` exit **2** |

Evidence: [`docs/evidence/live-cert/20260622-011418/checkpoint-01-f7-gate/`](../evidence/live-cert/20260622-011418/checkpoint-01-f7-gate/)

Prior agent-shell FAIL (pre-fix runner): `20260622-004953/`

## Blocked (do not run until F7 PASS)

```powershell
.\Run-LiveAssistiveCert.cmd -Session continue -SkipLaunch
.\ExportTbgEvidence.cmd
# Track A: Run-VanillaSellCert.cmd on feat/006c-4-sell-loop
# Track B: forge.ps1 -Command RunAutonomousGuildLoopNow on feat/006c-4b-second-leg-travel
```

## Exact next path — USER terminal (preferred)

```powershell
cd C:\Users\Cheex\Desktop\dev\Mods\Bannerlord\BlacksmithGuild
git fetch origin
git checkout fix/f7-gate-stability && git pull
# Close Bannerlord completely; minimize Cursor after launch starts
$env:TBG_MAP_READY_HOOK_MASK = "0x0F"   # immediate hooks only (first bisect)
dotnet build src/BlacksmithGuild/BlacksmithGuild.csproj -c Release
.\Run-F7GateContinue.cmd
# PASS: exit 0 + manifest passFail PASS + stableSeconds >= 60 + [TBG MAPREADY] or TBG READY
.\Run-LiveAssistiveCert.cmd -Session continue -SkipLaunch
.\ExportTbgEvidence.cmd
```

## If USER reaches map-ready but still crashes

```powershell
$env:TBG_MAP_READY_HOOK_MASK = "0x0F"   # immediate hooks only
$env:TBG_MAP_READY_HOOK_MASK = "0x1DF"  # skip TreasuryWatch
$env:TBG_MAP_READY_HOOK_MASK = "0x1BF"  # skip AutoCharacterBuild
```

## Parallel sprints

| Agent | Branch | PR | Gate |
|-------|--------|-----|------|
| **Next (USER verify)** | `fix/f7-gate-stability` | [#7](https://github.com/EndeavorEverlasting/BlacksmithGuild/pull/7) | F7 USER PASS (mask bisect) |
| Agent A | `feat/006c-4-sell-loop` | [#5](https://github.com/EndeavorEverlasting/BlacksmithGuild/pull/5) | F7 + Track A |
| Agent C | `feat/006c-4b-second-leg-travel` | [#6](https://github.com/EndeavorEverlasting/BlacksmithGuild/pull/6) | F7 + Track B |

**Do not merge PR #5/#6 until F7 PASS.**

## Output paths to analyze

| Path | Purpose |
|------|---------|
| `docs/evidence/live-cert/20260622-011418/checkpoint-01-f7-gate/manifest.json` | Post-fix F7 FAIL + Safe Mode |
| `.../Launch.tail.txt` | Safe Mode prompt + CONTINUE handoff |
| `.../Phase1.tail.txt` | MapTransition last signal |
| `docs/evidence/live-cert/20260622-013214/checkpoint-01-f7-gate/` | **USER** MapReady then ~2s crash (pre hotkey gate) |
| `docs/evidence/live-cert/20260622-014437/checkpoint-01-f7-gate/` | Agent shell MapTransition timeout (mask 0x0F) |
| `docs/evidence/live-cert/20260622-002034/` | Pre-fix map-ready then crash |
| `<Bannerlord>/BlacksmithGuild_Phase1.log` | Canonical live trace |
| `<Bannerlord>/BlacksmithGuild_Launch.log` | Process + Safe Mode lifetime |

## Known gaps

- USER F7 PASS not recorded (agent shell cannot validate post-MapReady fix)
- Immediate-hooks hotkey gate shipped — needs USER re-run with mask `0x0F`
- Continue marathon (009A, faction posture, cohesion) blocked
- Track A/B sell-loop blocked
- Agent shell may never PASS F7 (Cursor foreground competitor)
- `[TBG HOTKEY TRACE] Campaign tick polling active` during MapTransition may still appear if `IsCampaignMapReady` flickers true when MapState appears — verify after USER PASS
