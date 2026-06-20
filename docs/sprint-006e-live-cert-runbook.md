# Sprint 006E Live Certification Runbook

## Purpose

This runbook explains when and how to capture live-cert evidence for Sprint 006E hotfix `v0.0.11`.

006E validates the zero-click launch funnel:

```text
Forge.cmd / ForgeContinue.cmd
→ write launch intent
→ open Bannerlord launcher
→ click PLAY or CONTINUE
→ handle Safe Mode / CAUTION dialogs
→ Bannerlord.exe starts
→ in-game mod consumes launch intent
→ main menu auto-selects New Campaign / SandBox or Continue Campaign
→ QuickStart / intro skip / character creation automation
→ TBG READY
```

The tail commands are evidence collection. They are not the test itself.

Run the tail commands only after a cert attempt reaches success, stalls, requires manual rescue, or crashes.

---

## Cert evidence rule

Run the log tails immediately after one of these outcomes:

| Outcome                                  | When to capture evidence                                                                |
| ---------------------------------------- | --------------------------------------------------------------------------------------- |
| The chain reaches `TBG READY`            | Capture tails immediately after success                                                 |
| The game stalls                          | Capture tails while still stalled, before manual rescue                                 |
| Launcher does not click PLAY or CONTINUE | Capture tails while stuck at the launcher                                               |
| Manual click was required                | Capture tails immediately before or after the manual click, and record what was clicked |
| Bannerlord crashes or closes             | Capture tails immediately after the crash                                               |

Do not capture tails before starting Forge. Pre-run tails are weak evidence.

If the funnel stalls, do not rescue it first. Capture the corpse where it fell. That is the evidence.

---

## Path A: Bootstrap cert

### 1. Start clean

Close Bannerlord and the launcher fully.

Optional process check:

```powershell
Get-Process Bannerlord*, TaleWorlds*, Launcher* -ErrorAction SilentlyContinue
```

If anything is still running, close it before starting the cert attempt.

### 2. Run the actual test

Run:

```text
Forge.cmd
```

Expected chain:

```text
launcher auto-clicks PLAY
→ Bannerlord.exe starts
→ intent = play
→ auto SandBoxNewGame
→ culture selected
→ character creation advances
→ TBG READY
```

### 3. Capture evidence after success or stall

Only after success, stall, manual rescue, or crash, run all four tails in sequence:

```powershell
Get-Content "C:\Program Files (x86)\Steam\steamapps\common\Mount & Blade II Bannerlord\BlacksmithGuild_Launch.log" -Tail 120
Get-Content "C:\Program Files (x86)\Steam\steamapps\common\Mount & Blade II Bannerlord\BlacksmithGuild_Phase1.log" -Tail 200
Get-Content "$env:USERPROFILE\Documents\Mount and Blade II Bannerlord\BlacksmithGuild_Phase1.log" -Tail 200
Get-Content "$env:USERPROFILE\Documents\Mount and Blade II Bannerlord\BlacksmithGuild_Status.json" -Tail 80
```

Paste the output labeled:

```text
PATH A / Forge.cmd
```

---

## Path B: Continue cert

Run Path B only after Path A evidence has been captured.

### 1. Start clean

Close Bannerlord and the launcher fully.

Optional process check:

```powershell
Get-Process Bannerlord*, TaleWorlds*, Launcher* -ErrorAction SilentlyContinue
```

If anything is still running, close it before starting the cert attempt.

### 2. Run the actual test

Run:

```text
ForgeContinue.cmd
```

Expected chain:

```text
launcher auto-clicks CONTINUE
→ Bannerlord.exe starts
→ intent = continue
→ auto ContinueCampaign
→ dev save loads
→ TBG DEVSAVE / TBG READY
```

### 3. Capture evidence after success or stall

Only after success, stall, manual rescue, or crash, run all four tails in sequence:

