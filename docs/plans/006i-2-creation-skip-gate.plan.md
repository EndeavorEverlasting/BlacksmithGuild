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
  - id: cert-and-docs
    content: Build, Forge.cmd cert Paths A/B/C + launcher PASS; update sprint-006i-live-results.md
    status: pending
isProject: false
---

# Sprint 006I-2 — Creation-Phase Skip Gate + Launcher Handoff

## Shipped (006I-2)

| Track | File | Change |
|-------|------|--------|
| Creation gate | `SandboxCampaignIntroSkip.cs` | `IsCharacterCreationBootstrapActive()` blocks OnActivate skip; `CleanAndPushStatePostfix` blocks when `Phase == CharacterCreation` |
| Launcher handoff | `launcher-auto-nav.ps1` | Stable-poll handoff; post-crash-reporter immediate handoff; tightened `HasCrashReporterDialog`; 180s timeout on Safe Mode/crash path; handoff reason logging |

## Blockers addressed

### Blocker A — Launcher timeout

**Symptom:** `launcher-auto-nav timed out after 120s` while `Bannerlord.exe` already running.

**Fix:** Hand off when game process is stable (3 polls), launcher gone or Safe Mode/PLAY path taken; immediate handoff after crash reporter No if game running; ignore text-based crash reporter heuristic when game main window present.

### Blocker B — Creation loop (count=2)

**Symptom:** `intro skip via CleanAndPushState (count=2)` during Options → creation resets to culture/narrative.

**Fix:** Block all intro skip hooks while `CampaignSetupStateTracker.Phase == CharacterCreation`. Culture Back still works: Back exits creation → phase becomes IntroVideo → skip allowed.

## Live cert protocol (user)

**Precondition:** Close Bannerlord completely → `Forge.cmd`

| Path | PASS signature |
|------|----------------|
| Forge exit | `handoff:` log line; no launcher timeout |
| A — bootstrap | count=1 only; six narrative menus; `TBG READY` |
| B — culture Back | No full cutscene replay |
| C — Quit | Clean exit bootstrap + map |

### Log paths

```text
C:\Program Files (x86)\Steam\steamapps\common\Mount & Blade II Bannerlord\BlacksmithGuild_Phase1.log
BlacksmithGuild_Launch.log
BlacksmithGuild_Status.json
```

### FAIL signatures (must not recur)

```text
intro skip: campaign video via CleanAndPushState (count=2)   (during Options/creation)
launcher-auto-nav timed out after 120s
Options → Culture → narrative restart loop
```

## Out of scope

- 005E economics
- Module version bump until cert PASS
- Tutorial skip
