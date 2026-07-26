# Dev disposable save — quick forge start

Use a **bundled dev save** to skip New Campaign character creation during daily development.

## Disposable authority (critical)

Tracked harness policy (`.tbg/harness/policies/disposable-save.policy.json`) approves saves only by:

1. explicit disposable/dev name patterns, or
2. a machine-local active pin under `.local/disposable-save.active.json`

**Calendar year alone is never a shipped product default.** A workstation may optionally enable a gitignored year-floor cohort in `.local/disposable-save.operator.json` for local development only. That file must be disabled or deleted before treating this harness as player-facing save safety.

Preferred sprint pin on this workstation: `BlacksmithGuildDevStart.sav` (also mirrored to `Native\BlacksmithGuild_DevStart.sav` when present).

## Zero-click launch contract (006E)

| Forge entry | Launcher (auto) | In-game (auto) | Use |
|-------------|-----------------|----------------|-----|
| **`Forge.cmd`** | PLAY | New Campaign → SandBox | Bootstrap cert / fresh sandbox |
| **`ForgeContinue.cmd`** | PLAY | Exact approved dev-save Continue | **Daily dev loop** |

```text
Forge.cmd          → zero clicks until map (bootstrap cert)
ForgeContinue.cmd  → launcher PLAY → exact approved dev save → map (daily dev loop)
```

Opt-out: `.\forge.ps1 -Launch -LaunchManual` opens the launcher without UI automation.

Plan: [docs/plans/006e-main-menu-auto-launch.plan.md](plans/006e-main-menu-auto-launch.plan.md) · Cert: [sprint-006e-live-results.md](sprint-006e-live-results.md)

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
ForgeContinue.cmd → launcher PLAY → exact in-game dev-save CONTINUE → map ready
```

| Step | Action |
|------|--------|
| 1 | Close Bannerlord if open |
| 2 | Double-click **`ForgeContinue.cmd`** (build + install + launcher PLAY + exact dev-save load) |
| 3 | Wait for `TBG READY` or `TBG DEVSAVE: map ready` |
| 4 | Run dev tests (F7, inbox cert, etc.) |

**PASS target:** map ready in under ~60s via Continue with **no manual clicks**.

For fresh bootstrap cert, use **`Forge.cmd`** instead (auto PLAY → New Campaign → SandBox).

## New Campaign vs Continue

| Path | Behavior (006C+) |
|------|------------------|
| **Continue** | Launcher selects PLAY; the mod loads only the exact approved dev save at the in-game main menu. A failed exact load does not fall back to vanilla Continue. |
| **New Campaign → SandBox** | Fresh bootstrap: intro skip + auto character creation + 006B auto-build |
| **Play → SandBox** | Same as New Campaign (dev save **not** auto-loaded on `StartNewGame`) |

To re-enable dev-save hijack on Play/New Campaign (legacy 003C behavior), set `DevToolsConfig.AutoLoadDevSaveOnStartNewGame = true`.

The approved physical pair is
`Game Saves\BlacksmithGuildDevStart.sav` and
`Game Saves\Native\BlacksmithGuild_DevStart.sav`. `pin-dev-save.ps1`
requires both files to be byte-identical and never selects an autosave. A
newer-save/version error remains operator-visible; the harness does not
auto-dismiss it.

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
<Bannerlord install root>\BlacksmithGuild_Launch.log
Documents\Mount and Blade II Bannerlord\BlacksmithGuild_Phase1.log
Documents\Mount and Blade II Bannerlord\BlacksmithGuild_Status.json
```

Look for `[TBG QUICKSTART]` transition lines during New Campaign setup, and `[TBG HOTKEY TRACE]` after map ready.
