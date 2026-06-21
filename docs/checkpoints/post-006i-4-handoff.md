# BlacksmithGuild — 006I-4 Quit-to-Menu Fix — Agent Handoff

**Last updated:** 2026-06-21 (Path C USER PASS recorded)  
**HEAD:** `31571e1` — docs: refresh 006I-4 handoff with path glossary and portable paths  
**Fix commits:** `286df1e`, `f318f3a`

---

## Repo state

| Field | Value |
|-------|-------|
| Repo root | [`C:/Users/Cheex/Desktop/dev/Mods/Bannerlord/BlacksmithGuild`](C:/Users/Cheex/Desktop/dev/Mods/Bannerlord/BlacksmithGuild) |
| Remote | `https://github.com/EndeavorEverlasting/BlacksmithGuild.git` |
| Branch | `main` (clean working tree) |
| Ahead of origin | 50 commits — **not pushed** unless user asks |
| Open PRs | None |
| Stale branches | None |

### Build

```powershell
cd C:/Users/Cheex/Desktop/dev/Mods/Bannerlord/BlacksmithGuild
dotnet build -c Release src/BlacksmithGuild/BlacksmithGuild.csproj
```

---

## What “Path A / B / C” mean (006I cert matrix)

These are **named manual test scenarios** from the 006I intro/launcher certification — not file paths, not git branches.

| Path | Plain English | Entry command | What you do in-game | PASS means |
|------|---------------|---------------|---------------------|------------|
| **Path A** | **Zero-click new campaign → map** | [`Forge.cmd`](../../Forge.cmd) at repo root | Run command, wait — do not click launcher or character creation | Land on campaign map with **`TBG READY`**; intro skip **`count=1`** only; character auto-advances; profile applied |
| **Path B** | **Culture Back does not replay intro** | Same as Path A (start fresh with [`Forge.cmd`](../../Forge.cmd)) | During character creation at **culture** stage, press **Back** or **Escape** | No full campaign intro video replay; no stuck cutscene; recover or return safely |
| **Path C** | **Quit to main menu stays on menu** | [`Forge.cmd`](../../Forge.cmd) **or** [`LaunchForgeContinue.cmd`](../../LaunchForgeContinue.cmd) | Reach map (`TBG READY`) → **Pause → Quit to main menu once** | Main menu stays idle — **no** auto SandBox/Continue click, **no** intro trap, **no** Task Manager |
| **Path C-play** | Path C on **new campaign** intent | [`Forge.cmd`](../../Forge.cmd) | As Path C after fresh SandBox bootstrap | Same as Path C; log must not show second `decision=auto-select` for play |
| **Path C-continue** | Path C on **Continue** intent | [`LaunchForgeContinue.cmd`](../../LaunchForgeContinue.cmd) | As Path C after loading existing save | Same as Path C; log must not show second `decision=auto-select` for continue |

**Related (not A/B/C):**

| Name | Meaning | Entry |
|------|---------|-------|
| **Continue load (006I-5)** | Launcher clicks Continue, handles Module Mismatch, reaches map without 5+ min hang | [`LaunchForgeContinue.cmd`](../../LaunchForgeContinue.cmd) |
| **Layer A** | PowerShell launcher automation (PLAY, CAUTION, Safe Mode) | [`scripts/launcher-auto-nav.ps1`](../../scripts/launcher-auto-nav.ps1) — evidence in Launch.log |
| **Layer B** | In-game C# automation (main menu → map) | `MainMenuAutoLauncher.cs` etc. — evidence in Phase1.log |
| **Stage C (Tier 3)** | Headless charcoal refine mutation cert | [`RunStageCCharcoalCert.cmd`](../../RunStageCCharcoalCert.cmd) — separate from 006I paths |

---

## Sprint delivered (2026-06-21)

### Problem fixed

After quit-to-main-menu, `MainMenuAutoLauncher.Poll` re-clicked **Continue** or **SandBox**, reloading the campaign. Root cause: `continue` was exempt from the bootstrap-completed guard; Continue sessions never set `_bootstrapUsed`, so guards never latched.

