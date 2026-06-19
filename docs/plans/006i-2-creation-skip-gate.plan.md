---
name: 006I-2 Creation Skip Gate + Launcher Handoff
overview: "006I hotfix (3758335) fixed premature disarm and forward intro skip, but live cert FAILs on launcher timeout and count=2 creation loop. Gate intro skip during CharacterCreation; harden launcher Bannerlord.exe handoff."
todos:
  - id: creation-phase-gate
    content: Gate CleanAndPushState/OnActivate intro skip when Phase is CharacterCreation
    status: completed
  - id: launcher-handoff
    content: Fix launcher-auto-nav Bannerlord.exe handoff when crash reporter blocks or PLAY skipped
    status: completed
  - id: build-and-docs
    content: Build via forge.ps1 PASS; update sprint docs and checkpoint
    status: completed
  - id: live-cert
    content: User runs Forge.cmd Paths A/B/C + launcher handoff cert
    status: pending
isProject: false
---

# Sprint 006I-2 — Creation-Phase Skip Gate + Launcher Handoff

## Verdict

**SHIPPED — LIVE CERT PENDING**

## Repo state

| Field | Value |
|-------|-------|
| Path | `C:\Users\Cheex\Desktop\dev\Mods\Bannerlord\BlacksmithGuild` |
| Remote | `https://github.com/EndeavorEverlasting/BlacksmithGuild.git` |
| Branch | `main` |
| HEAD | `6fb5825` |
| Version | `v0.0.11` |
| Remote sync | 4 commits ahead of `origin/main` — treat local git as authoritative |
| Open PRs | None |
| Working tree | Clean at implementation commit |

## Build status

- `forge.ps1` PASS
- Release DLL installed to Bannerlord Modules
- Live cert Paths A/B/C not yet run

## Sprint status

| Sprint | Status |
|--------|--------|
| 006H | LIVE CERT PASS. Do not regress narrative/bootstrap. |
| 006I hotfix | Partial PASS. Disarm fix and count=1 OnActivate skip confirmed. |
| 006I-2 | SHIPPED. Live cert PENDING. |
| 005E economics | NEXT. No plan file yet. Gated on 006I cert. |

## Shipped (006I-2, commit `6fb5825`)

| Track | File | Change |
|-------|------|--------|
| Creation gate | `SandboxCampaignIntroSkip.cs` | `IsCharacterCreationBootstrapActive()` blocks OnActivate skip; `CleanAndPushStatePostfix` blocks when `Phase == CharacterCreation` |
| Launcher handoff | `launcher-auto-nav.ps1` | 3-poll stable handoff; post-crash-reporter immediate handoff; tightened `HasCrashReporterDialog`; 180s timeout on Safe Mode/crash path; `handoff: <reason>` logging |

## Blockers addressed

### Blocker A — Launcher timeout

**Symptom:** `launcher-auto-nav timed out after 120s` while `Bannerlord.exe` already running.

**Fix:** Hand off when game process is stable (3 polls), launcher gone or Safe Mode/PLAY path taken; immediate handoff after crash reporter No if game running; ignore text-based crash reporter heuristic when game main window present.

### Blocker B — Creation loop (count=2)

**Symptom:** `intro skip via CleanAndPushState (count=2)` during Options → creation resets to culture/narrative.

**Fix:** Block all intro skip hooks while `CampaignSetupStateTracker.Phase == CharacterCreation`. Culture Back still works: Back exits creation → phase becomes IntroVideo → skip allowed.

## Live cert protocol

**Precondition:** Close Bannerlord completely. Confirm no `Bannerlord.exe` or Launcher processes remain.

**Run:**

```powershell
cd C:\Users\Cheex\Desktop\dev\Mods\Bannerlord\BlacksmithGuild
Forge.cmd
```

**Analyze:**

```powershell
Get-Content "C:\Program Files (x86)\Steam\steamapps\common\Mount & Blade II Bannerlord\BlacksmithGuild_Phase1.log" -Tail 80
Get-Content "C:\Program Files (x86)\Steam\steamapps\common\Mount & Blade II Bannerlord\BlacksmithGuild_Launch.log" -Tail 30
Get-Content "C:\Program Files (x86)\Steam\steamapps\common\Mount & Blade II Bannerlord\BlacksmithGuild_Status.json" -Tail 60
```

### Path table

| Path | Cert action | PASS condition |
|------|-------------|----------------|
| Forge exit | Forge.cmd completes launcher handoff | Launch.log has `handoff:` reason, no timeout |
| A | Full bootstrap to map | count=1 only, narrative advances, TBG READY |
| B | Culture stage Back | No full campaign_intro replay |
| C | Pause then Quit | Clean exit from bootstrap/map |

### PASS signatures

- Launch.log contains `handoff:`
- Phase1.log contains `intro skip: campaign video via OnActivate (count=1)`
- Phase1.log contains `TBG READY: campaign map ready`
- No launcher timeout
- No forward-bootstrap `CleanAndPushState (count=2)` before TBG READY
- No Options → Culture narrative restart

### FAIL signatures

- `launcher-auto-nav timed out`
- `intro skip: campaign video via CleanAndPushState (count=2)` during forward bootstrap before TBG READY
- Options → Culture narrative restart
- `bootstrap disarmed: returned to main menu` between auto-select and intro skip

## Out of scope

- 005E economics (gated on 006I cert)
- Module version bump until cert PASS
- Tutorial skip
