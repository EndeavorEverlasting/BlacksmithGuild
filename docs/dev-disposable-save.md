# Dev disposable save — quick forge start

Use a **bundled dev save** to skip New Campaign character creation during daily development.

## One-time setup

1. Start a disposable sandbox campaign with **The Blacksmith Guild** enabled.
2. Play until you reach the campaign map and see `TBG READY`.
3. Save the campaign (any name is fine in-game).
4. Close Bannerlord.
5. Copy that save file to:

```text
Documents\Mount and Blade II Bannerlord\Game Saves\Native\BlacksmithGuild_DevStart.sav
```

The repo does **not** commit `.sav` binaries — only this Documents path is documented.

## Daily dev loop (preferred)

```text
Forge.cmd → launcher → Load BlacksmithGuild_DevStart.sav → TBG READY → F7 / F10 / cert
```

| Step | Action |
|------|--------|
| 1 | Close Bannerlord if open |
| 2 | Double-click **`Forge.cmd`** (or `Ctrl+Shift+B` in Cursor) |
| 3 | Steam → Play → **The Blacksmith Guild** checked |
| 4 | **Load** → `BlacksmithGuild_DevStart.sav` |
| 5 | Wait for `TBG READY: campaign map ready. Press F8 for commands.` |
| 6 | Run dev tests (F7, F10, inbox cert, etc.) |

**PASS target:** map ready in under ~30 seconds, zero character-creation screens.

## Mod checkbox rules

| Save type | Blacksmith Guild |
|-----------|------------------|
| `BlacksmithGuild_DevStart.sav` (dev disposable) | **ON** |
| Legacy / personal saves | **OFF** |

## When to use New Campaign instead

- First-time creation of the dev save (one-time)
- Testing Sprint 003C Phase 2 auto character creation (`DevToolsConfig.AutoSkipCharacterCreation`)
- Verifying a clean sandbox bootstrap after game updates

## Retest checklist

**Phase 1 (load save):**

1. Load `BlacksmithGuild_DevStart.sav`
2. Confirm forge-lit message in log
3. Confirm `TBG READY` on campaign map
4. Press **F7** — status summary appears

**Phase 2 (auto New Campaign — when enabled):**

1. New Sandbox with mod ON
2. No manual character-creation clicks
3. Log shows `[TBG QUICKSTART] transition:` lines
4. In-game notice: `TBG QUICKSTART: default character applied.`
5. Then `TBG READY`

## Output files to analyze

```text
Documents\Mount and Blade II Bannerlord\BlacksmithGuild_Phase1.log
Documents\Mount and Blade II Bannerlord\BlacksmithGuild_Status.json
```

Look for `[TBG QUICKSTART]` transition lines during New Campaign setup, and `[TBG HOTKEY TRACE]` after map ready.