### Code touched

| File | Change |
|------|--------|
| [`src/BlacksmithGuild/DevTools/QuickStart/MainMenuAutoLauncher.cs`](../../src/BlacksmithGuild/DevTools/QuickStart/MainMenuAutoLauncher.cs) | `_forwardLaunchCompletedThisProcess`; removed continue exemption; `DisarmForSessionEnd()` |
| [`src/BlacksmithGuild/DevTools/QuickStart/CampaignSetupStateTracker.cs`](../../src/BlacksmithGuild/DevTools/QuickStart/CampaignSetupStateTracker.cs) | `ForwardLaunchCompletedThisProcess`, `MarkForwardLaunchCompleted()`, fixed `TryDisarmOnMainMenuReturn`, `_sessionEndDisarmed` |
| [`src/BlacksmithGuild/DevTools/QuickStart/SandboxCampaignIntroSkip.cs`](../../src/BlacksmithGuild/DevTools/QuickStart/SandboxCampaignIntroSkip.cs) | `GameEndPrefix` → session disarm |
| [`src/BlacksmithGuild/Behaviors/BlacksmithGuildCampaignBehavior.cs`](../../src/BlacksmithGuild/Behaviors/BlacksmithGuildCampaignBehavior.cs) | `ResetCampaignMapReadyAnnouncement()` on session end |

### Docs touched

| File | Change |
|------|--------|
| [`docs/plans/006i-4-quit-to-menu-intro-loop.plan.md`](../plans/006i-4-quit-to-menu-intro-loop.plan.md) | Implementation record + Path C smoke table |
| [`docs/forge-zero-click-contract.md`](../forge-zero-click-contract.md) | Quit contract + PASS log signatures |

---

## User cert still required (Tier 2)

~~Path C-play + Path C-continue PENDING.~~

### Path C — **USER PASS 2026-06-21** (user confirmed)

| Path | Verdict | Evidence timestamp |
|------|---------|-------------------|
| Path C-play | **PASS** | 15:36:56 — `session ended`; menu stayed idle |
| Path C-continue | **PASS** | 15:51:12 — `forward launch already completed this process`; no Continue auto-select on quit |

Log file: `C:/Program Files (x86)/Steam/steamapps/common/Mount & Blade II Bannerlord/BlacksmithGuild_Phase1.log`

### Optional regression (when touching related code)

| Path | When to run |
|------|-------------|
| Path A | Any time launcher/intro/creation code changes |
| Path B | Any time `SandboxCampaignIntroSkip.cs` or creation skip changes |
| Continue load (006I-5) | Any time `launcher-auto-nav.ps1` or Module Mismatch code changes |

---

## Runtime log paths (Bannerlord install dir)

Default Steam path (adjust drive if Bannerlord is elsewhere):

| Artifact | Path |
|----------|------|
| Phase1 (primary cert evidence) | `C:/Program Files (x86)/Steam/steamapps/common/Mount & Blade II Bannerlord/BlacksmithGuild_Phase1.log` |
| Launch (Layer A) | `C:/Program Files (x86)/Steam/steamapps/common/Mount & Blade II Bannerlord/BlacksmithGuild_Launch.log` |
| Status snapshot | `C:/Program Files (x86)/Steam/steamapps/common/Mount & Blade II Bannerlord/BlacksmithGuild_Status.json` |
| Launch intent (should be deleted after forward launch) | `C:/Program Files (x86)/Steam/steamapps/common/Mount & Blade II Bannerlord/BlacksmithGuild_LaunchIntent.json` |
| Forge command log | `C:/Program Files (x86)/Steam/steamapps/common/Mount & Blade II Bannerlord/BlacksmithGuild_Forge.log` |

Also check Documents fallback for intent file: `%USERPROFILE%/Documents/Mount and Blade II Bannerlord/BlacksmithGuild_LaunchIntent.json`

### Collect logs (one command)