```powershell
Get-Content "C:\Program Files (x86)\Steam\steamapps\common\Mount & Blade II Bannerlord\BlacksmithGuild_Launch.log" -Tail 120
Get-Content "C:\Program Files (x86)\Steam\steamapps\common\Mount & Blade II Bannerlord\BlacksmithGuild_Phase1.log" -Tail 200
Get-Content "$env:USERPROFILE\Documents\Mount and Blade II Bannerlord\BlacksmithGuild_Phase1.log" -Tail 200
Get-Content "$env:USERPROFILE\Documents\Mount and Blade II Bannerlord\BlacksmithGuild_Status.json" -Tail 80
```

Paste the output labeled:

```text
PATH B / ForgeContinue.cmd
```

---

## Clean certification rhythm

```text
Close Bannerlord
Run Forge.cmd
Wait for READY or stall
Run 4 tails
Paste Path A logs

Close Bannerlord
Run ForgeContinue.cmd
Wait for READY or stall
Run 4 tails
Paste Path B logs
```

---

## Evidence checklist

### Layer A: Launcher automation

Expected evidence:

```text
launcher-auto: clicked PLAY
```

or:

```text
launcher-auto: clicked CONTINUE
```

Also expected:

```text
launcher-auto: Bannerlord.exe detected
```

Fail signals:

```text
launcher-auto never clicks PLAY or CONTINUE
manual click required
Bannerlord.exe never detected
```

### Layer B: In-game launch intent consumption

Path A expected evidence:

```text
[TBG QUICKSTART] launch intent: play
```

Path B expected evidence:

```text
[TBG QUICKSTART] launch intent: continue
```

Fail signals:

```text
40s idle on InitialState
no auto-selecting line after launch intent
LaunchIntent.json remains after successful menu click
```

### Main menu action

Path A expected evidence:

```text
[TBG QUICKSTART] auto-selecting SandBoxNewGame (SandBox).
```

Path B expected evidence:

```text
[TBG QUICKSTART] auto-selecting ContinueCampaign (Continue).
```

Fail signals:

```text
main menu option IDs do not match
no auto-selecting line after launch intent
manual click required
```

### Character creation automation

Path A expected evidence:

```text
[TBG QUICKSTART] culture auto-selected:
[TBG QUICKSTART] transition: CharacterCreation(CharacterCreationCultureStage) -> CharacterCreation(CharacterCreationFaceGeneratorStage)
```

Fail signal:

```text
stage stalled for 5s at CharacterCreationCultureStage
```

### Ready state

Expected evidence:

```text
TBG READY
```

Continue path may also show:

```text
TBG DEVSAVE
```

---

## Gameplay quick notes for rusty cert runs

These notes are for manual orientation during live cert. They are not new sprint scope.

### Where to begin blacksmithing

To reach vanilla Bannerlord smithing manually:

1. Enter a town.
2. Use the town menu.
3. Choose the smithy / enter smithy option.
4. Use the smithing screen for:

   * Smelting
   * Refining
   * Forging

Villages and castles are not the usual smithing entry point. Use towns.

### Smithing stamina basics

Smithing stamina is consumed by smithing actions:

```text
smelting
refining
forging
```

When stamina runs out, the smith cannot keep working until stamina recovers.

### How to recover stamina

Stamina recovery is tied to resting or waiting in a settlement.

Practical loop:

```text
Enter town
Use smithy until stamina is low
Exit smithy
Wait/rest in town
Return to smithy
Repeat
```

Do not assume that traveling around the campaign map restores smithing stamina efficiently. For cert runs, use town waiting when stamina matters.

### How to maximize stamina across the party

Each eligible hero has their own smithing stamina pool.

Practical loop:

```text
Open smithy
Use main character stamina
Switch smith to companion
Use companion stamina
Repeat across available companions
Wait/rest in town
Repeat
```

In the smithy screen, switch the active smith by using the hero portrait / character selector.

This effectively turns one stamina pool into a party-wide stamina rotation.

### Cert discipline

Do not let gameplay cleanup hide automation evidence.

If automation stalls, capture logs before manually continuing.
