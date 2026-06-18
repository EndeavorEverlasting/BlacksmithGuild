# Sprint 001U Live Certification Results

## Verdict

**Live-certified** — 2026-06-18, module version **v0.0.5**

## Environment

| Field | Value |
|-------|-------|
| Campaign | Disposable (mod ON) |
| Map | Plain campaign map, paused |
| In-game date | Summer 1, 1084 |
| Combat Log | Expanded via **Enter** on campaign map |
| DLL | `v0.0.5`, utc `2026-06-18T19:43:38.7068652Z` |

## Screenshot evidence (user-facing behavior)

| Action | Expected message | Observed |
|--------|------------------|----------|
| F9 `AdvanceOneDay` | Daily tick / day advance notice | PASS |
| F10 `ToggleFastForward` | Fast-forward ON, then OFF | PASS (×2) |
| F11 `RichPlayerEconomyTest` | Gold test PASS, +100000 | PASS (×2) |
| Gold total after second F11 | 201,000 (from 1,000 start + 200,000) | PASS |
| Daily Gold Change | 0 (no auto gold on tick) | PASS |

## Certified behaviors

| Check | Result |
|-------|--------|
| F7 `ShowForgeStatus` | PASS |
| F8 `ListScenarios` | PASS |
| F9 `AdvanceOneDay` | PASS |
| F10 `ToggleFastForward` (ON + OFF) | PASS |
| F11 `RichPlayerEconomyTest` (×2) | PASS |
| `TBG READY` map readiness gate | PASS |
| Hotkey trace logging | PASS |
| In-game notice feed (Enter log) | PASS |
| Sprint 001 inbox cert (`certification.overall`) | PASS (6/6) |

## Caveat

After `TBG READY`, **open campaign panels** (e.g. Training Field) may swallow F-keys. Close panels or use **Ctrl+Alt+7–1** fallbacks. The mod logs this explicitly:

```text
[TBG HOTKEY TRACE] READY at menu=training_field_menu; F-keys may be swallowed — use Ctrl+Alt+7-1 or close panel
TBG WARN: Map menu open — close panel for F-keys, or use Ctrl+Alt+7-1.
```

## Engineering record (log excerpts)

Source: `BlacksmithGuild_Phase1.log` (Bannerlord install root), session 2026-06-18 15:44–15:46.

### Startup and readiness

```text
[2026-06-18 15:44:07] [TBG VERSION] Loaded assembly: version=v0.0.5 dllUtc=2026-06-18T19:43:38.7068652Z
[2026-06-18 15:44:19] [The Blacksmith Guild] Mod loaded. The forge is lit.
[2026-06-18 15:45:02] TBG READY: campaign map ready. Press F8 for commands.
[2026-06-18 15:45:02] [TBG HOTKEY TRACE] CanPollHotkeys=true; activeState=MapState; atMenu=true; missionActive=false
```

### F9 — AdvanceOneDay

```text
[2026-06-18 15:46:02] [TBG HOTKEY TRACE] key=F9 detected
[2026-06-18 15:46:02] [TBG TEST] Command received: AdvanceOneDay (source: F9)
[2026-06-18 15:46:02] [TBG TEST] AdvanceOneDay: DailyTick fired.
[2026-06-18 15:46:02] TBG F9: DailyTick fired.
[2026-06-18 15:46:02] [TBG COMMAND TRACE] hotkey=F9 command=AdvanceOneDay result=Success
```

### F10 — ToggleFastForward (×2)

```text
[2026-06-18 15:46:06] [TBG HOTKEY TRACE] key=F10 detected
[2026-06-18 15:46:06] [TBG TEST] ToggleFastForward: ON (unstoppable fast-forward).
[2026-06-18 15:46:06] TBG F10: Fast-forward ON.
[2026-06-18 15:46:06] [TBG COMMAND TRACE] hotkey=F10 command=ToggleFastForward result=Success
[2026-06-18 15:46:06] [TBG HOTKEY TRACE] key=F10 detected
[2026-06-18 15:46:06] [TBG TEST] ToggleFastForward: OFF (time stopped).
[2026-06-18 15:46:06] TBG F10: Fast-forward OFF.
[2026-06-18 15:46:06] [TBG COMMAND TRACE] hotkey=F10 command=ToggleFastForward result=Success
```

### F11 — RichPlayerEconomyTest (×2)

```text
[2026-06-18 15:46:09] [TBG HOTKEY TRACE] key=F11 detected
[2026-06-18 15:46:09] [TBG TEST] Gold before: 1,000
[2026-06-18 15:46:09] [TBG TEST] Gold added: 100,000
[2026-06-18 15:46:09] [TBG TEST] Gold after: 101,000
[2026-06-18 15:46:09] [TBG TEST] PASS
[2026-06-18 15:46:09] TBG F11: Gold test PASS, +100000.
[2026-06-18 15:46:10] [TBG HOTKEY TRACE] key=F11 detected
[2026-06-18 15:46:10] [TBG TEST] Gold before: 101,000
[2026-06-18 15:46:10] [TBG TEST] Gold added: 100,000
[2026-06-18 15:46:10] [TBG TEST] Gold after: 201,000
[2026-06-18 15:46:10] [TBG TEST] PASS
[2026-06-18 15:46:10] TBG F11: Gold test PASS, +100000.
```

## Status JSON evidence

Source: `BlacksmithGuild_Status.json` (Bannerlord install root), 2026-06-18T15:56:29.

```json
"certification": {
  "sprint": "001",
  "overall": "PASS",
  "completed": 6,
  "required": 6
},
"goldTest": {
  "ran": true,
  "passed": true,
  "goldBefore": 101000,
  "goldAfter": 201000,
  "delta": 100000
},
"lastCommand": {
  "name": "RichPlayerEconomyTest",
  "source": "F11",
  "result": "Success"
},
"certification002": {
  "overall": "NOT_STARTED"
}
```

## Proof model

- **Screenshot / in-game messages** = user-facing behavior proof
- **Phase1.log + Status JSON** = engineering record
- If logs disagree with screenshot → treat as **logging regression**, not necessarily hotkey failure

## Failure classification

| Symptom | Likely cause | Action |
|---------|--------------|--------|
| No `TBG READY` | Campaign map not stable | Wait; check MainHero / MapState |
| F-keys silent, log shows `atMenu=true` | Open panel swallowing keys | Close panel or Ctrl+Alt+7–1 |
| Command in log, no in-game message | Notice feed not scrolled | Press **Enter** on map |
| `result=Success` but no gold change | Wrong campaign or blocked preflight | Check `goldTest` in status JSON |
| Hotkey trace missing | Stale DLL or mod not loaded | Close game, `Forge.cmd`, reload campaign |
| `certification.overall` not PASS | Inbox cert not run | `.\forge.ps1 -Certify -Wait` |