```powershell
cd C:/Users/Cheex/Desktop/dev/Mods/Bannerlord/BlacksmithGuild
./CollectCertLogs.cmd
```

### Grep Path C evidence

```powershell
Select-String -Path "C:/Program Files (x86)/Steam/steamapps/common/Mount & Blade II Bannerlord/BlacksmithGuild_Phase1.log" -Pattern "main menu intent decision|returned to main menu|Game\.End|forward launch complete|auto-select"
```

**PASS after quit-to-menu:** only `decision=block` with `session ended` / `intent already consumed` / `forward launch already completed` — **no second** `decision=auto-select`.

**FAIL:** second `decision=auto-select`; `launch intent file (...): exists=true` after quit; map reloads without fresh Forge.

---

## Repo entrypoints (markdown paths from repo root)

| Script | Intent | Use for |
|--------|--------|---------|
| [`Forge.cmd`](../../Forge.cmd) | `play` | Daily dev; **Path A**, **Path C-play** |
| [`LaunchForgeContinue.cmd`](../../LaunchForgeContinue.cmd) | `continue` | **Path C-continue**, Continue load cert |
| [`LaunchForge.cmd`](../../LaunchForge.cmd) | `play` | Build + launcher (manual mod checkboxes OK) |
| [`ForgeContinue.cmd`](../../ForgeContinue.cmd) | `continue` | Continue without launcher UI |
| [`ForgeStop.cmd`](../../ForgeStop.cmd) | — | Emergency kill game + launcher + forge shell |
| [`CollectCertLogs.cmd`](../../CollectCertLogs.cmd) | — | Paste block for agent after cert |
| [`RunStageCCharcoalCert.cmd`](../../RunStageCCharcoalCert.cmd) | — | Stage C smithing (Tier 3 — not 006I) |

---

## Known gaps & risks

| Gap / risk | Detail |
|------------|--------|
| **Path C user cert** | **DONE** 2026-06-21 — play + continue USER PASS |
| **Path C-continue is the critical repro** | Old bug was continue-specific; must cert both play and continue |
| **Same-process relaunch by design** | Quit-to-menu stays on menu; new session = full game exit + fresh Forge |
| **50 unpushed commits** | Push when user ready; next feature should branch from clean `main` |
| **Path B not re-tested** | Culture Back guard unchanged; regression possible |
| **Stale sprint-006i-live-results.md** | Still references pre-2026-06-21 continue exemption; treat this checkpoint as authoritative for 006I-4 |

---

## If cert FAILs — inspect first

| Symptom | First file |
|---------|------------|
| Continue replays on quit | [`MainMenuAutoLauncher.cs`](../../src/BlacksmithGuild/DevTools/QuickStart/MainMenuAutoLauncher.cs) |
| SandBox replays on quit | same |
| Intent file survives quit | [`scripts/write-launch-intent.ps1`](../../scripts/write-launch-intent.ps1) vs `GetIntentCandidatePaths()` |
| Intro replay on quit (not menu click) | [`SandboxCampaignIntroSkip.cs`](../../src/BlacksmithGuild/DevTools/QuickStart/SandboxCampaignIntroSkip.cs) |
| Continue never disarms at map | [`CampaignSetupStateTracker.cs`](../../src/BlacksmithGuild/DevTools/QuickStart/CampaignSetupStateTracker.cs) `NotifyCampaignMapReady` |

---

## Scope lock

- No launcher rewrite unless cert proves Layer A failure
- No 005E economics / smithing / evidence JSON changes
- No git push unless user asks

---

## After Path C PASS

1. ~~Update 006I-4 plan → USER PASS~~ **Done 2026-06-21**
2. Update [`docs/sprint-006i-live-results.md`](../sprint-006i-live-results.md) with 2026-06-21 continue re-cert
3. Proceed to [`docs/plans/006j-full-live-cert-closeout.plan.md`](../plans/006j-full-live-cert-closeout.plan.md) (Path B, Layer A handoff, Market F12) or **005E** per user direction
