# In-game surfaces — see status and run basic tests

Use these three layers while developing on a **disposable campaign** (mod ON).

## Quick workflow

| Goal | Do this |
|------|---------|
| Mod loaded? | **Enter** on campaign map → look for `The forge is lit` |
| Hotkey worked? | **Enter** → `TBG HOTKEY: … fired` toast |
| Cert / session summary? | **F7** `ShowForgeStatus`, then **Enter** to scroll |
| New build while game open? | Install via Forge.cmd / `dotnet build` → `TBG RELOAD: …` in notice log; **F7** shows `reload=pending` — restart Bannerlord |
| List dev commands? | **F8** |
| Full test output? | Tail `BlacksmithGuild_Phase1.log` or `.\forge.ps1 -Check -SkipInstall` |
| Engine sanity (gold/XP)? | **Alt+`** dev console on disposable save only |

---

## 1. Bottom-left notice log

| Item | Detail |
|------|--------|
| **Open** | **Enter** on the **campaign map** (not inside a menu) |
| **Scroll** | Mouse wheel while the log is open |
| **Keybind** | Not listed in Bannerlord settings |

### What TBG writes here

Via `GuildLog` → `InformationManager.DisplayMessage`:

- `[The Blacksmith Guild] Mod loaded. The forge is lit.`
- Fake forge advisor lines on daily tick
- `TBG HOTKEY: <Command> fired` after F7–F11 / Ctrl+Alt dev keys
- **F7** status lines (`TBG STATUS: …`)
- **`TBG RELOAD: …`** when a newer build was installed while the game is still running (once per install; restart required)

### What is *not* here

Most `[TBG TEST]` detail is **file-only** (`showInGame: false`). Use `BlacksmithGuild_Phase1.log` or status JSON for certification evidence.

---

## 2. Developer console overlay (Alt + `)

| Item | Detail |
|------|--------|
| **Enable (persistent)** | `Documents\Mount and Blade II Bannerlord\Configs\engine_config.txt` → `cheat_mode = 1`, restart game |
| **Enable (session)** | Open console, type `config.cheat_mode 1` |
| **Open / close** | **Alt + `** (US grave/tilde). UK/German layouts: often **Alt + ^** — same physical key |
| **UI** | Text input bar along the **top** of the screen |

### Use for TBG (cross-check only — not certification)

| Console command | When useful |
|-----------------|-------------|
| `config.cheat_mode 1` | Enable if commands are rejected |
| `campaign.change_main_hero_gold 100000` | Sanity-check gold outside F11 / inbox |
| `campaign.add_skill_xp_to_hero Crafting 10000` | Sanity-check smithing XP (verify syntax on your game version) |

**Do not use the console for sprint certification.** Use TBG dev commands + `BlacksmithGuild_Status.json`.

Achievements are disabled with unofficial modules. Console commands can corrupt saves — disposable campaign only.

---

## 3. TBG dev commands (primary harness)

### Hotkeys (game focused, campaign map)

| Key | Command |
|-----|---------|
| **F7** | `ShowForgeStatus` — read-only verdict card (cached state only) |
| **F8** | `ListScenarios` |
| **F9** | `AdvanceOneDay` |
| **F10** | `ToggleFastForward` |
| **F11** | `RichPlayerEconomyTest` |
| **Ctrl+Alt+S** | `RichSmithingProgressionTest` |
| **Ctrl+Alt+X** | `AddSmithingXp` |
| **Ctrl+Alt+C** | `AddSmithingFocus` |
| **Ctrl+Alt+L/D/F** | Legacy list / day / fast-forward |

### File inbox (alt-tab OK)

```powershell
.\forge.ps1 -Certify -Wait              # Sprint 001 (6 checks)
.\forge.ps1 -CertifyProgression -Wait   # Sprint 002 (4 checks)
.\forge.ps1 -Command ShowForgeStatus -Wait
.\forge.ps1 -Check -SkipInstall
```

Inbox path: `<Bannerlord install>\BlacksmithGuild_CommandInbox.json`

### Status and logs on disk

| Artifact | Path |
|----------|------|
| Status JSON | `<Bannerlord install>\BlacksmithGuild_Status.json` |
| Pending reload marker | `<Bannerlord install>\BlacksmithGuild_PendingReload.json` |
| Mod log | `<Bannerlord install>\BlacksmithGuild_Phase1.log` |
| Command ack | `<Bannerlord install>\BlacksmithGuild_CommandAck.json` |
| Forge tooling status | `%USERPROFILE%\Documents\Mount and Blade II Bannerlord\BlacksmithGuild_Status.json` |

---

## F7 verdict card (architecture)

**F7 reads summarized state only.** It does not scan, classify, or mutate campaign data.

Future **Treasury Delta Watch** (Sprint 003) will append summary lines from `status.treasuryWatch` once that service exists — see [treasury-delta-watch-plan.md](treasury-delta-watch-plan.md) and [treasury-delta-watch-surfaces.md](treasury-delta-watch-surfaces.md).

Example F7 output today:

```text
TBG STATUS: cert=PASS (6/6) preflight=Pass
TBG STATUS: last=RichPlayerEconomyTest Success
TBG STATUS: session=MapPaused inbox=ok
TBG STATUS: cert002=PASS (4/4)
TBG STATUS: reload=pending — restart Bannerlord
```
