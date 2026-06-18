# In-game surfaces — see status and run basic tests

Use these three layers while developing on a **disposable campaign** (mod ON).

## Quick workflow

| Goal | Do this |
|------|---------|
| Mod loaded? | **Enter** on campaign map → look for `The forge is lit` |
| Shortcut fired? | Wait for `TBG READY: campaign map ready. Press F8 for commands.` then **Enter** → `TBG F9:` / `TBG F10:` / `TBG F11:` or `TBG … BLOCKED:` in the **lower-left message feed** |
| Cert / session summary? | **F7** → `TBG STATUS:` lines in the message feed |
| New build while game open? | Build may succeed but Client DLL install can be **blocked** (file locked). In-game: `TBG RELOAD: … close Bannerlord …`; **F7** shows `reload=blocked`. After successful install: `reload=pending` — restart Bannerlord |
| List dev commands? | **F8** |
| Full test output? | Tail `BlacksmithGuild_Phase1.log` or `.\forge.ps1 -Check -SkipInstall` |
| Engine sanity (gold/XP)? | **Alt+`** dev console on disposable save only |

---

## Message channels

The Blacksmith Guild uses three separate channels. Do not confuse them.

| Channel | Mechanism | Where it appears | Used for |
|---------|-----------|------------------|----------|
| **In-game message feed** | `InformationManager.DisplayMessage(...)` via `GuildLog` / `InGameNotice` | Lower-left / bottom-left game log (press **Enter** on campaign map to scroll). Colored where supported (green success, yellow blocked/warn, red fail). | F7–F11 shortcut ack, `TBG READY`, results, block reasons, compact status |
| **Windows toast** | PowerShell after forge install | Windows notification area (usually bottom-right) | Build/install/reload reminders when Bannerlord is running |
| **File logs** | Append to disk | `<Bannerlord>\BlacksmithGuild_Phase1.log`, `BlacksmithGuild_Forge.log` | Full diagnostics, certification evidence |

**Not used for normal shortcut feedback:** Bannerlord cheat/developer console (Alt+` — top overlay). Toast alone is not sufficient; in-game feed always gets the primary signal.

---

## In-game feedback location

Shortcut feedback is displayed through Bannerlord's normal in-game message feed (`InformationManager.DisplayMessage`). In the game UI this is the **lower-left / bottom-left message log area** — press **Enter** on the campaign map to open and scroll.

During intro/cinematic or other non-map states, Bannerlord may render the feed differently or less prominently. **Do not certify hotkeys until** you see:

```text
TBG READY: campaign map ready. Press F8 for commands.
```

Gold test does **not** auto-run on DailyTick by default — use **F11** manually after the ready message.

If shortcut keys do not appear to work, first **close any open campaign panels** (Training Field, settlement, encounter, or menu panels). Hotkeys are certified on the **plain campaign map** after the `TBG READY` line appears.

**F7/F8** are diagnostic/help keys (looser gate). **F9/F10/F11** are risky dev keys and may be blocked when the map menu is open or the campaign map is not in a safe state.

If there is no visible response, check `BlacksmithGuild_Phase1.log` for `[TBG HOTKEY TRACE]` and `[TBG COMMAND TRACE]` lines.

**Fallback when F-keys are swallowed by Bannerlord menus:** Ctrl+Alt+7 (status), Ctrl+Alt+8 (commands), Ctrl+Alt+9 (daily tick), Ctrl+Alt+0 (fast-forward), Ctrl+Alt+1 (gold test).

Windows toast notifications are separate (forge install scripts) and may appear in the Windows notification area, usually bottom-right. Toast is **not** used for shortcut feedback.

Full diagnostic detail remains in:

- `BlacksmithGuild_Phase1.log`
- `BlacksmithGuild_Forge.log`

### Shortcut feedback (visible in message feed)

| Key | Expected visible messages |
|-----|---------------------------|
| **F7** | `TBG STATUS: loadedVersion=… dllUtc=… reload=…`; session/preflight/last command; optional cert line |
| **F8** | `TBG COMMANDS` + `F7 Status \| F8 Commands` + `F9 Daily tick \| F10 Fast-forward \| F11 Gold test` + feed hint |
| **F9** | `TBG F9: Daily tick test requested.` → `TBG F9: DailyTick fired.` or `TBG F9 BLOCKED:` / `TBG F9 FAILED:` |
| **F10** | `TBG F10: Fast-forward ON.` / `OFF.` or `TBG F10 BLOCKED:` / `FAILED:` |
| **F11** | `TBG F11: Gold test requested.` → `TBG F11: Gold test PASS, +100000.` or `BLOCKED` / `FAILED` |

If a risky command is blocked, the block reason appears in-game (e.g. `TBG F11 BLOCKED: map menu open — close panel first.`) and in the file log with additional detail.

### Trace-based failure classification

| Log pattern | Classification |
|-------------|----------------|
| No `[TBG HOTKEY TRACE] Campaign tick polling active` | FAIL: hotkey polling not wired |
| Polling active, no `key=F7 detected` after press | FAIL/WARN: input swallowed or wrong key — try Ctrl+Alt+7-1 or close panels |
| Key detected, no `[TBG COMMAND TRACE]` | FAIL: handler → bus wiring |
| Command received, no visible message | FAIL: in-game notice surface |
| F7 shows old `dllUtc` vs Forge build | FAIL: stale DLL loaded — close Bannerlord, run `Forge.cmd`, relaunch |

---

## 1. Bottom-left notice log

| Item | Detail |
|------|--------|
| **Open** | **Enter** on the **campaign map** (not inside a menu) |
| **Scroll** | Mouse wheel while the log is open |
| **Keybind** | Not listed in Bannerlord settings |

### What TBG writes here

Via `GuildLog` / `InGameNotice` → `InformationManager.DisplayMessage`:

- `[The Blacksmith Guild] Mod loaded. The forge is lit.`
- **`TBG READY: campaign map ready. Press F8 for commands.`** (once per session, after stable map)
- Fake forge advisor lines on daily tick
- **F7–F11** shortcut feedback (`TBG STATUS:`, `TBG COMMANDS`, `TBG F9:`, etc.)
- **`TBG RELOAD: …`** when a newer build exists:
  - `installStatus: installed` — new DLL copied; restart Bannerlord to load it
  - `installStatus: blockedByRunningGame` — build ready but Client DLL locked; close Bannerlord, run `Forge.cmd` again

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
| Pending reload marker | `<Bannerlord install>\BlacksmithGuild_PendingReload.json` (`installStatus`: `installed` or `blockedByRunningGame`) |
| Mod log | `<Bannerlord install>\BlacksmithGuild_Phase1.log` |
| Command ack | `<Bannerlord install>\BlacksmithGuild_CommandAck.json` |
| Forge tooling status | `%USERPROFILE%\Documents\Mount and Blade II Bannerlord\BlacksmithGuild_Status.json` |

---

## F7 verdict card (architecture)

**F7 reads summarized state only.** It does not scan, classify, or mutate campaign data.

Future **Treasury Delta Watch** (Sprint 003) will append summary lines from `status.treasuryWatch` once that service exists — see [treasury-delta-watch-plan.md](treasury-delta-watch-plan.md) and [treasury-delta-watch-surfaces.md](treasury-delta-watch-surfaces.md).

Example F7 output today:

```text
TBG STATUS: v0.0.5 session=MapPaused devTools=on reload=clear
TBG STATUS: preflight=Pass last=AdvanceOneDay Success
TBG STATUS: cert=PASS (6/6)
TBG STATUS: reload=blocked — close Bannerlord, run Forge.cmd
```
