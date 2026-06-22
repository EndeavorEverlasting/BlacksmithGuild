# Play Now — Cert Triage Checkpoint

**Date:** 2026-06-22  
**User goal:** Reach gameplay on Continue save; stop optional cert rituals.

---

## Diagnosis: false AnalyzeHorseMarket ACK

`forge.ps1 -Command AnalyzeHorseMarket -Wait` reported `ProbeSmithingRefineApi = Success` because:

1. Game was in `CharacterCreationState` — `canPollFileInbox: false`
2. Stale `BlacksmithGuild_CommandAck.json` matched sequence only (old probe run)
3. Horse market command never executed — no `BlacksmithGuild_HorseMarketIntel.json`

**Fixed in repo:** `Send-ForgeCommand` clears ack before wait and requires `ack.command` match.

---

## Skip (low priority / already PASS)

| Item | Why skip |
|------|----------|
| `RunCharacterBuildVisibleCert.cmd` | Only for certifying new `TBGPersonalAserai001`; not needed to play Continue |
| Catalog / matrix (008C AgentHeadless) | Agent-only; never personal saves |
| `RunStageCCharcoalCert.cmd` | Stage C USER PASS 2026-06-20 |
| `RunStageBSmithingCert.cmd` | Stage B USER PASS 2026-06-21 |
| `AnalyzeHorseMarket` smoke | Tier 1 optional; try on map inside town if curious |
| Sprint 001/002 cert in Status.json | Internal dev harness noise |

---

## Play path (Continue save)

```powershell
cd C:\Users\Cheex\Desktop\dev\Mods\Bannerlord\BlacksmithGuild
.\ForgeStop.cmd
.\ForgeContinue.cmd
```

Confirm map: **F7** → `campaignReady: true`

**Loop:** Ctrl+Alt+M → trade manually → Ctrl+Alt+R or Ctrl+Alt+G → smithy manually

---

## Success criteria

- [ ] Campaign map loaded (not CC / main menu)
- [ ] Ctrl+Alt+M shows ACTION PLAN
- [ ] Trading/crafting in vanilla UI
- [ ] No cert CMD required

---

## Deferred (not blocking play)

- 008C visible personal cert
- 005E-1 horse market USER smoke
- 005E-2 market memory
- Push to origin (65+ commits)
