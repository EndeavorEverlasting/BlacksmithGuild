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
Forge.cmd → launcher opens → Continue → map ready
```

| Step | Action |
|------|--------|
| 1 | Close Bannerlord if open |
| 2 | Double-click **`Forge.cmd`** (build + install + open launcher) |
| 3 | **Continue** — loads `BlacksmithGuild_DevStart*.sav` (pinned as most recent by Forge) |
| 4 | Wait for `TBG READY` or `TBG DEVSAVE: map ready` |
| 5 | Run dev tests (F7, inbox cert, etc.) |

**PASS target:** map ready in under ~60s via Continue.

## New Campaign vs Continue

| Path | Behavior (006C+) |
|------|------------------|
| **Continue** | Loads pinned dev save — daily dev loop |
| **New Campaign → SandBox** | Fresh bootstrap: intro skip + auto character creation + 006B auto-build |
| **Play → SandBox** | Same as New Campaign (dev save **not** auto-loaded on `StartNewGame`) |

To re-enable dev-save hijack on Play/New Campaign (legacy 003C behavior), set `DevToolsConfig.AutoLoadDevSaveOnStartNewGame = true`.

## Mod checkbox rules

| Save type | Blacksmith Guild |
|-----------|------------------|
| `BlacksmithGuild_DevStart.sav` (dev disposable) | **ON** |
| Legacy / personal saves | **OFF** |

**Auto character build:** applies automatically only on **new-game SandBox bootstrap** (no dev save). On **Continue**, run `ApplyAutoCharacterBuild` explicitly via file inbox.

## When to use New Campaign instead

- First-time creation of the dev save (one-time)
- Testing Sprint 006C SandBox intro skip + visible QuickStart bootstrap
- Verifying a clean sandbox bootstrap after game updates

## Retest checklist

**Phase 1 (load save):**

1. Load `BlacksmithGuild_DevStart.sav`
2. Confirm forge-lit message in log
3. Confirm `TBG READY` on campaign map
4. Press **F7** — status summary appears

**Phase 2 (auto New Campaign — when enabled):**

1. New Sandbox with mod ON
2. No manual character-creation clicks; intro cutscene auto-skipped
3. Log shows `[TBG QUICKSTART] transition:` lines
4. In-game notice: at least one `TBG QUICKSTART:` during setup
5. Map ready: `TBG QUICKSTART: sandbox character auto-applied.` then `TBG READY`

## Output files to analyze

```text
Documents\Mount and Blade II Bannerlord\BlacksmithGuild_Phase1.log
Documents\Mount and Blade II Bannerlord\BlacksmithGuild_Status.json
```

Look for `[TBG QUICKSTART]` transition lines during New Campaign setup, and `[TBG HOTKEY TRACE]` after map ready.
