# Save compatibility harness

## Purpose

Bannerlord save compatibility is a prelaunch gate. The harness classifies save identity from the file bytes and compares the parsed save version with the exact installed game version before launcher-lifecycle is allowed to reuse a save.

A save name is not compatibility proof. `Disposable`, `DevStart`, and similar names classify intended role only.

## Working surface

- Registry: `.tbg/state/save-compatibility.registry.json`
- Workflow: `.tbg/workflows/save-compatibility-classification.contract.json`
- Artifact registry: `.tbg/harness/save-compatibility-artifacts.registry.json`
- Classifier: `scripts/tbg/Invoke-TbgSaveCompatibility.ps1`
- Validator: `scripts/tbg/Test-TbgSaveCompatibility.ps1`
- Fixtures: `.tbg/harness/fixtures/save-compatibility.fixtures.json`
- One-click test: `core.save-compatibility`

## Classification model

Each save receives two independent classifications.

### Role

- `approved_alias` — one of the canonical BlacksmithGuild dev-save aliases.
- `disposable_candidate` — the name matches tracked disposable/dev naming policy.
- `autosave` — Bannerlord autosave naming.
- `user_or_unclassified` — no automation authority is implied.

### Version compatibility

- `PASS_SAVE_VERSION_EXACT` — parsed save version exactly matches the current exact game version.
- `BLOCKED_SAVE_NEWER_THAN_GAME` — save was produced by a newer game version.
- `ATTENTION_SAVE_OLDER_THAN_GAME_RECERTIFY` — save is older and must be explicitly recertified before automatic reuse.
- `BLOCKED_SAVE_VERSION_UNKNOWN` — no trustworthy version was parsed.
- `BLOCKED_SAVE_VERSION_AMBIGUOUS` — multiple distinct version candidates were found.

The approved alias pair is additionally required to be byte-identical, equal in length, and equal in parsed version.

## Catalog versus gate

`catalog` mode is inventory. It can report a compatible dev save and an incompatible autosave side-by-side without treating the autosave as the selected target.

`gate` mode evaluates one explicit target. Launcher-lifecycle must consume gate mode before acting on an exact-save target.

## Read-only contract

The classifier opens `.sav` files with read access and shared-read/write compatibility. It records SHA-256, size, last-write time, parsed version, and role. It verifies after parsing that bytes, file length, and last-write time are unchanged.

It never:

- launches Bannerlord;
- clicks or dismisses a dialog;
- chooses a save for the operator;
- changes save contents or timestamps;
- copies a save into the repository;
- creates a new campaign/save;
- writes command inbox files.

## New saves

Creating a save belongs to launcher/runtime authority. After a new save is created, the runtime lane hands its path to this classifier. The classifier then records the actual observed bytes, SHA-256, and parsed version. A new save is not automatically trusted merely because it was created by the currently running game.

This lets future disposable/test/real saves carry explicit provenance from creation onward without giving the harness save-mutation authority.

## In-game load boundary

A prelaunch `PASS_SAVE_VERSION_EXACT` is not proof that Bannerlord loaded the file.

The launcher/runtime lane must still prove, in the same correlated run:

1. the exact classified file was selected;
2. the game reported or exposed the same save identity/version at the load boundary;
3. the load completed without a newer-save/version modal;
4. campaign readiness later passed its independent stable-readiness gate.

The harness report may never promote prelaunch parsing into launcher or runtime proof.

## Operator-reported real-file reference, 2026-07-26

The current reported read-only observations are useful regression targets but are not substituted for a tracked local replay:

- `saveauto1.sav`: save `1.4.7.117484` against game `1.4.6.115628` -> expected `BLOCKED_SAVE_NEWER_THAN_GAME`.
- `BlacksmithGuildDevStart.sav` and `Native\BlacksmithGuild_DevStart.sav`: reported byte-identical, save/game `1.4.6.115628`, SHA-256 begins `C472` and ends `9BDC` -> expected exact-match pass when the complete local hash and bytes are replayed.

## Commands

Fixture validation:

```powershell
pwsh -NoProfile -File .\scripts\tbg\Test-TbgSaveCompatibility.ps1
```

Read-only catalog using the current game-compatibility result:

```powershell
pwsh -NoProfile -File .\scripts\tbg\Invoke-TbgSaveCompatibility.ps1 -Mode catalog
```

Explicit target gate:

```powershell
pwsh -NoProfile -File .\scripts\tbg\Invoke-TbgSaveCompatibility.ps1 -Mode gate -TargetSavePath '<exact .sav path>'
```

## Next executable gate

After the harness is merged, run the classifier read-only against the real save files while preserving the existing live session. Compare the complete SHA-256 and parsed versions with the reported observations. Only then may launcher-lifecycle wire the gate into the canonical exact-save route and prove the in-game load boundary on a later clean launch.
